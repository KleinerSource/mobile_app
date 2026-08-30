import 'package:flutter_test/flutter_test.dart';
import 'package:omm/features/player/lrc_parser.dart';

void main() {
  test('解析 BOM、毫秒、多时间标签和 offset，并按时间排序', () {
    final document = parseLrc('''
\ufeff[ar:歌手]
[offset:+100]
[00:02.345][00:01.2]第一句
[01:02.34]第二句
[00:60.00]错误行
[bad]忽略
''');

    expect(document, isNotNull);
    expect(document!.cues, hasLength(3));
    expect(document.cues[0].position, const Duration(milliseconds: 1300));
    expect(document.cues[0].text, '第一句');
    expect(document.cues[1].position, const Duration(milliseconds: 2445));
    expect(document.cues[2].position, const Duration(milliseconds: 62440));
    expect(document.indexAt(const Duration(milliseconds: 1299)), -1);
    expect(document.indexAt(const Duration(milliseconds: 1300)), 0);
    expect(document.cueAt(const Duration(seconds: 3))?.text, '第一句');
  });

  test('忽略信息标签、空歌词和不合法时间', () {
    expect(
      parseLrc('[ti:标题]\n[00:61.00]错误\n[00:01.0000]错误\n[00:01]有效'),
      isNotNull,
    );
    expect(parseLrc('[ti:标题]\n[00:61.00]错误\n[00:01.0000]错误'), isNull);
    expect(parseLrc('[00:01.000]'), isNull);
  });

  test('负 offset 不会生成负时间 cue', () {
    final document = parseLrc('[offset:-1500]\n[00:01.000]太早');
    expect(document, isNull);
  });
}
