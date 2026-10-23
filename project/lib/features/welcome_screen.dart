import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/models/subject.dart';
import '../core/providers/auth_provider.dart';
import '../core/router/return_to.dart';
import '../core/repositories/learning_repository.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';
import 'account/guest_upgrade.dart';
import 'account/upgrade_screen.dart';
import '../core/theme/app_palette.dart';
import 'about_screen.dart';
import '../core/widgets/paragon_logo.dart';
import '../core/providers/analytics_provider.dart';
import '../core/config/site_config.dart';
import '../core/sound/sfx.dart';
import '../core/widgets/answer_option.dart';
import '../core/widgets/auth/google_button.dart';
import '../core/widgets/math_text.dart';
import '../core/widgets/ui/ui.dart';

/// Pre-auth landing screen — the front door for signed-out visitors.
/// See the redirect logic in app_router.dart: any signed-out navigation
/// (other than to /signin) is sent here.
///
/// Built from Figma file 29nbJDmGOJI3bBj5AtburF, node 23:323
/// ("welcome/default"), read via the Figma MCP.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  bool _isLoading = false;
  String? _errorMessage;

  // Reuses the shared Google sign-in flow from auth_provider.dart — the
  // same flow SignInScreen calls. Only the loading/error UI is local.
  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      // A guest returning here (Android always opens at /welcome) keeps
      // their session by linking Google to it, rather than being signed
      // in afresh and leaving the guest's work behind.
      if (ref.read(isGuestProvider)) {
        final outcome = await GuestUpgrade.withGoogle(ref);
        if (outcome != GuestUpgradeOutcome.accountExists || !mounted) return;
        if (!await confirmSignInToExistingAccount(context, isGoogle: true)) {
          return;
        }
      }
      await signInWithGoogle(ref);
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = e.message ?? 'Google sign-in failed.');
    } catch (e) {
      setState(() => _errorMessage = 'Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Guest session via the shared anonymous-auth helper — an anonymous UID
  // is a real UID, so nothing downstream needs to know the difference.
  // Explicit navigation is required here: the router's redirect
  // deliberately does NOT move a guest off /welcome (an anonymous user
  // revisiting /welcome to upgrade must be allowed to stay put — see
  // app_router.dart's isReallySignedIn check), so it can't distinguish
  // that case from "just signed in as guest, should land on home."
  Future<void> _handleGuestSignIn({String? to}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await signInAnonymously(ref);
      ref.read(analyticsProvider).guestStart();
      // '/' is the dashboard — a guest lands on the same home surface a
      // signed-in user does.
      if (mounted) {
        // Back to the page a shared link was opening, if there was one.
        context.go(
          to ??
              safeNextPath(
                GoRouterState.of(context).uri.queryParameters[kNextParam],
              ) ??
              '/',
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(
        () => _errorMessage = e.message ?? "Couldn't start a guest session.",
      );
    } catch (e) {
      setState(() => _errorMessage = 'Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 900;
    final p = context.palette;
    final isGuest = ref.watch(isGuestProvider);

    // Sign-in is the main action (owner's decision, 2026-10-23); the
    // taster and guest browsing sit beneath it.
    final actions = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_errorMessage != null) ...[
            InlineAlert(
              tone: Tone.danger,
              message: _errorMessage!,
              announce: true,
            ),
            const SizedBox(height: 12),
          ],
          GoogleSignInButton(
            onPressed: _handleGoogleSignIn,
            loading: _isLoading,
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Sign in with email',
            tone: ButtonTone.secondary,
            size: ButtonSize.lg,
            icon: Icons.mail_outline_rounded,
            expand: true,
            // welcome shouldn't stay on the back stack once we leave it
            onPressed: _isLoading ? null : () => context.go('/signin'),
          ),
          const SizedBox(height: 16),
          // Five questions before any decision: the quickest way to see
          // what Paragon is. Starts a guest session, like browsing.
          Align(
            alignment: wide ? Alignment.centerLeft : Alignment.center,
            child: AppButton(
              label: 'Try 5 questions, no sign-up',
              tone: ButtonTone.ghost,
              icon: Icons.bolt_rounded,
              onPressed: _isLoading
                  ? null
                  : () => _handleGuestSignIn(to: '/try'),
            ),
          ),
          // A guest who came back to welcome (from the menu's "Welcome
          // page") carries on where they were.
          Align(
            alignment: wide ? Alignment.centerLeft : Alignment.center,
            child: AppButton(
              label: isGuest ? 'Continue as guest' : 'Browse as a guest',
              tone: ButtonTone.ghost,
              size: ButtonSize.sm,
              onPressed: _isLoading
                  ? null
                  : isGuest
                  ? () => context.go('/')
                  : () => _handleGuestSignIn(),
            ),
          ),
        ],
      ),
    );

    final hero = Column(
      crossAxisAlignment: wide
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        SizedBox(
          height: wide ? 64 : 52,
          child: const AspectRatio(
            aspectRatio: 818 / 215,
            child: ParagonLogo(semanticLabel: 'Project Paragon'),
          ),
        ),
        SizedBox(height: wide ? 32 : 24),
        // A plain placeholder until the owner picks one of the options in
        // docs/COPY.md (audit C15).
        Semantics(
          header: true,
          child: Text(
            _headline,
            textAlign: wide ? TextAlign.start : TextAlign.center,
            style: (wide ? AppTheme.display : AppTheme.heading1).copyWith(
              color: p.textStrong,
            ),
          ),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Text(
            'Real WAEC past questions, worked answers, lessons and practice '
            'for every topic. Free for every student.',
            textAlign: wide ? TextAlign.start : TextAlign.center,
            style: AppTheme.bodyLg.copyWith(color: p.textSecondary),
          ),
        ),
        const SizedBox(height: 28),
        actions,
        const SizedBox(height: 32),
        const _ValuePoints(),
      ],
    );

    return Scaffold(
      backgroundColor: p.background,
      // CustomScrollView + SliverFillRemaining(hasScrollBody: false) fills
      // the page when the content fits and scrolls when it does not, with
      // a bounded height so the Spacer below can push the footer down.
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Stack(
                children: [
                  // Decorative background (Figma: "lo-effort-decor").
                  Positioned.fill(
                    child: SvgPicture.asset(
                      'assets/images/decor_background.svg',
                      fit: BoxFit.cover,
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1120),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              24,
                              wide ? 72 : 40,
                              24,
                              40,
                            ),
                            child: wide
                                ? Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Expanded(flex: 6, child: hero),
                                      const SizedBox(width: 56),
                                      const Expanded(
                                        flex: 5,
                                        child: _HeroArt(),
                                      ),
                                    ],
                                  )
                                : hero,
                          ),
                        ),
                      ),
                      // Pushes the ticker and footer to the bottom of a
                      // tall window; nothing when the content fills it.
                      const Spacer(),
                      Container(height: 1, color: p.border.withAlpha(102)),
                      const SizedBox(height: 24),
                      const _SubjectTicker(),
                      const SizedBox(height: 24),
                      // About and contact — readable signed out, like the
                      // legal pages below.
                      const _FooterLinks(),
                      const SizedBox(height: 12),
                      const _ConsentLine(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The welcome page's headline: the tagline once the owner has picked one
/// from docs/COPY.md, and until then a plain statement of what Paragon is
/// rather than the placeholder.
const _headline = kTagline == 'To be determined'
    ? 'Free WAEC past questions and practice'
    : kTagline;

/// Three things Paragon gives a student.
class _ValuePoints extends StatelessWidget {
  const _ValuePoints();

  @override
  Widget build(BuildContext context) {
    const points = [
      (
        Icons.history_edu_rounded,
        AppColors.primary,
        'Real past questions',
        'From WAEC papers, each marked with its year.',
      ),
      (
        Icons.lightbulb_outline_rounded,
        AppColors.medalGold,
        'Worked answers',
        'Hints and the working, not just the letter.',
      ),
      (
        Icons.insights_rounded,
        AppColors.secondary,
        'Know where you stand',
        'Mastery for every topic and a grade estimate.',
      ),
    ];
    final p = context.palette;
    // A column, not a Wrap: the page sizes itself from its content's
    // intrinsic height, which a Wrap under-reports when it wraps.
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (icon, colour, title, text) in points)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconTile(icon: icon, color: colour, size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTheme.bodyMd.copyWith(
                            color: p.textStrong,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          text,
                          style: AppTheme.label.copyWith(
                            color: p.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The wide screen's right half: the welcome illustration over a question
/// to try on the spot.
class _HeroArt extends StatelessWidget {
  const _HeroArt();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Illustration(IllustrationAsset.welcome, height: 220),
        SizedBox(height: 8),
        _SampleQuestion(),
      ],
    );
  }
}

/// One question to answer on the welcome page: instant feedback, nothing
/// recorded, no account needed. The arithmetic is checked here, not drawn
/// from the bank: 2³ × 2⁴ = 2⁷.
class _SampleQuestion extends StatefulWidget {
  const _SampleQuestion();

  @override
  State<_SampleQuestion> createState() => _SampleQuestionState();
}

class _SampleQuestionState extends State<_SampleQuestion> {
  static const _options = [
    r'\(2^7\)',
    r'\(2^{12}\)',
    r'\(4^7\)',
    r'\(4^{12}\)',
  ];
  static const _right = 0;
  int? _picked;

  void _pick(int i) {
    if (_picked != null) return;
    Sfx.unlock();
    Sfx.play(i == _right ? SfxCue.correct : SfxCue.wrong);
    setState(() => _picked = i);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final picked = _picked;
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Tag('Try one', tone: Tone.info),
              const Spacer(),
              if (picked != null)
                AppButton(
                  label: 'Again',
                  tone: ButtonTone.ghost,
                  size: ButtonSize.sm,
                  onPressed: () => setState(() => _picked = null),
                ),
            ],
          ),
          const SizedBox(height: 10),
          MathText(
            text: r'Simplify \(2^3 \times 2^4\)',
            style: AppTheme.questionStem.copyWith(color: p.textStrong),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < _options.length; i++)
            AnswerOption(
              index: i,
              text: _options[i],
              state: picked == null
                  ? AnswerOptionState.idle
                  : i == _right
                  ? AnswerOptionState.correct
                  : i == picked
                  ? AnswerOptionState.wrong
                  : AnswerOptionState.ruledOut,
              onTap: picked == null ? () => _pick(i) : null,
            ),
          if (picked != null) ...[
            AnswerVerdict(right: picked == _right, correctIndex: _right),
            MathText(
              text: r'Same base, so add the powers: \(2^{3+4} = 2^7\).',
              style: AppTheme.bodyMd.copyWith(color: p.textSecondary),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

/// Seamless, continuously left-scrolling subject ticker.
/// Figma annotation on the frame: "Seamless marquee loop, left scroll,
/// ~70px/s" — implemented here as a hand-rolled AnimationController
/// (no marquee package). Pre-auth screen — `subjects` is confirmed
/// publicly readable (see project/firestore.rules and .cursorrules).
/// Fails gracefully (renders nothing) on error.
class _SubjectTicker extends ConsumerStatefulWidget {
  const _SubjectTicker();

  @override
  ConsumerState<_SubjectTicker> createState() => _SubjectTickerState();
}

class _SubjectTickerState extends ConsumerState<_SubjectTicker>
    with SingleTickerProviderStateMixin {
  static const _pixelsPerSecond = 70.0;
  static const _height = 32.0;

  final GlobalKey _rowKey = GlobalKey();
  late final AnimationController _controller;
  double? _rowWidth;

  @override
  void initState() {
    super.initState();
    // Placeholder duration — replaced with the real one once the row's
    // rendered width is measured and repeat() is (re)started.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
  }

  void _measure() {
    final box = _rowKey.currentContext?.findRenderObject() as RenderBox?;
    final width = box?.size.width;
    if (!mounted || width == null || width <= 0) return;
    setState(() => _rowWidth = width);
    _controller
      ..duration = Duration(
        milliseconds: (width / _pixelsPerSecond * 1000).round(),
      )
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _colorFor(Subject subject) {
    // Figma's 2-tone scheme for this component: primary for Mathematics,
    // secondary for every other subject (not the app-wide 10-color
    // AppColors.forSubject() palette used elsewhere).
    return subject.name.toLowerCase() == 'mathematics'
        ? AppColors.primary
        : AppColors.secondary;
  }

  Widget _buildRow(List<Subject> subjects, {Key? key}) {
    return Row(
      key: key,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final subject in subjects) ...[
          Text(
            subject.name,
            style: AppTheme.label.copyWith(color: _colorFor(subject)),
          ),
          const SizedBox(width: 10),
          SvgPicture.asset('assets/icons/dot.svg', width: 4, height: 4),
          // The live split from `subjects.pastQuestionCount` and
          // `practiceQuestionCount` (kept by `jobs.js --job=counts`, from
          // the same counts as every topic's, so the course page agrees).
          // Nothing known yet means nothing shown, never 0.
          if (subject.counts.label.isNotEmpty) ...[
            const SizedBox(width: 10),
            Text(
              subject.counts.label,
              style: AppTheme.label.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
          ],
          const SizedBox(width: 22),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final subjectsAsync = ref.watch(subjectsProvider);

    return subjectsAsync.when(
      loading: () => const SizedBox(height: _height),
      error: (e, st) => const SizedBox.shrink(),
      data: (subjects) {
        if (subjects.isEmpty) return const SizedBox.shrink();
        // One label for the whole marquee: read as it moves, a screen
        // reader got each repeated copy of the row, several times over.
        final spoken =
            'Subjects: ${[
              for (final s in subjects) [s.name, if (s.counts.label.isNotEmpty) s.counts.label].join(', '),
            ].join('; ')}.';
        return Semantics(
          label: spoken,
          excludeSemantics: true,
          child: _ticker(subjects),
        );
      },
    );
  }

  Widget _ticker(List<Subject> subjects) {
    // Reduced motion: the same row, still, scrollable by hand.
    if (reduceMotion(context)) {
      _controller.stop();
      return SizedBox(
        height: _height,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: _buildRow(subjects),
        ),
      );
    }

    if (_rowWidth == null) {
      // Measuring pass: lay the row out invisibly to learn its
      // rendered width, then compute the animation duration from it.
      // The row's natural width is (by design) usually wider than the
      // viewport — especially on narrow phones — so it needs an
      // OverflowBox here too, or a plain Row under the SizedBox's
      // tight screen-width constraint throws a RenderFlex overflow.
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
      return SizedBox(
        height: _height,
        child: Opacity(
          opacity: 0,
          child: OverflowBox(
            minWidth: 0,
            maxWidth: double.infinity,
            alignment: Alignment.centerLeft,
            child: _buildRow(subjects, key: _rowKey),
          ),
        ),
      );
    }

    // Repeat the row enough times to cover the viewport width, plus
    // one extra copy — otherwise, on a screen wider than a couple of
    // row-widths, there'd be a blank gap once the translate has
    // shifted past however many copies exist. The loop itself still
    // only ever translates by exactly one row-width (see below); the
    // extra copies just mean there's always a full row's worth of
    // buffer still off-screen to the right at any point in that
    // translate range.
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final repeatCount = (viewportWidth / _rowWidth!).ceil() + 1;

    return SizedBox(
      height: _height,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Transform.translate(
              // Loops by translating exactly one row-width: at
              // value=1 this sits exactly where value=0 started,
              // because every copy is identical, so the reset (which
              // repeat() performs instantly) is imperceptible.
              offset: Offset(-_controller.value * _rowWidth!, 0),
              child: OverflowBox(
                minWidth: 0,
                maxWidth: double.infinity,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 0; i < repeatCount; i++)
                      _buildRow(subjects, key: i == 0 ? _rowKey : null),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// "By continuing you agree to our Terms and Privacy Policy." — shown
/// above the fold's end on the welcome screen, with both destinations
/// reachable without signing in.
class _FooterLinks extends StatelessWidget {
  const _FooterLinks();

  @override
  Widget build(BuildContext context) {
    final style = AppTheme.caption.copyWith(
      color: context.palette.textSecondary,
      decoration: TextDecoration.underline,
      decorationColor: context.palette.textSecondary,
    );

    Widget link(String label, VoidCallback onTap) =>
        _TextLink(label: label, style: style, onTap: onTap);

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 20,
      children: [
        link('About', () => context.push('/about')),
        link('Contact', () => launchUrl(aboutMailto)),
      ],
    );
  }
}

class _ConsentLine extends StatelessWidget {
  const _ConsentLine();

  @override
  Widget build(BuildContext context) {
    // Not the brand orange: on the light theme it is under 3:1 against
    // the background, and these are the words a student agrees to.
    final linkStyle = AppTheme.caption.copyWith(
      color: context.palette.textPrimary,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: context.palette.textPrimary,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'By continuing you agree to our ',
            style: AppTheme.caption.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
          _TextLink(
            label: 'Terms',
            style: linkStyle,
            onTap: () => context.push('/terms'),
          ),
          Text(
            ' and ',
            style: AppTheme.caption.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
          _TextLink(
            label: 'Privacy Policy',
            style: linkStyle,
            onTap: () => context.push('/privacy'),
          ),
          Text(
            '.',
            style: AppTheme.caption.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// A link inside a line of text that is a real button: a name and a role
/// for screen readers, keyboard focus, and a 48px-tall tap target, without
/// the button padding that would break the sentence apart. The welcome
/// screen's links were bare `GestureDetector`s, invisible to assistive
/// technology (live-site review, F9).
class _TextLink extends StatelessWidget {
  const _TextLink({
    required this.label,
    required this.style,
    required this.onTap,
  });

  final String label;
  final TextStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        minimumSize: const Size(0, 48),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: style.color,
      ),
      child: Text(label, style: style),
    );
  }
}
