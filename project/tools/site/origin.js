/**
 * The site's public address, read from `kSiteOrigin` in the app's
 * lib/core/config/site_config.dart: the one line a domain move changes.
 * The static build, the redirect site and the notification emails all
 * read it here, so no script carries its own copy of the address.
 */
const fs = require("fs");
const path = require("path");

const CONFIG = path.resolve(__dirname, "..", "..", "lib", "core", "config", "site_config.dart");

/** The address with no trailing slash. Throws if the constant is missing. */
function siteOrigin(file = CONFIG) {
  const m = /kSiteOrigin\s*=\s*'([^']+)'/.exec(fs.readFileSync(file, "utf8"));
  if (!m) throw new Error(`kSiteOrigin not found in ${file}`);
  return m[1].replace(/\/+$/, "");
}

/** The address Firebase gives the project's default site. It is what
 *  web/index.html names (so `flutter run` has a real canonical), and the
 *  build swaps it for `siteOrigin()` when the two differ. */
const DEFAULT_ORIGIN = "https://paragon-hq.web.app";

module.exports = { siteOrigin, DEFAULT_ORIGIN };
