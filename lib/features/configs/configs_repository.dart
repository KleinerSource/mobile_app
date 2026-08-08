import '../../core/api/envelope.dart';
import '../../core/api/services/configs_api.dart';
import '../../core/api/services/configs_extended_api.dart';
import '../../core/models/avdb_config.dart';
import '../../core/models/dbo_config.dart';
import '../../core/models/ffmpeg_config.dart';

class ConfigsRepository {
  ConfigsRepository(this._api, this._extendedApi);
  final ConfigsApi _api;
  final ConfigsExtendedApi _extendedApi;

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

  // ===== AVDB 数据源 =====

  Future<AvdbConfig> getAvdb() async {
    final raw = await _extendedApi.avdb();
    return unwrapStd<AvdbConfig>(raw, (d) {
      if (d is Map) return AvdbConfig.fromJson(Map<String, dynamic>.from(d));
      return const AvdbConfig();
    });
  }

  Future<AvdbConfig> saveAvdb(
    AvdbConfig cfg, {
    bool keepApiKey = false,
  }) async {
    final body = cfg.toJson();
    if (keepApiKey) body.remove('api_key');
    final raw = await _extendedApi.saveAvdb(body);
    return unwrapStd<AvdbConfig>(raw, (d) {
      if (d is Map) return AvdbConfig.fromJson(Map<String, dynamic>.from(d));
      return cfg;
    });
  }

  // ===== FFmpeg / 硬解 =====

  Future<FfmpegConfig> getFfmpeg() async {
    final raw = await _extendedApi.ffmpeg();
    return unwrapStd<FfmpegConfig>(raw, (d) {
      if (d is Map) return FfmpegConfig.fromJson(Map<String, dynamic>.from(d));
      return const FfmpegConfig();
    });
  }

  Future<FfmpegConfig> saveFfmpeg(FfmpegConfig cfg) async {
    final raw = await _extendedApi.saveFfmpeg(cfg.toJson());
    return unwrapStd<FfmpegConfig>(raw, (d) {
      if (d is Map) return FfmpegConfig.fromJson(Map<String, dynamic>.from(d));
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
