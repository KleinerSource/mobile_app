import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/shared/pinyin_search.dart';

void main() {
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
}
