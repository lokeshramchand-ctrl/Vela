import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/screen_back_header.dart';
import 'auth_controller.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await ref.read(authControllerProvider.notifier).registerAndLogin(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
    final state = ref.read(authControllerProvider);
    if (state.hasError && mounted) {
      final error = state.error;
      final message = error is ApiException ? error.message : 'Something went wrong. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: AppColors.ink900,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                const ScreenBackHeader(),
                const SizedBox(height: 12),
                Text('Create your account', style: AppTypography.bigHeadline26.copyWith(color: AppColors.onDark)),
                const SizedBox(height: 8),
                Text(
                  'One account, every statement you add.',
                  style: AppTypography.footnote15.copyWith(color: AppColors.onDarkMuted),
                ),
                const SizedBox(height: 28),
                _label('EMAIL'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  style: AppTypography.body14.copyWith(color: AppColors.onDark),
                  keyboardType: TextInputType.emailAddress,
                  decoration: _decoration('you@example.com'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Enter your email';
                    if (!value.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                _label('PASSWORD'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  style: AppTypography.body14.copyWith(color: AppColors.onDark),
                  obscureText: _obscure,
                  decoration: _decoration('At least 8 characters').copyWith(
                    suffixIcon: IconButton(
                      tooltip: _obscure ? 'Show password' : 'Hide password',
                      icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.onDarkFaint),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.length < 8) return 'Use at least 8 characters';
                    if (value.length > 128) return 'Password is too long';
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                _label('CONFIRM PASSWORD'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _confirmController,
                  style: AppTypography.body14.copyWith(color: AppColors.onDark),
                  obscureText: _obscure,
                  decoration: _decoration('Re-enter your password'),
                  onFieldSubmitted: (_) => _submit(),
                  validator: (value) {
                    if (value != _passwordController.text) return "Passwords don't match";
                    return null;
                  },
                ),
                const SizedBox(height: 28),
                PrimaryPillButton(label: 'Create account', onPressed: _submit, loading: isLoading),
                const SizedBox(height: 20),
                Center(
                  child: TextButton(
                    onPressed: () => context.pop(),
                    child: Text('Already have an account? Sign in', style: AppTypography.footnote12.copyWith(color: AppColors.accentDim)),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text, style: AppTypography.microLabel11.copyWith(color: AppColors.onDarkFaint));

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTypography.body14.copyWith(color: AppColors.onDarkFaint),
      filled: true,
      fillColor: AppColors.ink850,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.hairlineDark)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.hairlineDark)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.accent)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.rose)),
    );
  }
}
