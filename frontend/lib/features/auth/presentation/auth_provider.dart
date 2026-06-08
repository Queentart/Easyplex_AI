import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../shared/models/user.dart';
import '../data/auth_repository.dart';

/// Transient state of the login form.
///
/// [isSubmitting] disables the submit button + shows a spinner. [errorMessage]
/// is surfaced via SnackBar by the screen and cleared on the next attempt.
class LoginFormState {
  const LoginFormState({
    this.isSubmitting = false,
    this.errorMessage,
    this.loggedInUser,
  });

  final bool isSubmitting;
  final String? errorMessage;

  /// Set on a successful login (the screen can react / log; navigation is
  /// driven by the router redirect, not by this field).
  final AppUser? loggedInUser;

  LoginFormState copyWith({
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
    AppUser? loggedInUser,
  }) {
    return LoginFormState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      loggedInUser: loggedInUser ?? this.loggedInUser,
    );
  }

  static const initial = LoginFormState();
}

/// Drives the login submission: prevents duplicate submits, calls the auth
/// flow, and exposes a clean error message for the UI.
class LoginFormNotifier extends Notifier<LoginFormState> {
  @override
  LoginFormState build() => LoginFormState.initial;

  /// Attempts a login. Returns true on success (auth state flipped → router
  /// redirects). On failure, stores the error message for the SnackBar and
  /// returns false.
  Future<bool> submit(String email, String password) async {
    if (state.isSubmitting) return false; // guard against duplicate submits
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final user = await ref.read(authStateProvider.notifier).login(
            email.trim(),
            password,
          );
      // Auth state has flipped; the router redirect tears this page down.
      // Reset isSubmitting so that if the user later logs out and returns to
      // /login, this (global) form state isn't stuck showing a spinner.
      state = state.copyWith(isSubmitting: false, loggedInUser: user);
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: '로그인 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.',
      );
      return false;
    }
  }

  /// Clears a surfaced error (e.g. after the SnackBar is shown or on edit).
  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(clearError: true);
    }
  }
}

final loginFormProvider =
    NotifierProvider<LoginFormNotifier, LoginFormState>(LoginFormNotifier.new);
