import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/models/playback.dart' as playback_models;
import 'player_session_controller.dart';
import 'subtitle_settings.dart';

/// 偏移为 0 时字幕底边与视频画面底部之间保留的间距（逻辑像素）。
const subtitleBottomPadding = 24.0;

/// 计算 BoxFit.contain 下视频画面在视口中的内容矩形。
///
/// 视频尺寸未知时退化为整个视口，行为与旧的屏幕底部锚定一致。
Rect containedVideoRect({required Size viewport, required Size video}) {
  if (viewport.isEmpty) return Rect.zero;
  if (video.isEmpty || video.width <= 0 || video.height <= 0) {
    return Offset.zero & viewport;
  }
  final scale = math.min(
    viewport.width / video.width,
    viewport.height / video.height,
  );
  return Alignment.center.inscribe(video * scale, Offset.zero & viewport);
}

SubtitleVerticalOffsetBounds subtitleVerticalOffsetBoundsFor({
  required Size viewport,
  required Rect contentRect,
  required double subtitleHeight,
  required double viewportScale,
  double bottomPadding = subtitleBottomPadding,
}) {
  final scale = viewportScale > 0 ? viewportScale : 1.0;
  final contentBottom = math.min(contentRect.bottom, viewport.height);
  final contentTop = math.max(contentRect.top, 0.0);
  // 偏移以画面底边为基准：正数上移进画面，负数下沉进下方黑边。
  final anchor = contentBottom - bottomPadding;
  // 字幕高度是按缩放后字体测量的，先归一到与画面矩形一致的坐标系。
  final normalizedSubtitleHeight = subtitleHeight / scale;
  // 正向最多把字幕顶边抬到画面顶部；负向以字幕底边不出视口为限。
  var maxPixels =
      contentBottom - contentTop - bottomPadding - normalizedSubtitleHeight;
  final minPixels = anchor - viewport.height;
  if (maxPixels < minPixels) maxPixels = minPixels;
  return SubtitleVerticalOffsetBounds(
    min: minPixels / scale,
    max: maxPixels / scale,
  );
}

TextStyle subtitleTextStyle(
  SubtitleSettings settings,
  SubtitleAdjustments adjustments, {
  double baseFontSize = 32,
  bool landscape = false,
}) {
  final outlineWidth = settings.outlineWidth.clamp(0.0, 6.0).toDouble();
  final shadowSize = settings.shadowSize.clamp(0.0, 12.0).toDouble();
  final shadows = <Shadow>[];

  if (outlineWidth > 0) {
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      shadows.add(
        Shadow(
          color: settings.outlineColor,
          offset: Offset(
            math.cos(angle) * outlineWidth,
            math.sin(angle) * outlineWidth,
          ),
          blurRadius: 0,
        ),
      );
    }
  }
  if (shadowSize > 0) {
    shadows.add(
      Shadow(
        color: settings.shadowColor,
        offset: Offset(shadowSize / 2, shadowSize / 2),
        blurRadius: shadowSize,
      ),
    );
  }

  return TextStyle(
    fontFamily:
        settings.fontFamily == 'System' || settings.fontFamily.trim().isEmpty
        ? null
        : settings.fontFamily,
    fontSize: baseFontSize * adjustments.sizeScaleFor(
      landscape,
    ).clamp(subtitleSizeScaleMin, subtitleSizeScaleMax).toDouble(),
    fontWeight: settings.bold ? FontWeight.w700 : FontWeight.normal,
    fontStyle: settings.italic ? FontStyle.italic : FontStyle.normal,
    color: settings.fontColor,
    backgroundColor: settings.backgroundColor,
    height: 1.25,
    shadows: shadows,
  );
}

