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
