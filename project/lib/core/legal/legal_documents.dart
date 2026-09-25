/// Source of truth for the privacy policy and terms of service.
///
/// Held as structured Dart rather than Markdown for two reasons: there is
/// no Markdown renderer in the app (adding one would mean a new pinned
/// dependency), and a single source cannot drift from a second copy.
///
/// **The publisher and contact details are interim.** They are real and
/// monitored, which is what matters — a policy that names no one to write
/// to is worse than one naming a personal address. But [contactEmail] is a
/// personal inbox standing in until a domain address exists; swap it the
/// day that does. [legalPlaceholdersRemain] is what guards the general
/// case: any value still carrying the "to be confirmed" marker makes the
/// app render a visible warning above the document, so a placeholder
/// cannot ship unnoticed.
///
/// **This is a draft, not legal advice.** It describes the system
/// accurately — the data inventory below was read out of the code, not
/// assumed — but it has not been reviewed by a lawyer. The clauses most
/// needing professional review are flagged in `docs/audit/` and in the
/// handover notes: lawful basis and consent for users under 18 under the
/// Nigeria Data Protection Act, cross-border transfer, and the retention
/// commitments.
///
/// **Keep it true.** Every claim here is checkable against the code today.
/// If the schema gains fields (Session 12's `topicStats`, Session 13's XP)
/// or a dependency starts collecting analytics, this file is part of that
/// change, not a follow-up.
library;

/// Marks a value that has not been decided yet. [legalPlaceholdersRemain]
/// looks for this, rather than for any particular constant, so a
/// placeholder added later is caught without anyone remembering to extend
/// the check.
const String unconfirmedMarker = 'to be confirmed';

/// Who operates Paragon. No company exists yet, so this names the people
/// actually responsible — which is the thing a privacy policy is for.
const String publisher = 'Darren Ohiomoba and the Paragon Team';

/// Where data requests go. Interim: a personal inbox until Paragon has a
/// domain. It is the only route a student or parent is offered for access
/// and deletion, so it has to be an address that is genuinely read.
const String contactEmail = 'darrenn.cp@gmail.com';

/// Copied on the same requests, so nothing is lost if the primary inbox is
/// missed. Named in the contact sections rather than repeated inline
/// everywhere — one address to write to, one that also sees it.
const String contactEmailCc = 'darren.ohiomoba.adm@gmail.com';

/// True while any placeholder is still unfilled anywhere in either
/// document. The legal screen renders a warning when it is.
bool get legalPlaceholdersRemain => [
  publisher,
  contactEmail,
  contactEmailCc,
].any((value) => value.contains(unconfirmedMarker));

/// Shown on both documents. Update when the content changes materially.
const String legalLastUpdated = '24 September 2026';

class LegalSection {
  const LegalSection({
    required this.heading,
    this.paragraphs = const [],
    this.bullets = const [],
  });

  final String heading;
  final List<String> paragraphs;
  final List<String> bullets;
}

class LegalDocument {
  const LegalDocument({
    required this.title,
    required this.intro,
    required this.sections,
  });

  final String title;
  final String intro;
  final List<LegalSection> sections;
}

// ─── Privacy policy ──────────────────────────────────────────────────────

