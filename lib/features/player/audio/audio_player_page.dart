import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sources/files/file_playback_progress.dart';
import '../../../core/config/server_config_provider.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../common/playback_engine.dart';
import '../common/player_overlay_indicators.dart';
import '../common/player_queue.dart';
import '../common/player_session_controller.dart';
import '../common/player_settings.dart';
import 'audio_metadata.dart';
import 'audio_now_playing_view.dart';
import 'audio_playback_engine.dart';
import 'audio_player_controls.dart';
import 'audio_playback_service.dart';
import 'lrc_parser.dart';

/// 全屏音频播放页。后台播放由 [AudioPlaybackService] 持有，页面只负责
/// 前台展示、队列控制和音频增强信息。
class AudioPlayerPage extends ConsumerStatefulWidget {
  const AudioPlayerPage.direct({
    super.key,
    required this.title,
    required this.directUrl,
    this.directHeaders,
    this.directFormatHint,
    this.directPlaybackFileName,
    this.startPositionSec = 0,
    this.queue = const <PlayerQueueItem>[],
    this.queueIndex = 0,
    this.audioMetadataLoader,
    this.onQueueDispose,
  });

  final String title;
  final String directUrl;
  final Map<String, String>? directHeaders;
  final String? directFormatHint;
  final String? directPlaybackFileName;
  final int startPositionSec;
  final List<PlayerQueueItem> queue;
  final int queueIndex;
  final AudioTrackMetadataLoader? audioMetadataLoader;
  final Future<void> Function()? onQueueDispose;

  static Future<void> openDirect(
    BuildContext context, {
    required String title,
    required String directUrl,
    Map<String, String>? directHeaders,
    String? directFormatHint,
    String? directPlaybackFileName,
    int startPositionSec = 0,
    List<PlayerQueueItem> queue = const <PlayerQueueItem>[],
    int queueIndex = 0,
    AudioTrackMetadataLoader? audioMetadataLoader,
    Future<void> Function()? onQueueDispose,
    bool useRootNavigator = false,
  }) {
    return Navigator.of(context, rootNavigator: useRootNavigator).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, __, ___) => AudioPlayerPage.direct(
          title: title,
          directUrl: directUrl,
          directHeaders: directHeaders,
          directFormatHint: directFormatHint,
          directPlaybackFileName: directPlaybackFileName,
          startPositionSec: startPositionSec,
          queue: queue,
          queueIndex: queueIndex,
          audioMetadataLoader: audioMetadataLoader,
          onQueueDispose: onQueueDispose,
        ),
        transitionsBuilder: (context, animation, _, child) {
          if (MediaQuery.maybeOf(context)?.disableAnimations == true) {
            return child;
          }
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.035),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  ConsumerState<AudioPlayerPage> createState() => _AudioPlayerPageState();
}

class _AudioPlayerPageState extends ConsumerState<AudioPlayerPage> {
  late final AudioPlaybackEngine _engine;
  late final PlayerSessionController _host;
  late final FilePlaybackProgressRepository _filePlaybackProgress;
  late final List<PlayerQueueItem> _audioQueue;
  AudioMetadataCoordinator? _metadataCoordinator;

  bool _loading = true;
  String? _error;
  bool _leaving = false;
  Future<void>? _stopFuture;
  int? _metadataIndex;
  String? _artworkPath;
  LrcDocument? _lyrics;
  double _playbackRate = 1.0;
  int _lastPositionSec = 0;
  int _lastDurationSec = 0;

  @override
  void initState() {
    super.initState();
    _audioQueue = widget.queue
        .where((item) => item.type == PlayerQueueItemType.audio)
        .toList(growable: false);
    _engine = AudioPlaybackEngine(handler: AudioPlaybackService.handler);
    _host = PlayerSessionController(engine: _engine);
    _filePlaybackProgress = FilePlaybackProgressRepository(
      ref.read(sharedPrefsProvider),
    );
    final loader = widget.audioMetadataLoader;
    if (loader != null) {
      _metadataCoordinator = AudioMetadataCoordinator(loader: loader);
    }
    _host.addListener(_onPlaybackStateChanged);
    unawaited(_load());
  }

