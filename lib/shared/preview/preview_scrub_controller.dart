import 'dart:async';
import 'dart:ui';

typedef PreviewScrubEnsurePreview = Future<void> Function();
typedef PreviewScrubPause = Future<void> Function();
typedef PreviewScrubPlay = Future<void> Function();
typedef PreviewScrubSeek = Future<void> Function(Offset localPosition);

/// 横版预览视频的统一横向拖动状态机。
///
/// 卡片负责提供预览播放器的加载、暂停、续播和 seek 实现；这里统一处理
/// 拖动期间的状态、播放器加载期间的位置缓存，以及手势结束后的续播。
class PreviewScrubController {
  PreviewScrubController({
    required PreviewScrubEnsurePreview ensurePreview,
    required bool Function() isReady,
    required PreviewScrubPause pause,
    required PreviewScrubPlay play,
    required PreviewScrubSeek seek,
  }) : _ensurePreview = ensurePreview,
       _isReady = isReady,
       _pause = pause,
       _play = play,
       _seek = seek;

  final PreviewScrubEnsurePreview _ensurePreview;
  final bool Function() _isReady;
  final PreviewScrubPause _pause;
  final PreviewScrubPlay _play;
  final PreviewScrubSeek _seek;

  bool _active = false;
  bool _preparing = false;
  Offset? _pendingPosition;
  int _generation = 0;

  void start(Offset localPosition) {
    _active = true;
    _preparing = true;
    _pendingPosition = localPosition;
    final generation = ++_generation;
    unawaited(_prepare(generation));
  }

  void update(Offset localPosition) {
    if (!_active) return;
    _pendingPosition = localPosition;
    if (!_preparing && _isReady()) unawaited(_seek(localPosition));
  }

  void end() {
    if (!_active) return;
    _active = false;
    if (!_preparing && _isReady()) {
      _pendingPosition = null;
      unawaited(_play());
    }
  }

  void cancel() => end();

  /// 中止正在等待的加载或 seek，不触发续播。
  void reset() {
    _active = false;
    _preparing = false;
    _pendingPosition = null;
    ++_generation;
  }

  void dispose() => reset();

  Future<void> _prepare(int generation) async {
    try {
      await _ensurePreview();
      if (generation != _generation) return;

      await _pause();
      if (generation != _generation) return;

      final position = _pendingPosition;
      if (position != null) await _seek(position);
      if (generation != _generation) return;

      if (!_active) {
        _pendingPosition = null;
        await _play();
      }
    } finally {
      if (generation == _generation) _preparing = false;
    }
  }
}
