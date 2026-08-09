import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:md_center/core/models/playback.dart';
import 'package:md_center/features/player/subtitle_settings.dart';

void main() {
  const track = SubtitleTrack(
    index: 2,
    source: 'external',
    language: 'zh',
    title: '简体中文',
    codec: 'srt',
    url: '/api/subtitles/2?token=secret-a',
    isDefault: false,
  );

  test('字幕设置默认值满足现有播放行为', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final actual = SubtitleSettingsRepository(prefs).load();

    expect(actual.rememberSelectedSubtitle, isTrue);
    expect(actual.ignoreAssStyle, isFalse);
    expect(actual.ignoreSrtStyle, isFalse);
    expect(actual.fontFamily, 'Inter');
    expect(actual.bold, isFalse);
    expect(actual.italic, isFalse);
    expect(actual.outlineWidth, 0);
    expect(actual.shadowSize, 0);
    expect(actual.fontColor, const Color(0xFFFFFFFF));
    expect(actual.backgroundColor, const Color(0xAA000000));
  });

  test('字幕设置和选择结果可以持久化恢复', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repository = SubtitleSettingsRepository(prefs);
    const expected = SubtitleSettings(
      rememberSelectedSubtitle: false,
      ignoreAssStyle: true,
      ignoreSrtStyle: true,
      fontFamily: 'monospace',
      bold: true,
      italic: true,
      fontColor: Color(0xFFFFD166),
      backgroundColor: Color(0x00000000),
      outlineColor: Color(0xFF101010),
      outlineWidth: 2.5,
      shadowColor: Color(0xCC000000),
      shadowSize: 4,
      rememberedSubtitleKey: 'remembered',
    );

    await repository.save(expected);
    final actual = repository.load();

    expect(actual.rememberSelectedSubtitle, isFalse);
    expect(actual.ignoreAssStyle, isTrue);
    expect(actual.ignoreSrtStyle, isTrue);
    expect(actual.fontFamily, 'monospace');
    expect(actual.bold, isTrue);
    expect(actual.italic, isTrue);
    expect(actual.fontColor, expected.fontColor);
    expect(actual.backgroundColor, expected.backgroundColor);
    expect(actual.outlineWidth, 2.5);
    expect(actual.shadowSize, 4);
    expect(actual.rememberedSubtitleKey, 'remembered');
  });

  test('字幕记忆键不包含可能变化的 URL 或 token', () {
    final changedUrl = track.copyWithForTest(
      url: '/api/subtitles/2?token=secret-b',
    );

    expect(subtitleSelectionKey(track), subtitleSelectionKey(changedUrl));
    expect(subtitleSelectionKey(track), isNot(contains('secret-a')));
    expect(subtitleSelectionKey(track), isNot(contains('/api/subtitles')));
  });
}

extension on SubtitleTrack {
  SubtitleTrack copyWithForTest({String? url}) {
    return SubtitleTrack(
      index: index,
      source: source,
      language: language,
      title: title,
      codec: codec,
      url: url ?? this.url,
      isDefault: isDefault,
    );
  }
}
