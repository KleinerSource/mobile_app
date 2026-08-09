import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:md_center/core/models/playback.dart';
import 'package:md_center/features/player/subtitle_rendering.dart';
import 'package:md_center/features/player/subtitle_settings.dart';

void main() {
  const assTrack = SubtitleTrack(
    index: 1,
    source: 'external',
    language: 'zh',
    title: 'ASS',
    codec: 'ass',
    url: '/subtitle.ass',
    isDefault: false,
  );
  const srtTrack = SubtitleTrack(
    index: 2,
    source: 'external',
    language: 'zh',
    title: 'SRT',
    codec: 'subrip',
    url: '/subtitle.srt',
    isDefault: false,
  );

  test('忽略 ASS 样式时清理标签并保留换行', () {
    final lines = sanitizeSubtitleLines(
      const ['{\\an8}第一行\\N第二行'],
      track: assTrack,
      settings: const SubtitleSettings(ignoreAssStyle: true),
    );

    expect(lines, const ['第一行\n第二行']);
  });

  test('忽略 SRT 样式时清理 HTML 标签', () {
    final lines = sanitizeSubtitleLines(
      const ['<i>这是一句字幕</i>'],
      track: srtTrack,
      settings: const SubtitleSettings(ignoreSrtStyle: true),
    );

    expect(lines, const ['这是一句字幕']);
  });

  test('未启用样式清理时保留原始标记', () {
    expect(
      sanitizeSubtitleLines(
        const ['<i>字幕</i>'],
        track: srtTrack,
        settings: const SubtitleSettings(),
      ),
      const ['<i>字幕</i>'],
    );
  });

  test('字幕文字样式应用客户端设置和实时缩放', () {
    final style = subtitleTextStyle(
      const SubtitleSettings(
        fontFamily: 'monospace',
        bold: true,
        italic: true,
        fontColor: Color(0xFFFFD166),
        backgroundColor: Color(0xAA000000),
        outlineWidth: 2,
        shadowSize: 3,
      ),
      const SubtitleAdjustments(sizeScale: 1.5),
      baseFontSize: 20,
    );

    expect(style.fontFamily, 'monospace');
    expect(style.fontSize, 30);
    expect(style.fontWeight, FontWeight.w700);
    expect(style.fontStyle, FontStyle.italic);
    expect(style.color, const Color(0xFFFFD166));
    expect(style.shadows, isNotEmpty);
  });
}
