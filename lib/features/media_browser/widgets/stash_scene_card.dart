import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:omm/core/platform/app_haptics.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/features/media_browser/api/media_browser_server_urls.dart';
import 'package:omm/features/media_browser/models/media_browser_models.dart';
import 'package:omm/features/privacy/privacy_mask.dart';
import 'package:omm/features/privacy/privacy_providers.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

/// Stash 预览播放器的最小协议，便于页面测试注入 Fake 实现。
abstract interface class StashPreviewPlayer {
  ValueListenable<Duration> get duration;

  ValueListenable<Duration> get position;

  Widget buildVideo({BoxFit fit = BoxFit.cover});

  Future<void> open(String url, {Map<String, String>? headers});

  Future<void> seek(Duration position);

  Future<void> stop();

  Future<void> dispose();
}

typedef StashPreviewPlayerFactory = StashPreviewPlayer Function();

/// 根据列表滚动位置选择当前应自动预览的最上方 Scene。
///
/// 列表项之间有固定间距；当上一张封面已经完全离开视口时，立即切到下一张，
/// 不必等下一张卡片真正贴到视口顶部。
int? stashPreviewItemIndexForScroll({
  required double scrollOffset,
  required double cardHeight,
  required double itemGap,
  required int itemCount,
  double leadingPadding = 0,
}) {
  if (itemCount <= 0 ||
      !scrollOffset.isFinite ||
      !cardHeight.isFinite ||
      cardHeight <= 0 ||
      !itemGap.isFinite ||
      itemGap < 0) {
    return null;
  }
  final offset = (scrollOffset - leadingPadding).clamp(0.0, double.infinity);
  final itemExtent = cardHeight + itemGap;
  final baseIndex = (offset / itemExtent).floor();
  final withinItem = offset - baseIndex * itemExtent;
  final index = withinItem >= cardHeight ? baseIndex + 1 : baseIndex;
  return index.clamp(0, itemCount - 1);
}

/// 默认使用 media_kit 的 Stash 短视频播放器。
class MediaKitStashPreviewPlayer implements StashPreviewPlayer {
  MediaKitStashPreviewPlayer()
    : _player = Player(
        configuration: const PlayerConfiguration(
          muted: true,
          bufferSize: 8 * 1024 * 1024,
        ),
      ) {
    _controller = VideoController(
      _player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
      ),
    );
    _subscriptions.add(
      _player.stream.duration.listen((value) {
        _duration.value = value;
      }),
    );
    _subscriptions.add(
      _player.stream.position.listen((value) {
        _position.value = value;
      }),
    );
  }

  final Player _player;
  late final VideoController _controller;
  final ValueNotifier<Duration> _duration = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> _position = ValueNotifier(Duration.zero);
  final List<StreamSubscription<Object?>> _subscriptions = [];

  @override
  ValueListenable<Duration> get duration => _duration;

  @override
  ValueListenable<Duration> get position => _position;

  @override
  Widget buildVideo({BoxFit fit = BoxFit.cover}) => Video(
    controller: _controller,
    controls: NoVideoControls,
    fit: fit,
    subtitleViewConfiguration: const SubtitleViewConfiguration(visible: false),
  );

  @override
  Future<void> open(String url, {Map<String, String>? headers}) async {
    await _player
        .open(
          Media(url, httpHeaders: headers?.isEmpty == true ? null : headers),
          play: true,
        )
        .timeout(const Duration(seconds: 3));
    try {
      await _controller.waitUntilFirstFrameRendered.timeout(
        const Duration(seconds: 5),
      );
    } catch (_) {
      // 某些平台不回报首帧，但播放器可能已经可以正常显示。
    }
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await _player.dispose();
    _duration.dispose();
    _position.dispose();
  }
}

/// 页面级预览协调器，保证同一媒体列表同时只有一个预览播放器。
class StashPreviewCoordinator {
  VoidCallback? _activeRelease;

  void claim(VoidCallback release) {
    if (identical(_activeRelease, release)) return;
    _activeRelease?.call();
    _activeRelease = release;
  }

