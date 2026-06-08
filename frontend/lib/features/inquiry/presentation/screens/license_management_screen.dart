import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants.dart';
import '../../../../core/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/utils/date_formatter.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_data_table.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../../shared/widgets/top_bar.dart';
import '../../data/inquiry_repository.dart';
import '../../domain/inquiry_model.dart';
import '../inquiry_provider.dart';

StatusTone _licenseTone(LicenseStatus s) => switch (s) {
      LicenseStatus.active => StatusTone.success,
      LicenseStatus.expired => StatusTone.warning,
      LicenseStatus.revoked => StatusTone.danger,
    };

/// Software license management (`/tech/licenses`). Tech Support and Operations
/// can view + reveal keys; only Operations (admin_ops) can register new
/// licenses (the create button is hidden otherwise and the backend enforces
/// 403 anyway).
///
/// Revealing a key calls the AUDITED `GET /licenses/{id}/key` endpoint behind a
/// confirmation dialog that explicitly notes the access is recorded.
class LicenseManagementScreen extends ConsumerWidget {
  const LicenseManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final licenses = ref.watch(licenseListProvider);
    final user = ref.watch(currentUserProvider);
    final canCreate = user?.role == AppRoles.adminOps;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: TopBar(
        title: '라이선스 관리',
        actions: [
          if (canCreate) ...[
            const SizedBox(width: AppSpacing.sm),
            AppButton(
              label: '라이선스 등록',
              icon: Icons.add_rounded,
              variant: AppButtonVariant.primary,
              onPressed: () => _openCreateDialog(context, ref),
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: licenses.when(
          loading: () => const LoadingView(message: '라이선스를 불러오는 중입니다'),
          error: (e, _) => ErrorView(
            message: e.toString(),
            onRetry: () => ref.read(licenseListProvider.notifier).refresh(),
          ),
          data: (items) => items.isEmpty
              ? EmptyState(
                  icon: Icons.vpn_key_outlined,
                  title: '등록된 라이선스가 없습니다',
                  description: canCreate
                      ? '상단의 "라이선스 등록" 버튼으로 라이선스를 등록하세요.'
                      : '등록된 라이선스가 없습니다.',
                )
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () =>
                      ref.read(licenseListProvider.notifier).refresh(),
                  child: ResponsiveLayout(
                    mobile: (_) => _LicenseCardList(items: items),
                    tablet: (_) => _LicenseTable(items: items),
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _openCreateDialog(BuildContext context, WidgetRef ref) async {
    await showDialog<void>(
      context: context,
      builder: (_) => const _LicenseCreateDialog(),
    );
  }
}

class _LicenseCardList extends StatelessWidget {
  const _LicenseCardList({required this.items});

  final List<SoftwareLicense> items;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, i) {
        final lic = items[i];
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(lic.serviceName,
                        style: AppTypography.headlineSm),
                  ),
                  StatusChip(
                    label: lic.statusEnum.label,
                    tone: _licenseTone(lic.statusEnum),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '좌석 ${lic.seatCount?.toString() ?? '-'} · '
                '만료 ${lic.expiresAt == null ? '-' : DateFormatter.date(lic.expiresAt!)}',
                style: AppTypography.bodySm
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.md),
              _RevealKeyButton(license: lic),
            ],
          ),
        );
      },
    );
  }
}

class _LicenseTable extends StatelessWidget {
  const _LicenseTable({required this.items});

