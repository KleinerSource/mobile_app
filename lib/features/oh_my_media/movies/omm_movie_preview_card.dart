import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/api/url_resolver.dart';
import 'package:omm/core/auth/auth_session_provider.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/models/movie.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/features/privacy/privacy_mask.dart';
import 'package:omm/features/privacy/privacy_providers.dart';
import 'package:omm/shared/movie_card.dart';
import 'package:omm/shared/preview/preview_player.dart';
import 'package:omm/shared/preview/preview_scrub_controller.dart';
import 'package:omm/shared/preview/preview_seek.dart';
import 'package:omm/shared/preview/preview_surface.dart';

/// OMM 横版影片卡片的自动预览层。
///
/// 播放器和单实例协调逻辑复用公共预览模块；OMM 这里只启用滚动选中后的自动播放，
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
  final PreviewCoordinator coordinator;
  final bool autoPlayPreview;
  final bool selecting;
  final bool selected;
  final PreviewPlayerFactory playerFactory;

  @override
  ConsumerState<OmmMoviePreviewCard> createState() =>
      _OmmMoviePreviewCardState();
}

PreviewPlayer _defaultOmmPreviewPlayerFactory() => MediaKitPreviewPlayer();

class _OmmMoviePreviewCardState extends ConsumerState<OmmMoviePreviewCard> {
  late final VoidCallback _releaseForCoordinator = _releasePreview;
  PreviewPlayer? _previewPlayer;
  Future<void>? _previewOpening;
  bool _previewLoading = false;
  bool _previewing = false;
  int _previewGeneration = 0;
  late final PreviewScrubController _scrubController = PreviewScrubController(
    ensurePreview: () => _startPreview(autoplay: false, manual: true),
    isReady: _isPreviewReady,
    pause: _pausePreview,
    play: _playPreview,
    seek: _seekPreview,
  );

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
    _scrubController.dispose();
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
    _scrubController.start(details.localPosition);
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    _scrubController.update(details.localPosition);
  }

  bool _isPreviewReady() =>
      _previewPlayer != null &&
      _previewing &&
      !_previewLoading &&
      _previewOpening == null;

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
    _scrubController.end();
  }

  void _onHorizontalDragCancel() {
    _scrubController.cancel();
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
    _scrubController.reset();
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
    final watchRecord = widget.movie.watchRecord;
    final watchProgress = watchRecord?.progressRatio ?? 0;
    final isMasked =
        ref.watch(privacyShieldProvider) &&
        !ref.watch(revealedMoviesProvider).contains(widget.movie.id);
    final showWatchProgress =
        !isMasked && watchRecord?.completed != true && watchProgress > 0;
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
                child: PreviewGestureSurface(
                  onTap: _onTap,
                  enabled: allowPreviewGesture,
                  loading: _previewLoading,
                  showHint: ready,
                  bottomOverlay: showWatchProgress
                      ? _OmmWatchProgressBar(
                          value: watchProgress,
                          color: appColors(context).accent,
                        )
                      : null,
                  onHorizontalDragStart: _onHorizontalDragStart,
                  onHorizontalDragUpdate: _onHorizontalDragUpdate,
                  onHorizontalDragEnd: _onHorizontalDragEnd,
                  onHorizontalDragCancel: _onHorizontalDragCancel,
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
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => _buildCard();
}

class _OmmWatchProgressBar extends StatelessWidget {
  const _OmmWatchProgressBar({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 3,
    child: LinearProgressIndicator(
      value: value.clamp(0.0, 1.0),
      backgroundColor: Colors.black.withValues(alpha: 0.45),
      valueColor: AlwaysStoppedAnimation(color),
    ),
  );
}
