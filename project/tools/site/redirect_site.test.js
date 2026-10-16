// node redirect_site.test.js
const assert = require("assert");
const { redirectConfig } = require("./redirect_site");
const { siteOrigin } = require("./origin");

// One 301 rule that keeps the path.
const c = redirectConfig("https://paragon.ng/");
assert.strictEqual(c.hosting.site, "paragon-hq");
assert.deepStrictEqual(c.hosting.redirects, [
  { regex: "^/(.*)$", destination: "https://paragon.ng/:1", type: 301 },
]);

// Redirecting the old site to itself is refused, under either of its names.
assert.throws(() => redirectConfig("https://paragon-hq.web.app"), /being redirected/);
assert.throws(() => redirectConfig("https://paragon-hq.firebaseapp.com"), /being redirected/);
// So is anything that is not a plain https origin.
assert.throws(() => redirectConfig("http://paragon.ng"), /https origin/);
assert.throws(() => redirectConfig("https://paragon.ng/app"), /https origin/);

// The origin is read from the app's config, with no trailing slash.
assert.match(siteOrigin(), /^https:\/\/[^/]+[^/]$/);

console.log("redirect_site: ok");
