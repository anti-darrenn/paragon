#!/usr/bin/env node
/**
 * Sets an account's content-team role from the command line.
 *
 *   node set_role.js --email=someone@example.com                     # show current claims
 *   node set_role.js --email=someone@example.com --role=writer
 *   node set_role.js --email=someone@example.com --role=reviewer --subjects=Mathematics,Physics
 *   node set_role.js --email=someone@example.com --role=none         # remove from the team
 *
 * Usually you don't need this: admins manage the team from the studio's
 * Team page, applied by apply_roles.js every 15 minutes. This does the same
 * immediately, with the same claim logic (`nextClaims`).
 *
 * `--subjects` limits the role to those subjects, by name or id, comma-
 * separated; leave it out for every subject. `admin` is never touched here
 * (use set_admin_claim.js); an admin already has every reviewer power in
 * every subject. See docs/CONTENT_ROLES.md.
 *
 * A signed-in session sees the change after its token refreshes (within
 * an hour) or on a fresh sign-in. Lowering a role revokes refresh tokens.
 */
const { initAdmin } = require("./credential");
const { nextClaims, isLowered } = require("./apply_roles");

const ROLES = ["writer", "reviewer", "none"];

const args = process.argv.slice(2);
const arg = (name) => {
  const hit = args.find((a) => a.startsWith(`--${name}=`));
  return hit === undefined ? undefined : hit.slice(name.length + 3);
};
const email = arg("email");
const role = arg("role");
const subjectsArg = arg("subjects");

/** Subject names or ids → ids, failing loudly on anything unknown. */
async function resolveSubjects(db, list) {
  const snap = await db.collection("subjects").get();
  const byName = new Map(snap.docs.map((d) => [String(d.data().name || "").toLowerCase(), d.id]));
  const ids = new Set(snap.docs.map((d) => d.id));
  return list.map((raw) => {
    const s = raw.trim();
    if (ids.has(s)) return s;
    const id = byName.get(s.toLowerCase());
    if (!id) throw new Error(`Unknown subject "${s}". Known: ${[...byName.keys()].join(", ")}`);
    return id;
  });
}

async function main() {
  if (!email) throw new Error("Pass --email=<address>.");
  if (role !== undefined && !ROLES.includes(role)) {
    throw new Error(`--role must be one of: ${ROLES.join(", ")}.`);
  }

  const admin = initAdmin();
  const auth = admin.auth();
  const user = await auth.getUserByEmail(email);
  const current = user.customClaims || {};
  console.log(`${email} (uid ${user.uid}) — current claims: ${JSON.stringify(current)}`);
  if (role === undefined) return;

  const subjects = subjectsArg ? await resolveSubjects(admin.firestore(), subjectsArg.split(",")) : [];
  const next = nextClaims(current, role, subjects);
  const lowered = isLowered(current, next);

  await auth.setCustomUserClaims(user.uid, next);
  if (lowered) await auth.revokeRefreshTokens(user.uid);

  console.log(`Set. New claims: ${JSON.stringify(next)}`);
  if (lowered) console.log("Refresh tokens revoked: the old access stops working on next token refresh.");
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error(e.message || e);
    process.exit(1);
  });
