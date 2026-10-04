import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/api/url_resolver.dart';
import 'package:omm/core/config/server_runtime.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/features/db_online/widgets/db_online_subscription_action.dart';

/// 演员等实体的纵向卡片：头像在上（无图时显示类型占位块），订阅按钮
/// 靠右上角，底部为名称与元信息，无码标识悬浮在头像右下角；点击进入
/// 实体影片列表。搜索结果与排行榜共用，排行榜通过 [topLeftBadge]
/// 悬挂名次徽章。
class DbOnlineEntityCard extends ConsumerWidget {
  const DbOnlineEntityCard({
    super.key,
    required this.id,
    required this.name,
    required this.label,
    required this.icon,
    required this.subscriptionKind,
    this.count = 0,
    this.imageUrl,
    this.uncensored = false,
    this.metaText,
    this.subscriptionData = const <String, dynamic>{},
    this.topLeftBadge,
    this.onTap,
  });

  final String id;
  final String name;
  final String label;
  final IconData icon;
  final String? imageUrl;
  final bool uncensored;
  final int count;

  /// 底部元信息行；为空时回退展示 [count] 作品数。
  final String? metaText;
  final String subscriptionKind;
  final Map<String, dynamic> subscriptionData;
  final Widget? topLeftBadge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = appColors(context);
    final l = AppL10n.of(context);
    final config = ref.watch(mediaRuntimeConfigProvider);
    final image = imageUrl != null && config != null
        ? resolveServerUrl(config, imageUrl!)
        : null;
    final nameStyle = AppText.body(context).copyWith(
      fontWeight: FontWeight.w700,
    );
    final metaStyle = AppText.meta(context);
    final fallbackMeta = metaText ?? (count > 0 ? l.libraryCount(count) : null);
    // 底部信息块固定高度：名称恒定两行 + 间距 + 元信息一行（含内边距）。
    // 高度按当前字体缩放计算，保证每张卡片的头像区域高度一致。
    final scaler = MediaQuery.textScalerOf(context);
    final nameLineHeight =
        scaler.scale(nameStyle.fontSize ?? 14) * (nameStyle.height ?? 1.5);
    final metaLineHeight = scaler.scale(metaStyle.fontSize ?? 12) * 1.3;
    final bottomHeight = 18 + nameLineHeight * 2 + 4 + metaLineHeight;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (image != null)
                    Image.network(
                      image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _EntityAvatarFallback(
                        icon: icon,
                        label: label,
                      ),
                    )
                  else
                    _EntityAvatarFallback(icon: icon, label: label),
                  if (topLeftBadge != null)
                    Positioned(left: 6, top: 6, child: topLeftBadge!),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: DbOnlineSubscriptionAction(
                      kind: subscriptionKind,
                      id: id,
                      title: name,
                      initial: subscriptionData,
                    ),
                  ),
                  if (uncensored)
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: colors.bg.withValues(alpha: 0.82),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          l.dbOnlineCategoryUncensored,
                          strutStyle: const StrutStyle(
                            fontSize: 10.5,
                            height: 1.0,
                            forceStrutHeight: true,
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: bottomHeight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: nameStyle,
                    ),
                    const SizedBox(height: 4),
                    if (fallbackMeta != null && fallbackMeta.isNotEmpty)
                      Text(
                        fallbackMeta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: metaStyle,
                      ),
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

/// 无图实体的占位头像：强调色底 + 类型图标与标签（网页端同款）。
class _EntityAvatarFallback extends StatelessWidget {
  const _EntityAvatarFallback({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: 0.10),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 30, color: colors.accent),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.meta(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
