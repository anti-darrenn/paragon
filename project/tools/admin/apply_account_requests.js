#!/usr/bin/env node
/**
 * Carries out requests students make from Settings → Sign-in and security.
 *
 *   node apply_account_requests.js              # apply pending requests
 *   node apply_account_requests.js --dry-run    # print what would happen
 *
 * The app writes `accountRequests/{uid}` — `{type, requestedAt}` — for
 * things only the Admin SDK can do. Run every 15 minutes by
 * `.github/workflows/notify-drafts.yml`, beside `apply_roles.js`.
 *
 * Types:
 *   - `revokeSessions` ("sign out everywhere"): revokes the account's
 *     refresh tokens, so no device can renew its session. Each device
 *     keeps its current ID token until it expires, up to an hour — the
 *     screen says so. The request is deleted once done.
 *
 * A request for an account that no longer exists is simply deleted.
 * Reads only the requests there are, which is nearly always none.
 */
const { initAdmin } = require("./credential");

const DRY_RUN = process.argv.includes("--dry-run");

async function main() {
  const admin = initAdmin();
  const db = admin.firestore();
  const auth = admin.auth();

  const snap = await db.collection("accountRequests").get();
  console.log(`${snap.size} account request(s)`);

  for (const doc of snap.docs) {
    const uid = doc.id;
    const { type } = doc.data();
    try {
      if (type !== "revokeSessions") {
        throw new Error(`Unknown request type "${type}".`);
      }
      const exists = await auth.getUser(uid).then(
        () => true,
        (e) => {
          if (e.code === "auth/user-not-found") return false;
          throw e;
        }
      );
      console.log(`${uid}: ${type}${exists ? "" : " (account gone)"}`);
      if (DRY_RUN) continue;
      if (exists) await auth.revokeRefreshTokens(uid);
      await doc.ref.delete();
    } catch (e) {
      // Left in place, so the next run tries again.
      console.error(`${uid}: ${e.message || e}`);
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
