import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/movie.dart';
import '../core/platform/app_theme.dart';
import '../features/i18n/badge_position_provider.dart';
import '../features/privacy/privacy_mask.dart';
import '../features/privacy/privacy_providers.dart';
import 'poster.dart';
import 'stacked_badges.dart';

/// omm 标准影片卡片 · 海报 + 评分角标 + 进度条 + 标题元数据
///
/// 隐私模式开启时,海报盖 blur 暗罩,标题用方块代替;
/// 单击卡片揭开当张 (而不进 detail),再次点击才进详情。
class MovieCard extends ConsumerWidget {
  const MovieCard({
    super.key,
    required this.movie,
    required this.posterUrlBuilder,
    this.onTap,
    this.onLongPress,
    this.restricted = false,
    this.selectionMode = false,
    this.selected = false,
  });

  final MovieListItem movie;
  final String Function(String uuid) posterUrlBuilder;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool restricted;
  final bool selectionMode;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = movie.watchRecord?.progressRatio ?? 0.0;
    final completed = movie.watchRecord?.completed ?? false;
    final c = appColors(context);
    final hasRating = movie.rating != null && movie.rating! > 0;
    final privacyOn = ref.watch(privacyShieldProvider);
    final revealed = ref.watch(revealedMoviesProvider).contains(movie.id);
    final masked = privacyOn && !revealed;
    final positions = ref.watch(badgePositionsProvider);

    // 按角分组收集 badge widgets
    final byCorner = <BadgeCorner, List<Widget>>{
      for (final corner in BadgeCorner.values) corner: <Widget>[],
    };

    if (!masked && !selectionMode && !restricted) {
      if (hasRating && positions.ratingEnabled) {
        byCorner[positions.rating]!.add(RatingBadge(rating: movie.rating!));
      }
      if (positions.subtitleEnabled) {
        // 四种字幕来源: 外挂(橙) / AI(紫,文件名带 .ai. 标记) / 内嵌轨道(绿) / 文件名标识(黄),
        // 多来源时合并为叠加堆,点按展开
        final subBadges = <Widget>[
          if (movie.hasExternalSubtitle)
            const _SubtitleBadge(color: Color(0xFFFF9F1C), tooltip: '外挂字幕'),
          if (movie.hasAiSubtitle)
            const _SubtitleBadge(color: Color(0xFF8B5CF6), tooltip: 'AI 字幕'),
          if (movie.hasMuxedSubtitle)
            const _SubtitleBadge(color: Color(0xFF16A34A), tooltip: '内嵌字幕轨道'),
          if (movie.hasFilenameSubtitle)
            const _SubtitleBadge(color: Color(0xFFFFD60A), tooltip: '内嵌字幕'),
        ];
        if (subBadges.length > 1) {
          final corner = positions.subtitle;
          byCorner[corner]!.add(
            StackedBadges(
              tooltip: '字幕 ×${subBadges.length}（点按展开）',
              expandUpward:
                  corner == BadgeCorner.bottomLeft ||
                  corner == BadgeCorner.bottomRight,
              children: subBadges,
            ),
          );
        } else {
          byCorner[positions.subtitle]!.addAll(subBadges);
        }
      }
      if (positions.crackEnabled && movie.hasCracked) {
        byCorner[positions.crack]!.add(const _CrackBadge());
      }
      if (positions.resolutionEnabled) {
        final tier = movie.resolutionTier;
        if (tier != ResolutionTier.none) {
          byCorner[positions.resolution]!.add(_ResolutionBadge(tier: tier));
        }
      }
    }
    if (!selectionMode &&
        !restricted &&
        positions.newResourcesEnabled &&
        movie.hasNewResources) {
      byCorner[positions.newResources]!.add(const NewResourcesIcon());
    }

