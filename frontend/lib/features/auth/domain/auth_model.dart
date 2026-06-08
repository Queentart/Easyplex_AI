import '../../../shared/models/user.dart';

/// Auth-only DTOs for the F1 login flow.
///
/// The current user is represented by [AppUser] (shared/models/user.dart) —
/// this file intentionally does NOT define another user model. Only the
/// request/response shapes that are specific to authentication live here.

/// Request body for `POST /auth/login`.
class LoginRequest {
  const LoginRequest({required this.email, required this.password});

  final String email;
  final String password;

  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
      };
}

/// The token bundle returned by `POST /auth/login` and `POST /auth/refresh`.
///
/// Backend envelope `data` shape:
/// `{access_token, refresh_token, token_type, expires_in, user:{...}}`.
/// The nested `user` is parsed into [AppUser].
class TokenPair {
  const TokenPair({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresIn,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;
  final AppUser user;

  factory TokenPair.fromJson(Map<String, dynamic> json) {
    int? asInt(Object? v) => v is int ? v : (v is num ? v.toInt() : null);
    final rawUser = json['user'];
    return TokenPair(
      accessToken: (json['access_token'] ?? '').toString(),
      refreshToken: (json['refresh_token'] ?? '').toString(),
      tokenType: (json['token_type'] ?? 'bearer').toString(),
      expiresIn: asInt(json['expires_in']) ?? 0,
      user: rawUser is Map<String, dynamic>
          ? AppUser.fromJson(rawUser)
          : const AppUser(id: 0, email: '', name: '', role: ''),
    );
  }
}
