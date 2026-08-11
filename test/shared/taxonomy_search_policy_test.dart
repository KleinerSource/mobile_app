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
}
