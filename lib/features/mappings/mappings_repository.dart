import '../../core/api/envelope.dart';
import '../../core/api/services/mappings_api.dart';
import '../../core/models/mapping_rule.dart';

/// 普通映射规则类型 · 与后端路径 /mappings/type/{type} 一致
enum MappingType {
  tag(value: 'tags', label: '标签'),
  genre(value: 'genres', label: '分类'),
  series(value: 'series', label: '系列');

  const MappingType({required this.value, required this.label});
  final String value;
  final String label;
}

class MappingsRepository {
  MappingsRepository(this._api);
  final MappingsApi _api;

  Future<List<MappingRule>> list(
    MappingType type, {
    String? search,
    /// 'all' / 'convert' / 'delete'
    String status = 'all',
  }) async {
    final q = <String, dynamic>{};
    if (search != null && search.trim().isNotEmpty) q['search'] = search.trim();
    if (status != 'all') q['status'] = status;
    final raw = await _api.list(type.value, q);
    if (raw is! Map || raw['success'] != true) return const [];
    final data = raw['data'];
    final list = data is List
        ? data
        : (data is Map && data['items'] is List ? data['items'] as List : const []);
    return list
        .whereType<Map>()
        .map((e) => MappingRule.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<MappingRule> create(
    MappingType type, {
    required List<String> originalValues,
    String? mappedValue,
  }) async {
    final body = {
      'original_values': originalValues,
      if (mappedValue != null) 'mapped_value': mappedValue,
    };
    final raw = await _api.create(type.value, body);
    return unwrapStd<MappingRule>(
      raw,
      (d) => MappingRule.fromJson(Map<String, dynamic>.from(d as Map)),
    );
  }

  Future<MappingRule> update(
    MappingType type,
    int id, {
    List<String>? originalValues,
    String? mappedValue,
  }) async {
    final body = <String, dynamic>{};
    if (originalValues != null) body['original_values'] = originalValues;
    body['mapped_value'] = mappedValue; // 显式 null 表示删除规则
    final raw = await _api.update(type.value, id, body);
    return unwrapStd<MappingRule>(
      raw,
      (d) => MappingRule.fromJson(Map<String, dynamic>.from(d as Map)),
    );
  }

  Future<void> delete(MappingType type, List<int> ids) async {
    final raw = await _api.delete(type.value, {'mappings_ids': ids});
    unwrapStd<void>(raw, (_) {});
  }

}
