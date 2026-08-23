import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/envelope.dart';
import '../../core/api/services/actors_api.dart';
import '../../core/api/services/mappings_api.dart';
import '../../core/models/avdb_config.dart';
import '../../core/models/dbo_config.dart';
import '../../core/models/mapping_rule.dart';

enum ActorDataSource { dbonline, avdb, mixed }

extension ActorDataSourceX on ActorDataSource {
  String get value => switch (this) {
    ActorDataSource.dbonline => 'dbonline',
    ActorDataSource.avdb => 'avdb',
    ActorDataSource.mixed => 'mixed',
  };

  String get label => switch (this) {
    ActorDataSource.dbonline => 'DB Online',
    ActorDataSource.avdb => 'AVDB',
    ActorDataSource.mixed => '混合渠道',
  };
}

ActorDataSource? actorDataSourceFromValue(String? value) {
  return switch (value?.trim().toLowerCase()) {
    'dbonline' => ActorDataSource.dbonline,
    'avdb' => ActorDataSource.avdb,
    'mixed' => ActorDataSource.mixed,
    _ => null,
  };
}

/// 只有服务端配置中同时存在启用状态、地址和 API Key 的来源才允许同步。
/// API Key 不随演员同步请求下发，实际请求由后端从数据源配置读取。
/// 混合渠道（mixed）并行采集所有已启用渠道并合并资料，需要各渠道同时可用。
List<ActorDataSource> configuredActorDataSources({
  DboConfig? dbonline,
  AvdbConfig? avdb,
}) {
  final result = <ActorDataSource>[];
  final dbonlineReady =
      dbonline?.enabled == true &&
      dbonline!.baseUrl.trim().isNotEmpty &&
      dbonline.hasApiKey;
  final avdbReady =
      avdb?.enabled == true &&
      avdb!.baseUrl.trim().isNotEmpty &&
      avdb.hasApiKey;
  if (dbonlineReady) {
    result.add(ActorDataSource.dbonline);
  }
  if (avdbReady) {
    result.add(ActorDataSource.avdb);
  }
  if (dbonlineReady && avdbReady) {
    result.add(ActorDataSource.mixed);
  }
  return result;
}

/// 数据源预览结果
class ActorAssociationAvatarChoice {
  const ActorAssociationAvatarChoice({
    required this.downloadUrl,
    this.sourceUrl = '',
    this.source = '',
  });

  final String downloadUrl;
  final String sourceUrl;

  /// 候选所属渠道（dbonline/avdb）；混合渠道时代理下载按此选择下载方式
  final String source;

  factory ActorAssociationAvatarChoice.fromJson(Map<String, dynamic> json) {
    return ActorAssociationAvatarChoice(
      downloadUrl: (json['download_url'] ?? '').toString().trim(),
      sourceUrl: (json['source_url'] ?? '').toString().trim(),
      source: (json['source'] ?? '').toString().trim(),
    );
  }
}

class ActorAssocPreview {
  const ActorAssocPreview({
    required this.found,
    required this.mappedValue,
    required this.actorName,
    required this.allAliases,
    required this.existingAliases,
    required this.newAliases,
    this.externalId,
    this.externalIds = const {},
    this.notFoundSources = const [],
    this.biography = '',
    this.biographyChanged,
    this.avatarUrl = '',
    this.avatarExists = false,
    this.avatarChoices = const [],
    this.warnings = const [],
  });

  final bool found;
  final String mappedValue;
  final String actorName;
  final List<String> allAliases;
  final List<String> existingAliases;
  final List<String> newAliases;
  final String? externalId;

  /// 混合渠道：source → external_id，apply 时一次事务保存多来源身份
  final Map<String, String> externalIds;

  /// 混合渠道：请求成功但未命中演员的渠道（在补齐横幅位置展示，不占警告卡片）
  final List<String> notFoundSources;
  final String biography;
  final bool? biographyChanged;
  final String avatarUrl;
  final bool avatarExists;
  final List<ActorAssociationAvatarChoice> avatarChoices;

