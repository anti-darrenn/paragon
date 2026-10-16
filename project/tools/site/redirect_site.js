/**
 * Writes the Hosting site that 301-redirects the old address to the custom
 * domain, path and query kept. Hosting cannot redirect by hostname inside
 * one site, so after a domain move the app is served from a new site and
 * the old one (`paragon-hq`, which answers on paragon-hq.web.app and
 * paragon-hq.firebaseapp.com) carries only this. docs/DOMAIN_SETUP.md is
 * the whole procedure.
 *
 *   node tools/site/redirect_site.js            # target: kSiteOrigin
 *   node tools/site/redirect_site.js --to=https://paragon.ng
 *   firebase deploy --only hosting --config build/redirect/firebase.json
 *
 * Refuses while the target is still the old address: that config would
 * redirect the site to itself.
 */
const fs = require("fs");
const path = require("path");
const { siteOrigin, DEFAULT_ORIGIN } = require("./origin");

/** The redirect site's firebase.json for `target` (no trailing slash). */
function redirectConfig(target, site = "paragon-hq") {
  const to = String(target).replace(/\/+$/, "");
  if (!/^https:\/\/[a-z0-9.-]+\.[a-z]{2,}$/i.test(to)) {
    throw new Error(`Not an https origin: ${target}`);
  }
  if (to === DEFAULT_ORIGIN || to.endsWith(`//${site}.web.app`) || to.endsWith(`//${site}.firebaseapp.com`)) {
    throw new Error(`${to} is the site being redirected; set kSiteOrigin to the custom domain first.`);
  }
  return {
    hosting: {
      site,
      public: "public",
      // `/__/` is Hosting's reserved namespace (the Auth handler lives
      // there). DOMAIN_SETUP.md moves `authDomain` to the new domain so
      // sign-in never depends on this site, and checks /__/auth/handler
      // with curl after the deploy.
      redirects: [{ regex: "^/(.*)$", destination: `${to}/:1`, type: 301 }],
    },
  };
}

if (require.main === module) {
  const args = Object.fromEntries(
    process.argv.slice(2).map((a) => {
      const [k, v] = a.replace(/^--/, "").split("=");
      return [k, v ?? true];
    }),
  );
  const target = args.to || siteOrigin();
  const out = path.resolve(__dirname, "..", "..", args.out || "build/redirect");
  const config = redirectConfig(target, args.site || "paragon-hq");
  fs.mkdirSync(path.join(out, "public"), { recursive: true });
  fs.writeFileSync(path.join(out, "firebase.json"), JSON.stringify(config, null, 2) + "\n");
  // Hosting wants a public folder; nothing in it is ever served.
  fs.writeFileSync(path.join(out, "public", "index.html"), `<!doctype html><meta http-equiv="refresh" content="0;url=${target}/">\n`);
  console.log(`Wrote ${path.relative(process.cwd(), out)}: every path → ${target}/…`);
}

module.exports = { redirectConfig };
