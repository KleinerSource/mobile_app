import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'playback_engine.dart';

/// 播放器 Debug OSD。只读取统一播放状态，不参与控制栏和手势处理。
class PlayerDebugOverlay extends StatelessWidget {
  const PlayerDebugOverlay({super.key, required this.stateListenable});

  final ValueListenable<PlaybackViewState> stateListenable;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PlaybackViewState>(
      valueListenable: stateListenable,
      builder: (_, state, __) => DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Wrap(
            spacing: 10,
            runSpacing: 2,
            children: _items(state)
                .map(
                  (item) => Text(
                    item,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      height: 1.2,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ),
    );
  }

  List<String> _items(PlaybackViewState state) {
    final info = state.mediaInfo;
    final resolution = state.videoSize.width > 0 && state.videoSize.height > 0
        ? '${state.videoSize.width.round()}×${state.videoSize.height.round()}'
        : '--';
    final fps = info?.videoFps == null
        ? '--'
        : '${_trimNumber(info!.videoFps!)} fps';
    final decoder = _value(info?.videoDecoder);
    final internal = info?.internalPlayer;

    return [
      '内核 ${state.engineKind.label}',
      if (internal != null && internal.trim().isNotEmpty) '内部 $internal',
      '容器 ${_value(info?.container)}',
      '视频 ${_value(info?.videoCodec)}',
      '视频码率 ${formatPlaybackBitrate(info?.videoBitrate)}',
      '帧率 $fps',
      '分辨率 $resolution',
      if (decoder != '--') '解码器 $decoder',
      if (_value(info?.audioCodec) != '--') '音频 ${_value(info?.audioCodec)}',
      if (info?.audioBitrate != null)
        '音频码率 ${formatPlaybackBitrate(info?.audioBitrate)}',
    ];
  }

  String _value(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? '--' : normalized;
  }

  String _trimNumber(double value) {
    final text = value.toStringAsFixed(2);
    return text.replaceFirst(RegExp(r'\.?0+$'), '');
  }
}

String formatPlaybackBitrate(int? bitrate) {
  if (bitrate == null || bitrate <= 0) return '--';
  if (bitrate >= 1000000) {
    return '${(bitrate / 1000000).toStringAsFixed(2)} Mbps';
  }
  return '${(bitrate / 1000).toStringAsFixed(0)} kbps';
}
