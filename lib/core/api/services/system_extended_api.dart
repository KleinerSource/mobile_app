import 'package:dio/dio.dart';

import '../../config/server_config.dart';
import '../../models/system.dart';
import '../envelope.dart';
import '../url_resolver.dart';

/// 非 Retrofit 的系统扩展接口，覆盖 FFmpeg、定时任务和下载代理。
class SystemExtendedApi {
  SystemExtendedApi(this._dio, {this.config});

  final Dio _dio;
  final ServerConfig? config;

  Future<ServerProfileData> serverProfile() async {
    final response = await _dio.get<dynamic>('/public/server-profile');
    return unwrapStd<ServerProfileData>(
      response.data,
      (data) {
        final json = Map<String, dynamic>.from(data as Map);
        final avatar = json['avatar_url']?.toString().trim() ?? '';
        return ServerProfileData(
          name: json['name']?.toString().trim() ?? '',
          avatarUrl: config == null || avatar.isEmpty
              ? null
              : resolveServerUrl(config!, avatar),
        );
      },
    );
  }

  Future<ScheduleStatus> schedule() async {
    final response = await _dio.get<dynamic>('/schedule');
    return unwrapStd<ScheduleStatus>(
      response.data,
      (data) => ScheduleStatus.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }

  Future<ScheduleStatus> updateSchedule({
    required bool enabled,
    required List<String> times,
  }) async {
    final response = await _dio.put<dynamic>(
      '/schedule',
      data: {'enabled': enabled, 'times': times},
    );
    return unwrapStd<ScheduleStatus>(
      response.data,
      (data) => ScheduleStatus.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }

  Future<Map<String, dynamic>> ffmpegStatus() => _mapGet('/ffmpeg/status');

  Future<Map<String, dynamic>> ffmpegGpuDetect() =>
      _mapGet('/ffmpeg/gpu-detect');

  Future<Map<String, dynamic>> ffmpegEnvironment() => _mapGet('/ffmpeg/env');

  Future<Map<String, dynamic>> installFfmpeg() =>
      _mapPost('/ffmpeg/install');

  Future<Map<String, dynamic>> ffmpegInstallStatus() =>
      _mapGet('/ffmpeg/install/status');

  Future<Map<String, dynamic>> orphanedCount() =>
      _mapGet('/maintenance/orphaned-count');

  Future<Map<String, dynamic>> cleanupOrphans() =>
      _mapPost('/maintenance/cleanup-orphans');

  Future<List<Downloader>> downloaders() async {
    final response = await _dio.get<dynamic>('/downloaders');
    return unwrapStd<List<Downloader>>(response.data, (data) {
      final raw = data is Map ? data['downloaders'] : data;
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((item) => Downloader.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    });
  }

  Future<Object?> directDownload(Map<String, dynamic> body) async {
    final response = await _dio.post<dynamic>('/download', data: body);
    return unwrapStd<Object?>(response.data, (data) => data);
  }

  Future<Map<String, dynamic>> _mapGet(String path) async {
    final response = await _dio.get<dynamic>(path);
    return _decodeMap(response.data);
  }

  Future<Map<String, dynamic>> _mapPost(String path) async {
    final response = await _dio.post<dynamic>(path);
    return _decodeMap(response.data);
  }

  Map<String, dynamic> _decodeMap(Object? raw) => unwrapStd<Map<String, dynamic>>(
        raw,
        (data) => data is Map ? Map<String, dynamic>.from(data) : const {},
      );
}
