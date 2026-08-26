import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omm/core/models/playback.dart';
import 'package:omm/features/player/subtitle_rendering.dart';
import 'package:omm/features/player/subtitle_settings.dart';

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

  test('字幕垂直边界允许覆盖视频但不会超出视口', () {
    final bounds = subtitleVerticalOffsetBoundsFor(
      viewport: const Size(400, 800),
      contentRect: Offset.zero & const Size(400, 800),
      subtitleHeight: 40,
      viewportScale: 1,
    );

    expect(bounds.min, -24);
    expect(bounds.max, 736);
    expect(bounds.clamp(900), 736);
    expect(bounds.clamp(-100), -24);
  });

  test('contain 视频矩形在竖屏视口中上下留黑边', () {
    // 16:9 视频放进 9:16 视口：宽度撑满，高度按比例缩小。
    final rect = containedVideoRect(
      viewport: const Size(360, 640),
      video: const Size(1920, 1080),
    );

    expect(rect.width, 360);
    expect(rect.height, closeTo(202.5, 0.01));
    expect(rect.top, closeTo((640 - 202.5) / 2, 0.01));
  });

  test('画面窄于视口时左右留黑边且垂直占满', () {
    final rect = containedVideoRect(
      viewport: const Size(390, 844),
      video: const Size(1080, 2340),
    );

    expect(rect.height, 844);
    expect(rect.width, closeTo(844 * 1080 / 2340, 0.01));
  });

  test('视频尺寸未知时退化为整个视口', () {
    final viewport = const Size(1280, 720);
    final rect = containedVideoRect(viewport: viewport, video: Size.zero);

    expect(rect, Offset.zero & viewport);
  });

  test('横竖屏切换后同一偏移值始终相对画面底部定位', () {
    // 旧实现把偏移锚在屏幕底部：竖屏补偿下方黑边调出的值，切到
    // 全屏横屏后会把字幕顶进画面中部。新实现锚定画面底边后，
    // 同一数值在两个方向下相对画面的位置必须一致。
    SubtitleVerticalOffsetBounds boundsFor(Size viewport) {
      final content = containedVideoRect(
        viewport: viewport,
        video: const Size(1920, 1080),
      );
      return subtitleVerticalOffsetBoundsFor(
        viewport: viewport,
        contentRect: content,
        subtitleHeight: 40,
        viewportScale: 1,
      );
    }

    // 竖屏 9:16：画面只占视口中部一小条（高约 219）。
    final portrait = boundsFor(const Size(390, 780));
    // 横屏 16:9：画面恰好占满视口。
    final landscape = boundsFor(const Size(1386, 780));

    // 偏移 0 = 字幕紧贴画面底部内侧（留 24px 间距），无需再补偿黑边。
    // 正向可把字幕抬到画面顶部；负向允许沉入下方黑边直至屏幕底。
    expect(portrait.max, closeTo(219.375 - 24 - 40, 0.01));
    expect(portrait.min, closeTo(-280.3125 - 24, 0.01));
    // 横屏画面占满视口，负向只能沉出底部间距那么多。
    expect(landscape.max, closeTo(780 - 24 - 40, 1));
    expect(landscape.min, closeTo(-24, 0.5));

    // 迁移后的默认值与任意画面内合法值在两个方向语义一致：
    // "距画面底部 N 像素"，不会被旋转钳制成别的含义。
    const userOffset = 120.0;
    expect(portrait.clamp(userOffset), userOffset);
    expect(landscape.clamp(userOffset), userOffset);
  });
}
