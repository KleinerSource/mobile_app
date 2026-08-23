import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/system.dart';

/// 持久化服务器公开资料，避免启动时先显示本地默认名称。
class ServerProfileCacheRepository {
  ServerProfileCacheRepository(this._prefs);

  static const _key = 'server.profile_cache.v1';

  final SharedPreferences _prefs;
  Future<void> _writeQueue = Future<void>.value();

  ServerProfileData? load(String serverId) {
    final id = serverId.trim();
    if (id.isEmpty) return null;
    final cached = _readAll()[id];
    if (cached is! Map) return null;
    try {
      return ServerProfileData.fromJson(Map<String, dynamic>.from(cached));
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String serverId, ServerProfileData profile) async {
    final id = serverId.trim();
    if (id.isEmpty) return;
    await _enqueueWrite(() async {
      final values = _readAll();
      values[id] = profile.toJson();
      await _prefs.setString(_key, jsonEncode(values));
    });
  }

  Future<void> remove(String serverId) async {
    final id = serverId.trim();
    if (id.isEmpty) return;
    await _enqueueWrite(() async {
      final values = _readAll();
      if (values.remove(id) != null) {
        await _prefs.setString(_key, jsonEncode(values));
      }
    });
  }

  Future<void> clear() => _enqueueWrite(() async {
    await _prefs.remove(_key);
  });

  Future<void> _enqueueWrite(Future<void> Function() operation) {
    final result = _writeQueue.then((_) => operation());
    _writeQueue = result.then<void>((_) {}, onError: (_, __) {});
    return result;
  }

  Map<String, dynamic> _readAll() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, dynamic>{};
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return <String, dynamic>{};
    }
  }
}