List<String> sanitizeSubtitleLines(
  List<String> lines, {
  required playback_models.SubtitleTrack? track,
  required SubtitleSettings settings,
}) {
  final codec = track?.codec.trim().toLowerCase() ?? '';
  final isAss = codec.contains('ass') || codec.contains('ssa');
  final isSrt = codec.contains('srt') || codec.contains('subrip');
  return [
    for (final line in lines)
      _sanitizeSubtitleLine(
        line,
        ignoreAssStyle: settings.ignoreAssStyle && isAss,
        ignoreSrtStyle: settings.ignoreSrtStyle && isSrt,
      ),
  ];
}

String _sanitizeSubtitleLine(
  String line, {
  required bool ignoreAssStyle,
  required bool ignoreSrtStyle,
}) {
  var value = line;
  if (ignoreAssStyle) {
    value = value
        .replaceAll(RegExp(r'\{[^}]*\}'), '')
        .replaceAll(r'\N', '\n')
        .replaceAll(r'\n', '\n');
  }
  if (ignoreSrtStyle) {
    value = value.replaceAll(RegExp(r'<[^>]*>'), '');
  }
  return value;
}

/// 自定义字幕层，只消费统一会话字幕状态，不感知具体播放器内核。
class PlayerSubtitleOverlay extends StatefulWidget {
  const PlayerSubtitleOverlay({
    super.key,
    required this.controller,
    required this.selectedTrack,
    required this.settings,
    required this.adjustments,
    this.onVerticalOffsetBoundsChanged,
  });

  final PlayerSessionController controller;
  final playback_models.SubtitleTrack? selectedTrack;
  final SubtitleSettings settings;
  final SubtitleAdjustments adjustments;
  final ValueChanged<SubtitleVerticalOffsetBounds>?
  onVerticalOffsetBoundsChanged;

  @override
  State<PlayerSubtitleOverlay> createState() => _PlayerSubtitleOverlayState();
}