  List<PlayerQueueItem> get _queue {
    if (_audioQueue.isNotEmpty) return _audioQueue;
    return [
      PlayerQueueItem(
        title: widget.title,
        type: PlayerQueueItemType.audio,
        mediaId: widget.directUrl,
        directUrl: widget.directUrl,
        directHeaders: widget.directHeaders,
        directFormatHint: widget.directFormatHint,
        directPlaybackFileName: widget.directPlaybackFileName ?? widget.title,
      ),
    ];
  }

  Future<void> _load() async {
    try {
      var startAt = widget.startPositionSec > 0
          ? Duration(seconds: widget.startPositionSec)
          : null;
      final fileName = widget.directPlaybackFileName?.trim();
      if (startAt == null && fileName != null && fileName.isNotEmpty) {
        final settings = ref.read(playerSettingsProvider);
        if (settings.resumeFromLastPosition) {
          final saved = _filePlaybackProgress.load(fileName);
          if (saved != null && saved.positionSec > 0) {
            startAt = Duration(seconds: saved.positionSec);
          }
        }
      }
      await _host.open(
        widget.directUrl,
        startAt: startAt,
        headers: widget.directHeaders,
        formatHint: widget.directFormatHint,
        play: true,
        queue: _queue,
        queueIndex: widget.queueIndex.clamp(0, _queue.length - 1),
        onQueueDispose: widget.onQueueDispose,
      );
      if (!mounted || _leaving) return;
      setState(() => _loading = false);
      _onPlaybackStateChanged();
    } catch (error) {
      if (!mounted || _leaving) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  void _onPlaybackStateChanged() {
    if (_leaving) return;
    final index = (_host.value.queueIndex ?? widget.queueIndex).clamp(
      0,
      _queue.length - 1,
    );
    if (_metadataIndex == index) return;
    _metadataIndex = index;
    final coordinator = _metadataCoordinator;
    if (coordinator == null) return;
    if (mounted) {
      setState(() {
        _artworkPath = null;
        _lyrics = null;
      });
    }
    unawaited(
      coordinator.load(
        _queue[index],
        onLoaded: (metadata) => unawaited(_applyMetadata(metadata)),
      ),
    );
  }

  Future<void> _applyMetadata(AudioTrackMetadata metadata) async {
    if (_leaving || !mounted) return;
    setState(() {
      _artworkPath = metadata.artworkPath;
      _lyrics = metadata.lyrics;
    });
    try {
      await _engine.updateCurrentMetadata(metadata);
    } catch (_) {}
  }

  void _togglePlay() => unawaited(_host.playOrPause());

  void _seekBy(int seconds) {
    var target = _host.position + Duration(seconds: seconds);
    if (target < Duration.zero) target = Duration.zero;
    if (_host.duration > Duration.zero && target > _host.duration) {
      target = _host.duration;
    }
    unawaited(_host.seek(target));
  }

  void _onRateChanged(double rate) {
    _playbackRate = rate;
    unawaited(_host.setRate(rate));
  }

  void _toggleShuffle() {
    unawaited(_host.setShuffleMode(!_host.value.shuffleEnabled));
  }

  void _toggleRepeat() {
    final next = switch (_host.value.repeatMode) {
      PlaybackRepeatMode.off => PlaybackRepeatMode.one,
      PlaybackRepeatMode.one => PlaybackRepeatMode.all,
      PlaybackRepeatMode.all => PlaybackRepeatMode.off,
    };
    unawaited(_host.setRepeatMode(next));
  }

  Future<void> _saveProgress({Duration? position, Duration? duration}) async {
    final fileName = widget.directPlaybackFileName?.trim();
    if (fileName == null || fileName.isEmpty) return;
    if (!ref.read(playerSettingsProvider).resumeFromLastPosition) return;
    final positionSec = (position ?? _host.position).inSeconds;
    final durationSec = (duration ?? _host.duration).inSeconds;
    _lastPositionSec = positionSec > 0 ? positionSec : _lastPositionSec;
    _lastDurationSec = durationSec > 0 ? durationSec : _lastDurationSec;
    await _filePlaybackProgress.savePosition(
      fileName: fileName,
      positionSec: _lastPositionSec,
      durationSec: _lastDurationSec,
    );
  }

  Future<void> _stopPlayback() {
    return _stopFuture ??= _host.stop().catchError((_) {});
  }

  Future<void> _disposePlayback() async {
    await _stopPlayback();
    await _host.dispose();
  }

  Future<void> _exitPlayer() async {
    if (_leaving) return;
    _leaving = true;
    final position = _host.position;
    final duration = _host.duration;
    await _stopPlayback();
    await _saveProgress(position: position, duration: duration);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _leaving = true;
    _host.removeListener(_onPlaybackStateChanged);
    unawaited(_metadataCoordinator?.dispose());
    // 页面被系统返回或外部路由移除时，也必须停止独立于页面生命周期的后台音频。
    unawaited(_disposePlayback());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_exitPlayer());
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: SafeArea(
          child: ValueListenableBuilder<PlaybackViewState>(
            valueListenable: _host,
            builder: (_, state, __) => _body(state),
          ),
        ),
      ),
    );
  }

  Widget _body(PlaybackViewState state) {
    final settings = ref.watch(playerSettingsProvider);
    final l10n = AppL10n.of(context);
    if (_error != null) {
      return _AudioErrorView(
        message: _error!,
        onRetry: () {
          setState(() {
            _error = null;
            _loading = true;
          });
          unawaited(_load());
        },
        onExit: () => unawaited(_exitPlayer()),
      );
    }
    return Stack(
      children: [
        Positioned.fill(child: _host.buildSurface()),
        Positioned.fill(
          child: AudioNowPlayingView(
            controller: _host,
            artworkPath: _artworkPath ?? state.artworkPath,
            lyrics: _lyrics,
          ),
        ),
        const Positioned.fill(child: PlayerOverlayIndicators(indicator: null)),
        Positioned.fill(
          child: AudioPlayerControls(
            controller: _host,
            hapticProgressBar: settings.hapticProgressBar,
            showPlayPauseButton: settings.showPlayPauseButton,
            isLoading: _loading,
            showSeekButtons: true,
            showSpeedButton: true,
            showMediaSwitchButton: true,
            showShuffleButton: true,
            shuffleEnabled: state.shuffleEnabled,
            shuffleOnTooltip: l10n.playerShuffleOn,
            shuffleOffTooltip: l10n.playerShuffleOff,
            onShuffleToggle: _toggleShuffle,
            showRepeatButton: true,
            repeatMode: state.repeatMode,
            repeatOffTooltip: l10n.playerRepeatOff,
            repeatOneTooltip: l10n.playerRepeatOne,
            repeatAllTooltip: l10n.playerRepeatAll,
            onRepeatToggle: _toggleRepeat,
            playbackRate: _playbackRate,
            onPreviousMedia: () => unawaited(_host.skipToPrevious()),
            onNextMedia: () => unawaited(_host.skipToNext()),
            onTogglePlay: _togglePlay,
            onSeekBackward: () => _seekBy(-10),
            onSeekForward: () => _seekBy(10),
            onRateChanged: _onRateChanged,
            onSeek: _host.seek,
            onInteraction: () {},
            onExit: () => unawaited(_exitPlayer()),
          ),
        ),
      ],
    );
  }
}

class _AudioErrorView extends StatelessWidget {
  const _AudioErrorView({
    required this.message,
    required this.onRetry,
    required this.onExit,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 42),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              children: [
                FilledButton(onPressed: onRetry, child: const Text('重试')),
                OutlinedButton(onPressed: onExit, child: const Text('退出')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
