import 'package:flutter_test/flutter_test.dart';
import 'package:omm/features/media_browser/playback/media_browser_lyrics.dart';

void main() {
  test('解析 Jellyfin LyricsDto 的逐行歌词（tick 起点转毫秒）', () {
    final document = parseMediaBrowserLyrics(<String, dynamic>{
      'Metadata': {'Artist': '艺术家'},
      'Lyrics': [
        {'Text': '第一行', 'Start': 10000000}, // 1s
        {'Text': '第二行', 'Start': 65000000}, // 6.5s
      ],
    });

    expect(document, isNotNull);
    expect(document!.cues.length, 2);
    expect(document.cues[0].text, '第一行');
    expect(document.cues[0].position, const Duration(seconds: 1));
    expect(document.cues[1].position, const Duration(milliseconds: 6500));
  });

  test('无时间轴的歌词行被跳过，全部缺失时按无歌词处理', () {
    final document = parseMediaBrowserLyrics(<String, dynamic>{
      'Lyrics': [
        {'Text': '第一行'},
        {'Text': '第二行'},
      ],
    });

    expect(document, isNull);
  });

  test('纯 LRC 文本直接透传给 LRC 解析器', () {
    const lrc = '[00:01.00]第一行\n[00:06.50]第二行\n';
    final document = parseMediaBrowserLyrics(lrc);

    expect(document, isNotNull);
    expect(document!.cues.length, 2);
    expect(document.cues[0].text, '第一行');
    expect(document.cues[0].position, const Duration(seconds: 1));
  });

  test('Lyrics 字段为字符串时按 LRC 解析，空响应返回 null', () {
    final document = parseMediaBrowserLyrics(<String, dynamic>{
      'Lyrics': '[00:02.00]唯一一行',
    });
    expect(document, isNotNull);
    expect(document!.cues.single.text, '唯一一行');

    expect(parseMediaBrowserLyrics(null), isNull);
    expect(parseMediaBrowserLyrics('  '), isNull);
    expect(parseMediaBrowserLyrics(<String, dynamic>{}), isNull);
  });

  test('起点为负数或非数字的行被忽略', () {
    final document = parseMediaBrowserLyrics(<String, dynamic>{
      'Lyrics': [
        {'Text': '坏行 A', 'Start': -1},
        {'Text': '坏行 B', 'Start': 'abc'},
        {'Text': '好行', 'Start': 10000000},
      ],
    });

    expect(document, isNotNull);
    expect(document!.cues.single.text, '好行');
  });
}
