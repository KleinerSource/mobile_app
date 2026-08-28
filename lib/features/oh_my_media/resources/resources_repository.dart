import 'package:omm/core/api/dio_factory.dart';
import 'package:omm/core/api/envelope.dart';
import 'package:omm/core/models/paged_result.dart';
import 'package:omm/core/models/resource.dart';
import 'package:omm/core/sources/media/omm_metadata_operations_source.dart';

/// 三类相同 schema 的资源 · 同样的 5 个 CRUD
enum ResourceKind {
  genre(label: '分类', plural: '分类管理', searchHint: '搜索分类名称', icon: 'GENRES'),
  tag(label: '标签', plural: '标签管理', searchHint: '搜索标签名称', icon: 'TAGS'),
  series(label: '系列', plural: '系列管理', searchHint: '搜索系列名称', icon: 'SERIES');

  const ResourceKind({
    required this.label,
    required this.plural,
    required this.searchHint,
    required this.icon,
  });

  final String label;
  final String plural;
  final String searchHint;
  final String icon;
}

class ResourcesRepository {
  ResourcesRepository(this._source);
  final OmmMetadataOperationsSource _source;

  Future<dynamic> _list(ResourceKind k, Map<String, dynamic> q) {
    switch (k) {
      case ResourceKind.genre:
        return _source.resourceList('genres', q);
      case ResourceKind.tag:
        return _source.resourceList('tags', q);
      case ResourceKind.series:
        return _source.resourceList('series', q);
    }
  }

  Future<dynamic> _options(ResourceKind k, Map<String, dynamic> q) {
    switch (k) {
      case ResourceKind.genre:
        return _source.resourceOptions('genres', q);
      case ResourceKind.tag:
        return _source.resourceOptions('tags', q);
      case ResourceKind.series:
        return _source.resourceOptions('series', q);
    }
  }

  Future<dynamic> _create(ResourceKind k, Map<String, dynamic> body) {
    switch (k) {
      case ResourceKind.genre:
        return _source.resourceCreate('genres', body);
      case ResourceKind.tag:
        return _source.resourceCreate('tags', body);
      case ResourceKind.series:
        return _source.resourceCreate('series', body);
    }
  }

  Future<dynamic> _update(ResourceKind k, int id, Map<String, dynamic> body) {
    switch (k) {
      case ResourceKind.genre:
        return _source.resourceUpdate('genres', id, body);
      case ResourceKind.tag:
        return _source.resourceUpdate('tags', id, body);
      case ResourceKind.series:
        return _source.resourceUpdate('series', id, body);
    }
  }

  Future<dynamic> _batchDelete(ResourceKind k, Map<String, dynamic> body) {
    switch (k) {
      case ResourceKind.genre:
        return _source.resourceDelete('genres', body);
      case ResourceKind.tag:
        return _source.resourceDelete('tags', body);
      case ResourceKind.series:
        return _source.resourceDelete('series', body);
    }
  }

  Future<ResourceItem> get(ResourceKind kind, int id) async {
    final type = switch (kind) {
      ResourceKind.genre => 'genres',
      ResourceKind.tag => 'tags',
      ResourceKind.series => 'series',
    };
    final raw = await _source.resourceDetail(type, id);
    return unwrapStd<ResourceItem>(
      raw,
      (d) => ResourceItem.fromJson(Map<String, dynamic>.from(d as Map)),
    );
  }

  Future<PagedResult<ResourceItem>> list(
    ResourceKind kind, {
    int limit = 100,
    int offset = 0,
    String? search,
    String sortBy = 'name',
    String sortOrder = 'asc',
  }) async {
    final q = <String, dynamic>{
      'limit': limit,
      'offset': offset,
      'sort_by': sortBy,
      'sort_order': sortOrder,
    };
    if (search != null && search.trim().isNotEmpty) {
      q['search'] = search.trim();
    }
    final raw = await _list(kind, q);
    // 后端 /tags · /genres · /series 返回 { success, data: [...] } 顶层数组
    // (不是分页 envelope 的 data.items 结构)
    return unwrapTopLevelList<ResourceItem>(raw, ResourceItem.fromJson);
  }

  Future<OptionsResult<ResourceItem>> options(
    ResourceKind kind, {
    String? search,
    int offset = 0,
    int? limit,
  }) async {
    final q = <String, dynamic>{'offset': offset};
    final keyword = search?.trim() ?? '';
    if (keyword.isNotEmpty) q['search'] = keyword;
    if (limit != null && limit > 0) q['limit'] = limit;

    try {
      final raw = await _options(kind, q);
      final result = unwrapOptions<ResourceItem>(raw, ResourceItem.fromJson);
      // 旧服务可能不返回 offset；客户端以本次请求的偏移为准，避免第二页重复请求第一页。
      return OptionsResult<ResourceItem>(
        items: result.items,
        hasMore: result.hasMore,
        limit: result.limit,
        offset: offset,
      );
    } catch (error) {
      // 新接口是增量能力；老服务没有路由时继续使用原列表接口。
      final status = toApiException(error).status;
      // 老服务没有 /options 路由时，/options 可能会命中 /:id 并返回 400。
      if (status != 404 && status != 400) rethrow;
      final fallbackLimit = kind == ResourceKind.series ? 100 : 300;
      final page = await list(
        kind,
        limit: fallbackLimit,
        offset: offset,
        search: keyword.isEmpty ? null : keyword,
        sortBy: 'name',
        sortOrder: 'asc',
      );
      return OptionsResult<ResourceItem>(
        items: page.items,
        hasMore: page.hasMore,
        limit: page.limit,
        offset: offset,
      );
    }
  }

  Future<ResourceItem> create(ResourceKind kind, {required String name}) async {
    final body = <String, dynamic>{'name': name};
    final raw = await _create(kind, body);
    return unwrapStd<ResourceItem>(
      raw,
      (d) => ResourceItem.fromJson(Map<String, dynamic>.from(d as Map)),
    );
  }

  Future<ResourceItem> update(
    ResourceKind kind,
    int id, {
    String? name,
    bool autoMapping = false,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    body['auto_mapping'] = autoMapping;
    final raw = await _update(kind, id, body);
    return unwrapStd<ResourceItem>(
      raw,
      (d) => ResourceItem.fromJson(Map<String, dynamic>.from(d as Map)),
    );
  }

  Future<void> deleteBatch(
    ResourceKind kind,
    List<int> ids, {
    bool force = false,
  }) async {
    final raw = await _batchDelete(kind, {'ids': ids, 'force': force});
    unwrapStd<void>(raw, (_) {});
  }

  Future<void> merge(
    ResourceKind kind, {
    required List<int> sourceIds,
    required String targetName,
  }) async {
    final type = switch (kind) {
      ResourceKind.tag => 'tags',
      ResourceKind.genre => 'genres',
      ResourceKind.series => 'series',
    };
    final raw = await _source.resourceMerge(type, {
      'source_ids': sourceIds,
      'target_name': targetName,
    });
    unwrapStd<void>(raw, (_) {});
  }
}
