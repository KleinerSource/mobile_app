import 'package:dio/dio.dart';

import '../../auth/auth_session.dart';
import '../envelope.dart';

class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

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
