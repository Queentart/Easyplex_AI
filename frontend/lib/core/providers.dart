import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/data/auth_repository.dart';
import '../shared/models/user.dart';
import 'api/api_client.dart';
import 'api/auth_interceptor.dart';
import 'auth/auth_storage.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Infrastructure providers
/// ─────────────────────────────────────────────────────────────────────────

/// Secure storage wrapper for tokens + cached user.
final authStorageProvider = Provider<AuthStorage>((ref) => AuthStorage());

/// Configured Dio with the [AuthInterceptor] attached.
///
/// On unrecoverable auth failure (refresh failed / no refresh token) the
/// interceptor flips [authStateProvider] to logged-out, which makes the router
/// redirect to /login.
final dioProvider = Provider<Dio>((ref) {
  final dio = ApiClient.createDio();
  final storage = ref.watch(authStorageProvider);

  dio.interceptors.add(
    AuthInterceptor(
      storage: storage,
      onAuthFailure: () {
        ref.read(authStateProvider.notifier).onSessionExpired();
      },
    ),
  );
  return dio;
});

/// ─────────────────────────────────────────────────────────────────────────
/// Auth state
/// ─────────────────────────────────────────────────────────────────────────

/// Snapshot of authentication state consumed by the router and UI.
class AuthState {
  const AuthState({this.user, this.isInitializing = false});

  /// The current user, or null when logged out.
  final AppUser? user;

  /// True during the initial token/session restore (router holds redirects).
  final bool isInitializing;

  bool get isAuthenticated => user != null;
  String? get role => user?.role;

  AuthState copyWith({AppUser? user, bool clearUser = false, bool? isInitializing}) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      isInitializing: isInitializing ?? this.isInitializing,
    );
  }

  static const initial = AuthState(isInitializing: true);
}

/// Holds auth state and exposes `{isAuthenticated, role, user}`.
///
/// Implemented in the F1 auth phase: [login] hits `POST /auth/login` and
/// persists the token pair + user; [_restore] validates a cached access token
/// against `GET /auth/me`; [logout] revokes the refresh token server-side
/// before clearing local state.
class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Kick off session restore from any persisted token/user.
    _restore();
    return AuthState.initial;
  }

  /// Restores the session on app start.
  ///
  /// If an access token is persisted, validate it via `GET /auth/me` and
  /// refresh the cached user from the server response (don't trust the cached
  /// JSON blindly). On any failure, clear storage and stay logged out. The
  /// AuthInterceptor transparently refreshes an expired access token during the
  /// `/auth/me` call, so a valid refresh token keeps the session alive.
  Future<void> _restore() async {
    final storage = ref.read(authStorageProvider);
    final token = await storage.readAccessToken();

    if (token == null || token.isEmpty) {
      state = const AuthState(isInitializing: false);
      return;
    }

    try {
      final user = await ref.read(authRepositoryProvider).me();
      await storage.saveUser(user.toJson());
      state = AuthState(user: user, isInitializing: false);
    } catch (_) {
      // Token invalid / refresh failed / offline → drop to logged-out.
      await storage.clear();
      state = const AuthState(isInitializing: false);
    }
  }

  /// Logs in against `POST /auth/login`.
  ///   1. POST /auth/login {email, password}
  ///   2. persist access_token / refresh_token / user via AuthStorage
  ///   3. setAuthenticated(user) → router redirects to the role home
  ///
  /// Throws [AuthException] (clean Korean message) on failure so the caller can
  /// surface it via SnackBar.
  Future<AppUser> login(String email, String password) async {
    final tokens = await ref.read(authRepositoryProvider).login(email, password);

    final storage = ref.read(authStorageProvider);
    await storage.saveTokens(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );
    await storage.saveUser(tokens.user.toJson());

    setAuthenticated(tokens.user);
    return tokens.user;
  }

  /// Sets the authenticated user (called by the login flow after tokens are
  /// persisted). Flipping state here makes the router redirect fire.
  void setAuthenticated(AppUser user) {
    state = AuthState(user: user, isInitializing: false);
  }

  /// Logs out: best-effort `POST /auth/logout` (revokes the refresh token),
  /// then clear local state regardless of the network result.
  Future<void> logout() async {
    final storage = ref.read(authStorageProvider);
    final refreshToken = await storage.readRefreshToken();
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await ref.read(authRepositoryProvider).logout(refreshToken);
    }
    await storage.clear();
    state = const AuthState(isInitializing: false);
  }

  /// Invoked by [AuthInterceptor] when refresh fails — storage is already
  /// cleared, so just drop the in-memory user to trigger the /login redirect.
  void onSessionExpired() {
    state = const AuthState(isInitializing: false);
  }
}

final authStateProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

/// Convenience: the current user (null when logged out).
final currentUserProvider = Provider<AppUser?>(
  (ref) => ref.watch(authStateProvider).user,
);
