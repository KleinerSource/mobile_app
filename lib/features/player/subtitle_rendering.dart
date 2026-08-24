import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/models/playback.dart' as playback_models;
import 'player_session_controller.dart';
import 'subtitle_settings.dart';

SubtitleVerticalOffsetBounds subtitleVerticalOffsetBoundsFor({
  required double viewportHeight,
  required double subtitleHeight,
  required double viewportScale,
  double bottomPadding = 24,
}) {
  final scale = viewportScale > 0 ? viewportScale : 1.0;
  final minPixels = -bottomPadding;
  final maxPixels = math.max(
    minPixels,
    viewportHeight - subtitleHeight - bottomPadding,
  );
  return SubtitleVerticalOffsetBounds(
    min: minPixels / scale,
    max: maxPixels / scale,
  );
}

TextStyle subtitleTextStyle(
  SubtitleSettings settings,
  SubtitleAdjustments adjustments, {
  double baseFontSize = 32,
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
    fontSize: baseFontSize * adjustments.sizeScale.clamp(0.5, 2.0).toDouble(),
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

  @override
  void initState() {
    super.initState();
    _rawSubtitle = widget.controller.value.subtitleText;
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
    final value = widget.controller.value.subtitleText;
    if (listEquals(value, _rawSubtitle)) return;
    _rawSubtitle = List<String>.from(value);
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
            final area = constraints.maxWidth * constraints.maxHeight;
            const referenceArea = 1920 * 1080;
            final viewportScale = math.sqrt(
              (area / referenceArea).clamp(0.12, 1.0).toDouble(),
            );
            final style = subtitleTextStyle(
              widget.settings,
              widget.adjustments,
              baseFontSize: 32 * viewportScale,
            );
            final text = lines.join('\n');
            final textPainter = TextPainter(
              text: TextSpan(text: text, style: style),
              textAlign: TextAlign.center,
              textDirection: TextDirection.ltr,
            )..layout(maxWidth: math.max(1.0, constraints.maxWidth - 32));
            final bounds = subtitleVerticalOffsetBoundsFor(
              viewportHeight: constraints.maxHeight,
              subtitleHeight: textPainter.height,
              viewportScale: viewportScale,
            );
            _reportOffsetBounds(bounds);
            final verticalOffset =
                bounds.clamp(widget.adjustments.verticalOffset) * viewportScale;
            return Align(
              alignment: Alignment.bottomCenter,
              child: Transform.translate(
                offset: Offset(0, -verticalOffset),
                child: Opacity(
                  opacity: widget.adjustments.opacity
                      .clamp(0.1, 1.0)
                      .toDouble(),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: Text(
                      text,
                      textAlign: TextAlign.center,
                      style: style,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