const LegalDocument privacyPolicy = LegalDocument(
  title: 'Privacy Policy',
  intro:
      'This policy explains what Paragon collects about you, why, and what '
      'you can do about it. It describes what the app actually does today — '
      'if that changes, this policy changes with it.',
  sections: [
    LegalSection(
      heading: 'Who we are',
      paragraphs: [
        'Paragon is a WAEC practice app operated by $publisher. '
            'If you have a question about your data, or want to see, correct '
            'or delete it, contact us at $contactEmail.',
      ],
    ),
    LegalSection(
      heading: 'What we collect',
      paragraphs: [
        'Account details. If you sign up with email, we hold your email '
            'address; your password is handled by Google Firebase '
            'Authentication and we never see or store it. If you sign in '
            'with Google, we receive your name, email address and profile '
            'picture from Google. If you browse as a guest, we create an '
            'anonymous account identifier with no personal details attached.',
        'Profile details you give us. Your username, your display name, and '
            'the subjects you choose. You may also optionally add your '
            'school, class or year, age, gender, country and state. Every '
            'one of those optional fields can be left blank, and skipping '
            'them does not limit your use of the app.',
        'How you use Paragon. For each question you answer we record which '
            'question it was, which option you chose, whether it was '
            'correct, when you answered, and whether it was practice, an '
            'exercise inside a lesson, a topic test or a WAEC exam session. '
            'We also keep a running count of how many practice questions '
            'you have answered in each topic and how many you got right, '
            'which is what the progress rings show you. Lesson exercises '
            'and topic tests are not added to that count.',
        'Your lesson progress. When you finish a video, an article or an '
            'exercise in a lesson, we record that you finished it and when, '
            'so the app can show what you have done and take you back to '
            'where you left off. If you are browsing as a guest, this is '
            'kept only while the app is open and is never stored, and your '
            'exercise answers are not stored either.',
        'Your topic test results. For each topic test you take we record '
            'your best score, how many times you have taken it, when you '
            'last did, and whether you have passed it. Passing is what '
            'unlocks drill practice for that topic, so this is kept for as '
            'long as your account exists. Only you can see it.',
        'Problem reports. If you report a problem with a question, we record '
            'which question, the reason you selected, and your account '
            'identifier.',
      ],
    ),
    LegalSection(
      heading: 'Usage analytics',
      paragraphs: [
        'We use Google Analytics for Firebase to understand how the app is '
            'used — which subjects and topics get practised, how far people '
            'get through sign-up, and where they run into trouble. This '
            'tells us what to build and fix next.',
        'We deliberately keep this anonymous. We never send your name, '
            'username, email, school, age or gender to analytics, and we '
            'never send anything you typed. What goes is which screen of '
            'the app you are on, subject and topic identifiers, counts of '
            'questions answered and how many you got right, your topic '
            'test scores and whether you passed, which kinds of lesson '
            'item (video, article or exercise) you finish, your lesson '
            'exercise scores, and whether a session was a guest session. Google also collects standard '
            'technical information such as your device type, general '
            'region and app version.',
        'You can turn this off. Settings has a "Share usage data" switch; '
            'turning it off stops collection on that device, and you do '
            'not need an account to use it. Everything else in the app '
            'keeps working exactly the same.',
      ],
    ),
    LegalSection(
      heading: 'What we do not collect',
      paragraphs: [
        'We show no advertising of our own, and the app contains no '
            'advertising or marketing trackers. Lesson videos play in '
            "YouTube's player, and if a video's owner has enabled ads on it, "
            'YouTube may show them. We do not collect your precise location, '
            'your contacts, or your browsing outside the app, and we do not '
            'build an advertising profile of you. We do not sell your data '
            'to anyone, ever.',
      ],
    ),
    LegalSection(
      heading: 'Why we collect it',
      bullets: [
        'To give you an account and keep you signed in.',
        'To show your progress and results back to you.',
        'To choose which questions to show you next.',
        'To find and fix wrong answers in our question bank, which is why '
            'problem reports exist.',
        'To understand which subjects and topics students need, so we know '
            'what to build next.',
      ],
    ),
    LegalSection(
      heading: 'Who else can see it',
      paragraphs: [
        'Your account and practice history are private to you. Other '
            'students cannot see what you have answered or how you scored.',
        'Your username is visible to other signed-in users. Do not choose a '
            'username you would not want others to see.',
        'Paragon runs on Google Firebase, which stores and processes your '
            'data on our behalf, and uses Google Analytics for Firebase for '
            'the anonymous usage statistics described above. This means '
            'your data is held on Google servers, which may be outside '
            'Nigeria. We do not share your data with anyone else, other '
            'than where we are required to by law.',
        'Lesson videos are YouTube videos, embedded using YouTube\'s '
            'privacy-enhanced mode (youtube-nocookie.com). The player loads '
            'from YouTube only when you open a video lesson. When it does, '
            'YouTube receives the technical information any website visit '
            'sends, such as your IP address and device details, and '
            "YouTube's own privacy policy applies to what happens inside the "
            'player. We do not send YouTube your name, email or account '
            'details.',
      ],
    ),
    LegalSection(
      heading: 'How long we keep it',
      paragraphs: [
        'We keep your account and practice history for as long as your '
            'account exists. If you ask us to delete your account, we delete '
            'your account record and your practice history.',
        'Guest (anonymous) accounts are kept while they remain in use. We '
            'intend to delete unused guest accounts automatically; until '
            'that is in place, you can ask us to remove one.',
      ],
    ),
    LegalSection(
      heading: 'Your rights',
      paragraphs: [
        'You can ask us to show you the data we hold about you, correct it, '
            'delete it, or send you a copy. Email $contactEmail and we '
            'will respond.',
        'You can delete your account yourself from Settings. Deleting it '
            'removes your account record and your practice history. You can '
            'also email us and we will do it for you.',
        'Your username is an exception we cannot undo: usernames are '
            'permanent and cannot be changed or released once chosen, '
            'because other parts of the app rely on them staying fixed. '
            'Deleting your account does not free the username for reuse.',
      ],
    ),
    LegalSection(
      heading: 'Students under 18',
      paragraphs: [
        'Paragon is built for students preparing for WAEC, so most of the '
            'people using it are under 18, and some are under 16. We collect '
            'as little as we can: nothing in the optional profile step is '
            'required, and the app works fully without it.',
        'If you are under 16, please ask a parent, guardian or teacher '
            'before filling in the optional profile details. If you are a '
            'parent or guardian and want to see or delete what we hold about '
            'your child, email $contactEmail.',
      ],
    ),
    LegalSection(
      heading: 'Security',
      paragraphs: [
        'Your data is held in Google Firebase and protected by access rules '
            'that only let you read and write your own account. Passwords '
            'are handled entirely by Firebase Authentication and never '
            'reach us. No system is perfectly secure, and we do not claim '
            'ours is.',
      ],
    ),
    LegalSection(
      heading: 'Changes to this policy',
      paragraphs: [
        'If we change what we collect or what we do with it, we will update '
            'this page and the date at the top. Significant changes will be '
            'brought to your attention in the app.',
      ],
    ),
    LegalSection(
      heading: 'Contact',
      paragraphs: [
        'Questions, requests or complaints: $contactEmail, copying '
            '$contactEmailCc.',
      ],
    ),
  ],
);

