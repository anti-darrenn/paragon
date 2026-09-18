import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:paragon/core/repositories/user_repository.dart';
import 'package:paragon/core/theme/app_colors.dart';
import 'package:paragon/core/theme/app_theme.dart';

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

  // Hoisted to fields (rather than created inline in build()) so they can
  // be disposed — TapGestureRecognizer holds gesture-arena state that
  // leaks if never released. Each closure checks _isLoading at tap time,
  // not at assignment time, so a single recognizer instance stays correct
  // across the loading state changing.
  late final TapGestureRecognizer _createAccountRecognizer;
  late final TapGestureRecognizer _backToSignInRecognizer;

  bool get _isEmailValid => _emailRegExp.hasMatch(_emailController.text.trim());

  @override
  void initState() {
    super.initState();
    _createAccountRecognizer = TapGestureRecognizer()
      ..onTap = () {
        if (_isLoading) return;
        setState(() {
          _message = null;
          _step = _AuthStep.createAccount;
        });
      };
    _backToSignInRecognizer = TapGestureRecognizer()
      ..onTap = () {
        if (_isLoading) return;
        setState(() {
          _message = null;
          _step = _AuthStep.password;
        });
      };
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _createAccountRecognizer.dispose();
    _backToSignInRecognizer.dispose();
    super.dispose();
  }

  void _clearMessage() {
    if (_message != null) setState(() => _message = null);
  }

  Future<void> _submitPassword({required bool createAccount}) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    setState(() {
      _isLoading = true;
      _message = null;
      _messageIsError = true;
    });

    try {
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
          return 'Password is too weak. Use at least 6 characters.';
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
        _message = 'Password reset email sent — check your inbox.';
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        _messageIsError = true;
        _message = switch (e.code) {
          'user-not-found' => 'No account found with that email.',
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
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: AppColors.textPrimaryDark,
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
                        color: AppColors.surfaceDark,
                        border: Border.all(color: AppColors.borderDark),
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
        style: AppTheme.heading2.copyWith(color: AppColors.textPrimaryDark),
      ),
      const SizedBox(height: 24),
      _buildField(
        controller: _emailController,
        label: 'Email',
        keyboardType: TextInputType.emailAddress,
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 24),
      SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed: _isEmailValid
              ? () => setState(() => _step = _AuthStep.password)
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            disabledBackgroundColor: AppColors.primary.withAlpha(
              (0.4 * 255).round(),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            elevation: 0,
          ),
          child: Text(
            'Continue',
            style: AppTheme.btnLabel.copyWith(color: Colors.white),
          ),
        ),
      ),
    ];
  }

  List<Widget> _passwordStepChildren() {
    return [
      Text(
        'Sign in',
        textAlign: TextAlign.center,
        style: AppTheme.heading2.copyWith(color: AppColors.textPrimaryDark),
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
            color: AppColors.textSecondaryDark,
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
              color: AppColors.textSecondaryDark,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ),
      if (_message != null) ...[
        const SizedBox(height: 8),
        Text(
          _message!,
          textAlign: TextAlign.center,
          style: AppTheme.caption.copyWith(
            color: _messageIsError ? AppColors.wrong : AppColors.correct,
          ),
        ),
      ],
      const SizedBox(height: 24),
      SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed: _isLoading
              ? null
              : () => _submitPassword(createAccount: false),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            disabledBackgroundColor: AppColors.primary.withAlpha(
              (0.4 * 255).round(),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            elevation: 0,
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  'Sign in',
                  style: AppTheme.btnLabel.copyWith(color: Colors.white),
                ),
        ),
      ),
      const SizedBox(height: 24),
      Center(
        child: RichText(
          text: TextSpan(
            style: AppTheme.caption.copyWith(
              color: AppColors.textSecondaryDark,
              decoration: TextDecoration.underline,
            ),
            children: [
              const TextSpan(text: 'New here? '),
              TextSpan(
                text: 'Create an account!',
                style: const TextStyle(color: AppColors.primary),
                recognizer: _createAccountRecognizer,
              ),
            ],
          ),
        ),
      ),
    ];
  }

  List<Widget> _createAccountStepChildren() {
    return [
      Text(
        'Create an account',
        textAlign: TextAlign.center,
        style: AppTheme.heading2.copyWith(color: AppColors.textPrimaryDark),
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
            color: AppColors.textSecondaryDark,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
      if (_message != null) ...[
        const SizedBox(height: 8),
        Text(
          _message!,
          textAlign: TextAlign.center,
          style: AppTheme.caption.copyWith(
            color: _messageIsError ? AppColors.wrong : AppColors.correct,
          ),
        ),
      ],
      const SizedBox(height: 24),
      SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed: _isLoading
              ? null
              : () => _submitPassword(createAccount: true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            disabledBackgroundColor: AppColors.primary.withAlpha(
              (0.4 * 255).round(),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            elevation: 0,
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  'Create Account',
                  style: AppTheme.btnLabel.copyWith(color: Colors.white),
                ),
        ),
      ),
      const SizedBox(height: 24),
      Center(
        child: RichText(
          text: TextSpan(
            style: AppTheme.caption.copyWith(
              color: AppColors.textSecondaryDark,
              decoration: TextDecoration.underline,
            ),
            children: [
              const TextSpan(text: 'Already have an account? '),
              TextSpan(
                text: 'Sign in',
                style: const TextStyle(color: AppColors.primary),
                recognizer: _backToSignInRecognizer,
              ),
            ],
          ),
        ),
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
    final borderColor = hasError ? AppColors.wrong : AppColors.borderDark;
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: const TextStyle(color: AppColors.textPrimaryDark),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondaryDark),
        suffixIcon: suffixIcon,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        filled: true,
        fillColor: AppColors.backgroundDark,
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
