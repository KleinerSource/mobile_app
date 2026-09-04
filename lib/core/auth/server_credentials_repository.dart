import 'dart:convert';

import 'auth_session_repository.dart';

/// Stash 的 API Key 与普通服务器配置分离保存，并按服务器 ID 隔离。
class StashApiKeyRepository {
  StashApiKeyRepository({AuthTokenStore? store})
    : _store = store ?? SecureAuthTokenStore();

  final AuthTokenStore _store;

  Future<String?> read(String serverId) async {
    final value = await _store.read(_key(serverId));
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  Future<void> save(String serverId, String apiKey) async {
    final normalizedServerId = serverId.trim();
    final normalizedKey = apiKey.trim();
    if (normalizedServerId.isEmpty) {
      throw ArgumentError.value(serverId, 'serverId', '服务器 ID 不能为空');
    }
    if (normalizedKey.isEmpty) {
      throw ArgumentError.value(apiKey, 'apiKey', 'Stash API Key 不能为空');
    }
    await _store.write(_key(normalizedServerId), normalizedKey);
  }

  Future<void> delete(String serverId) => _store.delete(_key(serverId));

  String _key(String serverId) {
    final normalized = serverId.trim();
    final encoded = base64Url
        .encode(utf8.encode(normalized))
        .replaceAll('=', '');
    return 'omm.stash.server.$encoded.api_key';
  }
}
