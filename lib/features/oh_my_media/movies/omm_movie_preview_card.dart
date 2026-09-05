import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/api/url_resolver.dart';
import 'package:omm/core/auth/auth_session_provider.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/models/movie.dart';
import 'package:omm/features/media_browser/widgets/stash_scene_card.dart';
import 'package:omm/features/privacy/privacy_mask.dart';
import 'package:omm/features/privacy/privacy_providers.dart';
import 'package:omm/shared/movie_card.dart';

/// OMM 横版影片卡片的自动预览层。
///
/// 播放器和单实例协调逻辑复用 Stash；OMM 这里只启用滚动选中后的自动播放，
/// 只在横版封面上响应横向拖动，不接管长按事件，避免与影片库现有的
/// 长按选择手势冲突。
class OmmMoviePreviewCard extends ConsumerStatefulWidget {
  const OmmMoviePreviewCard({
    super.key,
    required this.movie,
    required this.posterUrlBuilder,
    required this.onTap,
    required this.coordinator,
    this.autoPlayPreview = false,
    this.selecting = false,
    this.selected = false,
    this.playerFactory = _defaultOmmPreviewPlayerFactory,
  });

  final MovieListItem movie;
  final String Function(String uuid) posterUrlBuilder;
  final VoidCallback onTap;
  final StashPreviewCoordinator coordinator;
  final bool autoPlayPreview;
  final bool selecting;
  final bool selected;
  final StashPreviewPlayerFactory playerFactory;

  @override
  ConsumerState<OmmMoviePreviewCard> createState() =>
      _OmmMoviePreviewCardState();
}

StashPreviewPlayer _defaultOmmPreviewPlayerFactory() =>
    MediaKitStashPreviewPlayer();

class _OmmMoviePreviewCardState extends ConsumerState<OmmMoviePreviewCard> {
  late final VoidCallback _releaseForCoordinator = _releasePreview;
  StashPreviewPlayer? _previewPlayer;
  Future<void>? _previewOpening;
  bool _previewLoading = false;
  bool _previewing = false;
  bool _horizontalDragActive = false;
  Offset? _pendingSeekPosition;
  int _gestureGeneration = 0;
  int _previewGeneration = 0;