  final List<SoftwareLicense> items;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: AppDataTable(
        columnFlex: const [3, 2, 2, 2, 3],
        columns: const ['서비스', '좌석', '만료일', '상태', '키'],
        rows: [
          for (final lic in items)
            AppTableRow(
              highlight: lic.statusEnum == LicenseStatus.expired ||
                  lic.statusEnum == LicenseStatus.revoked,
              cells: [
                Text(lic.serviceName,
                    style: AppTypography.bodySm
                        .copyWith(fontWeight: FontWeight.w600)),
                Text(lic.seatCount?.toString() ?? '-'),
                Text(lic.expiresAt == null
                    ? '-'
                    : DateFormatter.date(lic.expiresAt!)),
                Align(
                  alignment: Alignment.centerLeft,
                  child: StatusChip(
                    label: lic.statusEnum.label,
                    tone: _licenseTone(lic.statusEnum),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _RevealKeyButton(license: lic),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Reveals a license key via the AUDITED key endpoint behind a confirm dialog.
/// Once revealed, the key is shown inline with a copy action.
class _RevealKeyButton extends ConsumerStatefulWidget {
  const _RevealKeyButton({required this.license});

  final SoftwareLicense license;

  @override
  ConsumerState<_RevealKeyButton> createState() => _RevealKeyButtonState();
}

class _RevealKeyButtonState extends ConsumerState<_RevealKeyButton> {
  bool _loading = false;
  String? _revealedKey;

  Future<void> _reveal() async {
    if (_loading) return;
    final ok = await showConfirmDialog(
      context,
      title: '라이선스 키를 확인하시겠습니까?',
      message: '키 열람은 감사 로그에 기록됩니다. (열람자·시각이 저장됩니다)',
      confirmLabel: '키 확인',
    );
    if (!ok) return;

    setState(() => _loading = true);
    try {
      final SoftwareLicense full = await ref
          .read(inquiryRepositoryProvider)
          .revealLicenseKey(widget.license.id);
      if (!mounted) return;
      setState(() => _revealedKey = full.licenseKey);
    } on InquiryException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = _revealedKey;
    if (key != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SelectableText(
              key,
              style: AppTypography.bodySm.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
                color: AppColors.onSurface,
              ),
            ),
          ),
          IconButton(
            tooltip: '복사',
            icon: const Icon(Icons.copy_rounded, size: 18),
            color: AppColors.outline,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: key));
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(content: Text('키가 복사되었습니다.')),
                );
            },
          ),
        ],
      );
    }
    return AppButton(
      label: '키 확인',
      icon: Icons.visibility_outlined,
      variant: AppButtonVariant.secondary,
      loading: _loading,
      onPressed: _reveal,
    );
  }
}

/// Create-license dialog (Operations only). Submits via the list notifier which
/// reloads on success.
class _LicenseCreateDialog extends ConsumerStatefulWidget {
  const _LicenseCreateDialog();

  @override
  ConsumerState<_LicenseCreateDialog> createState() =>
      _LicenseCreateDialogState();
}

class _LicenseCreateDialogState extends ConsumerState<_LicenseCreateDialog> {
  final _serviceCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();
  final _seatCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime? _expiresAt;
  bool _submitting = false;

  @override
  void dispose() {
    _serviceCtrl.dispose();
    _keyCtrl.dispose();
    _seatCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _serviceCtrl.text.trim().isNotEmpty && _keyCtrl.text.trim().isNotEmpty;

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) setState(() => _expiresAt = picked);
  }

  Future<void> _submit() async {
    if (!_isValid || _submitting) return;
    setState(() => _submitting = true);
    try {
      await ref.read(licenseListProvider.notifier).create(
            serviceName: _serviceCtrl.text.trim(),
            licenseKey: _keyCtrl.text.trim(),
            expiresAt: _expiresAt,
            seatCount: int.tryParse(_seatCtrl.text.trim()),
            notes: _notesCtrl.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('라이선스가 등록되었습니다.')));
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('라이선스 등록', style: AppTypography.headlineSm),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _serviceCtrl,
                  decoration: const InputDecoration(labelText: '서비스명'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _keyCtrl,
                  decoration: const InputDecoration(labelText: '라이선스 키'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _seatCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: '좌석 수 (선택)'),
                ),
                const SizedBox(height: AppSpacing.sm),
                InkWell(
                  onTap: _pickExpiry,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: '만료일 (선택)'),
                    child: Text(
                      _expiresAt == null
                          ? '날짜 선택'
                          : DateFormatter.date(_expiresAt!),
                      style: AppTypography.bodyMd.copyWith(
                        color: _expiresAt == null
                            ? AppColors.outline
                            : AppColors.onSurface,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _notesCtrl,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: '메모 (선택)'),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AppButton(
                      label: '취소',
                      variant: AppButtonVariant.tertiary,
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    AppButton(
                      label: '등록',
                      loading: _submitting,
                      onPressed: _isValid ? _submit : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
