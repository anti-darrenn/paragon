# First-load size

Measured 2026-10-03 on a release build (Flutter 3.47.6), gzip -9 sizes. Firebase Hosting
serves gzip or brotli, and brotli is slightly smaller.

| File | Raw | Gzipped | Notes |
| --- | ---: | ---: | --- |
| `main.dart.js` | 4.99 MB | 1.47 MB | always loaded |
| `main.dart.js_1.part.js` | 0.39 MB | 0.11 MB | deferred: the lesson editor's image upload |
| CanvasKit `chromium/canvaskit.wasm` | 5.43 MB | 2.07 MB | from www.gstatic.com, cached by the browser between visits |
| **First visit** | | **≈ 3.5 MB** | plus fonts, the first Firestore reads and images |

**Rough time to first frame:**

| Connection | Bandwidth | Time |
| --- | ---: | ---: |
| "Fast 3G" | 1.6 Mbit/s | ≈ 18–20 s |
| A good 4G connection | 10 Mbit/s | ≈ 3–4 s |

A second visit revalidates `main.dart.js` (a `304` when the build has not changed;
`firebase.json` sets `no-cache`). CanvasKit comes from the HTTP cache, so a return
visit is a few hundred KB.

## Where the bytes are

These come from source-map attribution of `main.dart.js` (2.86 MB of its 4.99 MB is
mapped; the rest is runtime and names):

- **Flutter framework:** 1,063 KB.
- **Web engine (`dart:_engine`):** 436 KB.
- **Dart runtime:** ~300 KB.
- **The app's own code (`lib/`):** ~430 KB.
  - studio (`features/admin`): 45 KB;
  - study tools: 90 KB;
  - onboarding, account and legal: 40 KB.
- **Packages:**
  - `flutter_math_fork`: 83 KB;
  - the SVG stack (`flutter_svg`, `vector_graphics*`, `xml`, `petitparser`): ~96 KB;
  - riverpod: 37 KB;
  - go_router: 27 KB;
  - Firebase: ~90 KB.

**Conclusion: code splitting is not the lever.** Deferring the whole studio, the study
tools and onboarding would save about 175 KB raw, about 50 KB gzipped: 1–2% of the
first load. The floor is the Flutter engine plus framework.

## Options considered

- **`--wasm` (skwasm renderer).** The `main.dart.wasm` is 1.83 MB gzipped and
  `skwasm.wasm` 1.54 MB, 3.37 MB in total against 3.54 MB. That is about 5% smaller.
  Browsers without WasmGC (iOS Safari, older Android WebViews) fall back to JS
  anyway. **Not adopted**: the saving does not justify a second rendering path to
  test.
- **Self-hosting CanvasKit.** Not adopted. gstatic is a fast CDN, and the browser
  caches it.
- **Adopted (`web/index.html`):**
  - `preconnect` to gstatic, fonts.gstatic, Firestore and Identity Toolkit, which saves
    a TLS handshake each, most of a second apiece on 3G;
  - `preload` of `main.dart.js`, so it starts with the HTML instead of after
    `flutter_bootstrap.js` runs;
  - a splash that reads as a landing page (what Paragon is, which subjects), with a
    "first visit is the slowest" note after 6 s.

## Still to measure in a browser

DevTools → Network → "Fast 3G", cache disabled, open the site. Record the time to
the splash, the time to the first Flutter frame, and the total transferred, on the
production build. Then repeat with the cache enabled for a return visit.

## 2026-10-14: the first-visit extras (Wave D, PLAN.md Phase 4)

The engine and `main.dart.js` are unchanged: about 1.48 MB gzipped, 1,478,689 B after this
wave against 1,479,114 B before. The extras around them, which the table above left as
"plus fonts … and images", were cut. All sizes are gzip -9.

| What | Before | After | How |
| --- | ---: | ---: | --- |
| KaTeX fonts fetched at startup | 21 files | 12 files | `tools/site/trim_fonts.js` removes Caligraphic, Fraktur, SansSerif, Script and Typewriter from the built `FontManifest`. **−140 KB gz** (228 KB raw). The corpus never uses them; control: 66k `\frac` found by the same grep. |
| `paragon_logo.png` (first screen) | 149 KB | 42 KB | Generated at 128 px tall, 2x its largest drawn size, from a full-size source in `tool/logo_source/`. PNG is already compressed, so this is **−107 KB on the wire**. |
| `paragon_logo_light.png` (light theme) | 128 KB | 34 KB | The same. |
| Link-preview image | 113 KB PNG | 50 KB JPEG | Not part of the app's load; it speeds up WhatsApp previews. |
| `google_sign_in` | plugin | removed | It was never imported; sign-in uses `signInWithPopup`. The bundle is unchanged, and there is one plugin less to register. |

That is **about 250 KB less on a first visit (≈ 7%)** and 9 fewer requests, which is
roughly 1.2 s on "Fast 3G". The course catalog, course index and topic pages now show
skeletons (`SkeletonPage`) instead of a spinner on a blank page.

**Still not measured:** Lighthouse on Slow 4G (PLAN P4.1/P4.9). It needs a browser on the
deployed preview; record LCP and transfer here when it is run. The PLAN's "≥ 30% lower"
target can't be met from here. Two-thirds of the first visit is CanvasKit and the
framework, and the levers that move those were measured above and declined:
- `--wasm` is about 5%, with a second rendering path;
- code splitting saves about 50 KB.

The static `/past-questions/` pages (Wave C) are where a first visit can be small: about
40 KB including CSS and the fonts a page uses.
