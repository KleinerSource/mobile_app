import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/models/paged_result.dart';
import 'package:omm/core/models/resource.dart';
import 'package:omm/core/sources/media/media_source_providers.dart';
import 'resources_repository.dart';

final resourcesRepositoryProvider = Provider<ResourcesRepository>((ref) {
  final source = ref.watch(ommMediaSourceProvider);
  if (source == null) {
    throw StateError('当前服务器不是 OMM，无法访问媒体资源');
  }
  return ResourcesRepository(source.metadataOperations);
});

/// FutureProvider.family 不接受多参数,用 key 类包装
class ResourceListKey {
  const ResourceListKey({
    required this.kind,
    this.search,
    this.sortBy = 'name',
    this.sortOrder = 'asc',
  });

  final ResourceKind kind;
  final String? search;
  final String sortBy;
  final String sortOrder;

  @override
  bool operator ==(Object other) =>
      other is ResourceListKey &&
      other.kind == kind &&
      other.search == search &&
      other.sortBy == sortBy &&
      other.sortOrder == sortOrder;

  @override
  int get hashCode => Object.hash(kind, search, sortBy, sortOrder);
}

/// 列出某类资源 · 标签/分类默认前 300 条，系列默认前 100 条
final resourceListProvider = FutureProvider.autoDispose
    .family<PagedResult<ResourceItem>, ResourceListKey>((ref, key) async {
      final limit = key.kind == ResourceKind.series ? 100 : 300;
      return ref
          .watch(resourcesRepositoryProvider)
          .list(
            key.kind,
            limit: limit,
            offset: 0,
            search: key.search,
            sortBy: key.sortBy,
            sortOrder: key.sortOrder,
          );
    });
