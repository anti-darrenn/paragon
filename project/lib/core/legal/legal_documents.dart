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
const String legalLastUpdated = '15 October 2026';

/// The version of the terms and privacy policy a student agrees to,
/// recorded on `users/{uid}` as `legalVersion` with the time.
///
/// **Bump it only for a significant change** — the policy promises
/// notice of those. Every signed-in account on an older version is asked
/// to accept again before going on (`/legal/accept`), so bumping it for a
/// typo would interrupt every student for nothing. [legalLastUpdated] can
/// move without it.
const String kLegalVersion = '2026-10-15';

/// What changed in [kLegalVersion], in a sentence each, for the accept
/// screen. Rewrite this list whenever the version is bumped.
const List<String> kLegalChanges = [
  'We no longer ask for your age, gender, country or state, and we are '
      'deleting any we already had. School and class stay optional.',
  'You can set a weekly goal and your exam date. They are stored with your '
      'account, and only you can see them.',
  'You can challenge a friend with a link. Anyone with the link sees your '
      'first name and your score, and the link expires after 30 days.',
  'You can join a live quiz with a nickname. The room and everything in it '
      'is deleted a day later.',
  'You can ask to be told when a subject is ready. We keep the subjects you '
      'ask about.',
  'Usage analytics now include when practice, exams and sign-ups start, and '
      'the sign-in method (never the address).',
  'Lesson writers who agree can be credited by name under their lessons.',
];

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
            'anonymous account identifier with no personal details attached. '
            'We record which version of these terms and this policy you '
            'accepted, and when. '
            'If you use "Sign out everywhere", we store that request until it '
            'has been carried out, usually within 15 minutes, and then delete '
            'it.',
        'Profile details you give us. Your username, your display name, and '
            'the subjects you choose. You may also optionally add your '
            'school and your class or year, which tell us which schools and '
            'classes use Paragon so we can work with schools and write for '
            'the right level, a short '
            'bio of up to 160 characters, and a profile picture chosen from '
            'a set of built-in pictures or your initials (you cannot upload '
            'a photo). Every one of those optional fields can be left blank, '
            'and skipping them does not limit your use of the app. Your '
            'bio, picture and optional details are shown only to you.',
        'How you use Paragon. For each question you answer we record which '
            'question it was, which option you chose, whether it was '
            'correct, how many hints you used, when you answered, and '
            'whether it was practice, an '
            'exercise inside a lesson, a topic test, a unit test or course '
            'challenge, a WAEC exam session or practice from your mistakes '
            'notebook. '
            'We also keep a running count of how many practice questions '
            'you have answered in each topic and how many you got right '
            'without a hint, '
            'which is what the progress rings show you. Lesson exercises, '
            'topic tests and mistakes practice are not added to that count; '
            'unit tests and course challenges are, but only for topics you '
            'have unlocked. '
            'The mistakes notebook is worked out from those same answers; '
            'nothing extra is stored for it.',
        'Your lesson progress. When you finish a video, an article or an '
            'exercise in a lesson, we record that you finished it and when, '
            'so the app can show what you have done and take you back to '
            'where you left off. If you are browsing as a guest, this is '
            'kept only while the app is open and is not stored, and your '
            'exercise answers are not stored either — unless you create an '
            'account from that guest session, in which case the lessons you '
            'finished are saved to it.',
        'Your WAEC exam results. For each exam you finish we keep which '
            'questions it had, the option you picked for each, your score, '
            'whether it was timed and how long you took, so you can review '
            'it later and see your past exams. Only you can see them.',
        'Your topic test results. For each topic test you take we record '
            'your best score, how many times you have taken it, when you '
            'last did, and whether you have passed it. Passing is what '
            'unlocks drill practice for that topic, so this is kept for as '
            'long as your account exists. Only you can see it.',
        'Your notes, highlights and bookmarks. When you highlight part of a '
            'lesson, write a note on it, or save a lesson or a question, we '
            'store what you wrote, the highlight colour, which lesson or '
            'question it belongs to, a copy of the lesson text it was '
            'written against (so the note still makes sense if the lesson '
            'is later changed), and when. These are stored with your account '
            'so they are on every device you sign in on, only you can see '
            'them, and they are deleted when your account is deleted. If you '
            'are browsing as a guest, they are kept only on your device, in '
            'your browser, and are not sent to us unless you create an '
            'account from that guest session, when they are moved into it '
            'and removed from the device.',
        'Your flashcards. When you make a deck, we store its name, the '
            'subject you chose and each card\'s two sides with your account, '
            'and when each card is next due. Only you can see them, and they '
            'are deleted when you delete the deck or your account. As a '
            'guest they stay on your device until you create an account.',
        'Problem reports. If you report a problem with a question, we record '
            'which question, the reason you selected, and your account '
            'identifier.',
        'Feedback. If you send us feedback, we record what you wrote, the '
            'kind you chose, which screen of the app you sent it from, and '
            'your account identifier. The Paragon team reads it, and it is '
            'deleted when your account is deleted.',
        'Difficulty ratings. If you rate how hard a practice question was, '
            'we record your ratings with your account identifier. Each '
            'night they are added, without your name or identifier, into a '
            'count on each question, and the record of your ratings is '
            'deleted. Ratings not yet counted are deleted with your account.',
        'Challenges. If you challenge a friend, we store the questions, '
            'your score on them, the topic and your first name, so that '
            'whoever opens the link can see what to beat. Anyone with the '
            'link can see those, and nothing else about you. A challenge is '
            'deleted after 30 days, or with your account. If you answer a '
            "friend's challenge, your answers are kept with your practice.",
        'Lesson credits. If you write lessons for Paragon and agree to be '
            'credited, the name and the one-line description you approve are '
            'shown under your lessons to everyone. You can ask us to remove '
            'them at any time.',
        'Live quizzes. If you join a live quiz, we store the nickname you '
            'choose and your answers in that room, so the host can show the '
            'scores. Everyone in the room sees your nickname. A room and '
            'everything in it is deleted a day after it was made. Quiz '
            'answers are not added to your practice record.',
        'Your plan. If you set a weekly goal or the date of your exam, we '
            'store them with your account to work out your study plan on '
            'your device. Only you can see them, and they are deleted when '
            'your account is deleted.',
        'Subjects you want. If you tap "Notify me" on a subject that is not '
            'ready yet, we store which subjects you asked about, with your '
            'account. The Paragon team sees how many students want each '
            'subject. You can leave the list from the same screen, '
            'and it is deleted when your account is deleted.',
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
            'username, email or school to analytics, and we '
            'never send anything you typed. What goes is which screen of '
            'the app you are on, subject and topic identifiers, counts of '
            'questions answered and how many you got right, your topic '
            'test scores and whether you passed, which kinds of lesson '
            'item (video, article or exercise) you finish, your lesson '
            'exercise scores, which coming-soon subjects you ask to hear '
            'about, whether you started as a guest or made an account and '
            'which way (Google or email — never the address), when a drill '
            'or an exam starts and which exam length you chose, and '
            'whether a session was a guest session. When '
            'something in the app breaks, we send the kind of error and the '
            'screen it happened on, never what was on it. Google also collects standard '
            'technical information such as your device type, general '
            'region and app version.',
        'You can turn this off. Settings has a "Share usage data" switch; '
            'turning it off stops collection on that device, and you do '
            'not need an account to use it. If you are signed in, turning '
            'it off also turns it off on every other device you sign in '
            'on. Everything else in the app keeps working exactly the same.',
        'Your settings. If you are signed in, your reading settings (text '
            'size, line spacing, reading font, low-data mode) and your choice '
            'about usage data are stored with your account so they follow '
            'you to other devices. As a guest they stay on your device.',
        'An exam you have started but not submitted is kept on your '
            'device, not sent to us, so you can carry on after losing your '
            'connection or closing the app. It is removed when you submit '
            'or exit the exam, or after a day.',
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
        'To improve Paragon from what you tell us in feedback.',
        'To understand which subjects and topics students need, so we know '
            'what to build next.',
      ],
    ),
    // Draft for the NDPA's "lawful basis" requirement — see the file
    // header: this needs a lawyer's review before a public launch.
    LegalSection(
      heading: 'Our legal basis',
      paragraphs: [
        'We use your account, your practice and your study data to provide '
            'the service you signed up for. Without them there is nothing '
            'to show you. We use usage analytics, problem reports and '
            'feedback because we have a legitimate interest in finding and '
            'fixing what is wrong; you can turn analytics off at any time. '
            'The optional profile details, the plan and "Notify me" are '
            'yours to give or leave out, and to remove later.',
        'We handle your data under the Nigeria Data Protection Act 2023 '
            '(NDPA), which is enforced by the Nigeria Data Protection '
            'Commission (NDPC).',
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
        "If you donate, you pay on Paystack's own site, and Paystack's "
            'privacy policy applies there. Paragon never sees your card '
            'details. Paystack tells us the amount and the name and email '
            'you gave it, which we use only to keep a record of donations '
            'and to thank you.',
      ],
    ),
    LegalSection(
      heading: 'How long we keep it',
      paragraphs: [
        'We keep your account and practice history for as long as your '
            'account exists. If you ask us to delete your account, we delete '
            'your account record, your practice history, and your notes, '
            'highlights and bookmarks.',
        'Guest (anonymous) accounts are deleted automatically, together '
            'with everything recorded under them, once they have not been '
            'used for 30 days. You can also ask us to remove one sooner.',
      ],
    ),
    LegalSection(
      heading: 'Your rights',
      paragraphs: [
        'You can ask us to show you the data we hold about you, correct it, '
            'delete it, or send you a copy. Email $contactEmail and we '
            'will respond.',
        'You can also download a copy yourself, at any time, from Settings → '
            'Download your data. It is one file containing your account '
            'details, every answer you have recorded, your progress, test '
            'results, notes, bookmarks, revision cards, problem reports and '
            'feedback.',
        'You can delete your account yourself from Settings. Deleting it '
            'removes your account record, your practice history, and your '
            'notes, highlights and bookmarks. You choose whether that '
            'happens immediately or after 30 days; in the 30 days nothing is '
            'removed, and signing in again lets you keep the account. You '
            'can also email us and we will do it for you.',
        'Your username is an exception: you can change it once every 90 '
            'days, but no username is ever released. Every username you '
            'have used stays reserved, even after you change it or delete '
            'your account, so that nobody else can take it and pretend to '
            'be you. We keep the record of which account reserved it, and '
            'the date you last changed it.',
        'If you think we have handled your data wrongly, please tell us '
            'first at $contactEmail so we can put it right. You also have '
            'the right to complain to the Nigeria Data Protection '
            'Commission (ndpc.gov.ng).',
      ],
    ),
    LegalSection(
      heading: 'Students under 18',
      paragraphs: [
        'Paragon is built for students preparing for WAEC, so most of the '
            'people using it are under 18. The Nigeria Data Protection Act '
            'treats everyone under 18 as a child. We collect as little as we '
            'can: nothing in the optional profile step is required, and the '
            'app works fully without it.',
        'If you are under 18, please ask a parent or guardian before '
            'filling in the optional profile details. If you are a '
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
        'Our questions come from two places. Past examination questions were '
            'collected from a third-party source, and their answer key came '
            'with them. It is not an official answer key and we do not '
            'present it as one. Most practice questions are not past papers: '
            'they are generated by programs we wrote, in the style of WAEC '
            'questions, with each answer worked out by the program.',
        'We have checked a sample of the past questions by hand and found '
            'errors, and a generated question can be wrong too. Some '
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
        'You can change your username once every 90 days. A username you '
            'give up is never released, to you or anyone else, so choose '
            'carefully.',
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
            'are tied to the device and browser you started them on, and are '
            'deleted after 30 days without use. If you create an account '
            'from inside a guest session, your guest progress comes with you. '
            'If you instead sign in to an account you already have, the guest '
            "session's progress stays behind: two accounts cannot be merged.",
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