  void release(VoidCallback release) {
    if (identical(_activeRelease, release)) _activeRelease = null;
  }

  void dispose() {
    _activeRelease?.call();
    _activeRelease = null;
  }
}

/// 为媒体库/搜索页提供页面级 Stash 预览协调器。
class StashPreviewScope extends StatefulWidget {
  const StashPreviewScope({super.key, required this.child});

  final Widget child;

  static StashPreviewCoordinator? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_StashPreviewInherited>()
      ?.coordinator;

  @override
  State<StashPreviewScope> createState() => _StashPreviewScopeState();
}

class _StashPreviewScopeState extends State<StashPreviewScope> {
  final _coordinator = StashPreviewCoordinator();

  @override
  void dispose() {
    _coordinator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _StashPreviewInherited(coordinator: _coordinator, child: widget.child);
}

class _StashPreviewInherited extends InheritedWidget {
  const _StashPreviewInherited({
    required this.coordinator,
    required super.child,
  });

  final StashPreviewCoordinator coordinator;

  @override
  bool updateShouldNotify(_StashPreviewInherited oldWidget) =>
      coordinator != oldWidget.coordinator;
}

/// Stash Scene 横向卡片：全宽 16:9 封面，长按后可拖动预览视频时间轴。
class StashSceneCard extends ConsumerStatefulWidget {
  const StashSceneCard({
    super.key,
    required this.item,
    required this.urls,
    required this.width,
    required this.onTap,
    this.coordinator,
    this.playerFactory = _defaultStashPreviewPlayerFactory,
    this.autoPlayPreview = false,
  });

  final MediaBrowserItem item;
  final MediaBrowserServerUrls urls;
  final double width;
  final VoidCallback onTap;
  final StashPreviewCoordinator? coordinator;
  final StashPreviewPlayerFactory playerFactory;

  /// 页面滚动选中该条目时自动播放短预览；手动长按仍可在 false 时启动。
  final bool autoPlayPreview;

