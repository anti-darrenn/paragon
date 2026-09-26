#!/usr/bin/env node
/**
 * Sets an account's content-team role: writer, reviewer, or none.
 *
 *   node set_role.js --email=someone@example.com                  # show current claims
 *   node set_role.js --email=someone@example.com --role=writer
 *   node set_role.js --email=someone@example.com --role=reviewer
 *   node set_role.js --email=someone@example.com --role=none      # remove both
 *
 * Roles are custom claims on the Auth token — `writer` and `reviewer` —
 * checked by `isWriter()` / `isReviewer()` in firestore.rules and read by
 * `staffRoleProvider` in the app. No client can grant itself one. See
 * docs/CONTENT_ROLES.md for what each role may do.
 *
 * `admin` is separate and untouched here: use set_admin_claim.js. An admin
 * already has every reviewer power.
 *
 * Other claims are preserved (setCustomUserClaims replaces the whole set,
 * so this merges). A signed-in session sees the change after its token
 * refreshes (within an hour) or on a fresh sign-in. Lowering a role also
 * revokes refresh tokens, so a removed reviewer cannot keep publishing on
 * an old token.
 */
const { initAdmin } = require("./credential");

const ROLES = ["writer", "reviewer", "none"];

const args = process.argv.slice(2);
const arg = (name) => (args.find((a) => a.startsWith(`--${name}=`)) || "").split("=")[1];
const email = arg("email");
const role = arg("role");

async function main() {
  if (!email) throw new Error("Pass --email=<address>.");
  if (role !== undefined && !ROLES.includes(role)) {
    throw new Error(`--role must be one of: ${ROLES.join(", ")}.`);
  }

  const auth = initAdmin().auth();
  const user = await auth.getUserByEmail(email);
  const current = user.customClaims || {};
  console.log(`${email} (uid ${user.uid}) — current claims: ${JSON.stringify(current)}`);
  if (role === undefined) return;

  const next = { ...current };
  delete next.writer;
  delete next.reviewer;
  if (role !== "none") next[role] = true;

  const rank = (c) => (c.reviewer ? 2 : c.writer ? 1 : 0);
  const lowered = rank(next) < rank(current);

  await auth.setCustomUserClaims(user.uid, next);
  if (lowered) await auth.revokeRefreshTokens(user.uid);

  console.log(`Role set to ${role}. New claims: ${JSON.stringify(next)}`);
  if (lowered) console.log("Refresh tokens revoked: the old role stops working on next token refresh.");
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error(e.message || e);
    process.exit(1);
  });
