#!/usr/bin/env node
/**
 * Emails the content team about lesson-workflow transitions and student
 * problem reports they have not been told about:
 *
 *   submitted for review  → the reviewers (NOTIFY_TO), in one digest
 *                           together with new problem reports
 *   changes requested,
 *   published             → the writer, one email each (see writerEmails
 *                           for the shared-sender limitation)
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
 *   Items   carry `pendingNotice` (set by the studio on each transition,
 *           cleared here). Saving a draft emails nobody; submitting it does.
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

/**
 * Lesson items whose last workflow transition has not been emailed.
 *
 * The studio sets `pendingNotice` to the new status on every transition
 * someone should hear about (docs/CONTENT_ROLES.md) and this job clears it
 * after a successful send, so each transition is emailed once. Queried
 * with `in` on a collection-group field, served by the `pendingNotice`
 * override in firestore.indexes.json. Reads only pending items.
 */
async function pendingNotices(db, auth) {
  const snap = await db
    .collectionGroup("resources")
    .where("pendingNotice", "in", ["in_review", "changes_requested", "published"])
    .get();
  console.log(`${snap.size} workflow notices pending`);

  const topicNames = new Map();
  const emails = new Map();
  const notices = [];
  for (const doc of snap.docs) {
    const d = doc.data();
    if (!topicNames.has(d.topicId)) {
      const topic = await db.collection("topics").doc(d.topicId).get();
      topicNames.set(d.topicId, topic.exists ? topic.data().name : d.topicId);
    }
    const writerUid = d.submittedBy || d.createdBy || null;
    if (writerUid && !emails.has(writerUid)) {
      const user = await auth.getUser(writerUid).catch(() => null);
      emails.set(writerUid, user ? user.email || null : null);
    }
    notices.push({
      ref: doc.ref,
      status: d.pendingNotice,
      title: d.title || "(untitled)",
      topic: topicNames.get(d.topicId),
      link: editorLink(d.topicId, doc.id),
      writerEmail: writerUid ? emails.get(writerUid) : null,
    });
  }
  return notices;
}

const VERDICT = {
  changes_requested: "Changes requested",
  published: "Published",
};

/**
 * One email per writer about their items' verdicts.
 *
 * Resend's shared sender (no NOTIFY_FROM) only delivers to the account's
 * own address, so without a verified domain a writer's email would be
 * refused on every run. Until then the notice goes to NOTIFY_TO, labelled
 * with who it is for, so nothing is lost and the job never fails on it.
 */