// ─── Terms of service ────────────────────────────────────────────────────

const LegalDocument termsOfService = LegalDocument(
  title: 'Terms of Service',
  intro:
      'These terms cover your use of Paragon. By creating an account or '
      'using the app, you agree to them.',
  sections: [
    LegalSection(
      heading: 'Who we are',
      paragraphs: [
        'Paragon is operated by $publisher. You can reach us at '
            '$contactEmail.',
      ],
    ),
    LegalSection(
      heading: 'Not affiliated with WAEC',
      paragraphs: [
        'Paragon is an independent study tool. We are not affiliated with, '
            'endorsed by, or connected to the West African Examinations '
            'Council. References to WAEC describe the examinations our '
            'practice material is drawn from, nothing more.',
      ],
    ),
    LegalSection(
      heading: 'Questions and answers are not official',
      paragraphs: [
        'Our practice questions come from past examination papers collected '
            'from a third-party source, and the answer key came with them. '
            'It is not an official answer key and we do not present it as '
            'one.',
        'We have checked a sample by hand and found errors in it. Some '
            'answers in the app are wrong, and some explanations are missing '
            'or thin. Use Paragon to practise, not as an authority — check '
            'anything that matters against your textbook or your teacher.',
        'If you find a wrong answer, please report it from the question '
            'screen. Reports are how we find and fix them.',
      ],
    ),
    LegalSection(
      heading: 'Your account',
      bullets: [
        'You are responsible for what happens on your account. Keep your '
            'password to yourself.',
        'Give us accurate details. Do not impersonate someone else.',
        'Your username is permanent. It cannot be changed or released once '
            'chosen, so choose carefully.',
        'We may remove a username that impersonates someone, or that is '
            'offensive.',
      ],
    ),
    LegalSection(
      heading: 'Acceptable use',
      paragraphs: ['Please do not:'],
      bullets: [
        'Use the app to harass, abuse or impersonate anyone.',
        'Try to break, overload or gain unauthorised access to the service '
            'or other people\'s accounts.',
        'Scrape, bulk-download or resell our content.',
        'Use the app for anything unlawful.',
      ],
    ),
    LegalSection(
      heading: 'Guest accounts',
      paragraphs: [
        'You can use Paragon as a guest without signing up. Guest sessions '
            'are tied to the device and browser you started them on. If you '
            'later create a real account, your guest progress does not carry '
            'over — it stays with the guest session and is not transferred.',
      ],
    ),
    LegalSection(
      heading: 'Availability',
      paragraphs: [
        'Paragon is provided free and as-is. We do not guarantee it will '
            'always be available, uninterrupted, or error-free, and we may '
            'change or withdraw features. We will try not to surprise you '
            'with the significant ones.',
      ],
    ),
    LegalSection(
      heading: 'Ending your account',
      paragraphs: [
        'You can stop using Paragon at any time, and you can ask us to '
            'delete your account by emailing $contactEmail. We may '
            'suspend or close an account that breaks these terms.',
      ],
    ),
    LegalSection(
      heading: 'Our content',
      paragraphs: [
        'The app itself — its design, code, notes and explanations — belongs '
            'to us. Past examination questions belong to their respective '
            'owners. You may use all of it for your own study, and not for '
            'republication or resale.',
      ],
    ),
    LegalSection(
      heading: 'Limits on our liability',
      paragraphs: [
        'Paragon is a study aid. We are not responsible for your examination '
            'results, and to the extent the law allows, we are not liable '
            'for losses arising from your use of the app or from errors in '
            'the practice material. Nothing here removes rights you have '
            'under law that cannot be removed.',
      ],
    ),
    LegalSection(
      heading: 'Changes to these terms',
      paragraphs: [
        'We may update these terms. The date at the top shows when they last '
            'changed, and continuing to use Paragon after a change means you '
            'accept the updated terms.',
      ],
    ),
    LegalSection(
      heading: 'Contact',
      paragraphs: [
        'Questions about these terms: $contactEmail, copying '
            '$contactEmailCc.',
      ],
    ),
  ],
);