  /// 混合渠道：渠道请求失败等需卡片提示的警告
  final List<String> warnings;

  factory ActorAssocPreview.fromJson(Map<String, dynamic> j) {
    List<String> arr(dynamic v) =>
        (v is List ? v.whereType<String>().toList() : const <String>[]);
    final avatarChoices = (j['avatar_choices'] is List
        ? (j['avatar_choices'] as List)
              .whereType<Map>()
              .map(
                (item) => ActorAssociationAvatarChoice.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .where((item) => item.downloadUrl.isNotEmpty)
              .toList(growable: false)
        : const <ActorAssociationAvatarChoice>[]);
    final externalIds = j['external_ids'] is Map
        ? (j['external_ids'] as Map).map(
            (k, v) => MapEntry(k.toString(), v.toString()),
          )
        : const <String, String>{};
    return ActorAssocPreview(
      found: j['found'] == true,
      mappedValue: (j['mapped_value'] ?? '').toString(),
      actorName: (j['actor_name'] ?? '').toString(),
      allAliases: arr(j['all_aliases']),
      existingAliases: arr(j['existing_aliases']),
      newAliases: arr(j['new_aliases']),
      externalId: (j['external_id'] as String?)?.trim().isEmpty == true
          ? null
          : j['external_id']?.toString(),
      externalIds: externalIds,
      notFoundSources: arr(j['not_found_sources']),
      biography: (j['biography'] ?? '').toString().trim(),
      biographyChanged: j['biography_changed'] is bool
          ? j['biography_changed'] as bool
          : null,
      avatarUrl: (j['avatar_url'] ?? '').toString().trim(),
      avatarExists: j['avatar_exists'] == true,
      avatarChoices: avatarChoices,
      warnings: arr(j['warnings']),
    );
  }
}

/// 混合渠道渐进预览会话快照：渠道在后台并行采集，每完成一个即增量合并。
/// status=running 时 preview 为当前合并结果（可能只含部分渠道），pending_sources 为仍在采集的渠道。
class MixedActorPreviewSession {
  const MixedActorPreviewSession({
    required this.status,
    required this.pendingSources,
    this.preview,
    this.error = '',
  });

  final String status; // running | complete | failed
  final List<String> pendingSources;
  final ActorAssocPreview? preview;
  final String error;

  bool get running => status == 'running';
  bool get complete => status == 'complete';
  bool get failed => status == 'failed';

  factory MixedActorPreviewSession.fromJson(Map<String, dynamic> j) {
    List<String> arr(dynamic v) =>
        (v is List ? v.whereType<String>().toList() : const <String>[]);
    return MixedActorPreviewSession(
      status: (j['status'] ?? 'running').toString(),
      pendingSources: arr(j['pending_sources']),
      preview: j['preview'] is Map
          ? ActorAssocPreview.fromJson(
              Map<String, dynamic>.from(j['preview'] as Map),
            )
          : null,
      error: (j['error'] ?? '').toString(),
    );
  }
}

class ActorAssociationsRepository {
  ActorAssociationsRepository(this._api, {ActorsApi? actorsApi})
    : _actorsApi = actorsApi;
  final MappingsApi _api;
  final ActorsApi? _actorsApi;

  static const lastSourceKey = 'actor_association_source';

  static ActorDataSource? loadRememberedSource(SharedPreferences prefs) {
    return actorDataSourceFromValue(prefs.getString(lastSourceKey));
  }

  static Future<void> rememberSource(
    SharedPreferences prefs,
    ActorDataSource source,
  ) async {
    await prefs.setString(lastSourceKey, source.value);
  }

  static const _type = 'actors';
  static const _scope = 'association';

