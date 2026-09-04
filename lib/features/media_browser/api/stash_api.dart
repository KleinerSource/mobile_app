import 'dart:async';

import 'package:dio/dio.dart';

import 'package:omm/core/api/api_exception.dart';
import 'package:omm/core/config/server_config.dart';
import 'package:omm/core/auth/server_credentials_repository.dart';

import 'stash_models.dart';

const _sceneFields = r'''
  id
  title
  code
  details
  date
  rating100
  resume_time
  play_duration
  play_count
  last_played_at
  files {
    id path basename size duration format width height video_codec audio_codec frame_rate bit_rate
  }
  paths { screenshot preview stream webp }
  performers { id name }
  studio { id name }
  tags { id name }
''';

class StashApi {
  StashApi(
    this._dio, {
    this.serverId,
    StashApiKeyRepository? apiKeyRepository,
    this.apiKey,
    this.onApiKeyInvalid,
  }) : _apiKeyRepository = apiKeyRepository;

  factory StashApi.forEndpoint(String endpoint, {String? apiKey}) {
    return StashApi(
      Dio(BaseOptions(baseUrl: ServerConfig.normalize(endpoint))),
      apiKey: apiKey,
    );
  }

  final Dio _dio;
  final String? serverId;
  final StashApiKeyRepository? _apiKeyRepository;
  final String? apiKey;
  final FutureOr<void> Function()? onApiKeyInvalid;

  Future<void> validateApiKey([String? override]) async {
    await findScenes(page: 1, perPage: 1, apiKeyOverride: override);
  }

  /// 供播放器和图片 URL 层读取同一份安全凭据；不会暴露到配置模型。
  Future<String?> readApiKey() => _readApiKey(null);

  Future<StashScenePage> findScenes({
    int page = 1,
    int perPage = 24,
    String? searchText,
    String? apiKeyOverride,
  }) async {
    final normalizedPage = page < 1 ? 1 : page;
    final normalizedPerPage = perPage.clamp(1, 100);
    final sceneFilter = searchText?.trim() ?? '';
    final data = await _graphql(
      r'''
query FindScenes($filter: FindFilterType, $scene_filter: SceneFilterType) {
  findScenes(filter: $filter, scene_filter: $scene_filter) {
    count
    scenes { 
''' +
          _sceneFields +
          r'''
    }
  }
}
''',
      variables: {
        'filter': {
          'page': normalizedPage,
          'per_page': normalizedPerPage,
          'sort': 'created_at',
          'direction': 'DESC',
        },
        if (sceneFilter.isNotEmpty)
          'scene_filter': {
            'title': {'value': sceneFilter, 'modifier': 'INCLUDES'},
            'OR': {
              'details': {'value': sceneFilter, 'modifier': 'INCLUDES'},
            },
          },
      },
      apiKeyOverride: apiKeyOverride,
    );
    final result = data['findScenes'];
    if (result is! Map) throw ApiException('Stash Scene 列表响应格式异常');
    final rawScenes = result['scenes'];
    return StashScenePage(
      scenes: rawScenes is List
          ? rawScenes
                .map(StashScene.fromJson)
                .where((scene) => scene.id.isNotEmpty)
                .toList(growable: false)
          : const <StashScene>[],
      total: _intValue(result['count']),
    );
  }

  Future<StashScene> findScene(String id, {String? apiKeyOverride}) async {
    final normalized = id.trim();
    if (normalized.isEmpty) throw ApiException('Stash Scene ID 不能为空');
    final data = await _graphql(
      'query FindScene(\$id: ID!) { findScene(id: \$id) { $_sceneFields } }',
      variables: {'id': normalized},
      apiKeyOverride: apiKeyOverride,
    );
    final scene = StashScene.fromJson(data['findScene']);
    if (scene.id.isEmpty) throw ApiException('Stash Scene 不存在');
    return scene;
  }