  void _releasePreview() {
    unawaited(_stopPreview());
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncAutoPlay();
    });
  }

  @override
  void didUpdateWidget(covariant OmmMoviePreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final movieChanged =
        oldWidget.movie.id != widget.movie.id ||
        oldWidget.movie.previewVideoUrl != widget.movie.previewVideoUrl;
    final autoPlayChanged =
        oldWidget.autoPlayPreview != widget.autoPlayPreview ||
        oldWidget.selecting != widget.selecting;
    if (movieChanged || autoPlayChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncAutoPlay();
      });
    }
  }

  @override
  void dispose() {
    widget.coordinator.release(_releaseForCoordinator);
    unawaited(_stopPreview(rebuild: false));
    super.dispose();
  }

  void _syncAutoPlay() {
    if (widget.autoPlayPreview && !widget.selecting) {
      unawaited(_startPreview());
    } else {
      unawaited(_stopPreview());
    }
  }

  bool _revealOrAllow() {
    final shielded = ref.read(privacyShieldProvider);
    final revealed = ref.read(revealedMoviesProvider).contains(widget.movie.id);
    if (shielded && !revealed) {
      ref.read(revealedMoviesProvider.notifier).reveal(widget.movie.id);
      return false;
    }
    return true;
  }

  void _onTap() {
    if (_revealOrAllow()) widget.onTap();
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    if (widget.selecting || !_revealOrAllow()) return;
    _horizontalDragActive = true;
    _pendingSeekPosition = details.localPosition;
    final gestureGeneration = ++_gestureGeneration;
    unawaited(
      _startPreview(autoplay: false, manual: true).then((_) async {
        if (!mounted || gestureGeneration != _gestureGeneration) return;
        final player = _previewPlayer;
        if (player == null) return;
        await _pausePreview();
        final position = _pendingSeekPosition;
        if (position != null) await _seekPreview(position);
        if (!_horizontalDragActive) {
          _pendingSeekPosition = null;
          await _playPreview();
        }
      }),
    );
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!_horizontalDragActive) return;
    _pendingSeekPosition = details.localPosition;
    if (!_previewing || _previewLoading) return;
    unawaited(_seekPreview(details.localPosition));
  }

  Future<void> _seekPreview(Offset localPosition) async {
    final player = _previewPlayer;
    if (player == null) return;
    final target = previewSeekPositionForLocalOffset(
      localPosition: localPosition,
      width: _lastCoverWidth,
      duration: player.duration.value,
    );
    if (target == null) return;
    try {
      await player.seek(target);
    } catch (_) {}
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    _finishHorizontalDrag();
  }

  void _onHorizontalDragCancel() {
    _finishHorizontalDrag();
  }

  void _finishHorizontalDrag() {
    if (!_horizontalDragActive) return;
    _horizontalDragActive = false;
    if (!_previewLoading && _previewOpening == null) {
      _pendingSeekPosition = null;
      unawaited(_playPreview());
    }
  }

  Future<void> _startPreview({
    bool autoplay = true,
    bool manual = false,
  }) async {
    if (_previewPlayer != null) {
      final opening = _previewOpening;
      if (opening != null) {
        try {
          await opening;
        } catch (_) {}
      }
      return;
    }
    if ((!widget.autoPlayPreview && !manual) || widget.selecting) return;
    final rawUrl = widget.movie.previewVideoUrl?.trim() ?? '';
    if (rawUrl.isEmpty) return;

    final config = ref.read(serverConfigProvider);
    if (config?.isOmm != true) return;

    widget.coordinator.claim(_releaseForCoordinator);
    final generation = ++_previewGeneration;
    final player = widget.playerFactory();
    _previewPlayer = player;
    if (mounted) {
      setState(() {
        _previewing = true;
        _previewLoading = true;
      });
    }

    Future<void>? openFuture;
    try {
      final token = await ref.read(authSessionRepositoryProvider).accessToken();
      final url = resolveProtectedUrl(config!, rawUrl, token);
      openFuture = player.open(url, autoplay: autoplay);
      _previewOpening = openFuture;
      await openFuture;
      if (!mounted ||
          generation != _previewGeneration ||
          player != _previewPlayer) {
        await player.dispose();
        return;
      }
      setState(() => _previewLoading = false);
    } catch (_) {
      if (generation == _previewGeneration && player == _previewPlayer) {
        await _stopPreview();
      } else {
        await player.dispose();
      }
    } finally {
      if (identical(_previewOpening, openFuture)) _previewOpening = null;
    }
  }

  Future<void> _pausePreview() async {
    final player = _previewPlayer;
    if (player == null) return;
    try {
      await player.pause();
    } catch (_) {}
  }

  Future<void> _playPreview() async {
    final player = _previewPlayer;
    if (player == null) return;
    try {
      await player.play();
    } catch (_) {}
  }

  Future<void> _stopPreview({bool rebuild = true}) async {
    _horizontalDragActive = false;
    _pendingSeekPosition = null;
    ++_gestureGeneration;
    ++_previewGeneration;
    final player = _previewPlayer;
    _previewPlayer = null;
    widget.coordinator.release(_releaseForCoordinator);
    if (rebuild && mounted) {
      setState(() {
        _previewing = false;
        _previewLoading = false;
      });
    }
    if (player == null) return;
    try {
      await player.stop();
    } catch (_) {}
    try {
      await player.dispose();
    } catch (_) {}
  }

  double _lastCoverWidth = 1;

  Widget _buildCard() {
    final player = _previewPlayer;
    final card = AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: widget.selecting && !widget.selected ? 0.55 : 1.0,
      child: MovieCard(
        movie: widget.movie,
        posterUrlBuilder: widget.posterUrlBuilder,
        landscape: true,
        selectionMode: widget.selecting,
        selected: widget.selected,
        onTap: widget.onTap,
      ),
    );
    final ready = _previewing && !_previewLoading;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width - 44;
        _lastCoverWidth = width;
        final coverHeight = width * 9 / 16;
        final allowPreviewGesture = !widget.selecting;
        return Stack(
          children: [
            card,
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: coverHeight,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _onTap,
                  onHorizontalDragStart: allowPreviewGesture
                      ? _onHorizontalDragStart
                      : null,
                  onHorizontalDragUpdate: allowPreviewGesture
                      ? _onHorizontalDragUpdate
                      : null,
                  onHorizontalDragEnd: allowPreviewGesture
                      ? _onHorizontalDragEnd
                      : null,
                  onHorizontalDragCancel: allowPreviewGesture
                      ? _onHorizontalDragCancel
                      : null,
                  child: PrivacyMask(
                    movieId: widget.movie.id,
                    radius: 0,
                    child: IgnorePointer(
                      child: ready && player != null
                          ? player.buildVideo()
                          : const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
            if (_previewLoading)
              const Positioned(
                top: 14,
                right: 14,
                child: IgnorePointer(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => _buildCard();
}
