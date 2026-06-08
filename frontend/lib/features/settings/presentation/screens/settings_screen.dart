import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants.dart';
import '../../../../core/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../settings_provider.dart';

/// Account settings screen — available to ALL roles.
///
/// Sections:
///   (a) 프로필   — read-only, from [currentUserProvider] (name/email/role/cohort)
///   (b) 비밀번호 변경 — current / new / confirm form with validation + success SnackBar
///   (c) 알림·화면 설정 — local-only / "준비 중"; the backend exposes no preferences
///       endpoint yet, so these toggles are clearly labeled as not-yet-synced.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const String routePath = '/settings';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('설정')),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal:
              ResponsiveLayout.isMobile(context) ? AppSpacing.md : AppSpacing.xl,
          vertical: AppSpacing.lg,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ProfileSection(user: user),
                const SizedBox(height: AppSpacing.lg),
                const _PasswordChangeSection(),
                const SizedBox(height: AppSpacing.lg),
                const _PreferencesSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// (a) Profile — read-only
/// ─────────────────────────────────────────────────────────────────────────

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({required this.user});

  final AppUser? user;

  /// Maps the backend role code to a Korean label.
  static String _roleLabel(String role) {
    switch (role) {
      case AppRoles.adminOps:
        return '운영팀';
      case AppRoles.techSupport:
        return '기술지원팀';
      case AppRoles.instructor:
        return '강사';
      case AppRoles.student:
        return '수강생';
      default:
        return role.isEmpty ? '-' : role;
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = user;
    return AppSectionCard(
      title: '프로필',
      icon: Icons.person_outline_rounded,
      child: u == null
          ? Text('로그인 정보를 불러올 수 없습니다.', style: AppTypography.bodyMd)
          : Column(
              children: [
                _InfoRow(label: '이름', value: u.name.isEmpty ? '-' : u.name),
                const SizedBox(height: AppSpacing.md),
                _InfoRow(label: '이메일', value: u.email.isEmpty ? '-' : u.email),
                const SizedBox(height: AppSpacing.md),
                _InfoRow(label: '역할', value: _roleLabel(u.role)),
                const SizedBox(height: AppSpacing.md),
                _InfoRow(
                  label: '소속 기수',
                  value: u.cohortId == null ? '-' : '${u.cohortId}기',
                ),
              ],
            ),
    );
  }
}

/// Label/value row for the read-only profile block.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: AppTypography.labelMd
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: Text(value, style: AppTypography.bodyMd)),
      ],
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// (b) Password change — form
/// ─────────────────────────────────────────────────────────────────────────

class _PasswordChangeSection extends ConsumerStatefulWidget {
  const _PasswordChangeSection();

  @override
  ConsumerState<_PasswordChangeSection> createState() =>
      _PasswordChangeSectionState();
}

class _PasswordChangeSectionState
    extends ConsumerState<_PasswordChangeSection> {
  final _currentController = TextEditingController();
  final _nextController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _currentObscured = true;
  bool _nextObscured = true;
  bool _confirmObscured = true;

  /// Set true once submit has been attempted, so inline field errors don't
  /// shout at the user before they've interacted.
  bool _showErrors = false;

  @override
  void dispose() {
    _currentController.dispose();
    _nextController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _showErrors = true);
    final state = ref.read(passwordChangeProvider);
    if (!state.isValid) return;

    final ok = await ref.read(passwordChangeProvider.notifier).submit();
    if (!mounted) return;

    if (ok) {
      _currentController.clear();
      _nextController.clear();
      _confirmController.clear();
      setState(() => _showErrors = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('비밀번호가 변경되었습니다.')),
        );
    } else {
      final error = ref.read(passwordChangeProvider).error;
      if (error != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(error)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(passwordChangeProvider);
    final notifier = ref.read(passwordChangeProvider.notifier);

    return AppSectionCard(
      title: '비밀번호 변경',
      icon: Icons.lock_outline_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PasswordField(
            label: '현재 비밀번호',
            controller: _currentController,
            obscured: _currentObscured,
            onToggle: () =>
                setState(() => _currentObscured = !_currentObscured),
            onChanged: notifier.setCurrent,
            errorText: _showErrors ? state.currentError : null,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.md),
          _PasswordField(
            label: '새 비밀번호',
            controller: _nextController,
            obscured: _nextObscured,
            onToggle: () => setState(() => _nextObscured = !_nextObscured),
            onChanged: notifier.setNext,
            errorText: _showErrors ? state.nextError : null,
            helperText: '최소 ${PasswordChangeState.minLength}자 이상',
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.md),
          _PasswordField(
            label: '새 비밀번호 확인',
            controller: _confirmController,
            obscured: _confirmObscured,
            onToggle: () =>
                setState(() => _confirmObscured = !_confirmObscured),
            onChanged: notifier.setConfirm,
            errorText: _showErrors ? state.confirmError : null,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: '비밀번호 변경',
            expand: true,
            loading: state.isSubmitting,
            // Disabled while in flight; otherwise always tappable so the first
            // tap surfaces inline validation messages.
            onPressed: state.isSubmitting ? null : _submit,
          ),
        ],
      ),
    );
  }
}