  /// 解析用户输入的别名 (支持换行 / 逗号 / 顿号 / 分号 / 中英文符号)
  /// - trim 多空格
  /// - 去重 (保序)
  /// - 剔除等于 mappedValue 的项
  static List<String> parseAliases(String text, String mappedValue) {
    final raw = text.split(RegExp(r'[\n,，、;；]'));
    final norm = mappedValue.trim();
    final seen = <String>{};
    final result = <String>[];
    for (final r in raw) {
      final v = r.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (v.isEmpty) continue;
      if (v == norm) continue;
      if (seen.add(v)) result.add(v);
    }
    return result;
  }

  /// 合并 existing + additions, 同样去重/剔除 mappedValue
  static List<String> mergeAliases(
    List<String> existing,
    List<String> additions,
    String mappedValue,
  ) {
    final norm = mappedValue.trim();
    final seen = <String>{};
    final result = <String>[];
    for (final src in [existing, additions]) {
      for (final r in src) {
        final v = r.trim().replaceAll(RegExp(r'\s+'), ' ');
        if (v.isEmpty) continue;
        if (v == norm) continue;
        if (seen.add(v)) result.add(v);
      }
    }
    return result;
  }

  /// 判断数据源简介是否需要写回本地。
  ///
  /// 数据源可能只是在换行或首尾空白上不同,这类差异不应重复触发同步。
  static bool biographyNeedsSync(String? current, String? incoming) {
    final currentText = _normalizeBiography(current);
    final incomingText = _normalizeBiography(incoming);
    return incomingText.isNotEmpty && incomingText != currentText;
  }

  static String _normalizeBiography(String? value) {
    return (value ?? '').replaceAll('\r\n', '\n').trim();
  }

  // ===== 列表 / CRUD =====

