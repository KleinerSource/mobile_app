import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'player_overlay_indicators.dart' show formatDuration;

/// 播放器控制层 · 顶栏标题 + 底栏 (播放/暂停 · 进度条 · 时间 · 清晰度)
///
/// 时间 / 进度 / 播放图标用 StreamBuilder 局部订阅, 避免整页每秒重建。
/// 隐藏时由父级用 IgnorePointer 让手势穿透到手势层。
class PlayerControls extends StatefulWidget {
  const PlayerControls({
    super.key,
    required this.player,
    required this.title,
    required this.saveData,
    required this.onTogglePlay,
    required this.onSeek,
    required this.onToggleSaveData,
    required this.onInteraction,
  });

  final Player player;
  final String title;

  /// 当前是否省流量 (HLS) 档
  final bool saveData;

  final VoidCallback onTogglePlay;
  final void Function(Duration) onSeek;
  final VoidCallback onToggleSaveData;

  /// 任意控制交互 · 父级据此重置自动隐藏定时器
  final VoidCallback onInteraction;

  @override
  State<PlayerControls> createState() => _PlayerControlsState();
}

class _PlayerControlsState extends State<PlayerControls> {
  /// 拖动进度条时的本地预览值 (null = 未拖动)
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black54, Colors.transparent, Colors.black54],
          stops: [0, 0.4, 1],
        ),
      ),
      child: Column(
        children: [
          _topBar(),
          const Spacer(),
          _bottomBar(),
        ],
      ),
    );
  }

  Widget _topBar() {
    // 顶栏左侧留出常驻返回键的空间 (父级 Stack 顶层放返回键)
    return Padding(
      padding: const EdgeInsets.fromLTRB(52, 10, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: [
          _playPauseButton(),
          const SizedBox(width: 8),
          _positionText(),
          const SizedBox(width: 8),
          Expanded(child: _progressSlider()),
          const SizedBox(width: 8),
          _durationText(),
          const SizedBox(width: 4),
          _saveDataButton(),
        ],
      ),
    );
  }

  Widget _playPauseButton() {
    return StreamBuilder<bool>(
      stream: widget.player.stream.playing,
      initialData: widget.player.state.playing,
      builder: (context, snap) {
        final playing = snap.data ?? false;
        return IconButton(
          icon: Icon(playing ? Icons.pause : Icons.play_arrow,
              color: Colors.white, size: 30),
          onPressed: () {
            widget.onTogglePlay();
            widget.onInteraction();
          },
        );
      },
    );
  }

  Widget _positionText() {
    return StreamBuilder<Duration>(
      stream: widget.player.stream.position,
      initialData: widget.player.state.position,
      builder: (context, snap) {
        final pos = snap.data ?? Duration.zero;
        return _timeLabel(formatDuration(pos));
      },
    );
  }

  Widget _durationText() {
    return StreamBuilder<Duration>(
      stream: widget.player.stream.duration,
      initialData: widget.player.state.duration,
      builder: (context, snap) {
        final dur = snap.data ?? Duration.zero;
        return _timeLabel(formatDuration(dur));
      },
    );
  }

  Widget _timeLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    );
  }

  Widget _progressSlider() {
    return StreamBuilder<Duration>(
      stream: widget.player.stream.position,
      initialData: widget.player.state.position,
      builder: (context, snap) {
        final dur = widget.player.state.duration.inMilliseconds;
        final pos = (snap.data ?? Duration.zero).inMilliseconds;
        final max = dur > 0 ? dur.toDouble() : 1.0;
        final live = pos.clamp(0, max.toInt()).toDouble();
        final value = _dragValue ?? live;
        return SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white30,
            thumbColor: Colors.white,
            overlayColor: Colors.white24,
          ),
          child: Slider(
            min: 0,
            max: max,
            value: value.clamp(0, max),
            onChanged: dur <= 0
                ? null
                : (v) {
                    setState(() => _dragValue = v);
                    widget.onInteraction();
                  },
            onChangeEnd: dur <= 0
                ? null
                : (v) {
                    widget.onSeek(Duration(milliseconds: v.round()));
                    setState(() => _dragValue = null);
                    widget.onInteraction();
                  },
          ),
        );
      },
    );
  }

  Widget _saveDataButton() {
    return TextButton(
      onPressed: () {
        widget.onToggleSaveData();
        widget.onInteraction();
      },
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        widget.saveData ? '省流量' : '原画',
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}
