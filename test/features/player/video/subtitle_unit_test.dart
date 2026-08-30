// 合并自以下测试文件（测试内容保持不变，整合以减少每个文件的加载编译开销）。
//   - test/features/subtitle_settings_test.dart
//   - test/features/subtitle_content_fetcher_test.dart
//   - test/features/subtitle_rendering_test.dart

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/api/api_client.dart';
import 'package:omm/core/models/playback.dart';
import 'package:omm/core/sources/common/source_exception.dart';
import 'package:omm/core/sources/media/omm_media_source_adapter.dart';
import 'package:omm/features/player/video/subtitle_rendering.dart';
import 'package:omm/features/player/video/subtitle_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ==================== 原 test/features/subtitle_settings_test.dart ====================
void _main_0() {
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

// ==================== 原 test/features/subtitle_content_fetcher_test.dart ====================
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.responder);

  final Future<ResponseBody> Function(RequestOptions options) responder;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return responder(options);
  }
}

OmmMediaSourceAdapter _sourceWith(ResponseBody Function() responder) {
  final dio = Dio(BaseOptions(responseType: ResponseType.plain));
  dio.httpClientAdapter = _FakeAdapter((_) async => responder());
  return OmmMediaSourceAdapter(ApiClient(dio));
}

void _main_1() {
  test('成功下载时返回去空白后的字幕内容', () async {
    final source = _sourceWith(
      () => ResponseBody.fromString(
        'WEBVTT\n\n1\n00:00:01.000 --> 00:00:02.000\n你好\n',
        200,
        headers: {
          Headers.contentTypeHeader: ['text/vtt; charset=utf-8'],
        },
      ),
    );
    final content = await source.fetchSubtitleContent(
      'http://server/subtitles/1?format=vtt',
    );
    expect(content, startsWith('WEBVTT'));
    expect(content, contains('00:00:01.000 --> 00:00:02.000'));
  });

  test('接口返回 404 时抛出带后端文案的异常而不是影响调用方', () async {
    final source = _sourceWith(
      () => ResponseBody.fromString(
        '{"success":false,"message":"字幕不存在"}',
        404,
        headers: {
          Headers.contentTypeHeader: ['application/json; charset=utf-8'],
        },
      ),
    );
    await expectLater(
      source.fetchSubtitleContent('http://server/subtitles/99?format=vtt'),
      throwsA(
        isA<SourceException>()
            .having((e) => e.message, 'message', '字幕不存在')
            .having((e) => e.statusCode, 'statusCode', 404),
      ),
    );
  });

  test('错误响应体不是 JSON 时退回通用 HTTP 文案', () async {
    final source = _sourceWith(() => ResponseBody.fromString('Not Found', 404));
    await expectLater(
      source.fetchSubtitleContent('http://server/subtitles/99?format=vtt'),
      throwsA(
        isA<SourceException>().having(
          (e) => e.message,
          'message',
          contains('404'),
        ),
      ),
    );
  });

  test('内容缺少时间轴行时视为无效字幕', () async {
    final source = _sourceWith(() => ResponseBody.fromString('WEBVTT\n', 200));
    await expectLater(
      source.fetchSubtitleContent('http://server/subtitles/1?format=vtt'),
      throwsA(
        isA<SourceException>().having((e) => e.message, 'message', '字幕内容无效或为空'),
      ),
    );
  });

  test('连接失败映射为网络异常文案', () async {
    final dio = Dio(BaseOptions(responseType: ResponseType.plain));
    dio.httpClientAdapter = _FakeAdapter((_) async {
      throw DioException.connectionTimeout(
        requestOptions: RequestOptions(path: '/'),
        timeout: const Duration(seconds: 1),
      );
    });
    final source = OmmMediaSourceAdapter(ApiClient(dio));
    await expectLater(
      source.fetchSubtitleContent('http://server/subtitles/1?format=vtt'),
      throwsA(
        isA<SourceException>().having(
          (e) => e.message,
          'message',
          '请求超时，请稍后重试',
        ),
      ),
    );
  });
}

// ==================== 原 test/features/subtitle_rendering_test.dart ====================
void _main_2() {
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
      const SubtitleAdjustments(
        sizeScalePortrait: 1.5,
        sizeScaleLandscape: 2.5,
      ),
      baseFontSize: 20,
      landscape: false,
    );

    expect(style.fontFamily, 'monospace');
    expect(style.fontSize, 30);
    expect(style.fontWeight, FontWeight.w700);
    expect(style.fontStyle, FontStyle.italic);
    expect(style.color, const Color(0xFFFFD166));
    expect(style.shadows, isNotEmpty);

    // 横屏分组独立生效。
    final landscapeStyle = subtitleTextStyle(
      const SubtitleSettings(),
      const SubtitleAdjustments(
        sizeScalePortrait: 1.5,
        sizeScaleLandscape: 2.5,
      ),
      baseFontSize: 20,
      landscape: true,
    );
    expect(landscapeStyle.fontSize, 50);
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

void main() {
  group('subtitle_settings', _main_0);
  group('subtitle_content_fetcher', _main_1);
  group('subtitle_rendering', _main_2);
}