  /// 列表 · 固定 scope=association / status=active
  Future<({List<MappingRule> items, int totalCount})> list({
    int limit = 20,
    int offset = 0,
    String? search,
  }) async {
    final q = <String, dynamic>{
      'limit': limit,
      'offset': offset,
      'status': 'active',
      'scope': _scope,
    };
    final s = search?.trim();
    if (s != null && s.isNotEmpty) q['search'] = s;
    final raw = await _api.list(_type, q);
    if (raw is! Map || raw['success'] != true) {
      throw ApiException(
        (raw is Map ? raw['message'] as String? : null) ?? '加载失败',
      );
    }
    final data = raw['data'];
    final list = data is List
        ? data
        : (data is Map && data['items'] is List
              ? data['items'] as List
              : const []);
    final items = list
        .whereType<Map>()
        .map((e) => MappingRule.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final total = data is Map
        ? (data['total_count'] as num?)?.toInt() ?? items.length
        : items.length;
    return (items: items, totalCount: total);
  }

  Future<MappingRule> create({
    required String mappedValue,
    required List<String> originalValues,
  }) async {
    final raw = await _api.create(_type, {
      'mapped_value': mappedValue,
      'original_values': originalValues,
      'scope': _scope,
    });
    return unwrapStd<MappingRule>(
      raw,
      (d) => MappingRule.fromJson(Map<String, dynamic>.from(d as Map)),
    );
  }

  Future<MappingRule> update({
    required int id,
    required String mappedValue,
    required List<String> originalValues,
  }) async {
    final raw = await _api.update(_type, id, {
      'mapped_value': mappedValue,
      'original_values': originalValues,
      'scope': _scope,
    });
    return unwrapStd<MappingRule>(
      raw,
      (d) => MappingRule.fromJson(Map<String, dynamic>.from(d as Map)),
    );
  }

  Future<void> deleteById(int id) async {
    final raw = await _api.delete(_type, {
      'mappings_ids': [id],
    });
    unwrapStd<void>(raw, (_) {});
  }

  // ===== 同步演员关联 =====

  Future<ActorAssocPreview> previewSource(
    String actorName, {
    ActorDataSource source = ActorDataSource.dbonline,
  }) async {
    final raw = await _api.actorExternalSyncPreview({
      'actor_name': actorName,
      'source': source.value,
    });
    return unwrapStd<ActorAssocPreview>(raw, (d) {
      if (d is Map) {
        return ActorAssocPreview.fromJson(Map<String, dynamic>.from(d));
      }
      return ActorAssocPreview(
        found: false,
        mappedValue: actorName,
        actorName: actorName,
        allAliases: const [],
        existingAliases: const [],
        newAliases: const [],
      );
    });
  }

  // ===== 混合渠道渐进预览 =====

  /// 启动混合渠道渐进预览会话，返回任务 ID；轮询 [getMixedPreviewSession]
  /// 先渲染先到的渠道数据，后到的补齐（不必等待全部渠道完成）。
  Future<String> startMixedPreviewSession(String actorName) async {
    final raw = await _api.mixedExternalSyncPreviewStart({
      'actor_name': actorName.trim(),
    });
    return unwrapStd<String>(raw, (d) {
      if (d is Map) {
        final taskId = d['task_id']?.toString() ?? '';
        if (taskId.isNotEmpty) return taskId;
      }
      throw ApiException('预览任务创建失败');
    });
  }

  /// 轮询混合渠道预览会话进度。
  Future<MixedActorPreviewSession> getMixedPreviewSession(String taskId) async {
    final raw = await _api.mixedExternalSyncPreviewSession(taskId);
    return unwrapStd<MixedActorPreviewSession>(raw, (d) {
      if (d is Map) {
        return MixedActorPreviewSession.fromJson(Map<String, dynamic>.from(d));
      }
      throw ApiException('预览任务状态无效');
    });
  }

  /// 应用同步演员关联结果 (mapped_value + 合并后的所有别名)
  ///
  /// 混合渠道：avatarSource 为所选头像候选的来源（决定下载方式），
  /// externalIds 为预览返回的 source → ID 映射（一次事务保存多来源身份）。
  Future<void> applySource({
    required String mappedValue,
    required List<String> originalValues,
    ActorDataSource source = ActorDataSource.dbonline,
    String? biography,
    String? avatarUrl,
    bool avatarOverwrite = false,
    String? avatarSource,
    Map<String, String>? externalIds,
  }) async {
    final body = <String, dynamic>{
      'mapped_value': mappedValue,
      'original_values': originalValues,
      'source': source.value,
    };
    final trimmedBiography = biography?.trim() ?? '';
    if (trimmedBiography.isNotEmpty) {
      body['biography'] = trimmedBiography;
    }
    final trimmedAvatarUrl = avatarUrl?.trim() ?? '';
    if (trimmedAvatarUrl.isNotEmpty) {
      body['avatar_url'] = trimmedAvatarUrl;
      body['avatar_overwrite'] = avatarOverwrite;
    }
    if (source == ActorDataSource.mixed) {
      final trimmedAvatarSource = avatarSource?.trim() ?? '';
      if (trimmedAvatarSource.isNotEmpty) {
        body['avatar_source'] = trimmedAvatarSource;
      }
      if (externalIds != null && externalIds.isNotEmpty) {
        body['external_ids'] = externalIds;
      }
    }
    final raw = await _api.actorExternalSyncApply(body);
    unwrapStd<void>(raw, (_) {});
  }

  /// 获取外部头像的二进制预览。失败时由调用方决定是否继续同步其他字段。
  Future<List<int>> previewAvatar(
    String avatarUrl, {
    ActorDataSource source = ActorDataSource.dbonline,
  }) async {
    final api = _actorsApi;
    if (api == null) {
      throw ApiException('头像预览接口不可用');
    }
    final url = avatarUrl.trim();
    if (url.isEmpty) {
      throw ApiException('头像地址为空');
    }
    final response = await api.previewAvatar({
      'avatar_url': url,
      'source': source.value,
    });
    if (response.data.isEmpty) {
      throw ApiException('头像内容为空');
    }
    return response.data;
  }
}
