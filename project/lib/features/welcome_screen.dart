import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../core/models/subject.dart';
import '../core/providers/auth_provider.dart';
import '../core/repositories/learning_repository.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';

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
  Future<void> _handleGuestSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await signInAnonymously(ref);
      // '/' is the dashboard — a guest lands on the same home surface a
      // signed-in user does.
      if (mounted) context.go('/');
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
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      // CustomScrollView + SliverFillRemaining(hasScrollBody: false) fills
      // the child to exactly the remaining viewport space when content
      // fits (no scrollbar, nothing to scroll), and lets the CustomScrollView
      // become scrollable when content is taller than the viewport — the
      // sliver-based tool built for exactly this "fill or scroll" case.
      // Unlike a bare SingleChildScrollView, its child gets a properly
      // bounded height, so the Spacer below works directly with no
      // IntrinsicHeight workaround needed.
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Stack(
                children: [
                  // ── Decorative background layer (Figma:
                  // "lo-effort-decor"). One exported SVG asset, not
                  // hand-drawn shapes. BoxFit.cover preserves the shapes'
                  // aspect ratio (crops, never stretches). Edge-to-edge —
                  // not inset by the content's own vertical padding below.
                  Positioned.fill(
                    child: SvgPicture.asset(
                      'assets/images/decor_background.svg',
                      fit: BoxFit.cover,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 48),

                              // ── Logo — Figma: 818x215, capped at that
                              // width, aspect ratio preserved, shrinks on
                              // narrow screens (ConstrainedBox intersects
                              // with the incoming width constraint
                              // automatically). Also capped at ~22% of
                              // viewport height so the divider/strip stay
                              // above the fold on short-but-wide screens
                              // (e.g. 1366x768), where width alone isn't
                              // the binding constraint — AspectRatio picks
                              // whichever of the two caps is tighter.
                              Center(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: 818,
                                    maxHeight:
                                        MediaQuery.sizeOf(context).height *
                                        0.22,
                                  ),
                                  child: AspectRatio(
                                    aspectRatio: 818 / 215,
                                    child: Image.asset(
                                      'assets/images/paragon_logo.png',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // ── Tagline — Figma: Heading 1 (24/1.25, Bold)
                              Text(
                                'Learning the right way.',
                                textAlign: TextAlign.center,
                                style: AppTheme.heading1.copyWith(
                                  color: AppColors.textSecondaryDark,
                                ),
                              ),

                              const SizedBox(height: 56),

                              // ── Auth entry points — reuse existing logic/
                              // routes only, nothing rebuilt. Figma: both
                              // buttons 420x52, 4px radius, 16px gap, centered.
                              if (_errorMessage != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(
                                    _errorMessage!,
                                    textAlign: TextAlign.center,
                                    style: AppTheme.caption.copyWith(
                                      color: AppColors.wrong,
                                    ),
                                  ),
                                ),

                              // Extra inset on phone-width screens so the
                              // buttons read as an inset element rather
                              // than edge-to-edge — the 420 cap below
                              // already doesn't bind under ~470px (screen
                              // width minus the 24px padding on each
                              // side), so narrowing further here needs
                              // its own margin, not a smaller maxWidth.
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal:
                                      MediaQuery.sizeOf(context).width < 480
                                      ? 16
                                      : 0,
                                ),
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 420,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        // btn/google — Figma: #D9D9D9 fill, real
                                        // multi-color Google "G" PNG (not the
                                        // hand-drawn circle), dark text.
                                        SizedBox(
                                          height: 52,
                                          child: ElevatedButton(
                                            onPressed: _isLoading
                                                ? null
                                                : _handleGoogleSignIn,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  AppColors.buttonLight,
                                              disabledBackgroundColor: AppColors
                                                  .buttonLight
                                                  .withAlpha(
                                                    (0.6 * 255).round(),
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              elevation: 0,
                                            ),
                                            child: _isLoading
                                                ? const SizedBox(
                                                    height: 20,
                                                    width: 20,
                                                    child:
                                                        CircularProgressIndicator(
                                                          color: AppColors
                                                              .backgroundDark,
                                                          strokeWidth: 2,
                                                        ),
                                                  )
                                                : Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Image.asset(
                                                        'assets/icons/google_g.png',
                                                        width: 30,
                                                        height: 30,
                                                      ),
                                                      const SizedBox(width: 10),
                                                      Flexible(
                                                        child: Text(
                                                          'Continue with Google',
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: AppTheme
                                                              .btnLabel
                                                              .copyWith(
                                                                color: AppColors
                                                                    .backgroundDark,
                                                              ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                          ),
                                        ),
                                        const SizedBox(height: 16),

                                        // btn/email — Figma: 2px primary-orange
                                        // outline, mail icon, primary text color.
                                        SizedBox(
                                          height: 52,
                                          child: OutlinedButton(
                                            // welcome shouldn't stay on the back
                                            // stack once we leave it
                                            onPressed: _isLoading
                                                ? null
                                                : () => context.go('/signin'),
                                            style: OutlinedButton.styleFrom(
                                              side: const BorderSide(
                                                color: AppColors.primary,
                                                width: 2,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                SvgPicture.asset(
                                                  'assets/icons/mail_icon.svg',
                                                  width: 24,
                                                  height: 19,
                                                ),
                                                const SizedBox(width: 10),
                                                Flexible(
                                                  child: Text(
                                                    'Sign in with E-Mail',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: AppTheme.btnLabel
                                                        .copyWith(
                                                          color: AppColors
                                                              .textPrimaryDark,
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),

                              // ── Guest entry — Figma: Caption style,
                              // centered, ghost/text button, no fill, no
                              // border (spec §2.1.3). Routes into the WAEC
                              // setup screen's guest restrictions once
                              // signed in anonymously — see
                              // waec_subject_screen.dart / waec_exam_setup_screen.dart.
                              Center(
                                child: TextButton(
                                  onPressed: _isLoading
                                      ? null
                                      : _handleGuestSignIn,
                                  child: Text(
                                    'Browse as Guest',
                                    style: AppTheme.caption.copyWith(
                                      color: AppColors.textSecondaryDark,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),

                        // Pushes the divider/ticker/footer down to sit near the
                        // bottom (as in Figma) on a tall viewport with short
                        // content; contributes nothing when content already
                        // fills or exceeds the viewport (works because
                        // SliverFillRemaining(hasScrollBody: false) gives
                        // this Column a bounded height, unlike a bare
                        // SingleChildScrollView).
                        const Spacer(),

                        // ── Divider — Figma: full-bleed, AppColors.borderDark
                        // at 40% opacity, between the auth zone and the ticker.
                        Container(
                          height: 1,
                          color: AppColors.borderDark.withAlpha(
                            (0.4 * 255).round(),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── Subject strip — seamless left-scrolling marquee,
                        // full-bleed (not inset with the 24px content padding
                        // above, matching Figma's wider-than-frame ticker track).
                        const _SubjectTicker(),

                        const SizedBox(height: 24),

                        // TODO(design): contacts footer goes here — omitted
                        // this pass per instruction. Real contact details
                        // (email/phone) exist in the Figma frame but are not
                        // wired in yet; awaiting explicit sign-off to use them.

                        // Consent line — the destinations now exist at
                        // /terms and /privacy, both readable signed out.
                        const _ConsentLine(),
                        const SizedBox(height: 8),
                      ],
                    ),
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
          // The live count from `subjects.questionCount` (kept by
          // `jobs.js --job=counts`), never Figma's sample copy. Zero means
          // "not known yet", so the number is left out, not shown as 0.
          if (subject.questionCount > 0) ...[
            const SizedBox(width: 10),
            Text(
              '${_groupThousands(subject.questionCount)} questions',
              style: AppTheme.label.copyWith(
                color: AppColors.textSecondaryDark,
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
      },
    );
  }
}

/// "By continuing you agree to our Terms and Privacy Policy." — shown
/// above the fold's end on the welcome screen, with both destinations
/// reachable without signing in.
class _ConsentLine extends StatelessWidget {
  const _ConsentLine();

  @override
  Widget build(BuildContext context) {
    final linkStyle = AppTheme.caption.copyWith(
      color: AppColors.primary,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.primary,
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
              color: AppColors.textSecondaryDark,
            ),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => context.push('/terms'),
              child: Text('Terms', style: linkStyle),
            ),
          ),
          Text(
            ' and ',
            style: AppTheme.caption.copyWith(
              color: AppColors.textSecondaryDark,
            ),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => context.push('/privacy'),
              child: Text('Privacy Policy', style: linkStyle),
            ),
          ),
          Text(
            '.',
            style: AppTheme.caption.copyWith(
              color: AppColors.textSecondaryDark,
            ),
          ),
        ],
      ),
    );
  }
}

/// 14602 -> "14,602".
String _groupThousands(int n) =>
    n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
