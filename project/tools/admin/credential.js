/**
 * Admin SDK credentials, resolved the same way `jobs.js` does:
 * FIREBASE_SERVICE_ACCOUNT (JSON text, for CI), then
 * GOOGLE_APPLICATION_CREDENTIALS, then ../scraper/data/serviceAccountKey.json.
 */
const admin = require("firebase-admin");
const fs = require("fs");
const path = require("path");

/**
 * The service account from FIREBASE_SERVICE_ACCOUNT. A parse error is
 * rethrown without its message: Node quotes part of the input in it, and
 * the Actions logs are public.
 */
function parseServiceAccount(text) {
  try {
    return JSON.parse(text);
  } catch {
    throw new Error("FIREBASE_SERVICE_ACCOUNT is not valid JSON.");
  }
}

function loadCredential() {
  if (process.env.FIREBASE_SERVICE_ACCOUNT) {
    return admin.credential.cert(parseServiceAccount(process.env.FIREBASE_SERVICE_ACCOUNT));
  }
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    return admin.credential.applicationDefault();
  }
  const local = path.join(__dirname, "..", "scraper", "data", "serviceAccountKey.json");
  if (fs.existsSync(local)) {
    return admin.credential.cert(require(local));
  }
  throw new Error(
    "No credentials. Set FIREBASE_SERVICE_ACCOUNT or " +
      "GOOGLE_APPLICATION_CREDENTIALS, or place serviceAccountKey.json " +
      "in tools/scraper/data/."
  );
}

function initAdmin() {
  admin.initializeApp({ credential: loadCredential() });
  return admin;
}

module.exports = { initAdmin };
