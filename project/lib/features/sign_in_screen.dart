import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:paragon/core/auth/password_rules.dart';
import 'package:paragon/core/providers/auth_provider.dart';
import 'package:paragon/core/repositories/user_repository.dart';
import 'package:paragon/features/account/guest_upgrade.dart';
import 'package:paragon/core/theme/app_colors.dart';
import 'package:paragon/core/theme/app_theme.dart';
import '../core/widgets/ui/ui.dart';
import '../core/theme/app_palette.dart';
import '../core/providers/analytics_provider.dart';

enum _AuthStep { email, password, createAccount }

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  static final _emailRegExp = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  _AuthStep _step = _AuthStep.email;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  // One message slot, shared by errors and the password-reset
  // confirmation — _messageIsError picks red (error) vs green
  // (confirmation) styling for it.
  String? _message;
  bool _messageIsError = true;

  bool get _isEmailValid => _emailRegExp.hasMatch(_emailController.text.trim());

  void _goTo(_AuthStep step) {
    if (_isLoading) return;
    setState(() {
      _message = null;
      _step = step;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _clearMessage() {
    if (_message != null) setState(() => _message = null);
  }

  Future<void> _submitPassword({required bool createAccount}) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final short = createAccount ? newPasswordTooShort(password) : null;
    if (short != null) {
      setState(() {
        _messageIsError = true;
        _message = short;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _message = null;
      _messageIsError = true;
    });

    try {
      // A guest creating an account links it to their session, so what
      // they did as a guest is kept — the same path as /account/upgrade.
      final isGuest = FirebaseAuth.instance.currentUser?.isAnonymous ?? false;
      if (createAccount && isGuest) {
        final outcome = await GuestUpgrade.withEmail(
          ref,
          email: email,
          password: password,
        );
        if (outcome == GuestUpgradeOutcome.accountExists && mounted) {
          setState(() {
            _messageIsError = true;
            _message =
                'An account with this email already exists. Sign in to it '
                "below — this guest session's progress won't come with you.";
            _step = _AuthStep.password;
          });
        }
        return;
      }

      ref.read(analyticsProvider).signupStart(method: 'email');
      final userCredential = createAccount
          ? await FirebaseAuth.instance.createUserWithEmailAndPassword(
              email: email,
              password: password,
            )
          : await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: email,
              password: password,
            );

      if (userCredential.user != null) {
        await ref
            .read(userRepositoryProvider)
            .createUserIfNew(userCredential.user!);
        if (createAccount) {
          ref.read(analyticsProvider).signupComplete(method: 'email');
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _messageIsError = true;
        _message = _authErrorMessage(e.code, createAccount: createAccount);
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _authErrorMessage(String code, {required bool createAccount}) {
    if (createAccount) {
      switch (code) {
        case 'email-already-in-use':
          return 'An account with this email already exists.';
        case 'weak-password':
          return 'Password is too weak. Use at least $kMinPasswordLength characters.';
        case 'invalid-email':
          return 'Enter a valid email address.';
        case 'too-many-requests':
          return 'Too many attempts. Try again later.';
        default:
          return "Couldn't create your account. Please try again.";
      }
    }
    switch (code) {
      case 'wrong-password':
      case 'invalid-credential':
      case 'user-not-found':
        return 'Email or password is incorrect.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      default:
        return "Couldn't sign you in. Please try again.";
    }
  }

  static const _resetSent =
      'If an account uses that email, a reset link is on its way. '
      'Check your inbox and spam folder.';

  Future<void> _sendPasswordReset() async {
    final email = _emailController.text.trim();
    if (!_emailRegExp.hasMatch(email)) {
      setState(() {
        _messageIsError = true;
        _message = 'Enter a valid email above first.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      setState(() {
        _messageIsError = false;
        _message = _resetSent;
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        // The same words whether or not the address has an account, so
        // this box cannot be used to find out who studies on Paragon.
        _messageIsError = e.code != 'user-not-found';
        _message = switch (e.code) {
          'user-not-found' => _resetSent,
          'invalid-email' => 'Enter a valid email address.',
          'too-many-requests' => 'Too many attempts. Try again later.',
          _ => "Couldn't send reset email. Please try again.",
        };
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.background,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: context.palette.textPrimary,
                ),
                onPressed: () => context.go('/welcome'),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: context.palette.surface,
                        border: Border.all(color: context.palette.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: _buildStepChildren(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildStepChildren() {
    switch (_step) {
      case _AuthStep.email:
        return _emailStepChildren();
      case _AuthStep.password:
        return _passwordStepChildren();
      case _AuthStep.createAccount:
        return _createAccountStepChildren();
    }
  }

  List<Widget> _emailStepChildren() {
    return [
      Text(
        'Sign in',
        textAlign: TextAlign.center,
        style: AppTheme.heading2.copyWith(color: context.palette.textPrimary),
      ),
      const SizedBox(height: 24),
      _buildField(
        controller: _emailController,
        label: 'Email',
        keyboardType: TextInputType.emailAddress,
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 24),
      AppButton(
        label: 'Continue',
        size: ButtonSize.lg,
        expand: true,
        onPressed: _isEmailValid
            ? () => setState(() => _step = _AuthStep.password)
            : null,
      ),
    ];
  }

  List<Widget> _passwordStepChildren() {
    return [
      Text(
        'Sign in',
        textAlign: TextAlign.center,
        style: AppTheme.heading2.copyWith(color: context.palette.textPrimary),
      ),
      // Signing in to an existing account cannot bring a guest session
      // with it; creating one can. Say so before they choose.
      if (ref.watch(isGuestProvider)) ...[
        const SizedBox(height: 12),
        const InlineAlert(
          tone: Tone.warning,
          message:
              "You're browsing as a guest. Signing in to an existing account "
              "leaves this session's progress behind — create an account "
              'instead to keep it.',
        ),
      ],
      const SizedBox(height: 24),
      _buildField(
        controller: _emailController,
        label: 'Email',
        keyboardType: TextInputType.emailAddress,
        hasError: _message != null && _messageIsError,
        onChanged: (_) => _clearMessage(),
      ),
      const SizedBox(height: 24),
      _buildField(
        controller: _passwordController,
        label: 'Password',
        obscureText: _obscurePassword,
        hasError: _message != null && _messageIsError,
        onChanged: (_) => _clearMessage(),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: context.palette.textSecondary,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: _isLoading ? null : _sendPasswordReset,
          child: Text(
            'Forgot your password?',
            style: AppTheme.caption.copyWith(
              color: context.palette.textSecondary,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ),
      if (_message != null) ...[
        const SizedBox(height: 8),
        InlineAlert(
          tone: _messageIsError ? Tone.danger : Tone.success,
          message: _message!,
          announce: true,
        ),
      ],
      const SizedBox(height: 24),
      AppButton(
        label: 'Sign in',
        size: ButtonSize.lg,
        expand: true,
        loading: _isLoading,
        onPressed: () => _submitPassword(createAccount: false),
      ),
      const SizedBox(height: 24),
      _SwitchLink(
        question: 'New here?',
        action: 'Create an account',
        onPressed: () => _goTo(_AuthStep.createAccount),
      ),
    ];
  }

  List<Widget> _createAccountStepChildren() {
    return [
      Text(
        'Create an account',
        textAlign: TextAlign.center,
        style: AppTheme.heading2.copyWith(color: context.palette.textPrimary),
      ),
      const SizedBox(height: 24),
      _buildField(
        controller: _emailController,
        label: 'Email',
        keyboardType: TextInputType.emailAddress,
        hasError: _message != null && _messageIsError,
        onChanged: (_) => _clearMessage(),
      ),
      const SizedBox(height: 24),
      _buildField(
        controller: _passwordController,
        label: 'Password',
        obscureText: _obscurePassword,
        hasError: _message != null && _messageIsError,
        onChanged: (_) => _clearMessage(),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: context.palette.textSecondary,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
      if (_message != null) ...[
        const SizedBox(height: 8),
        InlineAlert(
          tone: _messageIsError ? Tone.danger : Tone.success,
          message: _message!,
          announce: true,
        ),
      ],
      const SizedBox(height: 24),
      AppButton(
        label: 'Create account',
        size: ButtonSize.lg,
        expand: true,
        loading: _isLoading,
        onPressed: () => _submitPassword(createAccount: true),
      ),
      const SizedBox(height: 24),
      _SwitchLink(
        question: 'Already have an account?',
        action: 'Sign in',
        onPressed: () => _goTo(_AuthStep.password),
      ),
    ];
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    bool hasError = false,
    ValueChanged<String>? onChanged,
  }) {
    final borderColor = hasError ? AppColors.wrong : context.palette.border;
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: TextStyle(color: context.palette.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: context.palette.textSecondary),
        suffixIcon: suffixIcon,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        filled: true,
        fillColor: context.palette.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(
            color: hasError ? AppColors.wrong : AppColors.primary,
            width: 2,
          ),
        ),
      ),
    );
  }
}

/// "New here? Create an account": a question and a real button — focusable,
/// 40px tall, read as a button. It was underlined 11px text with a tap
/// recognizer that a keyboard could not reach.
class _SwitchLink extends StatelessWidget {
  const _SwitchLink({
    required this.question,
    required this.action,
    required this.onPressed,
  });

  final String question;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          question,
          style: AppTheme.bodyMd.copyWith(color: context.palette.textSecondary),
        ),
        AppButton(
          label: action,
          tone: ButtonTone.ghost,
          size: ButtonSize.sm,
          onPressed: onPressed,
        ),
      ],
    );
  }
}