class _PlayerSubtitleOverlayState extends State<PlayerSubtitleOverlay> {
  final List<Timer> _delayTimers = <Timer>[];
  List<String> _rawSubtitle = const [];
  List<String> _displayedSubtitle = const [];
  SubtitleVerticalOffsetBounds? _lastReportedOffsetBounds;
  Size _videoSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _rawSubtitle = widget.controller.value.subtitleText;
    _videoSize = widget.controller.value.videoSize;
    _subscribe();
    _syncNativeSubtitleDelay();
    _scheduleDisplay();
  }

  @override
  void didUpdateWidget(covariant PlayerSubtitleOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _cancelSubscription();
      _cancelDelayTimers();
      _rawSubtitle = widget.controller.value.subtitleText;
      _videoSize = widget.controller.value.videoSize;
      _displayedSubtitle = const [];
      _subscribe();
      _syncNativeSubtitleDelay();
      _scheduleDisplay();
      return;
    }
    if (oldWidget.selectedTrack != widget.selectedTrack) {
      _cancelDelayTimers();
      _displayedSubtitle = const [];
      _scheduleDisplay();
    } else if (oldWidget.adjustments.delayMs != widget.adjustments.delayMs) {
      _cancelDelayTimers();
      _syncNativeSubtitleDelay();
      _scheduleDisplay();
    }
  }

  void _subscribe() {
    widget.controller.addListener(_onPlaybackStateChanged);
  }

  void _onPlaybackStateChanged() {
    final value = widget.controller.value;
    final videoSize = value.videoSize;
    final sizeChanged = videoSize != _videoSize;
    if (sizeChanged) _videoSize = videoSize;
    final subtitle = value.subtitleText;
    if (listEquals(subtitle, _rawSubtitle)) {
      // 视频尺寸变化会改变画面矩形，即使字幕未变也要重算边界与位置。
      if (sizeChanged) setState(() {});
      return;
    }
    _rawSubtitle = List<String>.from(subtitle);
    _scheduleDisplay(_rawSubtitle);
  }

  void _scheduleDisplay([List<String>? subtitle]) {
    final nextSubtitle = List<String>.from(subtitle ?? _rawSubtitle);
    final delayMs = widget.adjustments.delayMs;
    if (delayMs <= 0) {
      _applySubtitle(nextSubtitle);
      return;
    }
    late final Timer timer;
    timer = Timer(Duration(milliseconds: delayMs), () {
      _delayTimers.remove(timer);
      _applySubtitle(nextSubtitle);
    });
    _delayTimers.add(timer);
  }

  void _syncNativeSubtitleDelay() {
    final delayMs = widget.adjustments.delayMs < 0
        ? widget.adjustments.delayMs
        : 0;
    unawaited(
      widget.controller
          .setSubtitleDelay(Duration(milliseconds: delayMs))
          .catchError((_) {}),
    );
  }

  void _applySubtitle(List<String> subtitle) {
    if (!mounted) return;
    setState(() => _displayedSubtitle = subtitle);
  }

  void _cancelDelayTimers() {
    for (final timer in _delayTimers) {
      timer.cancel();
    }
    _delayTimers.clear();
  }

  @override
  void dispose() {
    _cancelDelayTimers();
    _cancelSubscription();
    super.dispose();
  }

  void _cancelSubscription() {
    widget.controller.removeListener(_onPlaybackStateChanged);
  }

  void _reportOffsetBounds(SubtitleVerticalOffsetBounds bounds) {
    final callback = widget.onVerticalOffsetBoundsChanged;
    if (callback == null || _lastReportedOffsetBounds == bounds) return;
    _lastReportedOffsetBounds = bounds;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.onVerticalOffsetBoundsChanged == callback) {
        callback(bounds);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.selectedTrack == null || _displayedSubtitle.isEmpty) {
      return const SizedBox.shrink();
    }
    final lines = sanitizeSubtitleLines(
      _displayedSubtitle,
      track: widget.selectedTrack,
      settings: widget.settings,
    ).where((line) => line.trim().isNotEmpty).toList();
    if (lines.isEmpty) return const SizedBox.shrink();

    return IgnorePointer(
      child: ClipRect(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewport = Size(
              constraints.maxWidth,
              constraints.maxHeight,
            );
            // 偏移与缩放按视口方向分组，横竖屏各自的调校互不覆盖。
            final landscape = viewport.width > viewport.height;
            final area = viewport.width * viewport.height;
            const referenceArea = 1920 * 1080;
            final viewportScale = math.sqrt(
              (area / referenceArea).clamp(0.12, 1.0).toDouble(),
            );
            final style = subtitleTextStyle(
              widget.settings,
              widget.adjustments,
              baseFontSize: 32 * viewportScale,
              landscape: landscape,
            );
            final text = lines.join('\n');
            final textPainter = TextPainter(
              text: TextSpan(text: text, style: style),
              textAlign: TextAlign.center,
              textDirection: TextDirection.ltr,
            )..layout(maxWidth: math.max(1.0, constraints.maxWidth - 32));
            final contentRect = containedVideoRect(
              viewport: viewport,
              video: _videoSize,
            );
            final bounds = subtitleVerticalOffsetBoundsFor(
              viewport: viewport,
              contentRect: contentRect,
              subtitleHeight: textPainter.height,
              viewportScale: viewportScale,
            );
            _reportOffsetBounds(bounds);
            final verticalOffset =
                bounds.clamp(
                  widget.adjustments.verticalOffsetFor(landscape),
                ) *
                viewportScale;
            // 字幕锚定视频画面底边而非屏幕底边，横竖屏切换时
            // 相同偏移值始终相对画面定位。
            final anchorBottom =
                math.min(contentRect.bottom, viewport.height) -
                subtitleBottomPadding;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 16,
                  right: 16,
                  // 正偏移向上抬升，等价于增大距视口底部的距离。
                  bottom:
                      math.max(0.0, viewport.height - anchorBottom) +
                      verticalOffset,
                  child: Opacity(
                    opacity: widget.adjustments.opacity
                        .clamp(subtitleOpacityMin, subtitleOpacityMax)
                        .toDouble(),
                    child: Text(
                      text,
                      textAlign: TextAlign.center,
                      style: style,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