    return PrivacyAwareInkWell(
      movieId: movie.id,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              PrivacyMask(
                movieId: movie.id,
                radius: 10,
                child: Poster(
                  url: movie.posterUuid != null
                      ? posterUrlBuilder(movie.posterUuid!)
                      : null,
                  title: movie.title,
                  year: movie.year,
                  restricted: restricted,
                ),
              ),
              // 选择模式遮罩 + 对勾
              if (selectionMode)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      color: selected
                          ? c.accent.withValues(alpha: 0.35)
                          : Colors.black.withValues(alpha: 0.15),
                    ),
                  ),
                ),
              if (selectionMode)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: selected ? c.accent : Colors.black54,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: selected
                        ? const Icon(Icons.check, color: Colors.white, size: 14)
                        : null,
                  ),
                ),
              // R18 角标 (固定右上)
              if (!masked && restricted)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: c.warning.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'R18',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'monospace',
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
              // 已看完 (固定左上, 与选择模式 / 配置 badge 错开)
              if (!masked && !selectionMode && !restricted && completed)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '已看完',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              // 进度条 (固定贴底部边缘, 不占独立空间, badge 位置不受影响)
              if (!masked && !restricted && !completed && progress > 0)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(10),
                      bottomRight: Radius.circular(10),
                    ),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      minHeight: 3,
                      backgroundColor: Colors.black.withValues(alpha: 0.45),
                      valueColor: AlwaysStoppedAnimation(c.accent),
                    ),
                  ),
                ),
              // 4 个角的 badge 集合
              for (final corner in BadgeCorner.values)
                if (byCorner[corner]!.isNotEmpty)
                  _CornerBadges(
                    corner: corner,
                    completed: completed,
                    // 进度条已贴底, badge 不再让位, 位置保持一致
                    skipTopLeftForSelection: selectionMode,
                    offset: positions.offsetOf(corner),
                    children: byCorner[corner]!,
                  ),
            ],
          ),
          const SizedBox(height: 8),
          // 标题: 隐私模式遮罩 · 固定 2 行高度避免溢出
          PrivacyText(
            movieId: movie.id,
            text: restricted ? 'Restricted' : movie.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.movieCardTitle(context).copyWith(
              color: restricted ? c.muted : c.text,
              fontStyle: restricted ? FontStyle.italic : FontStyle.normal,
            ),
          ),
          if (!restricted && (movie.year != null || movie.runtime != null))
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(_meta(movie), style: AppText.movieCardMeta(context)),
            ),
        ],
      ),
    );
  }

  static String _meta(MovieListItem m) {
    final parts = <String>[];
    if (m.year != null) parts.add('${m.year}');
    if (m.runtime != null && m.runtime! > 0) parts.add('${m.runtime}m');
    return parts.join(' · ');
  }
}

/// 外部数据源影片卡片的共享渲染层。
///
/// dbonline 等数据源的影片标识不一定是 OMM 的整数 ID，因此不强行转换为
/// [MovieListItem]。数据源只负责把字段整理成这里需要的展示值，海报、字号、
/// 角标和点击反馈仍由共享组件统一维护。
///
/// 与 OMM [MovieCard] 的差异通过可选参数表达：[code] 传 null 时省略番号行
/// （Emby/Jellyfin 的标题 + meta 两行布局与 MovieCard 完全一致）；
/// [played] / [progress] 提供 OMM 同款的已看完角标与海报底部进度条。
class CatalogMovieCard extends ConsumerWidget {
  const CatalogMovieCard({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.meta,
    this.code,
    this.width = 112,
    this.rating,
    this.canPlay = false,
    this.hasSubtitle = false,
    this.played = false,
    this.progress = 0,
    this.year,
    this.onTap,
    this.onLongPress,
    this.privacyId,
    this.showTitle = true,
    this.showMeta = true,
    this.posterAspectRatio = 2 / 3,
  });

  final String title;

  /// 番号行（DBO 等有番号的数据源）；null 时不渲染番号行，布局与
  /// [MovieCard] 的「标题 + meta」两行结构一致。
  final String? code;
  final String? imageUrl;
  final String meta;
  final double width;
  final double? rating;
  final bool canPlay;
  final bool hasSubtitle;

  /// 已看完 · 海报左上角标。
  final bool played;

  /// 观看进度 0..1 · 未看完时贴海报底部渲染。
  final double progress;

  /// 海报占位符上的年份（与 OMM 卡片一致）。
  final int? year;
  final VoidCallback? onTap;

