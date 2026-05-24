import '../../core/api/api_exception.dart';
import '../../core/api/envelope.dart';
import '../../core/api/services/mappings_api.dart';
import '../../core/models/mapping_rule.dart';

/// 外部接口预览结果
class ActorAssocPreview {
  const ActorAssocPreview({
    required this.found,
    required this.mappedValue,
    required this.actorName,
    required this.allAliases,
    required this.existingAliases,
    required this.newAliases,
    this.externalId,
  });

  final bool found;
  final String mappedValue;
  final String actorName;
  final List<String> allAliases;
  final List<String> existingAliases;
  final List<String> newAliases;
  final String? externalId;

  factory ActorAssocPreview.fromJson(Map<String, dynamic> j) {
    List<String> arr(dynamic v) =>
        (v is List ? v.whereType<String>().toList() : const <String>[]);
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
    );
  }
}

class ActorAssociationsRepository {
  ActorAssociationsRepository(this._api);
  final MappingsApi _api;

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
          (raw is Map ? raw['message'] as String? : null) ?? '加载失败');
    }
    final data = raw['data'];
    final list = data is List
        ? data
        : (data is Map && data['items'] is List ? data['items'] as List : const []);
    final items = list
        .whereType<Map>()
        .map((e) => MappingRule.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final total = data is Map ? (data['total_count'] as num?)?.toInt() ?? items.length : items.length;
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

  // ===== 外部同步 =====

  Future<ActorAssocPreview> previewExternal(String actorName) async {
    final raw =
        await _api.actorExternalSyncPreview({'actor_name': actorName});
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

  /// 应用外部同步结果 (mapped_value + 合并后的所有别名)
  Future<MappingRule> applyExternal({
    required String mappedValue,
    required List<String> originalValues,
  }) async {
    final raw = await _api.actorExternalSyncApply({
      'mapped_value': mappedValue,
      'original_values': originalValues,
    });
    return unwrapStd<MappingRule>(
      raw,
      (d) => MappingRule.fromJson(Map<String, dynamic>.from(d as Map)),
    );
  }
}
