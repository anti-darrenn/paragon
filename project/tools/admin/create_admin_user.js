#!/usr/bin/env node
/**
 * Provisions a content-editor account in one step: Auth user, username
 * reservation, `users/{uid}` document, and the `admin` claim.
 *
 *   node create_admin_user.js --email=x --username=y [--display-name=z]            # dry run
 *   node create_admin_user.js --email=x --username=y [--display-name=z] --commit
 *
 * One-shot and hand-run, like `jobs.js --job=dropstreak`. Refuses to touch
 * an email that already has an account unless --upgrade is passed, which
 * keeps that account and its password and adds the username, display name
 * and claim to it. A username the account already has is never replaced —
 * usernames are permanent.
 *
 * The password is generated here and printed once on --commit. It is not
 * stored anywhere. Change it after first sign-in.
 *
 * Sign in with email and password on /signin. Do NOT use "Continue with
 * Google" with a Gmail address that has a password account: Google is
 * authoritative for gmail.com, and Firebase may replace the password
 * provider with Google's on that sign-in.
 *
 * The user document mirrors what `UserRepository.createUserIfNew` and the
 * onboarding username step write, so the account behaves like any other.
 * `selectedSubjects` is left unset, so onboarding asks for subjects on
 * first sign-in. Nothing here bypasses a rule a real sign-up would face,
 * except by using the Admin SDK to write the same shapes.
 */
const crypto = require("crypto");
const { initAdmin } = require("./credential");

const args = process.argv.slice(2);
const arg = (name) =>
  (args.find((a) => a.startsWith(`--${name}=`)) || "").split("=").slice(1).join("=");
const COMMIT = args.includes("--commit");
const UPGRADE = args.includes("--upgrade");

const email = arg("email").trim();
const username = arg("username").trim();
const displayName = (arg("display-name") || username).trim();
const usernameKey = username.toLowerCase();

function generatePassword() {
  // 18 random bytes -> 24 base64url characters.
  return crypto.randomBytes(18).toString("base64url");
}

async function main() {
  if (!email || !username) {
    throw new Error("Pass --email=<address> and --username=<handle>.");
  }
  // Same constraint the rules enforce on usernames/{key}.
  if (!/^[a-z0-9_]{4,20}$/.test(usernameKey)) {
    throw new Error(`Username "${username}" must be 4-20 of a-z, 0-9, _.`);
  }

  const admin = initAdmin();
  const auth = admin.auth();
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;

  console.log(`Create admin account [${COMMIT ? "COMMIT" : "DRY RUN"}]`);
  console.log(`  email:        ${email}`);
  console.log(`  username:     ${username}  (key ${usernameKey})`);
  console.log(`  display name: ${displayName}`);

  const existing = await auth.getUserByEmail(email).catch((e) => {
    if (e.code === "auth/user-not-found") return null;
    throw e;
  });
  if (existing && !UPGRADE) {
    throw new Error(
      `${email} already has an account (uid ${existing.uid}). ` +
        `Re-run with --upgrade to make that account the admin.`
    );
  }

  const reservation = db.collection("usernames").doc(usernameKey);
  const held = await reservation.get();
  if (held.exists && held.data().uid !== existing?.uid) {
    throw new Error(`Username "${usernameKey}" is already taken. Pick another.`);
  }

  if (existing) {
    await upgrade({ auth, db, FieldValue, user: existing, reservation, held });
    return;
  }

  console.log("  checks passed: email unused, username free");
  if (!COMMIT) {
    console.log("\nDry run. Nothing created. Re-run with --commit.");
    return;
  }

  const password = generatePassword();
  const user = await auth.createUser({ email, password, displayName });
  console.log(`\n  auth user created: uid ${user.uid}`);

  try {
    // create(), not set(): fails if someone claimed the handle since the check.
    await reservation.create({ uid: user.uid, raw: username });
    await db.collection("users").doc(user.uid).set({
      uid: user.uid,
      email,
      displayName,
      isAnonymous: false,
      createdAt: FieldValue.serverTimestamp(),
      username,
      usernameKey,
      updatedAt: FieldValue.serverTimestamp(),
    });
    await auth.setCustomUserClaims(user.uid, { admin: true });
  } catch (e) {
    console.error(
      `\n  FAILED after creating the auth user. Partial state for uid ${user.uid}:` +
        `\n  check usernames/${usernameKey} and users/${user.uid}, or delete the` +
        `\n  auth user in the console and re-run.`
    );
    throw e;
  }

  console.log("  username reserved, user document written, admin claim granted");
  console.log("\n  ── Sign-in details (shown once) ──");
  console.log(`  email:    ${email}`);
  console.log(`  password: ${password}`);
  console.log("\n  Sign in on /signin with email and password, not Google.");
}

async function upgrade({ auth, db, FieldValue, user, reservation, held }) {
  const userRef = db.collection("users").doc(user.uid);
  const data = (await userRef.get()).data() || {};
  const hasUsername = typeof data.username === "string" && data.username.trim() !== "";

  console.log(`  existing account: uid ${user.uid}, password unchanged`);
  console.log(
    hasUsername
      ? `  keeps its username "${data.username}" (permanent)`
      : `  will reserve username "${username}"`
  );
  console.log(`  display name: "${data.displayName || ""}" -> "${displayName}"`);
  console.log(`  claims: ${JSON.stringify(user.customClaims || {})} -> +admin`);

  if (!COMMIT) {
    console.log("\nDry run. Nothing changed. Re-run with --commit.");
    return;
  }

  const update = { displayName, updatedAt: FieldValue.serverTimestamp() };
  if (!hasUsername) {
    if (!held.exists) await reservation.create({ uid: user.uid, raw: username });
    update.username = username;
    update.usernameKey = usernameKey;
  }
  await userRef.set(update, { merge: true });
  await auth.updateUser(user.uid, { displayName });
  await auth.setCustomUserClaims(user.uid, { ...(user.customClaims || {}), admin: true });

  console.log("\n  upgraded: profile written, admin claim granted");
  console.log("  Sign out and back in (or wait up to an hour) for the claim to apply.");
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error(`\n${e.message || e}`);
    process.exit(1);
  });
