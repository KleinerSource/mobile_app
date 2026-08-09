import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../../core/models/playback.dart' as playback_models;
import 'subtitle_settings.dart';

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
    fontFamily: settings.fontFamily == 'System' ||
            settings.fontFamily.trim().isEmpty
        ? null
        : settings.fontFamily,
    fontSize:
        baseFontSize * adjustments.sizeScale.clamp(0.5, 2.0).toDouble(),
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

/// 自定义字幕层，统一接管 media_kit 字幕流的样式、位置和显示延迟。
class PlayerSubtitleOverlay extends StatefulWidget {
  const PlayerSubtitleOverlay({
    super.key,
    required this.player,
    required this.selectedTrack,
    required this.settings,
    required this.adjustments,
  });

  final Player player;
  final playback_models.SubtitleTrack? selectedTrack;
  final SubtitleSettings settings;
  final SubtitleAdjustments adjustments;

  @override
  State<PlayerSubtitleOverlay> createState() => _PlayerSubtitleOverlayState();
}

class _PlayerSubtitleOverlayState extends State<PlayerSubtitleOverlay> {
  StreamSubscription<List<String>>? _subscription;
  final List<Timer> _delayTimers = <Timer>[];
  List<String> _rawSubtitle = const [];
  List<String> _displayedSubtitle = const [];

  @override
  void initState() {
    super.initState();
    _rawSubtitle = widget.player.state.subtitle;
    _subscribe();
    _scheduleDisplay();
  }

  @override
  void didUpdateWidget(covariant PlayerSubtitleOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.player != widget.player) {
      _subscription?.cancel();
      _cancelDelayTimers();
      _rawSubtitle = widget.player.state.subtitle;
      _displayedSubtitle = const [];
      _subscribe();
      _scheduleDisplay();
      return;
    }
    if (oldWidget.selectedTrack != widget.selectedTrack) {
      _cancelDelayTimers();
      _displayedSubtitle = const [];
      _scheduleDisplay();
    } else if (oldWidget.adjustments.delayMs != widget.adjustments.delayMs) {
      _cancelDelayTimers();
      _scheduleDisplay();
    }
  }

  void _subscribe() {
    _subscription = widget.player.stream.subtitle.listen((value) {
      _rawSubtitle = List<String>.from(value);
      _scheduleDisplay(_rawSubtitle);
    });
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
    _subscription?.cancel();
    super.dispose();
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
          final verticalOffset =
              widget.adjustments.verticalOffset * viewportScale;
          return Align(
            alignment: Alignment.bottomCenter,
            child: Transform.translate(
              offset: Offset(0, -verticalOffset),
              child: Opacity(
                opacity:
                    widget.adjustments.opacity.clamp(0.1, 1.0).toDouble(),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Text(
                    lines.join('\n'),
                    textAlign: TextAlign.center,
                    style: style,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
