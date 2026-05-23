import '../../core/api/envelope.dart';
import '../../core/api/services/configs_api.dart';
import '../../core/models/dbo_config.dart';

class ConfigsRepository {
  ConfigsRepository(this._api);
  final ConfigsApi _api;

  // ===== DBOnline =====

  Future<DboConfig> getDbo() async {
    final raw = await _api.getDbo();
    return unwrapStd<DboConfig>(raw, (d) {
      if (d is Map) return DboConfig.fromJson(Map<String, dynamic>.from(d));
      return const DboConfig();
    });
  }

  Future<DboConfig> saveDbo(DboConfig cfg, {bool keepApiKey = false}) async {
    final body = cfg.toJson();
    if (keepApiKey) body.remove('api_key');
    final raw = await _api.saveDbo(body);
    return unwrapStd<DboConfig>(raw, (d) {
      if (d is Map) return DboConfig.fromJson(Map<String, dynamic>.from(d));
      return cfg;
    });
  }

  // ===== 视频扩展名 =====

  Future<List<String>> getVideoExtensions() async {
    final raw = await _api.getVideoExtensions();
    return unwrapStd<List<String>>(raw, (d) {
      if (d is Map && d['extensions'] is List) {
        return (d['extensions'] as List)
            .whereType<String>()
            .toList();
      }
      if (d is List) return d.whereType<String>().toList();
      return const [];
    });
  }

  Future<List<String>> updateVideoExtensions(List<String> extensions) async {
    final raw = await _api.updateVideoExtensions({'extensions': extensions});
    return unwrapStd<List<String>>(raw, (d) {
      if (d is Map && d['extensions'] is List) {
        return (d['extensions'] as List).whereType<String>().toList();
      }
      return extensions;
    });
  }
}