/// Themed obscured text field with a show/hide toggle.
class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.label,
    required this.controller,
    required this.obscured,
    required this.onToggle,
    required this.onChanged,
    this.errorText,
    this.helperText,
    this.textInputAction,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final bool obscured;
  final VoidCallback onToggle;
  final ValueChanged<String> onChanged;
  final String? errorText;
  final String? helperText;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: AppTypography.labelMd),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: controller,
          obscureText: obscured,
          onChanged: onChanged,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          autofillHints: const [AutofillHints.password],
          decoration: InputDecoration(
            hintText: label,
            errorText: errorText,
            helperText: helperText,
            suffixIcon: IconButton(
              icon: Icon(
                obscured
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
              ),
              tooltip: obscured ? '표시' : '숨기기',
              onPressed: onToggle,
            ),
          ),
        ),
      ],
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// (c) Notification / display preferences — local-only / "준비 중"
/// ─────────────────────────────────────────────────────────────────────────

/// Notification + display preferences.
///
/// The backend exposes NO preferences endpoint yet, so these toggles are
/// local-only and clearly labeled as not-yet-synced ("준비 중"). They keep their
/// own in-widget state and intentionally do not call any API — inventing an
/// endpoint here would break the data-layer contract.
class _PreferencesSection extends StatefulWidget {
  const _PreferencesSection();

  @override
  State<_PreferencesSection> createState() => _PreferencesSectionState();
}

class _PreferencesSectionState extends State<_PreferencesSection> {
  bool _pushEnabled = true;
  bool _emailEnabled = false;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: '알림·화면 설정',
      icon: Icons.tune_rounded,
      trailing: const _ComingSoonBadge(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 20, color: AppColors.outline),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '환경설정 저장은 준비 중입니다. 아래 설정은 이 기기에서만 임시로 적용됩니다.',
                    style: AppTypography.bodySm
                        .copyWith(color: AppColors.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('푸시 알림', style: AppTypography.bodyMd),
            subtitle: Text(
              '새 공지·과제·답변 알림을 받습니다.',
              style: AppTypography.bodySm
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
            value: _pushEnabled,
            onChanged: (v) => setState(() => _pushEnabled = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('이메일 알림', style: AppTypography.bodyMd),
            subtitle: Text(
              '중요 알림을 이메일로도 받습니다.',
              style: AppTypography.bodySm
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
            value: _emailEnabled,
            onChanged: (v) => setState(() => _emailEnabled = v),
          ),
        ],
      ),
    );
  }
}

/// Small pill indicating a section is not yet backed by the server.
class _ComingSoonBadge extends StatelessWidget {
  const _ComingSoonBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.warningContainer,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        '준비 중',
        style: AppTypography.labelSm
            .copyWith(color: AppColors.onWarningContainer),
      ),
    );
  }
}
