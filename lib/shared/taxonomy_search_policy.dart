const taxonomyLocalLimit = 300;

bool shouldUseLocalTaxonomySearch({
  required bool hasMore,
  required int itemCount,
}) {
  return !hasMore && itemCount <= taxonomyLocalLimit;
}

List<T> prioritizeSelectedWhenSearchEmpty<T>({
  required Iterable<T> items,
  required bool searchIsEmpty,
  required bool Function(T item) isSelected,
}) {
  final orderedItems = items.toList(growable: false);
  if (!searchIsEmpty) return orderedItems;

  final selectedItems = <T>[];
  final unselectedItems = <T>[];
  for (final item in orderedItems) {
    (isSelected(item) ? selectedItems : unselectedItems).add(item);
  }
  return [...selectedItems, ...unselectedItems];
}
