#!/usr/bin/env node
/**
 * Emails the reviewers about Learn drafts and student problem reports
 * they have not been told about.
 *
 *   node notify_drafts.js              # send, then mark what was sent
 *   node notify_drafts.js --dry-run    # print what would be sent
 *
 * Run on a schedule by `.github/workflows/notify-drafts.yml`. There are no
 * Cloud Functions on the Spark plan, so "email when a draft is saved" is
 * "a job that checks every so often", the same trade `jobs.js` makes.
 *
 * One email per run covering everything new, never one per item. Nothing
 * is marked sent until the send succeeds, so a failed send is retried next
 * run and a successful one is never repeated.
 *
 *   Drafts  are stamped `notifiedAt`. Edits to an already-notified draft
 *           do not re-send.
 *   Reports are tracked by a cursor, `_meta/notify.flagsNotifiedThrough`
 *           (the newest `createdAt` already emailed), not a stamp on each
 *           report. A report without a stamp cannot be queried for — a
 *           missing field matches no filter — so stamping would mean
 *           re-reading every recent report every 15 minutes, ~19k reads a
 *           day against Spark's 50k. The cursor costs one read plus the
 *           new reports. `_meta` matches no rule, so no client can move it.
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

// The first run has no cursor; this bounds how much history it emails.
const MAX_REPORTS = 100;

// Must match `FlagReason` in lib/core/repositories/flag_repository.dart.
const REASONS = {
  wrong_answer: "The marked answer is wrong",
  unclear_question: "The question is unclear or incomplete",
  rendering: "Maths or text doesn't display properly",
  other: "Something else",
};

// The app uses Flutter's default hash URL strategy, so routes live after
// `#`. Must match `adminResourcePath` in admin_resource_editor_screen.dart
// and `adminFlagPath` in admin_flag_screen.dart.
const editorLink = (topicId, id) => `${APP_URL}/#/admin/topic/${topicId}/resource/${id}`;
const flagLink = (questionId) => `${APP_URL}/#/admin/flag/${questionId}`;
const adminLink = () => `${APP_URL}/#/admin`;

const escapeHtml = (s) =>
  String(s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);

/** A question stem as one short line: LaTeX delimiters dropped, clipped. */
const oneLine = (text) => {
  const s = String(text || "")
    .replace(/\\[()[\]]/g, "")
    .replace(/\s+/g, " ")
    .trim();
  return s.length > 90 ? `${s.slice(0, 87)}...` : s || "(no text)";
};

async function pendingDrafts(db) {
  const snap = await db.collectionGroup("resources").where("status", "==", "draft").get();
  const pending = snap.docs.filter((d) => d.data().notifiedAt == null);
  console.log(`${snap.size} drafts, ${pending.length} not yet notified`);

  const topicNames = new Map();
  for (const doc of pending) {
    const topicId = doc.data().topicId;
    if (!topicNames.has(topicId)) {
      const topic = await db.collection("topics").doc(topicId).get();
      topicNames.set(topicId, topic.exists ? topic.data().name : topicId);
    }
  }

  return pending.map((d) => ({
    ref: d.ref,
    title: d.data().title || "(untitled)",
    topic: topicNames.get(d.data().topicId),
    link: editorLink(d.data().topicId, d.id),
  }));
}

/** New reports since the cursor, grouped by question. */
async function pendingReports(db) {
  const meta = await db.collection("_meta").doc("notify").get();
  const cursor = meta.exists ? meta.data().flagsNotifiedThrough : null;

  let query = db.collection("flags").orderBy("createdAt", "asc");
  if (cursor) query = query.where("createdAt", ">", cursor);
  const snap = await query.limit(MAX_REPORTS).get();
  console.log(`${snap.size} problem reports since ${cursor ? cursor.toDate().toISOString() : "the start"}`);
  if (snap.empty) return { questions: [], through: null, count: 0 };

  const byQuestion = new Map();
  for (const doc of snap.docs) {
    const { questionId, reason } = doc.data();
    if (!questionId) continue;
    if (!byQuestion.has(questionId)) byQuestion.set(questionId, []);
    byQuestion.get(questionId).push(REASONS[reason] || REASONS.other);
  }

  const questions = [];
  for (const [questionId, reasons] of byQuestion) {
    const q = await db.collection("questions").doc(questionId).get();
    const counts = new Map();
    for (const r of reasons) counts.set(r, (counts.get(r) || 0) + 1);
    questions.push({
      stem: q.exists ? oneLine(q.data().text) : "(question no longer exists)",
      generated: q.exists && q.data().origin === "ai_generated",
      reasons: [...counts].map(([r, n]) => (n > 1 ? `${n} × ${r}` : r)).join("; "),
      count: reasons.length,
      link: flagLink(questionId),
    });
  }
  questions.sort((a, b) => b.count - a.count);

  return {
    questions,
    count: snap.size,
    // The newest report included. Only reports after it are new next run.
    through: snap.docs[snap.docs.length - 1].data().createdAt,
  };
}