  @override
  ConsumerState<StashSceneCard> createState() => _StashSceneCardState();
}

StashPreviewPlayer _defaultStashPreviewPlayerFactory() =>
    MediaKitStashPreviewPlayer();

class _StashSceneCardState extends ConsumerState<StashSceneCard> {
  late final VoidCallback _releaseForCoordinator = _releasePreview;
  StashPreviewCoordinator? _coordinator;
  StashPreviewPlayer? _previewPlayer;
  bool _previewing = false;
  bool _previewLoading = false;
  int _previewGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.autoPlayPreview) unawaited(_startPreview());
    });
  }

  void _releasePreview() {
    unawaited(_stopPreview());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _coordinator ??= widget.coordinator ?? StashPreviewScope.maybeOf(context);
  }

  @override
  void didUpdateWidget(covariant StashSceneCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final itemChanged = oldWidget.item.id != widget.item.id;
    if (itemChanged || oldWidget.playerFactory != widget.playerFactory) {
      unawaited(_stopPreview());
      if (widget.autoPlayPreview) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && widget.autoPlayPreview) unawaited(_startPreview());
        });
      }
      return;
    }
    if (oldWidget.autoPlayPreview != widget.autoPlayPreview) {
      if (widget.autoPlayPreview) {
        unawaited(_startPreview());
      } else {
        unawaited(_stopPreview());
      }
    }
  }

  @override
  void dispose() {
    _coordinator?.release(_releaseForCoordinator);
    unawaited(_stopPreview(rebuild: false));
    super.dispose();
  }

  bool _revealOrAllow() {
    final shielded = ref.read(privacyShieldProvider);
    final revealed = ref.read(revealedMoviesProvider).contains(widget.item.id);
    if (shielded && !revealed) {
      ref.read(revealedMoviesProvider.notifier).reveal(widget.item.id);
      return false;
    }
    return true;
  }

  void _onTap() {
    if (_revealOrAllow()) widget.onTap();
  }

  void _onLongPressStart(LongPressStartDetails details) {
    if (!_revealOrAllow()) return;
    AppHaptics.light();
    unawaited(_startPreview());
  }

  Future<void> _startPreview() async {
    if (_previewing) return;
    final url = widget.urls.preview(widget.item.previewPath);
    if (url == null || url.isEmpty) return;

    _coordinator?.claim(_releaseForCoordinator);
    final generation = ++_previewGeneration;
    final player = widget.playerFactory();
    _previewPlayer = player;
    if (mounted) {
      setState(() {
        _previewing = true;
        _previewLoading = true;
      });
    }
    try {
      await player.open(url, headers: widget.urls.directHeaders);
      if (!mounted ||
          generation != _previewGeneration ||
          player != _previewPlayer) {
        await player.dispose();
        return;
      }
      if (mounted) setState(() => _previewLoading = false);
    } catch (_) {
      if (generation == _previewGeneration && player == _previewPlayer) {
        await _stopPreview();
      } else {
        await player.dispose();
      }
    }
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (!_previewing || _previewLoading) return;
    final offset = details.offsetFromOrigin;
    if (offset.dx.abs() < 10 || offset.dx.abs() <= offset.dy.abs()) return;
    final player = _previewPlayer;
    if (player == null) return;
    final duration = player.duration.value;
    if (duration <= Duration.zero) return;
    final width = widget.width <= 0 ? 1 : widget.width;
    final fraction = (details.localPosition.dx / width).clamp(0.0, 1.0);
    final target = Duration(
      microseconds: (duration.inMicroseconds * fraction).round(),
    );
    unawaited(player.seek(target));
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    unawaited(_stopPreview());
  }

  Future<void> _stopPreview({bool rebuild = true}) async {
    ++_previewGeneration;
    final player = _previewPlayer;
    _previewPlayer = null;
    _coordinator?.release(_releaseForCoordinator);
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

  @override
  Widget build(BuildContext context) {
    final previewPlayer = _previewPlayer;
    final previewReady =
        _previewing && !_previewLoading && previewPlayer != null;
    final imageUrl = widget.urls.heroImage(widget.item);
    final colors = appColors(context);
    final tags = _uniqueNonEmpty(widget.item.genres);
    final performers = widget.item.people
        .where((person) => person.name.trim().isNotEmpty)
        .toList(growable: false);
    return SizedBox(
      width: widget.width,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.cardBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PrivacyMask(
                    movieId: widget.item.id,
                    radius: 0,
                    child: previewReady
                        ? previewPlayer.buildVideo()
                        : _CoverImage(
                            url: imageUrl,
                            headers: widget.urls.imageHeaders,
                          ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _ProgressBar(
                      value: previewReady
                          ? _ratio(
                              previewPlayer.position.value,
                              previewPlayer.duration.value,
                            )
                          : _itemProgress(widget.item),
                      color: colors.accent,
                    ),
                  ),
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _onTap,
                      onLongPressStart: _onLongPressStart,
                      onLongPressMoveUpdate: _onLongPressMoveUpdate,
                      onLongPressEnd: _onLongPressEnd,
                      child: const SizedBox.expand(),
                    ),
                  ),
                  if (_previewLoading)
                    const Positioned(
                      top: 14,
                      right: 14,
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  if (previewReady)
                    const Positioned(
                      top: 12,
                      right: 12,
                      child: Icon(
                        Icons.swipe_rounded,
                        size: 20,
                        color: Colors.white70,
                      ),
                    ),
                ],
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 15, 16, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PrivacyText(
                      movieId: widget.item.id,
                      text: widget.item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.cardTitle(context).copyWith(
                        color: colors.text,
                        fontSize: 17,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 11),
                    _StashInfoWrap(item: widget.item),
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 15),
                    _StashSectionLabel(
                      icon: Icons.local_offer_outlined,
                      label: AppL10n.of(context).movieEditorTag,
                    ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          for (var index = 0; index < tags.length; index++)
                            _StashTextPill(
                              text: tags[index],
                              privacyId: widget.item.id,
                            ),
                        ],
                      ),
                    ],
                    if (performers.isNotEmpty) ...[
                      const SizedBox(height: 15),
                      _StashSectionLabel(
                        icon: Icons.people_alt_outlined,
                        label: AppL10n.of(context).detailCast,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          for (
                            var index = 0;
                            index < performers.length;
                            index++
                          )
                            _StashTextPill(
                              text: performers[index].name.trim(),
                              privacyId: widget.item.id,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

List<String> _uniqueNonEmpty(Iterable<String> values) {
  final result = <String>[];
  final seen = <String>{};
  for (final value in values) {
    final normalized = value.trim();
    if (normalized.isNotEmpty && seen.add(normalized)) result.add(normalized);
  }
  return result;
}

class _StashInfoWrap extends StatelessWidget {
  const _StashInfoWrap({required this.item});

  final MediaBrowserItem item;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final code = item.code?.trim();
    final values = <({IconData icon, String text})>[
      if (code?.isNotEmpty == true)
        (icon: Icons.qr_code_2_rounded, text: '${l.movieEditorNumber} $code'),
      if (item.productionYear != null)
        (icon: Icons.calendar_today_outlined, text: '${item.productionYear}'),
      if (item.runtimeMinutes > 0)
        (
          icon: Icons.schedule_outlined,
          text: l.mediaBrowserMinuteShort(item.runtimeMinutes),
        ),
      if (item.communityRating case final rating? when rating > 0)
        (icon: Icons.star_border_rounded, text: rating.toStringAsFixed(1)),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final value in values)
          _StashInfoPill(icon: value.icon, text: value.text),
      ],
    );
  }
}

