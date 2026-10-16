#!/usr/bin/env node
/**
 * Read-only checks of production data for the things the rules could not
 * always prevent. Writes nothing.
 *
 *   node security_audit.js
 *
 * What it looks for, and why (docs/audit/SECURITY_2026-10-16.md):
 *   - problem reports or feedback dated in the future, and a notify cursor
 *     in the future: before the rules pinned `createdAt`, one such report
 *     could silence every report email for good;
 *   - every account holding a role claim, and whether its email is
 *     verified: roles were once granted to unverified addresses;
 *   - SVG lesson images that could run or fetch something (svg_safety.js);
 *   - lesson items filed under a topic of another subject: the subject
 *     scope was once checked against the item's own label;
 *   - usernames that pass as Paragon, or held by guest accounts;
 *   - attempts with a source outside the known set, and oversized display
 *     names: the shapes the rules now enforce.
 *
 * Emails are printed masked. Costs a few hundred reads (all users, all
 * usernames, topics and lesson items, SVG images), plus count() queries.
 * Exits 1 when anything needs attention, so it can gate a deploy.
 */
const { initAdmin } = require("./credential");
const { svgProblem } = require("./svg_safety");
const { masked } = require("./apply_roles");

// Mirrors the usernames rule in firestore.rules and UsernameRules.isReserved.
const RESERVED = /(admin|paragon|support|staff|moderator|official|waec|helpdesk|security|system)/;
const RESERVED_EXACT = new Set(["help", "root", "team", "owner"]);
const SOURCES = ["drill", "waec", "test", "exercise", "review", "challenge", "challenge_link"];

let problems = 0;
function finding(line) {
  problems++;
  console.log(`  ! ${line}`);
}
function ok(line) {
  console.log(`  ✓ ${line}`);
}

async function futureDated(db, now) {
  console.log("\nReports and feedback dated in the future");
  for (const collection of ["flags", "feedback"]) {
    const n = (await db.collection(collection).where("createdAt", ">", now).count().get()).data().count;
    if (n) finding(`${n} ${collection} document(s) with createdAt after now`);
    else ok(`${collection}: none`);
  }
  const meta = await db.collection("_meta").doc("notify").get();
  for (const field of ["flagsNotifiedThrough", "feedbackNotifiedThrough"]) {
    const v = meta.exists ? meta.data()[field] : null;
    if (!v) ok(`_meta/notify.${field}: not set`);
    else if (v.toMillis() > now.toMillis()) finding(`_meta/notify.${field} is in the future: ${v.toDate().toISOString()}`);
    else ok(`_meta/notify.${field}: ${v.toDate().toISOString()}`);
  }
}

/** Every auth user, once; reused by the claims and usernames checks. */
async function allUsers(auth) {
  const users = new Map();
  let pageToken;
  do {
    const page = await auth.listUsers(1000, pageToken);
    pageToken = page.pageToken;
    for (const u of page.users) users.set(u.uid, u);
  } while (pageToken);
  return users;
}

function staffClaims(users) {
  console.log("\nAccounts holding a role");
  let n = 0;
  for (const u of users.values()) {
    const c = u.customClaims || {};
    const roles = ["admin", "reviewer", "writer"].filter((r) => c[r] === true);
    if (!roles.length) continue;
    n++;
    const providers = u.providerData.map((p) => p.providerId).join(", ") || "none";
    const scope = Array.isArray(c.subjects) ? ` subjects=${c.subjects.join(",")}` : "";
    const line = `${roles.join("+")}${scope} — uid ${u.uid}, ${masked(u.email || "(no email)")}, providers: ${providers}`;
    if (!u.emailVerified) finding(`${line} — EMAIL NOT VERIFIED`);
    else ok(line);
  }
  if (!n) ok("no role claims at all");
}

async function svgAssets(db) {
  console.log("\nSVG lesson images");
  const snap = await db.collection("lessonAssets").where("mime", "==", "image/svg+xml").get();
  let bad = 0;
  for (const d of snap.docs) {
    const problem = svgProblem(d.data().data || "");
    if (problem) {
      bad++;
      finding(`lessonAssets/${d.id}: ${problem}`);
    }
  }
  if (!bad) ok(`${snap.size} SVG image(s), none unsafe`);
}

async function resourcesInTheirTopics(db) {
  console.log("\nLesson items whose subject differs from their topic's");
  const topics = await db.collection("topics").select("subjectId").get();
  const subjectOf = new Map(topics.docs.map((d) => [d.id, d.data().subjectId]));
  const items = await db.collectionGroup("resources").select("subjectId").get();
  let bad = 0;
  for (const d of items.docs) {
    const topicId = d.ref.parent.parent.id;
    const expected = subjectOf.get(topicId);
    if (expected === undefined) continue; // an orphaned subcollection; not a scope question
    if (d.data().subjectId !== expected) {
      bad++;
      finding(`topics/${topicId}/resources/${d.id}: subjectId "${d.data().subjectId}", topic's "${expected}"`);
    }
  }
  if (!bad) ok(`${items.size} item(s), all in their topic's subject`);
}

async function usernames(db, users) {
  console.log("\nUsernames");
  const snap = await db.collection("usernames").get();
  let bad = 0;
  for (const d of snap.docs) {
    const key = d.id;
    const owner = users.get(d.data().uid);
    if (RESERVED.test(key) || RESERVED_EXACT.has(key)) {
      const staff = owner && owner.customClaims && (owner.customClaims.admin || owner.customClaims.reviewer);
      if (!staff) {
        bad++;
        finding(`"${key}" passes as Paragon, held by uid ${d.data().uid}`);
      }
    }
    if (owner && owner.providerData.length === 0) {
      bad++;
      finding(`"${key}" is held by a guest account (uid ${owner.uid})`);
    }
  }
  if (!bad) ok(`${snap.size} reservation(s), none reserved-looking or held by a guest`);
}

async function shapes(db, users) {
  console.log("\nShapes the rules now enforce");
  const odd = (await db.collection("attempts").where("source", "not-in", SOURCES).count().get()).data().count;
  if (odd) finding(`${odd} attempt(s) with a source outside ${SOURCES.join("/")}`);
  else ok("attempts: every source is a known one");

  const docs = await db.collection("users").select("displayName").get();
  const long = docs.docs.filter((d) => String(d.data().displayName || "").length > 256);
  if (long.length) finding(`${long.length} user(s) with a display name over 256 characters`);
  else ok(`users: ${docs.size} checked, no oversized display names`);
  const strays = docs.docs.filter((d) => !users.has(d.id)).length;
  if (strays) console.log(`  · ${strays} user document(s) with no auth account (the nightly orphans job removes them)`);
}

async function main() {
  const admin = initAdmin();
  const db = admin.firestore();
  const now = admin.firestore.Timestamp.now();
  console.log(`Security audit of production data, ${now.toDate().toISOString()} (read-only)`);

  const users = await allUsers(admin.auth());
  console.log(`${users.size} auth accounts`);

  await futureDated(db, now);
  staffClaims(users);
  await svgAssets(db);
  await resourcesInTheirTopics(db);
  await usernames(db, users);
  await shapes(db, users);

  console.log(problems ? `\n${problems} finding(s) need attention.` : "\nNothing needs attention.");
  process.exit(problems ? 1 : 0);
}

main().catch((e) => {
  console.error(e.message || e);
  process.exit(1);
});
