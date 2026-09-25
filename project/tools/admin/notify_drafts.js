#!/usr/bin/env node
/**
 * Emails the reviewers about Learn drafts they have not been told about.
 *
 *   node notify_drafts.js              # send, then stamp notifiedAt
 *   node notify_drafts.js --dry-run    # print what would be sent
 *
 * Run on a schedule by `.github/workflows/notify-drafts.yml`. There are no
 * Cloud Functions on the Spark plan, so "email when a draft is saved" is
 * "a job that checks every so often", the same trade `jobs.js` makes.
 *
 * One email per run listing every new draft, never one per draft. Each
 * draft is stamped `notifiedAt` only after the send succeeds, so a failed
 * send is retried next run and a successful one is never repeated. Edits
 * to an already-notified draft do not re-send.
 *
 * Env:
 *   RESEND_API_KEY   required unless --dry-run
 *   NOTIFY_FROM      sender, default "Paragon <onboarding@resend.dev>".
 *                    Resend's shared sender only delivers to the address
 *                    the Resend account was registered with; to reach
 *                    anyone else, verify a domain and set this to an
 *                    address on it.
 *   NOTIFY_TO        comma-separated recipients, default both reviewers
 *   APP_URL          default https://paragon-hq.web.app
 */
const { initAdmin } = require("./credential");

const DRY_RUN = process.argv.includes("--dry-run");
const APP_URL = (process.env.APP_URL || "https://paragon-hq.web.app").replace(/\/+$/, "");
const FROM = process.env.NOTIFY_FROM || "Paragon <onboarding@resend.dev>";
const TO = (process.env.NOTIFY_TO || "darrenn.cp@gmail.com,darren.ohiomoba.adm@gmail.com")
  .split(",")
  .map((s) => s.trim())
  .filter(Boolean);

// The app uses Flutter's default hash URL strategy, so routes live after
// `#`. Must match `adminResourcePath` in admin_resource_editor_screen.dart
// (the `/admin/topic/:topicId/resource/:resourceId` route).
const editorLink = (topicId, id) => `${APP_URL}/#/admin/topic/${topicId}/resource/${id}`;
const adminLink = () => `${APP_URL}/#/admin`;

const escapeHtml = (s) =>
  String(s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);

async function main() {
  const admin = initAdmin();
  const db = admin.firestore();

  const snap = await db.collectionGroup("resources").where("status", "==", "draft").get();
  const pending = snap.docs.filter((d) => d.data().notifiedAt == null);
  console.log(`${snap.size} drafts, ${pending.length} not yet notified`);
  if (pending.length === 0) return;

  const topicNames = new Map();
  for (const doc of pending) {
    const topicId = doc.data().topicId;
    if (!topicNames.has(topicId)) {
      const topic = await db.collection("topics").doc(topicId).get();
      topicNames.set(topicId, topic.exists ? topic.data().name : topicId);
    }
  }

  const drafts = pending.map((d) => ({
    ref: d.ref,
    title: d.data().title || "(untitled)",
    topic: topicNames.get(d.data().topicId),
    link: editorLink(d.data().topicId, d.id),
  }));

  const subject =
    drafts.length === 1
      ? `Draft ready for review: ${drafts[0].title}`
      : `${drafts.length} drafts ready for review`;

  const text = [
    "New Learn drafts are waiting for review:",
    "",
    ...drafts.map((d) => `- ${d.title} (${d.topic})\n  ${d.link}`),
    "",
    `All drafts: ${adminLink()}`,
    "",
    "Sign in with the content-editor account first. If a link lands on the",
    "dashboard, open Settings > Content editor.",
  ].join("\n");

  const html = `
    <p>New Learn drafts are waiting for review:</p>
    <ul>
      ${drafts
        .map(
          (d) =>
            `<li><a href="${escapeHtml(d.link)}">${escapeHtml(d.title)}</a> &mdash; ${escapeHtml(d.topic)}</li>`
        )
        .join("\n      ")}
    </ul>
    <p><a href="${escapeHtml(adminLink())}">All drafts</a></p>
    <p style="color:#666">Sign in with the content-editor account first. If a link lands on the
    dashboard, open Settings &rsaquo; Content editor.</p>`;

  if (DRY_RUN) {
    console.log(`\nWould send to ${TO.join(", ")} from ${FROM}\nSubject: ${subject}\n\n${text}`);
    return;
  }

  const key = process.env.RESEND_API_KEY;
  if (!key) throw new Error("RESEND_API_KEY is not set. Nothing sent, nothing stamped.");

  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
    body: JSON.stringify({ from: FROM, to: TO, subject, text, html }),
  });
  const body = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new Error(`Resend refused the send (HTTP ${res.status}): ${JSON.stringify(body)}`);
  }
  console.log(`Sent to ${TO.join(", ")} (id ${body.id})`);

  const batch = db.batch();
  for (const d of drafts) {
    batch.update(d.ref, { notifiedAt: admin.firestore.FieldValue.serverTimestamp() });
  }
  await batch.commit();
  console.log(`Stamped ${drafts.length} drafts as notified`);
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error(e.message || e);
    process.exit(1);
  });
