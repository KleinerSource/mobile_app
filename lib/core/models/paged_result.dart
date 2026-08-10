class PagedResult<T> {
  const PagedResult({
    required this.items,
    required this.totalCount,
    required this.limit,
    required this.offset,
  });

  final List<T> items;
  final int totalCount;
  final int limit;
  final int offset;

  bool get hasMore => offset + items.length < totalCount;
}

/// 有界的编辑器选项结果。
///
/// 选项接口只返回 id/name，并通过 hasMore 告知用户继续缩小搜索范围，
/// 不携带资源管理列表中的影片计数等扩展字段。
class OptionsResult<T> {
  const OptionsResult({
    required this.items,
    required this.hasMore,
    required this.limit,
  });

  final List<T> items;
  final bool hasMore;
  final int limit;
}
