import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:omm/core/models/playback.dart';
import 'package:omm/features/player/subtitle_settings.dart';

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
    expect(actual.adjustments.delayMs, 0);
    expect(actual.adjustments.verticalOffsetPortrait, 0);
    expect(actual.adjustments.verticalOffsetLandscape, 0);
    expect(actual.adjustments.sizeScalePortrait, 1);
    expect(actual.adjustments.sizeScaleLandscape, 1);
    expect(actual.adjustments.opacity, 1);
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
      adjustments: SubtitleAdjustments(
        delayMs: 1200,
        verticalOffsetPortrait: 640,
        verticalOffsetLandscape: 320,
        sizeScalePortrait: 1.35,
        sizeScaleLandscape: 1.1,
        opacity: 0.65,
      ),
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
    expect(actual.adjustments.delayMs, 1200);
    expect(actual.adjustments.verticalOffsetPortrait, 640);
    expect(actual.adjustments.verticalOffsetLandscape, 320);
    expect(actual.adjustments.sizeScalePortrait, 1.35);
    expect(actual.adjustments.sizeScaleLandscape, 1.1);
    expect(actual.adjustments.opacity, 0.65);
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

  test('旧版共享偏移迁移到分组时归零，缩放带入两组', () async {
    SharedPreferences.setMockInitialValues({
      'subtitle.adjustment_vertical_offset': 500.0,
      'subtitle.adjustment_size_scale': 1.4,
      'subtitle.adjustment_delay_ms': 300,
    });
    final prefs = await SharedPreferences.getInstance();

    final actual = SubtitleSettingsRepository(prefs).load();

    // 偏移无法判断旧值属于哪个方向，统一归零重新校准。
    expect(actual.adjustments.verticalOffsetPortrait, 0);
    expect(actual.adjustments.verticalOffsetLandscape, 0);
    // 缩放是倍率语义，与方向无关，直接带入两组。
    expect(actual.adjustments.sizeScalePortrait, 1.4);
    expect(actual.adjustments.sizeScaleLandscape, 1.4);
    // 共享项不受迁移影响。
    expect(actual.adjustments.delayMs, 300);
    // 迁移幂等：写入分组值后再次加载保持不变。
    await prefs.setDouble('subtitle.adjustment_vertical_offset_portrait', 120);
    final again = SubtitleSettingsRepository(prefs).load();
    expect(again.adjustments.verticalOffsetPortrait, 120);
  });

  test('竖屏与横屏分组独立保存互不覆盖', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repository = SubtitleSettingsRepository(prefs);

    const adjustments = SubtitleAdjustments(
      delayMs: 100,
      verticalOffsetPortrait: 480,
      verticalOffsetLandscape: 60,
      sizeScalePortrait: 1.2,
      sizeScaleLandscape: 0.9,
      opacity: 0.8,
    );
    await repository.saveAdjustments(adjustments);

    final actual = SubtitleSettingsRepository(prefs).load();
    expect(actual.adjustments.verticalOffsetPortrait, 480);
    expect(actual.adjustments.verticalOffsetLandscape, 60);
    expect(actual.adjustments.sizeScalePortrait, 1.2);
    expect(actual.adjustments.sizeScaleLandscape, 0.9);
    expect(actual.adjustments.delayMs, 100);
    expect(actual.adjustments.opacity, 0.8);

    // 按方向读取：竖屏用竖屏组，横屏用横屏组。
    expect(adjustments.verticalOffsetFor(false), 480);
    expect(adjustments.verticalOffsetFor(true), 60);
    expect(adjustments.sizeScaleFor(false), 1.2);
    expect(adjustments.sizeScaleFor(true), 0.9);
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
