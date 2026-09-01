import 'package:flutter/material.dart';

import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/features/privacy/privacy_mask.dart';
import 'package:omm/shared/collection_card_layout.dart';
import 'package:omm/shared/poster.dart';

/// 媒体库入口卡片的Neutral视图模型（Emby/Jellyfin 首页共用）。
class HomeLibraryCardEntry {
  const HomeLibraryCardEntry({
    required this.id,
    required this.name,
    this.coverUrl,
    required this.onTap,
  });

  final Object id;
  final String name;

  /// 库封面；为空或加载失败时回退品牌渐变。
  final String? coverUrl;
  final VoidCallback onTap;
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
                child: Text('媒体库', style: AppText.sectionTitle(context)),
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

class _HomeLibraryCard extends StatelessWidget {
  const _HomeLibraryCard({required this.entry, required this.hue});

  final HomeLibraryCardEntry entry;
  final int hue;

  @override
  Widget build(BuildContext context) {
    // 与 OMM 首页 _LibraryCard 同款隐私遮罩:点击先揭开,不直接进库
    return PrivacyAwareInkWell(
      movieId: entry.id,
      scope: PrivacyScope.library,
      onTap: entry.onTap,
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
                  layoutBuilder: (currentChild, previousChildren) => Stack(
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
            ],
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