  /// 与 [MovieCard] 一致的长按通道。非 null 时 InkWell 注册长按手势，
  /// 长按不再出现水波纹/松手误触；拖选页面不要传（由 DragSelectionTarget
  /// 的长按手势接管，两个长按手势会竞争导致拖选失效）。
  final VoidCallback? onLongPress;
  final bool showTitle;
  final bool showMeta;

  /// 海报宽高比；音乐专辑等方形封面传 1。
  final double posterAspectRatio;

  /// 为非 OMM 影片提供隐私遮罩键；为空时保持普通目录卡片行为。
  final Object? privacyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = appColors(context);
    final positions = ref.watch(badgePositionsProvider);
    final displayTitle = title.trim().isEmpty ? '未命名影片' : title.trim();
    // code 为 null 省略番号行；空串保留 DBO 原有的「未命名番号」回退。
    final displayCode = code == null
        ? null
        : (code!.trim().isEmpty ? '未命名番号' : code!.trim());
    final displayMeta = meta.trim().isEmpty ? '暂无信息' : meta;
    final badgesByCorner = <BadgeCorner, List<Widget>>{
      for (final corner in BadgeCorner.values) corner: <Widget>[],
    };
    if (canPlay) {
      badgesByCorner[BadgeCorner.topLeft]!.add(
        const OnlinePlayBadge(iconOnly: true),
      );
    }
    if (hasSubtitle && positions.subtitleEnabled) {
      badgesByCorner[positions.subtitle]!.add(
        const _SubtitleBadge(color: Color(0xFFFFD60A), tooltip: '中字'),
      );
    }
    if (rating != null && rating! > 0 && positions.ratingEnabled) {
      badgesByCorner[positions.rating]!.add(RatingBadge(rating: rating!));
    }
    final poster = Stack(
      children: [
        Poster(
          url: imageUrl,
          title: displayTitle,
          year: year,
          radius: 10,
          aspectRatio: posterAspectRatio,
        ),
        // 已看完 (固定左上, 与 OMM 卡片一致)
        if (played)
          Positioned(
            top: 6,
            left: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '已看完',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        // 进度条 (固定贴海报底部边缘, 不占独立空间)
        if (!played && progress > 0)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(10),
                bottomRight: Radius.circular(10),
              ),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 3,
                backgroundColor: Colors.black.withValues(alpha: 0.45),
                valueColor: AlwaysStoppedAnimation(colors.accent),
              ),
            ),
          ),
        for (final corner in BadgeCorner.values)
          if (badgesByCorner[corner]!.isNotEmpty)
            _CornerBadges(
              corner: corner,
              completed: played,
              skipTopLeftForSelection: false,
              offset: positions.offsetOf(corner),
              children: badgesByCorner[corner]!,
            ),
      ],
    );
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              privacyId == null
                  ? poster
                  : PrivacyMask(movieId: privacyId!, child: poster),
              const SizedBox(height: 8),
              if (displayCode != null)
                privacyId == null
                    ? Text(
                        displayCode,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.movieCardMeta(
                          context,
                        ).copyWith(color: colors.accent, fontSize: 11.5),
                      )
                    : PrivacyText(
                        movieId: privacyId!,
                        text: displayCode,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.movieCardMeta(
                          context,
                        ).copyWith(color: colors.accent, fontSize: 11.5),
                      ),
              if (showTitle) ...[
                const SizedBox(height: 2),
                privacyId == null
                    ? Text(
                        displayTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.movieCardTitle(context),
                      )
                    : PrivacyText(
                        movieId: privacyId!,
                        text: displayTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.movieCardTitle(context),
                      ),
              ],
              if (showMeta) ...[
                const SizedBox(height: 2),
                privacyId == null
                    ? Text(
                        displayMeta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.movieCardMeta(context),
                      )
                    : PrivacyText(
                        movieId: privacyId!,
                        text: displayMeta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.movieCardMeta(context),
                      ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 多选网格卡片 · 收藏页/影片库共用的选择态外观:
/// 未选中整卡变暗 (0.55, 180ms 过渡), 选中全亮 + 左上角对勾圆标;
/// 角标不隐藏 (不向 [MovieCard] 传 selectionMode)
class SelectableMovieCard extends StatelessWidget {
  const SelectableMovieCard({
    super.key,
    required this.movie,
    required this.posterUrlBuilder,
    required this.selecting,
    required this.selected,
    this.onTap,
  });

  final MovieListItem movie;
  final String Function(String uuid) posterUrlBuilder;
  final bool selecting;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Stack(
      children: [
        AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: selecting && !selected ? 0.55 : 1.0,
          child: MovieCard(
            movie: movie,
            posterUrlBuilder: posterUrlBuilder,
            onTap: onTap,
          ),
        ),
        if (selecting)
          Positioned(
            top: 6,
            left: 6,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? c.accent
                    : Colors.black.withValues(alpha: 0.5),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              alignment: Alignment.center,
              child: selected
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : const SizedBox.shrink(),
            ),
          ),
      ],
    );
  }
}

