import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_session_repository.dart';

final authSessionRepositoryProvider = Provider<AuthSessionRepository>((ref) {
  return AuthSessionRepository();
});

/// HTTP 请求发现会话失效时递增，启动状态控制器据此重新检查服务器。
final authExpiryProvider = StateProvider<int>((ref) => 0);