function subjectLine(drafts, reports) {
  const parts = [];
  if (drafts.length === 1) parts.push(`Draft ready for review: ${drafts[0].title}`);
  else if (drafts.length > 1) parts.push(`${drafts.length} drafts ready for review`);
  if (reports.count > 0) {
    parts.push(`${reports.count} new problem report${reports.count === 1 ? "" : "s"}`);
  }
  return parts.join(", ");
}

function buildEmail(drafts, reports) {
  const text = [];
  const html = [];

  if (drafts.length) {
    text.push(
      "New Learn drafts are waiting for review:",
      "",
      ...drafts.map((d) => `- ${d.title} (${d.topic})\n  ${d.link}`),
      "",
    );
    html.push(
      "<p>New Learn drafts are waiting for review:</p>",
      "<ul>",
      ...drafts.map(
        (d) => `<li><a href="${escapeHtml(d.link)}">${escapeHtml(d.title)}</a> &mdash; ${escapeHtml(d.topic)}</li>`,
      ),
      "</ul>",
    );
  }

  if (reports.questions.length) {
    const tag = (q) => (q.generated ? " [generated: check the generator too]" : "");
    text.push(
      "Students reported problems with these questions:",
      "",
      ...reports.questions.map((q) => `- ${q.stem}${tag(q)}\n  ${q.reasons}\n  ${q.link}`),
      "",
    );
    html.push(
      "<p>Students reported problems with these questions:</p>",
      "<ul>",
      ...reports.questions.map(
        (q) =>
          `<li><a href="${escapeHtml(q.link)}">${escapeHtml(q.stem)}</a>${escapeHtml(tag(q))}` +
          `<br><span style="color:#666">${escapeHtml(q.reasons)}</span></li>`,
      ),
      "</ul>",
    );
  }

  text.push(
    `Content editor: ${adminLink()}`,
    "",
    "Sign in with the content-editor account first. If a link lands on the",
    "dashboard, open Settings > Content editor.",
  );
  html.push(
    `<p><a href="${escapeHtml(adminLink())}">Open the content editor</a></p>`,
    `<p style="color:#666">Sign in with the content-editor account first. If a link lands on the
    dashboard, open Settings &rsaquo; Content editor.</p>`,
  );

  return { text: text.join("\n"), html: html.join("\n") };
}

async function main() {
  const admin = initAdmin();
  const db = admin.firestore();

  const drafts = await pendingDrafts(db);
  const reports = await pendingReports(db);
  if (drafts.length === 0 && reports.count === 0) return;

  const subject = subjectLine(drafts, reports);
  const { text, html } = buildEmail(drafts, reports);

  if (DRY_RUN) {
    console.log(`\nWould send to ${TO.join(", ")} from ${FROM}\nSubject: ${subject}\n\n${text}`);
    return;
  }

  const key = process.env.RESEND_API_KEY;
  if (!key) throw new Error("RESEND_API_KEY is not set. Nothing sent, nothing marked.");

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
  if (reports.through) {
    batch.set(db.collection("_meta").doc("notify"), { flagsNotifiedThrough: reports.through }, { merge: true });
  }
  await batch.commit();
  console.log(`Marked ${drafts.length} drafts and ${reports.count} reports as notified`);
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error(e.message || e);
    process.exit(1);
  });