/// 4 个角的 badge 位置 · 同一 corner 横向堆叠
class _CornerBadges extends StatelessWidget {
  const _CornerBadges({
    required this.corner,
    required this.completed,
    required this.skipTopLeftForSelection,
    required this.offset,
    required this.children,
  });
  final BadgeCorner corner;
  final bool completed;
  final bool skipTopLeftForSelection;
  final BadgeCornerOffset offset;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (skipTopLeftForSelection && corner == BadgeCorner.topLeft) {
      return const SizedBox.shrink();
    }
    final top = corner == BadgeCorner.topLeft || corner == BadgeCorner.topRight;
    final left =
        corner == BadgeCorner.topLeft || corner == BadgeCorner.bottomLeft;

    final baseInset = 6.0;
    final hInset = (baseInset + offset.horizontal).clamp(0, 32).toDouble();
    final vInset = (baseInset + offset.vertical).clamp(0, 32).toDouble();

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          children[i],
        ],
      ],
    );

    final shifted = (corner == BadgeCorner.topLeft && completed)
        ? Padding(padding: const EdgeInsets.only(left: 52), child: row)
        : row;

    return Positioned(
      top: top ? vInset : null,
      bottom: top ? null : vInset,
      left: left ? hInset : null,
      right: !left ? hInset : null,
      child: shifted,
    );
  }
}

/// 评分 · 沿用 poster.dart 的 RatingBadge (黑玻璃 + 黄星)
/// 这里不再单独定义, 直接复用

class _SubtitleBadge extends StatelessWidget {
  const _SubtitleBadge({required this.color, required this.tooltip});
  final Color color;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 18,
        height: 18,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: const Icon(
          Icons.closed_caption_rounded,
          color: Colors.white,
          size: 13,
        ),
      ),
    );
  }
}

class NewResourcesIcon extends StatelessWidget {
  const NewResourcesIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '新资源',
      child: const Icon(
        Icons.auto_awesome_rounded,
        color: Color(0xFFFFD166),
        size: 17,
      ),
    );
  }
}

class _CrackBadge extends StatelessWidget {
  const _CrackBadge();

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFE91E63);
    return Tooltip(
      message: '破解 / 无码',
      child: Container(
        width: 18,
        height: 18,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: const Icon(
          Icons.lock_open_rounded,
          color: Colors.white,
          size: 12,
        ),
      ),
    );
  }
}

class _ResolutionBadge extends StatelessWidget {
  const _ResolutionBadge({required this.tier});
  final ResolutionTier tier;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (tier) {
      ResolutionTier.uhd => ('UHD', const Color(0xFF2D6CDF)),
      ResolutionTier.fhd => ('FHD', const Color(0xFF0EA5E9)),
      ResolutionTier.hd => ('HD', const Color(0xFF10B981)),
      _ => ('', Colors.white),
    };
    if (label.isEmpty) return const SizedBox.shrink();

    return Tooltip(
      message: label,
      child: Container(
        width: 18,
        height: 18,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: const Icon(Icons.tv_rounded, color: Colors.white, size: 13),
      ),
    );
  }
}
