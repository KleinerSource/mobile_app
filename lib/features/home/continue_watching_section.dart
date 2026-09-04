import 'package:flutter/material.dart';

import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/features/privacy/privacy_mask.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/poster.dart';

/// 继续观看条目的中性视图模型。
///
/// 由各媒体源（OMM/Emby/Jellyfin）把自有 DTO 映射成本结构，共享区块
/// 只负责渲染，不感知任何后端模型。
class ContinueWatchingEntry {
  const ContinueWatchingEntry({
    required this.privacyId,
    required this.title,
    required this.meta,
    this.coverUrl,
    this.progress = 0,
    this.minutesLeft,
    required this.onOpen,
    required this.onResume,
    this.imageHeaders,
    this.onLongPress,
  });

  /// 隐私遮罩键（条目 ID）。
  final Object privacyId;
  final String title;
  final String meta;
  final String? coverUrl;

  /// 观看进度 0..1。
  final double progress;
  final int? minutesLeft;
  final VoidCallback onOpen;
  final VoidCallback onResume;
  final Map<String, String>? imageHeaders;
  final VoidCallback? onLongPress;
}

/// 继续观看区块 · OMM 首页同款设计：
/// 16:10 宽幅横滑卡，fanart 底图 + 底部渐变遮罩 + 播放按钮/剩余分钟
/// + 进度条，下方两行标题与元信息。
class ContinueWatchingSection extends StatelessWidget {
  const ContinueWatchingSection({
    super.key,
    required this.entries,
    this.title,
    this.showTitle = true,
    this.topPadding = 26,
  });

  final List<ContinueWatchingEntry> entries;

  /// 区块标题；缺省沿用 OMM 的「继续观看」文案。接下来观看等
  /// 同款宽幅卡片区块传入自己的标题复用本布局。
  final String? title;
  final bool showTitle;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    final cardWidth =
        (MediaQuery.sizeOf(context).width * 0.7)
            .clamp(260.0, 520.0)
            .toDouble() *
        0.72;
    final coverHeight = cardWidth / (16 / 10);
    const titleAreaHeight = 60.0;

    return Padding(
      // 顶部间距与全出血 hero 衔接
      padding: EdgeInsets.only(top: topPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showTitle) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Text(
                title ?? AppL10n.of(context).homePickupTitle,
                style: AppText.sectionTitle(context),
              ),
            ),
            const SizedBox(height: 14),
          ],
          SizedBox(
            height: coverHeight + 8 + titleAreaHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, index) => SizedBox(
                width: cardWidth,
                child: _ContinueWatchingCard(
                  key: ValueKey(entries[index].privacyId),
                  entry: entries[index],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinueWatchingCard extends StatelessWidget {
  const _ContinueWatchingCard({super.key, required this.entry});

  final ContinueWatchingEntry entry;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final progress = entry.progress.clamp(0.0, 1.0);
    final minutesLeft = entry.minutesLeft;

    return PrivacyAwareInkWell(
      movieId: entry.privacyId,
      borderRadius: 22,
      onTap: () => entry.onOpen(),
      onLongPress: entry.onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PrivacyMask(
                    movieId: entry.privacyId,
                    radius: 0,
                    child: Poster(
                      url: entry.coverUrl,
                      title: entry.title,
                      aspectRatio: 16 / 10,
                      radius: 0,
                      imageAlignment: Alignment.centerRight,
                      httpHeaders: entry.imageHeaders,
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.7),
                          ],
                          stops: const [0.4, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 22,
                    right: 22,
                    bottom: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Semantics(
                                button: true,
                                label: AppL10n.of(context).homeResume,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => entry.onResume(),
                                  child: const Padding(
                                    padding: EdgeInsets.all(2),
                                    child: Icon(
                                      Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ),
                              if (minutesLeft != null && minutesLeft > 0) ...[
                                const SizedBox(width: 6),
                                Text(
                                  AppL10n.of(
                                    context,
                                  ).homeMinutesLeft(minutesLeft),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        // 接下来观看等未开播条目没有进度，空进度槽不展示。
                        if (progress > 0) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(100),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 4,
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.18,
                                ),
                                valueColor: AlwaysStoppedAnimation(c.accent),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          PrivacyText(
            movieId: entry.privacyId,
            text: entry.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: c.text,
              fontFamily: 'Inter',
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              entry.meta,
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
}
