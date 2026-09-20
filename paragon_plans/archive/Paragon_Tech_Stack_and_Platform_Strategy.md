# Project Paragon — Tech Stack & Platform Strategy
### Complete Reference Document · Flutter + Firebase · Solo Developer

---

## The Answer to "How Do I Port?"

You don't port. That is the entire point of Flutter.

Flutter is not a framework that builds a web app and then tries to make it look native on mobile. It is a rendering engine that compiles your Dart code to native ARM binaries on mobile, native Win32/Linux binaries on desktop, and optimised CanvasKit on web. Flutter draws every pixel itself using its own GPU-accelerated rendering layer. This means:

- The code you write for Android is the same code that runs on Windows
- There is no "web version" and "mobile version" — there is one codebase
- Platform-specific behaviour (notifications, file paths, keyboard shortcuts) is handled with 20–50 lines of conditional code per feature
- When you `flutter build apk`, you get an Android app. When you `flutter build web`, you get a web app. Same source. Same commands, different flag.

The only real porting work in your project is: (1) platform-specific UI adaptations (wider layouts on desktop), (2) platform-specific APIs (push notifications are different on mobile vs desktop), and (3) app store asset preparation (icons, splash screens, store listings).

---

## Language Decisions

| Layer | Language | Why |
|---|---|---|
| App (all platforms) | **Dart** | Flutter's language. Strongly typed. Similar to TypeScript — you'll be comfortable in 2–3 weeks. |
| Backend logic | **Dart** (Firebase SDK) | No separate backend language. Firebase handles auth, data, storage. |
| Firebase Cloud Functions | **TypeScript** (Node.js) | Only if needed — avoid in Phase 1. |
| Scripts / automation | **Bash or PowerShell** | For build scripts, CI/CD. |

