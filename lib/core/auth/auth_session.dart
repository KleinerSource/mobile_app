import 'package:flutter/foundation.dart';

@immutable
class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    this.issuedAt,
  });

  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final DateTime? issuedAt;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken:
          json['access_token']?.toString() ?? json['token']?.toString() ?? '',
      refreshToken: json['refresh_token']?.toString() ?? '',
      expiresIn: _intValue(json['expires_in']),
      issuedAt: DateTime.now().toUtc(),
    );
  }

  bool get isUsable => accessToken.isNotEmpty && refreshToken.isNotEmpty;

  bool get hasAccessToken => accessToken.isNotEmpty;

  bool get canRefresh => refreshToken.isNotEmpty;
}

int _intValue(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString().trim() ?? '') ?? 0;
}

@immutable
class AuthStatus {
  const AuthStatus({
    required this.enabled,
    required this.configured,
    required this.authenticated,
    required this.passwordLoginDisabled,
    required this.refreshTokenExpireDays,
    required this.maxFailedAttempts,
    required this.lockMinutes,
    required this.totpConfigured,
    required this.webAuthnConfigured,
  });

  final bool enabled;
  final bool configured;
  final bool authenticated;
  final bool passwordLoginDisabled;
  final int refreshTokenExpireDays;
  final int maxFailedAttempts;
  final int lockMinutes;
  final bool totpConfigured;
  final bool webAuthnConfigured;

  factory AuthStatus.fromJson(Map<String, dynamic> json) => AuthStatus(
    enabled: json['enabled'] == true,
    configured: json['configured'] == true,
    authenticated: json['authenticated'] == true,
    passwordLoginDisabled: json['password_login_disabled'] == true,
    refreshTokenExpireDays:
        (json['refresh_token_expire_days'] as num?)?.toInt() ?? 0,
    maxFailedAttempts: (json['max_failed_attempts'] as num?)?.toInt() ?? 0,
    lockMinutes: (json['lock_minutes'] as num?)?.toInt() ?? 0,
    totpConfigured: json['totp_configured'] == true,
    webAuthnConfigured: json['webauthn_configured'] == true,
  );
}

@immutable
class AuthConfig {
  const AuthConfig({
    this.enabled = false,
    this.configured = false,
    this.passwordLoginDisabled = false,
    this.refreshTokenExpireDays = 7,
    this.maxFailedAttempts = 5,
    this.lockMinutes = 30,
    this.totpConfigured = false,
    this.webAuthnConfigured = false,
  });

  final bool enabled;
  final bool configured;
  final bool passwordLoginDisabled;
  final int refreshTokenExpireDays;
  final int maxFailedAttempts;
  final int lockMinutes;
  final bool totpConfigured;
  final bool webAuthnConfigured;

  factory AuthConfig.fromJson(Map<String, dynamic> json) => AuthConfig(
    enabled: json['enabled'] == true,
    configured: json['configured'] == true,
    passwordLoginDisabled: json['password_login_disabled'] == true,
    refreshTokenExpireDays:
        (json['refresh_token_expire_days'] as num?)?.toInt() ?? 7,
    maxFailedAttempts: (json['max_failed_attempts'] as num?)?.toInt() ?? 5,
    lockMinutes: (json['lock_minutes'] as num?)?.toInt() ?? 30,
    totpConfigured: json['totp_configured'] == true,
    webAuthnConfigured: json['webauthn_configured'] == true,
  );
}

@immutable
class TotpSetup {
  const TotpSetup({
    required this.sessionId,
    required this.secret,
    required this.qrDataUrl,
  });

  final String sessionId;
  final String secret;
  final String qrDataUrl;

  factory TotpSetup.fromJson(Map<String, dynamic> json) => TotpSetup(
    sessionId: json['session_id']?.toString() ?? '',
    secret: json['secret']?.toString() ?? '',
    qrDataUrl: json['qr_data_url']?.toString() ?? '',
  );
}

enum AuthPhase {
  unconfigured,
  serverSelection,
  needsLogin,
  totpRequired,
  authenticated,
  incompatible,
  unavailable,
}

@immutable
class AuthState {
  const AuthState({required this.phase, this.status, this.message});

  final AuthPhase phase;
  final AuthStatus? status;
  final String? message;

  bool get isAuthenticated => phase == AuthPhase.authenticated;
}
