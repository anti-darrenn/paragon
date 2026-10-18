#!/usr/bin/env node
/**
 * Grants or revokes the `founder` custom claim (2026-10-17).
 *
 *   node set_founder_claim.js --email=someone@example.com            # show current claims
 *   node set_founder_claim.js --email=someone@example.com --grant
 *   node set_founder_claim.js --email=someone@example.com --revoke
 *
 * The founder is an admin who also owns the question bank: vetting
 * questions (only vetted ones reach students), changing any question's
 * subject, topic, source and year, and writing new ones. `isFounder()` in
 * firestore.rules checks the claim **and** `admin`, so granting refuses an
 * account that is not already an admin (set_admin_claim.js first), and
 * needs a verified email, like every grant.
 *
 * Other claims are kept (setCustomUserClaims replaces the whole set).
 * A session sees the change after its token refreshes or a fresh sign-in;
 * revoking also revokes refresh tokens.
 */
const { initAdmin } = require("./credential");
const { grantRefusal } = require("./apply_roles");

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
  if (grant) {
    const refusal = grantRefusal(user, "founder");
    if (refusal) throw new Error(`${email}: ${refusal}`);
    if (current.admin !== true) {
      throw new Error(`${email} is not an admin. Run set_admin_claim.js --grant first.`);
    }
  }

  const next = { ...current };
  if (grant) next.founder = true;
  if (revoke) delete next.founder;

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