Dart specifics for a JS/TS developer:
- `var`, `final`, `const` work like JS but `final` = immutable reference, `const` = compile-time constant
- `async`/`await` works identically to JS
- `null safety` is enforced (like TypeScript's strict mode) — nullable types use `String?`
- No `undefined` — everything is either null or not null
- Classes, interfaces (called abstract classes), generics — all familiar
- `List<T>`, `Map<K,V>`, `Set<T>` instead of Array/Object
- Arrow functions: `(x) => x * 2` same syntax

---

## Complete Package List

```yaml
# pubspec.yaml — copy this as your starting point

name: paragon
description: WAEC exam prep — past questions, explanations, progress tracking

environment:
  sdk: '>=3.0.0 <4.0.0'
  flutter: '>=3.16.0'

dependencies:
  flutter:
    sdk: flutter

  # ─── Firebase (Flutterfire) ───────────────────────────────────────────────
  firebase_core: ^2.24.0
  cloud_firestore: ^4.14.0
  firebase_auth: ^4.16.0
  firebase_analytics: ^10.8.0
  firebase_messaging: ^14.7.9       # push notifications — mobile only
  firebase_storage: ^11.6.0         # for future: profile photos, question images

  # ─── State management ─────────────────────────────────────────────────────
  flutter_riverpod: ^2.4.9
  riverpod_annotation: ^2.3.3

  # ─── Navigation ───────────────────────────────────────────────────────────
  go_router: ^13.0.0

  # ─── Local / offline database ─────────────────────────────────────────────
  isar: ^3.1.0                       # fast NoSQL local DB — offline question cache
  isar_flutter_libs: ^3.1.0
  path_provider: ^2.1.2              # get correct file paths per platform

  # ─── UI ───────────────────────────────────────────────────────────────────
  google_fonts: ^6.1.0               # Montserrat, Poppins, or Inter — your brand font
  cached_network_image: ^3.3.1       # cache network images
  flutter_svg: ^2.0.9                # SVG assets
  shimmer: ^3.0.0                    # loading placeholders
  lottie: ^2.7.0                     # animated illustrations (optional — for empty states)

  # ─── Video ────────────────────────────────────────────────────────────────
  youtube_player_iframe: ^4.0.2      # works on web + mobile + desktop

  # ─── Notifications ────────────────────────────────────────────────────────
  flutter_local_notifications: ^16.3.0  # local streak reminders

  # ─── Platform utils ───────────────────────────────────────────────────────
  url_launcher: ^6.2.2               # open WhatsApp, YouTube links
  share_plus: ^7.2.1                 # native share sheet (mobile)
  package_info_plus: ^5.0.1          # app version info

  # ─── Data / serialisation ─────────────────────────────────────────────────
  json_annotation: ^4.8.1
  freezed_annotation: ^2.4.1        # immutable data classes (like TypeScript readonly)
  intl: ^0.19.0                      # date formatting

  # ─── Connectivity ─────────────────────────────────────────────────────────
  connectivity_plus: ^5.0.2         # detect online/offline state

dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.4.7              # code generation
  riverpod_generator: ^2.3.9        # generates Riverpod providers from annotations
  json_serializable: ^6.7.1         # generates JSON serialisation code
  freezed: ^2.4.5                   # generates immutable model code
  isar_generator: ^3.1.0            # generates Isar schema code
  flutter_launcher_icons: ^0.13.1   # generates app icons for all platforms
  flutter_native_splash: ^2.3.9     # generates splash screens for all platforms
```

**Packages you will NOT use in Phase 1:**
- Any AI/LLM API package (Phase 3)
- Any payment package
- Any analytics beyond Firebase Analytics
- `sqflite` — Isar is better and works on desktop too

---

## Platform Feature Matrix

| Feature | Web | Android | iOS | Windows | Linux |
|---|:---:|:---:|:---:|:---:|:---:|
| Question practice | ✅ | ✅ | ✅ | ✅ | ✅ |
| Google + Email auth | ✅ | ✅ | ✅ | ✅ | ✅ |
| Streak tracking | ✅ | ✅ | ✅ | ✅ | ✅ |
| YouTube video embed | ✅ | ✅ | ✅ | ✅ | ✅ |
| FCM push notifications | ✅ web push | ✅ | ✅ | ❌ | ❌ |
| Local streak reminders | ❌ | ✅ | ✅ | ✅ phase 2 | ❌ |
| Full offline mode | ❌ | ✅ phase 2 | ✅ phase 2 | ✅ phase 2 | ✅ phase 2 |
| Download question packs | ❌ | ✅ phase 2 | ✅ phase 2 | ✅ | ✅ |
| Native share sheet | ❌ (URL share) | ✅ | ✅ | ❌ | ❌ |
| Haptic feedback | ❌ | ✅ | ✅ | ❌ | ❌ |
| Keyboard shortcuts | ❌ | ❌ | ❌ | ✅ | ✅ |
| Multi-column layout | ✅ | ❌ | ❌ | ✅ | ✅ |
| SEO meta tags | ✅ | N/A | N/A | N/A | N/A |
| Distribution | Firebase Hosting | Play Store / APK | App Store | GitHub Releases | GitHub Releases |
| Priority | **1st** | **2nd** | 4th | **3rd** | 4th |

**Build priority reasoning:**
- Web first: no store approval, instant deployment, anyone can access via URL
- Android second: >85% of Nigerian student device share; APK can be shared via WhatsApp before Play Store
- Windows third: school computer labs run Windows; download a .exe, install, use offline — no phone needed
- iOS and Linux last: smaller addressable audience in your target market

---

## Folder Structure

```
paragon/
│
├── lib/
│   ├── main.dart                          # Entry point, Firebase init
│   ├── app.dart                           # MaterialApp, theme, router setup
│   │
│   ├── core/
│   │   ├── theme/
│   │   │   ├── app_theme.dart             # Colors, typography, dark/light theme
│   │   │   ├── app_colors.dart            # Brand color constants
│   │   │   └── app_text_styles.dart       # Text style constants
│   │   │
│   │   ├── router/
│   │   │   └── app_router.dart            # go_router config, all routes
│   │   │
│   │   ├── constants/
│   │   │   └── app_constants.dart         # String constants, durations
│   │   │
│   │   └── utils/
│   │       ├── platform_utils.dart        # kIsWeb, Platform.isAndroid, etc.
│   │       └── date_utils.dart            # Streak date helpers
│   │
│   ├── features/
│   │   │
│   │   ├── auth/
│   │   │   ├── data/
│   │   │   │   └── auth_repository.dart   # Firebase Auth wrapper
│   │   │   ├── domain/
│   │   │   │   └── auth_state.dart        # Riverpod auth state
│   │   │   └── presentation/
│   │   │       └── sign_in_screen.dart
│   │   │
│   │   ├── questions/
│   │   │   ├── data/
│   │   │   │   ├── questions_repository.dart  # Firestore reads
│   │   │   │   └── local_questions_db.dart    # Isar local cache
│   │   │   ├── domain/
│   │   │   │   ├── question_model.dart        # Question data class
│   │   │   │   ├── topic_model.dart           # Topic data class
│   │   │   │   └── attempt_model.dart         # Student attempt record
│   │   │   └── presentation/
│   │   │       ├── topic_list_screen.dart     # Home: list of topics
│   │   │       ├── topic_detail_screen.dart   # Questions for one topic
│   │   │       └── question_screen.dart       # Single question + answer
│   │   │
│   │   ├── progress/
│   │   │   ├── data/
│   │   │   │   └── progress_repository.dart
│   │   │   ├── domain/
│   │   │   │   ├── streak_model.dart
│   │   │   │   └── topic_accuracy_model.dart
│   │   │   └── presentation/
│   │   │       └── dashboard_screen.dart      # Streak, accuracy by topic
│   │   │
│   │   ├── videos/
│   │   │   └── presentation/
│   │   │       └── video_widget.dart          # YouTube embed, used within topic screens
│   │   │
│   │   └── onboarding/
│   │       └── presentation/
│   │           └── about_screen.dart          # What Paragon is, WhatsApp join link
│   │
│   └── shared/
│       ├── widgets/
│       │   ├── paragon_button.dart            # Branded button component
│       │   ├── question_card.dart             # Reusable question card
│       │   ├── streak_badge.dart              # Streak count badge
│       │   └── topic_progress_bar.dart        # Accuracy bar per topic
│       └── providers/
│           └── shared_providers.dart          # Shared Riverpod providers
│
├── assets/
│   ├── questions/
│   │   └── maths_waec_seed.json              # Seed data: 50 questions for launch
│   ├── images/
│   │   └── paragon_logo.svg
│   └── fonts/                                 # If self-hosting (use google_fonts instead)
│
├── android/                                   # Flutter-managed — mostly don't touch
├── ios/                                       # Flutter-managed
├── web/
│   └── index.html                            # Add meta tags here for SEO
├── windows/                                   # Flutter-managed
├── linux/                                     # Flutter-managed
│
├── test/
│   ├── features/
│   │   └── questions/
│   │       └── question_model_test.dart
│   └── widget_test.dart
│
├── pubspec.yaml
├── analysis_options.yaml                      # Dart linting rules
└── README.md
```

---

## Firebase Services Configuration

### Services You Need (and when)

| Service | Phase | Purpose | Cost |
|---|---|---|---|
| Firebase Authentication | Phase 1 | Google + Email sign-in | Free (50k MAU) |
| Cloud Firestore | Phase 1 | User data, attempts, streaks | Free (1GB storage, 50k reads/day) |
| Firebase Analytics | Phase 1 | Weekly active users, retention | Free |
| Firebase Hosting | Phase 1 | Web deployment | Free (10GB/month) |
| Firebase Cloud Messaging | Phase 2 | Push notifications (mobile) | Free |
| Firebase Storage | Phase 3 | Question images (if any) | Free (5GB) |

**Free tier handles Phase 1–2 completely.** You will not hit paid limits until tens of thousands of daily active users.

### Firestore Data Model

```
Collections:

users/{uid}
  email: string
  displayName: string
  createdAt: timestamp
  currentStreak: number        # consecutive days with ≥5 questions
  lastActiveDate: string       # "YYYY-MM-DD"
  totalQuestionsAttempted: number
  topicAccuracy: {
    [topicId]: {
      correct: number
      total: number
    }
  }

topics/{topicId}
  name: string                 # "Completing the Square"
  subject: string              # "maths"
  waecFrequency: string        # "every_year" | "high" | "medium"
  videoId: string              # YouTube video ID
  questionCount: number
  order: number                # display order in topic list

questions/{questionId}
  topicId: string              # reference to topics
  year: number                 # WAEC year (e.g. 2022)
  questionText: string
  options: {
    A: string
    B: string
    C: string
    D: string
  }
  correctAnswer: string        # "A" | "B" | "C" | "D"
  workedSolution: string       # markdown text
  difficulty: number           # 1 | 2 | 3
  imageUrl: string | null      # if question has a diagram

attempts/{uid}_{questionId}
  userId: string
  questionId: string
  topicId: string
  selectedAnswer: string
  isCorrect: boolean
  attemptedAt: timestamp
  # Phase 3 additions:
  nextReviewDate: string | null   # for spaced repetition
  reviewCount: number
```

### Security Rules (Firestore)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Users can only read/write their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Questions and topics are public read, admin write only
    match /topics/{topicId} {
      allow read: if true;
      allow write: if false; // Manage via Firebase Console
    }
    
    match /questions/{questionId} {
      allow read: if true;
      allow write: if false;
    }
    
    // Attempts belong to the user
    match /attempts/{attemptId} {
      allow read, write: if request.auth != null 
        && resource.data.userId == request.auth.uid;
      allow create: if request.auth != null;
    }
  }
}
```

---

## Adaptive UI: Platform Detection in Dart

How you write different behaviour for different platforms — no separate codebases:

```dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

