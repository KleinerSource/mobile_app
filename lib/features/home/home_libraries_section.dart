import 'package:flutter/material.dart';

import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/features/privacy/privacy_mask.dart';
import 'package:omm/features/media_browser/widgets/media_browser_library_refresh_indicator.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/collection_card_layout.dart';
import 'package:omm/shared/poster.dart';

/// 媒体库入口卡片的Neutral视图模型（Emby/Jellyfin 首页共用）。
class HomeLibraryCardEntry {
  const HomeLibraryCardEntry({
    required this.id,
    required this.name,
    this.coverUrl,
    required this.onTap,
    this.imageHeaders,
    this.category,
    this.onRefresh,
    this.isRefreshing = false,
    this.refreshProgress,
  });

  final Object id;
  final String name;

  /// 库封面；为空或加载失败时回退品牌渐变。
  final String? coverUrl;
  final Map<String, String>? imageHeaders;
  final VoidCallback onTap;
  final String? category;
  final VoidCallback? onRefresh;
  final bool isRefreshing;
  final double? refreshProgress;
}

/// 首页「媒体库」区块 · OMM 媒体库卡片同款设计：
/// 5:3 横滑卡片，封面淡入，回退品牌渐变 + 圆斑装饰，左下库名白字。
class HomeLibrariesSection extends StatelessWidget {
  const HomeLibrariesSection({super.key, required this.entries});

  final List<HomeLibraryCardEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 28),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 卡片尺寸沿用两侧 22 留白的可用宽度，列表本身全宽可滚到屏幕边缘
          final cardWidth = collectionCardWidth(constraints.maxWidth - 44);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Text(
                  AppL10n.of(context).homeLibraries,
                  style: AppText.sectionTitle(context),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: cardWidth / (5 / 3),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, index) {
                    final entry = entries[index];
                    return SizedBox(
                      key: ValueKey(entry.id),
                      width: cardWidth,
                      child: _HomeLibraryCard(
                        entry: entry,
                        hue: AppHues.all[index % AppHues.all.length],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HomeLibraryCard extends StatefulWidget {
  const _HomeLibraryCard({required this.entry, required this.hue});

  final HomeLibraryCardEntry entry;
  final int hue;

  @override
  State<_HomeLibraryCard> createState() => _HomeLibraryCardState();
}

class _HomeLibraryCardState extends State<_HomeLibraryCard> {
  final _overlayController = OverlayPortalController();
  final _layerLink = LayerLink();
  final _tapRegionGroup = Object();
  var _showActions = false;

  void _showActionMenu() {
    if (widget.entry.onRefresh == null) return;
    setState(() => _showActions = true);
    _overlayController.show();
  }

  void _dismissActions() {
    if (!_showActions) return;
    setState(() => _showActions = false);
    _overlayController.hide();
  }

  void _refresh() {
    final callback = widget.entry.onRefresh;
    if (callback == null || widget.entry.isRefreshing) return;
    _dismissActions();
    callback();
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final hue = widget.hue;
    // 与 OMM 首页 _LibraryCard 同款隐私遮罩:点击先揭开,不直接进库
    return OverlayPortal(
      controller: _overlayController,
      overlayChildBuilder: _buildActionOverlay,
      child: TapRegion(
        groupId: _tapRegionGroup,
        onTapOutside: _showActions ? (_) => _dismissActions() : null,
        child: CompositedTransformTarget(
          link: _layerLink,
          child: PrivacyAwareInkWell(
            movieId: entry.id,
            scope: PrivacyScope.library,
            onTap: entry.onTap,
            onLongPress: _showActionMenu,
            borderRadius: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 5 / 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 背景: 封面就绪后淡入替换品牌渐变
                    PrivacyMask(
                      movieId: entry.id,
                      scope: PrivacyScope.library,
                      radius: 0,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        layoutBuilder: (currentChild, previousChildren) =>
                            Stack(
                              fit: StackFit.expand,
                              alignment: Alignment.center,
                              children: [
                                ...previousChildren,
                                if (currentChild != null) currentChild,
                              ],
                            ),
                        child: entry.coverUrl != null
                            ? KeyedSubtree(
                                key: ValueKey('cover-${entry.id}'),
                                child: Poster(
                                  url: entry.coverUrl,
                                  title: entry.name,
                                  radius: 0,
                                  httpHeaders: entry.imageHeaders,
                                ),
                              )
                            : KeyedSubtree(
                                key: ValueKey('hue-$hue'),
                                child: _HueGradient(hue: hue),
                              ),
                      ),
                    ),
                    // 封面上的压暗渐变,保证白色文字可读
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black54,
                            Colors.black87,
                          ],
                          stops: [0.35, 0.7, 1.0],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: PrivacyText(
                          movieId: entry.id,
                          scope: PrivacyScope.library,
                          text: entry.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ),
                    if (entry.isRefreshing)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: MediaBrowserLibraryRefreshIndicator(
                          ratio: entry.refreshProgress,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionOverlay(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        targetAnchor: Alignment.topLeft,
        followerAnchor: Alignment.bottomLeft,
        offset: const Offset(0, -8),
        child: TapRegion(
          groupId: _tapRegionGroup,
          child: _HomeLibraryActionList(
            enabled: !widget.entry.isRefreshing,
            onRefresh: _refresh,
          ),
        ),
      ),
    );
  }
}

class _HomeLibraryActionList extends StatelessWidget {
  const _HomeLibraryActionList({
    required this.enabled,
    required this.onRefresh,
  });

  static const width = 196.0;
  static const height = 51.0;

  final bool enabled;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final labelColor = enabled ? colors.text : colors.muted;
    final background = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1B1A24)
        : Colors.white;
    return Material(
      color: background,
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: 0.34),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: colors.cardBorder.withValues(alpha: 0.45),
          width: 0.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: width,
        height: height,
        child: InkWell(
          onTap: enabled ? onRefresh : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Icon(Icons.refresh_rounded, color: labelColor, size: 18),
                const SizedBox(width: 10),
                Text(
                  AppL10n.of(context).mediaBrowserRefresh,
                  style: TextStyle(
                    color: labelColor,
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HueGradient extends StatelessWidget {
  const _HueGradient({required this.hue});

  final int hue;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppHues.top(hue), AppHues.bottom(hue)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -30,
            right: -30,
            width: 100,
            height: 100,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppHues.highlight(hue),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
