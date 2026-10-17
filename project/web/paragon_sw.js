/*
 * Paragon's service worker (owner's decision, 2026-10-17): keeps the app
 * shell and what a student has opened, so a repeat visit on a bad
 * connection still starts, and the past-question pages they read stay
 * readable offline. Firestore keeps its own offline cache; this is only
 * the files Hosting serves.
 *
 * Registered from web/index.html. Flutter's own service worker is
 * deprecated, and its stub unregisters whatever is at "/", so
 * web/flutter_bootstrap.js loads the app without it.
 *
 * Strategies, by request (`routeFor`, tested by tools/site/sw.test.js):
 *   network-first   pages, the app's code (main.dart.js, flutter_bootstrap.js,
 *                   version.json): fresh whenever online, the copy when not
 *   cache-first     immutable files (/past-questions/img/, CanvasKit, fonts)
 *   stale-revalidate other same-origin files (assets/, icons, manifest)
 *   none            /__/ (Auth), non-GET, other origins (Firestore, YouTube)
 *
 * Bump VERSION to drop every cached file on the next visit.
 */
const VERSION = "v1";
const SHELL = `paragon-shell-${VERSION}`;
const PAGES = `paragon-pages-${VERSION}`;
const MAX_PAGES = 60;

const CODE = /\/(main\.dart\.js|flutter_bootstrap\.js|flutter\.js|version\.json)$/;
const IMMUTABLE_HOSTS = ["www.gstatic.com", "fonts.gstatic.com"];

/** Which strategy serves [url] (a URL), or null to leave it to the browser. */
function routeFor(url, { method = "GET", mode = "", origin } = {}) {
  if (method !== "GET") return null;
  const sameOrigin = url.origin === origin;
  if (!sameOrigin) {
    return IMMUTABLE_HOSTS.includes(url.hostname) ? "cache-first" : null;
  }
  const path = url.pathname;
  if (path.startsWith("/__/")) return null;
  if (path === "/paragon_sw.js" || path === "/flutter_service_worker.js") return null;
  if (path.startsWith("/past-questions/img/")) return "cache-first";
  if (mode === "navigate" || path.endsWith(".html") || path.endsWith("/")) return "network-first";
  if (CODE.test(path)) return "network-first";
  if (path === "/past-questions/search.json") return "network-first";
  return "stale-revalidate";
}

/** The app's routes all serve index.html; offline, any of them gets it. */
const SHELL_KEY = "/index.html";

/** How long a slow network gets before the cached copy is shown instead
 *  (it still finishes, and refreshes the cache for next time). */
const SLOW_MS = 4000;

async function networkFirst(request, cacheName, event) {
  const cache = await caches.open(cacheName);
  const cached = async () =>
    (await cache.match(request)) ||
    (request.mode === "navigate" ? await caches.match(SHELL_KEY) : undefined);
  const network = fetch(request).then(async (response) => {
    if (response.ok) {
      await cache.put(request, response.clone());
      if (request.mode === "navigate" && !new URL(request.url).pathname.startsWith("/past-questions/")) {
        await cache.put(SHELL_KEY, response.clone());
      }
      if (cacheName === PAGES) await trim(cache, MAX_PAGES);
    }
    return response;
  });
  const hit = await cached();
  if (!hit) return network;
  // A copy exists: the network wins if it answers in time, else the copy.
  event.waitUntil(network.catch(() => {}));
  const slow = new Promise((resolve) => setTimeout(() => resolve(hit), SLOW_MS));
  return Promise.race([network.catch(() => hit), slow]);
}

async function cacheFirst(request) {
  const cache = await caches.open(SHELL);
  const hit = await cache.match(request);
  if (hit) return hit;
  const response = await fetch(request);
  if (response.ok || response.type === "opaque") await cache.put(request, response.clone());
  return response;
}

async function staleRevalidate(request, event) {
  const cache = await caches.open(SHELL);
  const hit = await cache.match(request);
  const refresh = fetch(request).then(async (response) => {
    if (response.ok) await cache.put(request, response.clone());
    return response;
  });
  if (hit) {
    event.waitUntil(refresh.catch(() => {}));
    return hit;
  }
  return refresh;
}

/** Keeps the page cache to its newest [max] entries. */
async function trim(cache, max) {
  const keys = await cache.keys();
  for (const k of keys.slice(0, Math.max(0, keys.length - max))) await cache.delete(k);
}

if (typeof self !== "undefined" && typeof self.addEventListener === "function") {
  // The page that registers this worker loaded before it existed, so it
  // never passed through the fetch handler: without this, the shell would
  // not be cached until a second visit, and a first offline reload would
  // fail (it did, in testing). The browser has just downloaded these, so
  // they come from its HTTP cache. One missing file must not stop the rest.
  self.addEventListener("install", (event) => {
    self.skipWaiting();
    event.waitUntil(
      caches.open(SHELL).then((cache) =>
        Promise.all(
          [SHELL_KEY, "/flutter_bootstrap.js", "/main.dart.js", "/manifest.json"].map((path) =>
            cache.add(path).catch(() => {}),
          ),
        ),
      ),
    );
  });

  self.addEventListener("activate", (event) => {
    event.waitUntil(
      (async () => {
        const keep = new Set([SHELL, PAGES]);
        for (const name of await caches.keys()) {
          if (name.startsWith("paragon-") && !keep.has(name)) await caches.delete(name);
        }
        await self.clients.claim();
      })(),
    );
  });

  self.addEventListener("fetch", (event) => {
    const request = event.request;
    const url = new URL(request.url);
    const route = routeFor(url, {
      method: request.method,
      mode: request.mode,
      origin: self.location.origin,
    });
    if (!route) return;
    const pages = url.pathname.startsWith("/past-questions/") ? PAGES : SHELL;
    event.respondWith(
      route === "network-first"
        ? networkFirst(request, pages, event)
        : route === "cache-first"
          ? cacheFirst(request)
          : staleRevalidate(request, event),
    );
  });
}

if (typeof module !== "undefined") module.exports = { routeFor, VERSION };
