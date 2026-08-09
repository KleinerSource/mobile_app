import 'package:dio/dio.dart';

import '../../auth/auth_session.dart';
import '../envelope.dart';

class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  Future<AuthConfig> config() async {
    final response = await _dio.get<dynamic>('/auth/config');
    return unwrapStd<AuthConfig>(
      response.data,
      (data) => AuthConfig.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }

  Future<AuthConfig> updateConfig({
    required bool enabled,
    String? password,
    required int refreshTokenExpireDays,
    required int maxFailedAttempts,
    required int lockMinutes,
  }) async {
    final body = <String, dynamic>{
      'enabled': enabled,
      'refresh_token_expire_days': refreshTokenExpireDays,
      'max_failed_attempts': maxFailedAttempts,
      'lock_minutes': lockMinutes,
    };
    final normalizedPassword = password?.trim() ?? '';
    if (normalizedPassword.isNotEmpty) body['password'] = normalizedPassword;

    final response = await _dio.patch<dynamic>('/auth/config', data: body);
    return unwrapStd<AuthConfig>(
      response.data,
      (data) => AuthConfig.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }

  Future<TotpSetup> beginTotp() async {
    final response = await _dio.post<dynamic>('/auth/totp/begin');
    return unwrapStd<TotpSetup>(
      response.data,
      (data) => TotpSetup.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }

  Future<void> finishTotp({
    required String sessionId,
    required String code,
  }) async {
    final response = await _dio.post<dynamic>(
      '/auth/totp/finish',
      data: {'session_id': sessionId, 'code': code.trim()},
    );
    unwrapStd<void>(response.data, (_) {});
  }

  Future<void> deleteTotp() async {
    final response = await _dio.delete<dynamic>('/auth/totp');
    unwrapStd<void>(response.data, (_) {});
  }

  Future<AuthStatus> status() async {
    final response = await _dio.get<dynamic>('/auth/status');
    return unwrapStd<AuthStatus>(
      response.data,
      (data) => AuthStatus.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }

  Future<AuthSession> login({
    required String password,
    String? totpCode,
  }) async {
    final body = <String, dynamic>{'password': password};
    if (totpCode != null && totpCode.trim().isNotEmpty) {
      body['totp_code'] = totpCode.trim();
    }
    final response = await _dio.post<dynamic>('/auth/login', data: body);
    return unwrapStd<AuthSession>(
      response.data,
      (data) => AuthSession.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }

  Future<AuthSession> refresh(String refreshToken) async {
    final response = await _dio.post<dynamic>(
      '/auth/refresh',
      options: Options(
        extra: const {'skipAuth': true, 'skipRefresh': true},
        headers: {'Authorization': 'Bearer $refreshToken'},
      ),
    );
    return unwrapStd<AuthSession>(
      response.data,
      (data) => AuthSession.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }

  Future<bool> verify() async {
    final response = await _dio.get<dynamic>('/auth/verify');
    return unwrapStd<bool>(response.data, (data) {
      return data is Map && data['valid'] == true;
    });
  }

  Future<void> logout() async {
    final response = await _dio.post<dynamic>('/auth/logout');
    unwrapStd<void>(response.data, (_) {});
  }
}
