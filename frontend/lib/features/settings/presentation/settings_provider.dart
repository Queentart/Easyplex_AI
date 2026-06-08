import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/settings_repository.dart';

/// Immutable view-state for the password-change form.
///
/// The screen owns the [TextEditingController]s; this state only mirrors the
/// values it needs for validation plus the submission lifecycle
/// (loading / error / success).
class PasswordChangeState {
  const PasswordChangeState({
    this.current = '',
    this.next = '',
    this.confirm = '',
    this.isSubmitting = false,
    this.error,
    this.isSuccess = false,
  });

  final String current;
  final String next;
  final String confirm;

  /// True while the change request is in flight (disables submit).
  final bool isSubmitting;

  /// Last error message (cleared on the next edit / submit).
  final String? error;

  /// True once a change has succeeded (the screen reacts by showing a SnackBar
  /// and clearing the fields).
  final bool isSuccess;

  static const int minLength = 8;

  /// Field-level validation messages (null when the field is acceptable).
  /// These mirror [Validators.password] but are inlined so the notifier has no
  /// UI-layer dependency.
  String? get currentError =>
      current.isEmpty ? '현재 비밀번호를 입력해주세요.' : null;

  String? get nextError {
    if (next.isEmpty) return '새 비밀번호를 입력해주세요.';
    if (next.length < minLength) return '새 비밀번호는 최소 $minLength자 이상이어야 합니다.';
    if (next == current) return '새 비밀번호가 현재 비밀번호와 동일합니다.';
    return null;
  }

  String? get confirmError {
    if (confirm.isEmpty) return '새 비밀번호를 한 번 더 입력해주세요.';
    if (confirm != next) return '새 비밀번호가 일치하지 않습니다.';
    return null;
  }

  /// Ready to submit: every field valid and nothing currently in flight.
  bool get isValid =>
      currentError == null &&
      nextError == null &&
      confirmError == null &&
      !isSubmitting;

  PasswordChangeState copyWith({
    String? current,
    String? next,
    String? confirm,
    bool? isSubmitting,
    String? error,
    bool clearError = false,
    bool? isSuccess,
  }) {
    return PasswordChangeState(
      current: current ?? this.current,
      next: next ?? this.next,
      confirm: confirm ?? this.confirm,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

/// Drives the password-change form view-state and submission.
///
/// Riverpod 3.x [Notifier] pattern: the screen reads the notifier to push field
/// edits and calls [submit]; [build] always returns a clean initial state so
/// re-entering the screen (after `ref.invalidate`) starts fresh.
class PasswordChangeNotifier extends Notifier<PasswordChangeState> {
  @override
  PasswordChangeState build() => const PasswordChangeState();

  void setCurrent(String value) =>
      state = state.copyWith(current: value, clearError: true, isSuccess: false);

  void setNext(String value) =>
      state = state.copyWith(next: value, clearError: true, isSuccess: false);

  void setConfirm(String value) =>
      state = state.copyWith(confirm: value, clearError: true, isSuccess: false);

  /// Submits the change request. Returns true on success, false on failure
  /// (the error is exposed via [PasswordChangeState.error]).
  ///
  /// Guards against duplicate submission via [PasswordChangeState.isSubmitting].
  Future<bool> submit() async {
    if (!state.isValid) return false;
    state = state.copyWith(isSubmitting: true, clearError: true, isSuccess: false);
    try {
      await ref.read(settingsRepositoryProvider).changePassword(
            currentPassword: state.current,
            newPassword: state.next,
          );
      // Reset the form on success so the cleared fields aren't left populated.
      state = const PasswordChangeState(isSuccess: true);
      return true;
    } on SettingsException catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        error: '비밀번호를 변경하지 못했습니다. 잠시 후 다시 시도해주세요.',
      );
      return false;
    }
  }
}

final passwordChangeProvider =
    NotifierProvider<PasswordChangeNotifier, PasswordChangeState>(
  PasswordChangeNotifier.new,
);
