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