// Check what platform you're on
bool get isWeb => kIsWeb;
bool get isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
bool get isDesktop => !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
bool get isAndroid => !kIsWeb && Platform.isAndroid;
bool get isIOS => !kIsWeb && Platform.isIOS;
bool get isWindows => !kIsWeb && Platform.isWindows;

// Example: show different layout based on platform
Widget build(BuildContext context) {
  final screenWidth = MediaQuery.of(context).size.width;
  
  if (screenWidth > 900 || isDesktop) {
    return TwoColumnLayout();   // Desktop / wide web
  } else {
    return SingleColumnLayout(); // Mobile / narrow web
  }
}

// Example: show share button only on mobile
if (isMobile) ShareButton()

// Example: show keyboard shortcut hint only on desktop
if (isDesktop) KeyboardShortcutHint(shortcut: 'Ctrl+Enter', label: 'Submit')
```

---

## Dev Toolchain

| Tool | Purpose | Install |
|---|---|---|
| **Flutter SDK** | Everything — compile, run, build | flutter.dev/install |
| **VS Code** | Primary editor | code.visualstudio.com |
| **Flutter VS Code extension** | Hot reload, widget inspector, Dart language support | VS Code marketplace |
| **Dart VS Code extension** | Dart language support | VS Code marketplace |
| **Android Studio** | Android toolchain only (you don't have to use it as editor) | developer.android.com |
| **Claude Code** | AI coding in your terminal — the main way you'll build features | Terminal: `npm install -g @anthropic-ai/claude-code` |
| **Cowork** | Desktop file management + task automation | Claude desktop app |
| **Flutterfire CLI** | Connects your Flutter project to Firebase | `dart pub global activate flutterfire_cli` |
| **Firebase CLI** | Deploy to Firebase Hosting, manage rules | `npm install -g firebase-tools` |
| **Git + GitHub Desktop** | Version control | github.com/desktop |
| **Figma** (free) | Design your screens | figma.com |
| **Google Stitch** | Figma → Flutter widget code | stitch.withgoogle.com |

### Claude Code Workflow

Claude Code runs in your terminal and has full access to your codebase. It reads your files, writes code, runs Flutter commands, and debugs errors. The right way to use it:

```bash
# Start a Claude Code session in your project directory
cd paragon/
claude

