#!/usr/bin/env node
/**
 * Grants or revokes the `admin` custom claim on an account.
 *
 *   node set_admin_claim.js --email=someone@example.com            # show current claims
 *   node set_admin_claim.js --email=someone@example.com --grant
 *   node set_admin_claim.js --email=someone@example.com --revoke
 *
 * The claim is what `isAdmin()` in firestore.rules checks, and what
 * `isAdminProvider` reads to show the content editor. It lives on the
 * Auth token, not in Firestore, so no client can grant it to itself.
 *
 * Other claims on the account are preserved: setCustomUserClaims replaces
 * the whole set, so this merges rather than overwriting.
 *
 * A signed-in session only sees the change once its ID token refreshes
 * (within an hour) or it signs out and back in. Revoking also revokes
 * refresh tokens, so a removed admin cannot keep writing on an old token
 * for up to an hour.
 */
const { initAdmin } = require("./credential");

const args = process.argv.slice(2);
const email = (args.find((a) => a.startsWith("--email=")) || "").split("=")[1];
const grant = args.includes("--grant");
const revoke = args.includes("--revoke");

async function main() {
  if (!email) throw new Error("Pass --email=<address>.");
  if (grant && revoke) throw new Error("Pass --grant or --revoke, not both.");

  const auth = initAdmin().auth();
  const user = await auth.getUserByEmail(email);
  const current = user.customClaims || {};
  console.log(`${email} (uid ${user.uid}) — current claims: ${JSON.stringify(current)}`);

  if (!grant && !revoke) return;

  const next = { ...current };
  if (grant) next.admin = true;
  if (revoke) delete next.admin;

  await auth.setCustomUserClaims(user.uid, next);
  if (revoke) await auth.revokeRefreshTokens(user.uid);

  console.log(`${grant ? "Granted" : "Revoked"}. New claims: ${JSON.stringify(next)}`);
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error(e.message || e);
    process.exit(1);
  });
