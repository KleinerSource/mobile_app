import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/api/api_client.dart';
import 'package:omm/core/api/envelope.dart';
import 'package:omm/core/api/providers.dart';
import 'package:omm/core/models/system.dart';

final ommAdminRepositoryProvider = Provider<OmmAdminRepository>((ref) {
  final repository = OmmAdminRepository(ref.watch(requiredApiClientProvider));
  ref.onDispose(repository.close);
  return repository;
});

/// 管理操作固定在创建时的连接上；每个异步边界后检查连接有效性。
class OmmAdminRepository {
  OmmAdminRepository(this._client);
  final ApiClient _client;
  bool _closed = false;
  bool get isActive => !_closed && _client.isActive;
  void close() => _closed = true;

  Future<T> _call<T>(Future<T> Function() action) async {
    _client.ensureActive();
    if (_closed) throw StateError('Connection closed');
    final value = await action();
    _client.ensureActive();
    if (_closed) throw StateError('Connection closed');
    return value;
  }

  Future<Map<String, dynamic>> _map(Future<Object?> Function() action) => _call(
    () async => unwrapStd<Map<String, dynamic>>(
      await action(),
      (data) => data == null ? {} : Map<String, dynamic>.from(data as Map),
    ),
  );

  Future<ScheduleStatus> schedule() => _call(_client.systemExtended.schedule);
  Future<ScheduleStatus> saveSchedule(bool enabled, List<String> times) =>
      _call(
        () => _client.systemExtended.updateSchedule(
          enabled: enabled,
          times: times,
        ),
      );
  Future<Map<String, dynamic>> cacheInfo() =>
      _map(_client.mappingsExtended.cacheInfo);
  Future<Map<String, dynamic>> refreshCache() =>
      _map(_client.mappingsExtended.refreshCache);
  Future<void> invalidateCache() async {
    await _map(_client.mappingsExtended.invalidateCache);
  }

  Future<Map<String, dynamic>> orphanedCount() =>
      _call(_client.systemExtended.orphanedCount);
  Future<Map<String, dynamic>> cleanupOrphans() =>
      _call(_client.systemExtended.cleanupOrphans);
  Future<Map<String, dynamic>> ffmpegStatus() =>
      _call(_client.systemExtended.ffmpegStatus);
  Future<Map<String, dynamic>> ffmpegGpuDetect() =>
      _call(_client.systemExtended.ffmpegGpuDetect);
  Future<Map<String, dynamic>> ffmpegEnvironment() =>
      _call(_client.systemExtended.ffmpegEnvironment);
  Future<Map<String, dynamic>> installFfmpeg() =>
      _call(_client.systemExtended.installFfmpeg);
  Future<Map<String, dynamic>> ffmpegInstallStatus() =>
      _call(_client.systemExtended.ffmpegInstallStatus);

  Future<List<Map<String, dynamic>>> libraryStats() => _call(
    () async => unwrapStd<List<Map<String, dynamic>>>(
      await _client.librariesExtended.stats(),
      (data) => (data as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList(),
    ),
  );
  Future<Map<String, dynamic>> regenerateCovers([int? id]) => _map(
    () => id == null
        ? _client.librariesExtended.regenerateAllCovers()
        : _client.librariesExtended.regenerateCover(id),
  );
  Future<Map<String, dynamic>> directoryDetail(
    int libraryId,
    int directoryId,
  ) => _map(
    () => _client.librariesExtended.directoryDetail(libraryId, directoryId),
  );

  Future<Map<String, dynamic>> config(String key) =>
      _map(() => _client.configsExtended.getByKey(key));
  Future<Map<String, dynamic>> createConfig(
    String key,
    String value,
    String description,
  ) => _map(
    () => _client.configsExtended.create({
      'config_key': key,
      'config_value': value,
      'description': description,
    }),
  );
  Future<Map<String, dynamic>> updateConfig(
    String key,
    String value,
    String description,
  ) => _map(
    () => _client.configsExtended.updateByKey(key, {
      'config_value': value,
      'description': description,
    }),
  );
  Future<void> deleteConfig(String key) =>
      _call(() => _client.configsExtended.deleteByKey(key));
}
