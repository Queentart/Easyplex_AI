import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/utils/validators.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../auth_provider.dart';

/// Real login screen for the F1 auth phase.
///
/// On success, [LoginFormNotifier.submit] flips the global auth state, which
/// the router's redirect picks up and routes the user to their role home — so
/// this screen never navigates explicitly.
///
/// Layout mirrors the responsive dual-view mockup
/// (`unified_login_portal_responsive_dual_view`): a branded teal panel beside
/// the form on wide screens, collapsing to a single centered card on mobile.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    FocusScope.of(context).unfocus();

    final ok = await ref.read(loginFormProvider.notifier).submit(
          _emailController.text,
          _passwordController.text,
        );

    if (!ok && mounted) {
      final message = ref.read(loginFormProvider).errorMessage;
      if (message != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    }
    // On success the router redirect handles navigation automatically.
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(loginFormProvider);
    final isSubmitting = formState.isSubmitting;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            final formCard = _LoginFormCard(
              formKey: _formKey,
              emailController: _emailController,
              passwordController: _passwordController,
              passwordFocus: _passwordFocus,
              obscurePassword: _obscurePassword,
              isSubmitting: isSubmitting,
              onToggleObscure: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              onEmailSubmitted: () => _passwordFocus.requestFocus(),
              onSubmit: _submit,
            );

            if (!isWide) {
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: formCard,
                  ),
                ),
              );
            }

            return Row(
              children: [
                const Expanded(child: _BrandPanel()),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: formCard,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The teal brand panel shown beside the form on wide screens.
class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: double.infinity,
      color: AppColors.primary,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.school_rounded,
            size: 56,
            color: AppColors.onPrimary,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'DongA AI Lab',
            style: AppTypography.headlineLg.copyWith(color: AppColors.onPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '교육 운영 플랫폼',
            style: AppTypography.bodyLg
                .copyWith(color: AppColors.onPrimaryContainer),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '출결 · 과제 · 공지 · 기술지원을 한곳에서',
            style: AppTypography.bodyMd
                .copyWith(color: AppColors.onPrimaryContainer),
          ),
        ],
      ),
    );
  }
}

/// The login form card (shared between mobile and wide layouts).
class _LoginFormCard extends StatelessWidget {
  const _LoginFormCard({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.passwordFocus,
    required this.obscurePassword,
    required this.isSubmitting,
    required this.onToggleObscure,
    required this.onEmailSubmitted,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final FocusNode passwordFocus;
  final bool obscurePassword;
  final bool isSubmitting;
  final VoidCallback onToggleObscure;
  final VoidCallback onEmailSubmitted;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      hero: true,
      child: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('로그인', style: AppTypography.headlineMd),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '계정 정보를 입력해 주세요.',
              style: AppTypography.bodySm
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: emailController,
              enabled: !isSubmitting,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: Validators.email,
              onFieldSubmitted: (_) => onEmailSubmitted(),
              decoration: const InputDecoration(
                labelText: '이메일',
                hintText: 'name@dongaai.com',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: passwordController,
              focusNode: passwordFocus,
              enabled: !isSubmitting,
              obscureText: obscurePassword,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (v) => Validators.password(v),
              // Submit on Enter.
              onFieldSubmitted: (_) => onSubmit(),
              decoration: InputDecoration(
                labelText: '비밀번호',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: obscurePassword ? '비밀번호 표시' : '비밀번호 숨기기',
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: isSubmitting ? null : onToggleObscure,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: '로그인',
              expand: true,
              loading: isSubmitting,
              onPressed: isSubmitting ? null : () => onSubmit(),
            ),
          ],
        ),
      ),
    );
  }
}
