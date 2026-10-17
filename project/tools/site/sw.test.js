// node sw.test.js — which strategy the service worker uses for what.
const assert = require("assert");
const { routeFor } = require("../../web/paragon_sw.js");

const origin = "https://paragon-hq.web.app";
const r = (path, opts = {}) => routeFor(new URL(path, origin), { origin, ...opts });

// The app's code is always fresh when online.
assert.strictEqual(r("/main.dart.js"), "network-first");
assert.strictEqual(r("/flutter_bootstrap.js"), "network-first");
assert.strictEqual(r("/subject/mathematics/course", { mode: "navigate" }), "network-first");
assert.strictEqual(r("/past-questions/waec/mathematics/2018/"), "network-first");
// Files that never change once published.
assert.strictEqual(r("/past-questions/img/abc.webp"), "cache-first");
assert.strictEqual(routeFor(new URL("https://www.gstatic.com/flutter-canvaskit/x/canvaskit.wasm"), { origin }), "cache-first");
// Everything else of ours: served from cache, refreshed behind.
assert.strictEqual(r("/assets/FontManifest.json"), "stale-revalidate");
// Never touched: Auth, writes, other services, the workers themselves.
assert.strictEqual(r("/__/auth/handler"), null);
assert.strictEqual(r("/main.dart.js", { method: "POST" }), null);
assert.strictEqual(routeFor(new URL("https://firestore.googleapis.com/v1/x"), { origin }), null);
assert.strictEqual(routeFor(new URL("https://www.youtube-nocookie.com/embed/x"), { origin }), null);
assert.strictEqual(r("/paragon_sw.js"), null);

console.log("sw: ok");
