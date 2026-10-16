# Moving Paragon to a custom domain

The code is ready: the address is one constant, and the redirect site is generated. The
steps below are the owner's, in order. `<domain>` is the new address, for example
`paragon.ng`. Nothing here changes until step 4.

**Why two Hosting sites.** Hosting cannot redirect by hostname inside one site. Today the
app is the project's default site, `paragon-hq`, which answers on `paragon-hq.web.app`
and `paragon-hq.firebaseapp.com`. After the move:
- the app is served by a **new** site that carries the custom domain;
- `paragon-hq` serves only a 301 to the same path on `<domain>`.

## 1. Buy the domain

Use a registrar whose account the owner controls. Claude Code never holds it.

## 2. Create the app's new site and check it (nothing visible changes)

From `project/`:

```powershell
firebase hosting:sites:create paragon-app   # any free name; it becomes paragon-app.web.app
```

1. Add `"site": "paragon-app"` to the `hosting` block in `firebase.json`.
2. Build and deploy exactly as usual:
   ```powershell
   flutter build web --release; node tools/site/build_static_site.js; firebase deploy --only hosting
   ```
3. Check that `https://paragon-app.web.app` works, including `/past-questions/`.
4. Do not test sign-in there yet: that domain is not authorised.

## 3. Attach the domain to the new site

1. Go to Firebase console → Hosting → **paragon-app** → **Add custom domain**.
2. Add `<domain>`.
3. Add `www.<domain>`, set to **redirect** to `<domain>`.
4. At the registrar, add the TXT verification record and the A records the console shows.
5. Wait until both domains say **Connected**. The SSL certificate can take up to a day.

## 4. Point the app at the domain

These steps all ship in one PR:

- **`kSiteOrigin`** in `lib/core/config/site_config.dart` becomes `https://<domain>`. Three
  things follow from it:
  - the static pages, sitemap and `robots.txt` (on the next build);
  - the built `index.html`'s canonical and share tags;
  - the email links (`tools/admin/notify_drafts.js` reads it through
    `tools/site/origin.js`).
- **The Auth domain.** In `lib/firebase_options.dart`, set `authDomain: '<domain>'` on
  web. Every Hosting site in the project serves `/__/auth/handler`, so sign-in then
  stays on the app's own origin. It no longer depends on `paragon-hq.firebaseapp.com`,
  which step 6 redirects. Leave the CSP's `paragon-hq.firebaseapp.com` entries until
  step 6 has been checked.
- **Contact addresses.** In `lib/core/legal/legal_documents.dart`, change
  `contactEmail` and `contactEmailCc` to the domain addresses once forwarding works
  (step 7). The About, Support, account and legal pages, and the static privacy page,
  all read them.

Then make these console changes, all **before** deploying:

| Where | Add |
|---|---|
| Firebase → Authentication → Settings → Authorised domains | `<domain>` |
| Google Cloud → APIs & Services → Credentials → the Web OAuth client | JavaScript origin `https://<domain>`; redirect URI `https://<domain>/__/auth/handler` |
| Google Cloud → Credentials → the browser API key (if restricted by referrer) | `https://<domain>/*` |
| reCAPTCHA Enterprise key (App Check), if created | `<domain>` |

Deploy, then test on `https://<domain>`:
- [ ] Google sign-in
- [ ] email sign-up and sign-in
- [ ] guest
- [ ] a video lesson
- [ ] a WAEC exam
- [ ] `curl -sI https://<domain>/welcome` shows the security headers

## 5. Search Console

1. Add a **Domain** property for `<domain>`. It is verified by a DNS TXT record.
2. Submit `https://<domain>/sitemap.xml`.

## 6. Redirect the old address

Only after step 4 passes. From `project/`:

```powershell
node tools/site/redirect_site.js              # reads kSiteOrigin; refuses if it is still the old address
firebase deploy --only hosting --config build/redirect/firebase.json --project paragon-hq
```

Check:

```powershell
curl -sI https://paragon-hq.web.app/past-questions/waec/mathematics/2018/   # 301, Location https://<domain>/past-questions/...
curl -sI "https://paragon-hq.web.app/join?code=ABC234"                       # query kept
curl -sI https://paragon-hq.firebaseapp.com/__/auth/handler                  # 200: reserved path, not redirected
```

If the query string is dropped, put the redirect in a small Cloud Run service. That
needs Blaze, so ask first.

Then, in Search Console, use **Change of address** from the old `paragon-hq.web.app`
property, if it was verified (`web/index.html` carries a `google-site-verification`
tag).

## 7. Email

1. Choose a forwarding service, for example the registrar's own, Cloudflare Email Routing
   or ImprovMX. Forward `hello@<domain>` to the inbox that is read.
2. For staff emails from `notify_drafts.js`, verify `<domain>` in Resend and set the
   `NOTIFY_FROM` secret to `Paragon <hello@<domain>>`.

## 8. Docs

Update `CLAUDE.md` (the deploy line and site), `ARCHITECTURE.md` and
`LAUNCH_CHECKLIST.md` §4.
