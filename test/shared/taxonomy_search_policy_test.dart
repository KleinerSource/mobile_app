import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/shared/taxonomy_search_policy.dart';

void main() {
  test('不超过 300 条时使用本地搜索', () {
    expect(
      shouldUseLocalTaxonomySearch(hasMore: false, itemCount: 0),
      isTrue,
    );
    expect(
      shouldUseLocalTaxonomySearch(hasMore: false, itemCount: 299),
      isTrue,
    );
    expect(
      shouldUseLocalTaxonomySearch(hasMore: false, itemCount: 300),
      isTrue,
    );
  });

  test('超过 300 条时使用远程搜索', () {
    expect(
      shouldUseLocalTaxonomySearch(hasMore: true, itemCount: 300),
      isFalse,
    );
    expect(
      shouldUseLocalTaxonomySearch(hasMore: false, itemCount: 301),
      isFalse,
    );
  });

  test('空搜索时将已选项稳定排在最前面', () {
    final result = prioritizeSelectedWhenSearchEmpty(
      items: [1, 2, 3, 4, 5],
      searchIsEmpty: true,
      isSelected: {2, 4}.contains,
    );

    expect(result, [2, 4, 1, 3, 5]);
  });

  test('存在搜索词时保留匹配结果顺序', () {
    final result = prioritizeSelectedWhenSearchEmpty(
      items: [1, 2, 3, 4, 5],
      searchIsEmpty: false,
      isSelected: {2, 4}.contains,
    );

    expect(result, [1, 2, 3, 4, 5]);
  });
}
