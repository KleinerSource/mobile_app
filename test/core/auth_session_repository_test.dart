import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/auth/auth_session.dart';
import 'package:omm/core/auth/auth_session_repository.dart';

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

  test('dbonline token-only 会话可以保存', () async {
    final store = _MemoryTokenStore();
    final repository = AuthSessionRepository(store: store);
    const incomplete = AuthSession(
      accessToken: 'access-token',
      refreshToken: '',
      expiresIn: 3600,
    );

    await repository.save(incomplete);
    expect((await repository.current())?.accessToken, 'access-token');
    expect((await repository.current())?.refreshToken, isEmpty);
    expect(store.values.values, contains('access-token'));
  });

  test('不同服务器使用彼此隔离的会话', () async {
    final store = _MemoryTokenStore();
    final repository = AuthSessionRepository(store: store);

    repository.setActiveServerId('server-a');
    await repository.save(
      const AuthSession(
        accessToken: 'access-a',
        refreshToken: 'refresh-a',
        expiresIn: 3600,
      ),
    );

    repository.setActiveServerId('server-b');
    expect(await repository.current(), isNull);
    await repository.save(
      const AuthSession(
        accessToken: 'access-b',
        refreshToken: 'refresh-b',
        expiresIn: 3600,
      ),
    );

    repository.setActiveServerId('server-a');
    expect(await repository.accessToken(), 'access-a');
    repository.setActiveServerId('server-b');
    expect(await repository.accessToken(), 'access-b');
    expect(store.values.keys, everyElement(startsWith('omm.auth.server.')));
  });

  test('首次选择服务器时会迁移旧版全局会话', () async {
    final store = _MemoryTokenStore();
    final repository = AuthSessionRepository(store: store);
    await repository.save(
      const AuthSession(
        accessToken: 'legacy-access',
        refreshToken: 'legacy-refresh',
        expiresIn: 3600,
      ),
    );

    repository.setActiveServerId('server-a');
    expect(await repository.accessToken(), 'legacy-access');
    expect(store.values.keys, everyElement(startsWith('omm.auth.server.')));
  });

  test('固定作用域客户端不会因主仓库切换服务器而串用会话', () async {
    final store = _MemoryTokenStore();
    final repository = AuthSessionRepository(store: store);
    final serverA = repository.forServer('server-a');
    final serverB = repository.forServer('server-b');

    await serverA.save(
      const AuthSession(
        accessToken: 'access-a',
        refreshToken: 'refresh-a',
        expiresIn: 3600,
      ),
    );
    await serverB.save(
      const AuthSession(
        accessToken: 'access-b',
        refreshToken: 'refresh-b',
        expiresIn: 3600,
      ),
    );

    repository.setActiveServerId('server-b');
    expect(await serverA.accessToken(), 'access-a');
    expect(await serverB.accessToken(), 'access-b');
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
