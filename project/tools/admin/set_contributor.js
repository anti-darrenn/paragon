#!/usr/bin/env node
/**
 * Publishes (or removes) a contributor's public byline: contributors/{uid}.
 *
 *   node set_contributor.js --email=ada@example.com --name="Ada O." \
 *        --role=teacher --credential="A1 Mathematics, WASSCE 2025" [--apply]
 *   node set_contributor.js --email=ada@example.com --remove [--apply]
 *
 * Dry run without --apply. Only run this once the person has agreed to
 * be named and any credential line has been checked: it is shown to every
 * student under every lesson they wrote. Students are minors; use a first
 * name and an initial unless the person asks for more.
 */
const { initAdmin } = require("./credential");

const args = Object.fromEntries(
  process.argv.slice(2).map((a) => {
    const [k, ...v] = a.replace(/^--/, "").split("=");
    return [k, v.length ? v.join("=") : true];
  }),
);

const ROLES = ["student", "teacher", "team"];

/** Pure: the document to write, or an error message. */
function contributorDoc({ name, role, credential }) {
  const displayName = String(name || "").trim();
  if (!displayName || displayName.length > 40) return { error: "--name is required, at most 40 characters" };
  if (!ROLES.includes(role)) return { error: `--role must be one of ${ROLES.join(", ")}` };
  const cred = String(credential || "").trim();
  if (cred.length > 80) return { error: "--credential is at most 80 characters" };
  return { doc: { displayName, role, credential: cred } };
}

async function main() {
  const admin = initAdmin();
  if (!args.email) throw new Error("--email is required");
  const user = await admin.auth().getUserByEmail(args.email);
  const ref = admin.firestore().collection("contributors").doc(user.uid);
  if (args.remove) {
    console.log(`${args.apply ? "Removing" : "Would remove"} the byline for ${args.email} (${user.uid}).`);
    if (args.apply) await ref.delete();
    return;
  }
  const { doc, error } = contributorDoc(args);
  if (error) throw new Error(error);
  console.log(`${args.apply ? "Writing" : "Would write"} contributors/${user.uid}:`, doc);
  if (args.apply) await ref.set(doc);
  if (!args.apply) console.log("Dry run. Re-run with --apply.");
}

if (require.main === module) {
  main()
    .then(() => process.exit(0))
    .catch((e) => {
      console.error(e.message);
      process.exit(1);
    });
}

module.exports = { contributorDoc };
