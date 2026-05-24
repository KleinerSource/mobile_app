import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/movie.dart';
import '../core/platform/app_theme.dart';
import '../features/privacy/privacy_mask.dart';
import '../features/privacy/privacy_providers.dart';
import 'poster.dart';

/// md_center 标准影片卡片 · 海报 + 评分角标 + 进度条 + 标题元数据
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
              // 角标在遮罩之上仍可见 (评分/已看), 隐私模式下隐藏避免泄露信号
              if (!masked && !selectionMode && !restricted && hasRating)
                Positioned(
                  top: 6,
                  right: 6,
                  child: RatingBadge(rating: movie.rating!),
                ),
              if (!masked && restricted)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
              if (!masked && !restricted && completed)
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
              if (!masked && !restricted && !completed && progress > 0)
                Positioned(
                  left: 4,
                  right: 4,
                  bottom: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      minHeight: 3,
                      backgroundColor: Colors.black.withValues(alpha: 0.3),
                      valueColor: AlwaysStoppedAnimation(c.accent),
                    ),
                  ),
                ),
              // 底部 badge 行: 字幕 / 分辨率
              if (!masked && !restricted)
                Positioned(
                  left: 6,
                  right: 6,
                  bottom: (!completed && progress > 0) ? 12 : 6,
                  child: _PosterBadgeRow(movie: movie),
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
            style: TextStyle(
              color: restricted ? c.muted : c.text,
              fontFamily: 'Inter',
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              fontStyle: restricted ? FontStyle.italic : FontStyle.normal,
              height: 1.2,
            ),
          ),
          if (!restricted && (movie.year != null || movie.runtime != null))
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                _meta(movie),
                style: TextStyle(
                  color: c.muted,
                  fontFamily: 'Inter',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
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

/// 海报底部 badge 行 · 字幕(外挂橙/内嵌黄) + 分辨率
class _PosterBadgeRow extends StatelessWidget {
  const _PosterBadgeRow({required this.movie});
  final MovieListItem movie;

  @override
  Widget build(BuildContext context) {
    final tier = movie.resolutionTier;
    final hasExt = movie.hasExternalSubtitle;
    final hasInt = movie.hasInternalSubtitle;
    final showTier = tier != ResolutionTier.none && tier != ResolutionTier.sd;
    if (!hasExt && !hasInt && !showTier) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 外挂字幕 - 橙色
        if (hasExt)
          const _SubtitleBadge(
            color: Color(0xFFFF9F1C),
            tooltip: '外挂字幕',
          ),
        if (hasExt && (hasInt || showTier)) const SizedBox(width: 4),
        // 内嵌字幕 - 黄色
        if (hasInt)
          const _SubtitleBadge(
            color: Color(0xFFFFD60A),
            tooltip: '内嵌字幕',
          ),
        if (hasInt && showTier) const SizedBox(width: 4),
        // 分辨率
        if (showTier) _ResolutionBadge(tier: tier),
      ],
    );
  }
}

class _SubtitleBadge extends StatelessWidget {
  const _SubtitleBadge({required this.color, required this.tooltip});
  final Color color;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.7), width: 0.8),
        ),
        child: Icon(
          Icons.closed_caption_rounded,
          color: color,
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
      ResolutionTier.uhd => ('4K', const Color(0xFF4A9EFF)),
      ResolutionTier.fhd => ('FHD', const Color(0xFF00F3FF)),
      ResolutionTier.hd => ('HD', const Color(0xFF34F5A5)),
      _ => ('', Colors.white),
    };
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.7), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w800,
          fontSize: 9,
          letterSpacing: 0.4,
          height: 1,
        ),
      ),
    );
  }
}
