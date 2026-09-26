#!/usr/bin/env node
/**
 * Applies content-team requests made on the studio's Team page.
 *
 *   node apply_roles.js              # apply pending requests
 *   node apply_roles.js --dry-run    # print what would change
 *
 * The Team page (admins only) writes `staffInvites/{email}`:
 * `{email, role: writer|reviewer|none, subjects: [subjectId…], status}`.
 * Custom claims can only be set with the Admin SDK, which never ships in
 * the app, so this job does it. Run every 15 minutes by
 * `.github/workflows/notify-drafts.yml`, before the email step.
 *
 * For each request still `pending` or `no_account`:
 *   - no account with that email yet → `no_account`, checked again next
 *     run, so it applies as soon as they sign up;
 *   - otherwise the claims become `writer` or `reviewer`, plus `subjects`
 *     when the role is limited to some (absent = every subject). Other
 *     claims, `admin` included, are kept: this job never grants or removes
 *     admin. `none` removes both role claims and the subject limit.
 *     Lowering a role revokes refresh tokens, so an old token stops
 *     working within the hour.
 *
 * The result is written back (`applied`, or `error` with a message) so the
 * Team page shows it. Reads only requests that need work.
 */
const { initAdmin } = require("./credential");

const DRY_RUN = process.argv.includes("--dry-run");

/** The claims a request produces, starting from [current]. Pure, tested. */
function nextClaims(current, role, subjects) {
  const next = { ...current };
  delete next.writer;
  delete next.reviewer;
  delete next.subjects;
  if (role === "writer" || role === "reviewer") {
    next[role] = true;
    if (Array.isArray(subjects) && subjects.length > 0) next.subjects = [...subjects];
  }
  return next;
}

/** Whether [next] can do less than [current] — then old tokens are revoked. */
function isLowered(current, next) {
  const rank = (c) => (c.reviewer ? 2 : c.writer ? 1 : 0);
  if (rank(next) < rank(current)) return true;
  // Gaining a subject limit, or losing subjects from one, is also a loss.
  const was = current.subjects;
  const now = next.subjects;
  if (!was && now) return true;
  if (was && now) return was.some((s) => !now.includes(s));
  return false;
}

async function main() {
  const admin = initAdmin();
  const db = admin.firestore();
  const auth = admin.auth();
  const { FieldValue } = admin.firestore;

  const snap = await db.collection("staffInvites").where("status", "in", ["pending", "no_account"]).get();
  console.log(`${snap.size} team request(s) to apply`);

  for (const doc of snap.docs) {
    const { email, role, subjects } = doc.data();
    const result = { appliedAt: FieldValue.serverTimestamp() };
    try {
      if (!["writer", "reviewer", "none"].includes(role)) {
        throw new Error(`Unknown role "${role}".`);
      }
      const user = await auth.getUserByEmail(email).catch((e) => {
        if (e.code === "auth/user-not-found") return null;
        throw e;
      });
      if (!user) {
        console.log(`${email}: no account yet`);
        if (!DRY_RUN) {
          await doc.ref.update({ status: "no_account", message: "No account uses this email yet." });
        }
        continue;
      }
      const current = user.customClaims || {};
      const next = nextClaims(current, role, subjects);
      const lowered = isLowered(current, next);
      console.log(`${email}: ${JSON.stringify(current)} -> ${JSON.stringify(next)}${lowered ? " (revoking tokens)" : ""}`);
      if (DRY_RUN) continue;
      await auth.setCustomUserClaims(user.uid, next);
      if (lowered) await auth.revokeRefreshTokens(user.uid);
      await doc.ref.update({
        ...result,
        status: "applied",
        uid: user.uid,
        message: "They need to sign out and in again to see it.",
      });
    } catch (e) {
      console.error(`${email}: ${e.message || e}`);
      if (!DRY_RUN) await doc.ref.update({ ...result, status: "error", message: String(e.message || e) });
    }
  }
}

if (require.main === module) {
  main()
    .then(() => process.exit(0))
    .catch((e) => {
      console.error(e.message || e);
      process.exit(1);
    });
}

module.exports = { nextClaims, isLowered };
