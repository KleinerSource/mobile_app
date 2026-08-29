// 合并自以下测试文件（测试内容保持不变，整合以减少每个文件的加载编译开销）。
//   - test/shared/pinyin_search_test.dart
//   - test/shared/taxonomy_search_policy_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:omm/shared/pinyin_search.dart';
import 'package:omm/shared/taxonomy_search_policy.dart';

// ==================== 原 test/shared/pinyin_search_test.dart ====================
void _main_0() {
  test('支持名称、全拼和拼音首字母搜索', () {
    expect(matchesPinyinSearch('动作', '动作'), isTrue);
    expect(matchesPinyinSearch('动作', 'dongzuo'), isTrue);
    expect(matchesPinyinSearch('动作', 'dz'), isTrue);
    expect(matchesPinyinSearch('动作', '喜剧'), isFalse);
  });

  test('空搜索词匹配全部资源', () {
    expect(matchesPinyinSearch('动作', ''), isTrue);
    expect(matchesPinyinSearch('动作', '  '), isTrue);
  });

  test('拼音首字母不会匹配音节尾首拼接', () {
    expect(matchesPinyinSearch('性感', 'gg'), isFalse);
    expect(matchesPinyinSearch('顶高潮', 'gg'), isFalse);
    expect(matchesPinyinSearch('高跟鞋', 'gg'), isTrue);
  });

  test('保留中文、全拼和首字母搜索', () {
    expect(matchesPinyinSearch('性感', '性感'), isTrue);
    expect(matchesPinyinSearch('性感', 'xinggan'), isTrue);
    expect(matchesPinyinSearch('性感', 'gan'), isTrue);
    expect(matchesPinyinSearch('性感', 'xg'), isTrue);
  });
}

// ==================== 原 test/shared/taxonomy_search_policy_test.dart ====================
void _main_1() {
  test('不超过 300 条时使用本地搜索', () {
    expect(shouldUseLocalTaxonomySearch(hasMore: false, itemCount: 0), isTrue);
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

void main() {
  group('pinyin_search', _main_0);
  group('taxonomy_search_policy', _main_1);
}