class _StashSectionLabel extends StatelessWidget {
  const _StashSectionLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: colors.muted),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppText.meta(
            context,
          ).copyWith(color: colors.muted, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _StashInfoPill extends StatelessWidget {
  const _StashInfoPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colors.muted),
          const SizedBox(width: 5),
          Text(
            text,
            style: AppText.meta(
              context,
            ).copyWith(color: colors.text2, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _StashTextPill extends StatelessWidget {
  const _StashTextPill({required this.text, required this.privacyId});

  final String text;
  final String privacyId;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return Container(
      constraints: const BoxConstraints(maxWidth: 230),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: colors.chipBg,
        border: Border.all(color: colors.cardBorder),
        borderRadius: BorderRadius.circular(9),
      ),
      child: PrivacyText(
        movieId: privacyId,
        text: text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppText.meta(
          context,
        ).copyWith(color: colors.chipTextActive, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.url, required this.headers});

  final String? url;
  final Map<String, String> headers;

  @override
  Widget build(BuildContext context) {
    final value = url?.trim() ?? '';
    if (value.isEmpty) return const _CoverPlaceholder();
    return Image.network(
      value,
      fit: BoxFit.cover,
      headers: headers,
      errorBuilder: (_, __, ___) => const _CoverPlaceholder(),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.black26,
    child: Center(
      child: Icon(
        Icons.movie_outlined,
        size: 42,
        color: Colors.white.withValues(alpha: 0.6),
      ),
    ),
  );
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 3,
    child: LinearProgressIndicator(
      value: value > 0 ? value : 0,
      backgroundColor: Colors.white24,
      color: color,
    ),
  );
}

double _itemProgress(MediaBrowserItem item) {
  final duration = item.runTimeTicks ?? 0;
  if (duration <= 0 || item.userData.resumeSeconds <= 0) return 0;
  final seconds = mediaBrowserTicksToSeconds(duration);
  if (seconds <= 0) return 0;
  return (item.userData.resumeSeconds / seconds).clamp(0.0, 1.0);
}

double _ratio(Duration position, Duration duration) {
  if (duration <= Duration.zero) return 0;
  return (position.inMicroseconds / duration.inMicroseconds).clamp(0.0, 1.0);
}