function writerEmails(notices) {
  const byWriter = new Map();
  for (const n of notices) {
    if (n.status === "in_review") continue;
    const key = n.writerEmail || "(unknown writer)";
    if (!byWriter.has(key)) byWriter.set(key, []);
    byWriter.get(key).push(n);
  }
  const canReachWriters = Boolean(process.env.NOTIFY_FROM);
  return [...byWriter].map(([writer, items]) => {
    const lines = items.map((n) => `- ${VERDICT[n.status]}: ${n.title} (${n.topic})\n  ${n.link}`);
    const forWho = canReachWriters ? "" : ` (for ${writer})`;
    return {
      to: canReachWriters && writer.includes("@") ? [writer] : TO,
      subject:
        items.length === 1
          ? `${VERDICT[items[0].status]}: ${items[0].title}${forWho}`
          : `${items.length} lesson updates${forWho}`,
      text: ["Your lesson items were reviewed:", "", ...lines, "", `Content studio: ${adminLink()}`].join("\n"),
      html:
        "<p>Your lesson items were reviewed:</p><ul>" +
        items
          .map(
            (n) =>
              `<li><strong>${escapeHtml(VERDICT[n.status])}</strong>: ` +
              `<a href="${escapeHtml(n.link)}">${escapeHtml(n.title)}</a> &mdash; ${escapeHtml(n.topic)}</li>`,
          )
          .join("") +
        `</ul><p><a href="${escapeHtml(adminLink())}">Open the content studio</a></p>`,
      items,
    };
  });
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

function subjectLine(submitted, reports) {
  const parts = [];
  if (submitted.length === 1) parts.push(`Ready for review: ${submitted[0].title}`);
  else if (submitted.length > 1) parts.push(`${submitted.length} items ready for review`);
  if (reports.count > 0) {
    parts.push(`${reports.count} new problem report${reports.count === 1 ? "" : "s"}`);
  }
  return parts.join(", ");
}

/** The reviewers' digest: submitted items and new problem reports. */
function buildEmail(submitted, reports) {
  const text = [];
  const html = [];

  if (submitted.length) {
    text.push(
      "Lesson items submitted for review:",
      "",
      ...submitted.map((d) => `- ${d.title} (${d.topic})\n  ${d.link}`),
      "",
    );
    html.push(
      "<p>Lesson items submitted for review:</p>",
      "<ul>",
      ...submitted.map(
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
    `Content studio: ${adminLink()}`,
    "",
    "Sign in with your content-team account first. If a link lands on the",
    "dashboard, open Settings > Content studio.",
  );
  html.push(
    `<p><a href="${escapeHtml(adminLink())}">Open the content studio</a></p>`,
    `<p style="color:#666">Sign in with your content-team account first. If a link lands on the
    dashboard, open Settings &rsaquo; Content studio.</p>`,
  );

  return { text: text.join("\n"), html: html.join("\n") };
}

async function send(key, to, subject, text, html) {
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
    body: JSON.stringify({ from: FROM, to, subject, text, html }),
  });
  const body = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new Error(`Resend refused the send (HTTP ${res.status}): ${JSON.stringify(body)}`);
  }
  console.log(`Sent "${subject}" to ${to.join(", ")} (id ${body.id})`);
}

async function main() {
  const admin = initAdmin();
  const db = admin.firestore();
  const { FieldValue } = admin.firestore;

  const notices = await pendingNotices(db, admin.auth());
  const reports = await pendingReports(db);
  const submitted = notices.filter((n) => n.status === "in_review");
  const verdicts = writerEmails(notices);
  if (notices.length === 0 && reports.count === 0) return;

  const digest =
    submitted.length || reports.count
      ? { subject: subjectLine(submitted, reports), ...buildEmail(submitted, reports) }
      : null;

  if (DRY_RUN) {
    if (digest) console.log(`\nWould send to ${TO.join(", ")} from ${FROM}\nSubject: ${digest.subject}\n\n${digest.text}`);
    for (const v of verdicts) console.log(`\nWould send to ${v.to.join(", ")}\nSubject: ${v.subject}\n\n${v.text}`);
    return;
  }

  const key = process.env.RESEND_API_KEY;
  if (!key) throw new Error("RESEND_API_KEY is not set. Nothing sent, nothing marked.");

  // Each email is marked sent on its own, only once Resend has accepted
  // it: a refused writer email never blocks the reviewers' digest, and is
  // retried next run.
  if (digest) {
    await send(key, TO, digest.subject, digest.text, digest.html);
    const batch = db.batch();
    for (const n of submitted) batch.update(n.ref, { pendingNotice: FieldValue.delete() });
    if (reports.through) {
      batch.set(db.collection("_meta").doc("notify"), { flagsNotifiedThrough: reports.through }, { merge: true });
    }
    await batch.commit();
  }

  let failures = 0;
  for (const v of verdicts) {
    try {
      await send(key, v.to, v.subject, v.text, v.html);
      const batch = db.batch();
      for (const n of v.items) batch.update(n.ref, { pendingNotice: FieldValue.delete() });
      await batch.commit();
    } catch (e) {
      failures++;
      console.error(e.message || e);
    }
  }
  console.log(`Notified ${submitted.length} submissions, ${notices.length - submitted.length} verdicts, ${reports.count} reports`);
  if (failures) throw new Error(`${failures} writer email(s) failed; they will be retried.`);
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error(e.message || e);
    process.exit(1);
  });
