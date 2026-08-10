import '../../core/api/api_client.dart';
import '../../core/api/dio_factory.dart';
import '../../core/api/envelope.dart';
import '../../core/models/paged_result.dart';
import '../../core/models/resource.dart';

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
  ResourcesRepository(this._client);
  final ApiClient _client;

  Future<dynamic> _list(ResourceKind k, Map<String, dynamic> q) {
    switch (k) {
      case ResourceKind.genre:
        return _client.genres.list(q);
      case ResourceKind.tag:
        return _client.tags.list(q);
      case ResourceKind.series:
        return _client.series.list(q);
    }
  }

  Future<dynamic> _options(ResourceKind k, Map<String, dynamic> q) {
    switch (k) {
      case ResourceKind.genre:
        return _client.genres.options(q);
      case ResourceKind.tag:
        return _client.tags.options(q);
      case ResourceKind.series:
        return _client.series.options(q);
    }
  }

  Future<dynamic> _create(ResourceKind k, Map<String, dynamic> body) {
    switch (k) {
      case ResourceKind.genre:
        return _client.genres.create(body);
      case ResourceKind.tag:
        return _client.tags.create(body);
      case ResourceKind.series:
        return _client.series.create(body);
    }
  }

  Future<dynamic> _update(ResourceKind k, int id, Map<String, dynamic> body) {
    switch (k) {
      case ResourceKind.genre:
        return _client.genres.update(id, body);
      case ResourceKind.tag:
        return _client.tags.update(id, body);
      case ResourceKind.series:
        return _client.series.update(id, body);
    }
  }

  Future<dynamic> _batchDelete(ResourceKind k, Map<String, dynamic> body) {
    switch (k) {
      case ResourceKind.genre:
        return _client.genres.batchDelete(body);
      case ResourceKind.tag:
        return _client.tags.batchDelete(body);
      case ResourceKind.series:
        return _client.series.batchDelete(body);
    }
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
  }) async {
    final q = <String, dynamic>{};
    final keyword = search?.trim() ?? '';
    if (keyword.isNotEmpty) q['search'] = keyword;

    try {
      final raw = await _options(kind, q);
      return unwrapOptions<ResourceItem>(raw, ResourceItem.fromJson);
    } catch (error) {
      // 新接口是增量能力；老服务没有路由时继续使用原列表接口。
      final status = toApiException(error).status;
      // 老服务没有 /options 路由时，/options 可能会命中 /:id 并返回 400。
      if (status != 404 && status != 400) rethrow;
      final page = await list(
        kind,
        limit: 500,
        offset: 0,
        search: keyword.isEmpty ? null : keyword,
        sortBy: 'name',
        sortOrder: 'asc',
      );
      return OptionsResult<ResourceItem>(
        items: page.items,
        hasMore: page.hasMore,
        limit: page.limit,
      );
    }
  }

  Future<ResourceItem> create(
    ResourceKind kind, {
    required String name,
    String? description,
  }) async {
    final body = <String, dynamic>{'name': name};
    if (description != null && description.isNotEmpty) {
      body['description'] = description;
    }
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
    String? description,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (description != null) body['description'] = description;
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
}
