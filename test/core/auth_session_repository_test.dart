import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/auth/auth_session.dart';
import 'package:md_center/core/auth/auth_session_repository.dart';

void main() {
  test('会话只在保存时写入 token，clear 会清理所有字段', () async {
    final store = _MemoryTokenStore();
    final repository = AuthSessionRepository(store: store);
    const session = AuthSession(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresIn: 3600,
    );

    await repository.save(session);
    expect(await repository.accessToken(), 'access-token');
    expect(store.values.values, contains('refresh-token'));

    await repository.clear();
    expect(await repository.current(), isNull);
    expect(store.values, isEmpty);
  });

  test('不保存不完整会话', () async {
    final store = _MemoryTokenStore();
    final repository = AuthSessionRepository(store: store);
    const incomplete = AuthSession(
      accessToken: 'access-token',
      refreshToken: '',
      expiresIn: 3600,
    );

    await repository.save(incomplete);
    expect(await repository.current(), isNull);
    expect(store.values, isEmpty);
  });
}

class _MemoryTokenStore implements AuthTokenStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}
