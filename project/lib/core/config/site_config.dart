/// The few facts about the public site that a domain move or a copy change
/// touches, in one place (audit E10, G2, C15).
library;

/// The site's public address, with no trailing slash.
///
/// **The one switch for a custom domain.** `tools/site/build_static_site.js`
/// reads this line and puts the address into every static page, the
/// sitemap, robots.txt, and the built `index.html`'s canonical and share
/// tags. Firebase Hosting then needs the domain added in its console, and
/// Firebase Auth needs it as an authorised domain (docs/LAUNCH_CHECKLIST.md).
const String kSiteOrigin = 'https://paragon-hq.web.app';

/// The line under the logo on the welcome screen. A plain placeholder
/// while the owner chooses from the options in docs/COPY.md.
const String kTagline = 'Free WAEC prep. Still a work in progress.';