# Good prompts to use with Claude Code:
"Add a new screen called QuestionScreen that displays a question 
from Firestore. The question has four options A-D. On submission, 
reveal whether the answer is correct and show the worked solution."

"Implement streak tracking: when a user submits their 5th question 
in a day, increment their currentStreak in Firestore. If they 
haven't submitted any questions today and yesterday was their last 
active date, reset streak to 0."

"Make the topic list screen adaptive: single column on mobile 
(<600px), two columns on tablet/desktop (≥600px)."
```

Claude Code understands Flutter and Dart well. Give it context (show it your data models), give it the specific feature, and let it write the implementation. Review the code before accepting.

### Figma + Google Stitch Workflow

1. Design a screen in Figma (frame at 390×844 for mobile — iPhone 14 size)
2. Open Google Stitch, import your Figma design
3. Stitch generates Flutter widget code for the UI
4. Paste the generated widget into your feature's `presentation/` folder
5. Replace hardcoded data with your actual Riverpod providers and Firestore data
6. Use Claude Code to wire up the logic

Stitch generates static UI code — it doesn't know about your data layer. You connect the data yourself (with Claude Code's help if needed).

---

## Build & Deployment Commands

```bash
# Development — run on different platforms
flutter run -d chrome                    # Web (Google Chrome)
flutter run -d android                   # Connected Android device / emulator
flutter run -d windows                   # Windows desktop
flutter run -d linux                     # Linux desktop

