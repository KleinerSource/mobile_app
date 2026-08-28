import 'package:omm/core/api/envelope.dart';
import 'package:omm/core/models/mapping_rule.dart';
import 'package:omm/core/models/paged_result.dart';
import 'package:omm/core/sources/media/omm_metadata_operations_source.dart';

String normalizeMappingStatus(String status) => switch (status) {
  'convert' => 'active',
  'delete' => 'empty',
  _ => status,
};

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
  MappingsRepository(this._source);
  final OmmMetadataOperationsSource _source;

  Future<List<MappingRule>> list(
    MappingType type, {
    String? search,

    /// UI values are 'all' / 'convert' / 'delete'; the API expects
    /// 'active' / 'empty' for the latter two.
    String status = 'all',
  }) async {
    try {
      return (await listPage(type, search: search, status: status)).items;
    } catch (_) {
      return const [];
    }
  }

  Future<PagedResult<MappingRule>> listPage(
    MappingType type, {
    int limit = 50,
    int offset = 0,
    String? search,

    /// UI values are 'all' / 'convert' / 'delete'; the API expects
    /// 'active' / 'empty' for the latter two.
    String status = 'all',
  }) async {
    final q = <String, dynamic>{};
    q['limit'] = limit;
    q['offset'] = offset;
    if (search != null && search.trim().isNotEmpty) q['search'] = search.trim();
    final apiStatus = normalizeMappingStatus(status);
    if (apiStatus != 'all') q['status'] = apiStatus;
    final raw = await _source.mappingList(type.value, q);
    return unwrapTopLevelList<MappingRule>(raw, MappingRule.fromJson);
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
    final raw = await _source.mappingCreate(type.value, body);
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
    final raw = await _source.mappingUpdate(type.value, id, body);
    return unwrapStd<MappingRule>(
      raw,
      (d) => MappingRule.fromJson(Map<String, dynamic>.from(d as Map)),
    );
  }

  Future<void> delete(MappingType type, List<int> ids) async {
    final raw = await _source.mappingDelete(type.value, {'mappings_ids': ids});
    unwrapStd<void>(raw, (_) {});
  }
}
