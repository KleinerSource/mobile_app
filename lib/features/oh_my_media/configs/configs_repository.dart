import 'package:omm/core/api/envelope.dart';
import 'package:omm/core/api/services/configs_api.dart';
import 'package:omm/core/api/services/configs_extended_api.dart';
import 'package:omm/core/models/avdb_config.dart';
import 'package:omm/core/models/dbo_config.dart';
import 'package:omm/core/models/ffmpeg_config.dart';
import 'package:omm/core/models/preview_config.dart';

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
    // 密钥输入框留空表示沿用服务端配置；不要用空字符串覆盖已有密钥。
    if (keepApiKey || cfg.apiKey.trim().isEmpty) body.remove('api_key');
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

  Future<AvdbConfig> saveAvdb(AvdbConfig cfg, {bool keepApiKey = false}) async {
    final body = cfg.toJson();
    // AVDB 密钥同样由服务端数据源配置保存，留空时只更新其它字段。
    if (keepApiKey || cfg.apiKey.trim().isEmpty) body.remove('api_key');
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

  // ===== 预览视频 / Sprite =====

  Future<PreviewConfig> getPreview() async {
    final raw = await _extendedApi.preview();
    return unwrapStd<PreviewConfig>(raw, (d) {
      if (d is Map) return PreviewConfig.fromJson(Map<String, dynamic>.from(d));
      return const PreviewConfig();
    });
  }

  Future<PreviewConfig> savePreview(PreviewConfig cfg) async {
    final raw = await _extendedApi.savePreview(cfg.toJson());
    return unwrapStd<PreviewConfig>(raw, (d) {
      if (d is Map) return PreviewConfig.fromJson(Map<String, dynamic>.from(d));
      return cfg;
    });
  }

  // ===== 视频扩展名 =====

  Future<List<String>> getVideoExtensions() async {
    final raw = await _api.getVideoExtensions();
    return unwrapStd<List<String>>(raw, (d) {
      if (d is Map && d['extensions'] is List) {
        return (d['extensions'] as List).whereType<String>().toList();
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