# Production builds
flutter build web --release              # → build/web/ (deploy to Firebase Hosting)
flutter build apk --release              # → build/app/outputs/flutter-apk/app-release.apk
flutter build appbundle --release        # → for Play Store submission
flutter build windows --release          # → build/windows/x64/Release/
flutter build linux --release            # → build/linux/x64/release/

# Deploy web to Firebase Hosting
firebase deploy --only hosting

# Check all platform toolchains are configured
flutter doctor
```

---

## iOS Note

Building for iOS requires Xcode, which only runs on macOS. If you're on Windows or Linux, you cannot build the iOS app locally. Your options:

1. **Defer iOS**: launch Web + Android + Desktop first. Add iOS later if/when you have a Mac.
2. **GitHub Actions**: set up a macOS CI runner that builds iOS (GitHub provides free macOS minutes on GitHub Actions). Use this to build the .ipa without owning a Mac.
3. **Codemagic**: a Flutter-specific CI service with a free tier that builds iOS remotely.

iOS is your lowest-priority target anyway given Android dominance in Nigeria. Do not let it block everything else.

---

## State Management: Riverpod

Riverpod is what Hooks + Context would be if they were designed specifically for Flutter. Key concepts:

```dart
// A provider is like a React hook — it holds state and reacts to changes

// Simple state provider (like useState)
final counterProvider = StateProvider<int>((ref) => 0);

// Async provider — fetches data (like useEffect + useState)
@riverpod
Future<List<Topic>> topics(TopicsRef ref) async {
  return ref.watch(questionsRepositoryProvider).getTopics();
}

// In your widget — read state with ref.watch (rebuilds on change)
class TopicListScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topicsAsync = ref.watch(topicsProvider);
    
    return topicsAsync.when(
      loading: () => CircularProgressIndicator(),
      error: (e, s) => Text('Error: $e'),
      data: (topics) => ListView.builder(
        itemCount: topics.length,
        itemBuilder: (ctx, i) => TopicCard(topic: topics[i]),
      ),
    );
  }
}
```

This is the entire state management pattern. Learn this one thing well and you can build the whole app.

---

## Seed Data Format

Your initial question bank lives as a JSON file in `assets/questions/maths_waec_seed.json`. This is what you manually enter the first 50 questions into.

```json
{
  "questions": [
    {
      "id": "maths_2022_q1",
      "topicId": "completing_the_square",
      "year": 2022,
      "questionText": "Solve the equation x² - 6x + 5 = 0 by completing the square.",
      "options": {
        "A": "x = 1 or x = 5",
        "B": "x = -1 or x = -5",
        "C": "x = 2 or x = 3",
        "D": "x = -2 or x = -3"
      },
      "correctAnswer": "A",
      "workedSolution": "**Step 1:** Move the constant: x² - 6x = -5\n\n**Step 2:** Complete the square: x² - 6x + 9 = -5 + 9\n\n**Step 3:** Factor: (x - 3)² = 4\n\n**Step 4:** Solve: x - 3 = ±2, so x = 5 or x = 1",
      "difficulty": 2,
      "imageUrl": null
    }
  ]
}
```

---

*Project Paragon Tech Stack & Platform Strategy — May 2026*
