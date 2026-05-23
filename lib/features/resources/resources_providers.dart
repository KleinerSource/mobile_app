import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/providers.dart';
import '../../core/models/paged_result.dart';
import '../../core/models/resource.dart';
import 'resources_repository.dart';

final resourcesRepositoryProvider = Provider<ResourcesRepository>((ref) {
  return ResourcesRepository(ref.watch(requiredApiClientProvider));
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

/// 列出某类资源 · 默认前 200 条
final resourceListProvider = FutureProvider.autoDispose
    .family<PagedResult<ResourceItem>, ResourceListKey>((ref, key) async {
  return ref.watch(resourcesRepositoryProvider).list(
        key.kind,
        limit: 200,
        offset: 0,
        search: key.search,
        sortBy: key.sortBy,
        sortOrder: key.sortOrder,
      );
});