  Future<List<StashSceneStream>> sceneStreams(
    String id, {
    String? apiKeyOverride,
  }) async {
    final normalized = id.trim();
    if (normalized.isEmpty) throw ApiException('Stash Scene ID 不能为空');
    final data = await _graphql(
      r'''query SceneStreams($id: ID!) {
  sceneStreams(id: $id) { url mime_type label }
}''',
      variables: {'id': normalized},
      apiKeyOverride: apiKeyOverride,
    );
    final raw = data['sceneStreams'];
    return raw is List
        ? raw
              .map(StashSceneStream.fromJson)
              .where((stream) => stream.url.isNotEmpty)
              .toList(growable: false)
        : const <StashSceneStream>[];
  }

  Future<void> saveActivity(
    String id, {
    required double resumeTime,
    required double playDuration,
    String? apiKeyOverride,
  }) async {
    await _graphql(
      r'''mutation SaveSceneActivity(
  $id: ID!, $resume_time: Float, $playDuration: Float
) {
  sceneSaveActivity(
    id: $id, resume_time: $resume_time, playDuration: $playDuration
  )
}''',
      variables: {
        'id': id,
        'resume_time': resumeTime,
        'playDuration': playDuration,
      },
      apiKeyOverride: apiKeyOverride,
    );
  }

  Future<void> addPlay(String id, {String? apiKeyOverride}) async {
    await _graphql(
      r'''mutation AddScenePlay($id: ID!, $times: [Timestamp!]) {
  sceneAddPlay(id: $id, times: $times) { count }
}''',
      variables: {
        'id': id,
        'times': [DateTime.now().toUtc().toIso8601String()],
      },
      apiKeyOverride: apiKeyOverride,
    );
  }

  Future<Map<String, dynamic>> _graphql(
    String query, {
    Map<String, Object?> variables = const <String, Object?>{},
    String? apiKeyOverride,
  }) async {
    final key = await _readApiKey(apiKeyOverride);
    final headers = <String, String>{};
    if (key != null) headers['ApiKey'] = key;
    final Response<dynamic> response;
    try {
      response = await _dio.post<dynamic>(
        '/graphql',
        data: {'query': query, 'variables': variables},
        options: Options(
          headers: headers,
          extra: const {
            'skipAuth': true,
            'skipRefresh': true,
            'skipRetry': true,
          },
        ),
      );
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 401 || status == 403) await _invalidateApiKey();
      throw ApiException(
        status == 401 || status == 403
            ? 'Stash API Key 无效或已失效'
            : 'Stash 网络请求失败',
        status: status,
        data: error.response?.data,
      );
    }
    final body = response.data;
    if (body is! Map) throw ApiException('Stash GraphQL 响应格式异常');
    final errors = body['errors'];
    if (errors is List && errors.isNotEmpty) {
      final messages = errors
          .whereType<Map>()
          .map((error) => error['message']?.toString().trim() ?? '')
          .where((message) => message.isNotEmpty)
          .join('\n');
      final exception = ApiException(
        messages.isEmpty ? 'Stash GraphQL 请求失败' : messages,
        status: response.statusCode,
        data: errors,
      );
      if (response.statusCode == 401 || response.statusCode == 403) {
        await _invalidateApiKey();
      }
      throw exception;
    }
    final data = body['data'];
    if (data is! Map) throw ApiException('Stash GraphQL 数据为空');
    return Map<String, dynamic>.from(data);
  }

  Future<void> _invalidateApiKey() async {
    final id = serverId?.trim() ?? '';
    if (id.isNotEmpty) await _apiKeyRepository?.delete(id);
    await onApiKeyInvalid?.call();
  }

  Future<String?> _readApiKey(String? override) async {
    final normalizedOverride = override?.trim() ?? '';
    if (normalizedOverride.isNotEmpty) return normalizedOverride;
    final configured = apiKey?.trim() ?? '';
    if (configured.isNotEmpty) return configured;
    final id = serverId?.trim() ?? '';
    if (id.isEmpty || _apiKeyRepository == null) return null;
    return _apiKeyRepository.read(id);
  }
}

int _intValue(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
