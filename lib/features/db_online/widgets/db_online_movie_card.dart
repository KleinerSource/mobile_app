import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/api/url_resolver.dart';
import 'package:omm/core/config/server_config.dart';
import 'package:omm/core/sources/media/media_metadata_normalizer.dart';
import 'package:omm/core/sources/media/dbo/db_online_movie.dart';
import 'package:omm/features/db_online/repositories/dbo_subscription_repository.dart';
import 'package:omm/features/db_online/widgets/db_online_subscription_status_badge.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/movie_card.dart';
import 'package:omm/shared/media_metadata_widgets.dart';
import 'package:omm/shared/poster.dart';
import 'package:omm/features/privacy/privacy_providers.dart';
import 'package:omm/features/db_online/providers/db_online_subscription_providers.dart';
import 'package:omm/features/db_online/widgets/db_online_ranking_preview_card.dart';

/// dbonline 字段适配器。
///
/// 卡片本身由共享 [CatalogMovieCard] 渲染，这里只负责解析 dbonline 的
/// 字符串番号、图片地址和元数据，避免再维护一套独立 UI。
class DbOnlineMovieCard extends ConsumerWidget {
  const DbOnlineMovieCard({
    super.key,
    required this.movie,
    required this.config,
    this.width = 112,
    this.onTap,
    this.codeOnly = false,
    this.landscape = false,
    this.compact = false,
    this.previewList = false,
    this.listTitleMaxLines = 1,
    this.showRating = true,
  });

  final DbOnlineMovie movie;
  final ServerConfig? config;
  final double width;
  final VoidCallback? onTap;
  final bool codeOnly;
  final bool landscape;
  final bool compact;

  /// 榜单列表模式的预览条目：左封面 + 右预览图翻页，优先级高于 [compact]；
  /// 数据未携带 preview_images 时自动降级为 [compact] 紧凑条目。
  final bool previewList;
  final int listTitleMaxLines;
  final bool showRating;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final imageValue = landscape
        ? movie.coverUrl ?? movie.thumbUrl
        : movie.thumbUrl ?? movie.coverUrl;
    final imageUrl = imageValue == null || config == null
        ? null
        : resolveServerUrl(config!, imageValue);
    final privacyId = movie.id.trim().isEmpty
        ? movie.number.trim()
        : movie.id.trim();
    final privacyEnabled = ref.watch(privacyShieldProvider);
    final revealed = ref.watch(revealedMoviesProvider).contains(privacyId);
    final serverId = config?.activeServerId?.trim() ?? '';
    DbOnlineSubscriptionStatus? subscriptionStatus;
    if (serverId.isNotEmpty && movie.number.trim().isNotEmpty) {
      final capabilities = ref.watch(
        dbOnlineSubscriptionCapabilitiesProvider(serverId),
      );
      if (capabilities.asData?.value.database == true) {
        final code = movie.number.trim();
        subscriptionStatus = ref.watch(
          dbOnlineMovieSubscriptionStatusesProvider(
            serverId,
          ).select((statuses) => statuses[code.toUpperCase()]),
        );
        if (subscriptionStatus == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            ref
                .read(
                  dbOnlineMovieSubscriptionStatusesProvider(serverId).notifier,
                )
                .check(code);
          });
        }
      }
    }
    final subscriptionBadge = _subscriptionStatusBadge(
      context,
      subscriptionStatus,
    );
    final magnetBadge = _magnetBadge(l, movie.magnetsCount);
    final playBadge = movie.canPlay
        ? const OnlinePlayBadge(iconOnly: true)
        : null;
    void handleTap() {
      if (privacyEnabled && !revealed) {
        ref.read(revealedMoviesProvider.notifier).reveal(privacyId);
        return;
      }
      onTap?.call();
    }

    // 无 preview_images 时右侧只会重复一张大封面，降级为调用方传入的
    // [compact] 紧凑条目，避免预览区占位浪费空间。
    final previewUrls = previewList
        ? _previewUrls(movie, config)
        : const <String>[];

    if (previewUrls.isNotEmpty) {
      final rating = showRating ? normalizeMediaRating(movie.score) : null;
      // 已完成的绿点放在名称前，其余订阅状态角标留在预览图左下角。
      final subscriptionCompleted = _isSubscriptionCompleted(subscriptionStatus);
      return DbOnlineRankingPreviewCard(
        title: movie.title.trim().isEmpty
            ? l.movieCardUntitledTitle
            : movie.title,
        code: movie.number,
        coverUrl: imageUrl,
        previewUrls: previewUrls,
        fallbackPreviewUrl: _fallbackPreviewUrl(movie, config),
        meta: _metaText(context, movie),
        badges: [
          if (!subscriptionCompleted && subscriptionBadge != null)
            subscriptionBadge,
          if (magnetBadge != null) magnetBadge,
          if (playBadge != null) playBadge,
          if (rating != null) RatingBadge(rating: rating),
        ],
        titleLeading: subscriptionCompleted
            ? _subscriptionCompletedDot(l)
            : null,
        privacyId: privacyId,
        onTap: handleTap,
      );
    }

    if (compact) {
      // 已完成的绿点放在标题前，其余订阅状态角标仍留在标题下方。
      final subscriptionCompleted = _isSubscriptionCompleted(subscriptionStatus);
      return CatalogListMovieCard(
        titleMaxLines: listTitleMaxLines,
        title: movie.title.trim().isEmpty
            ? l.movieCardUntitledTitle
            : movie.title,
        code: movie.number,
        imageUrl: imageUrl,
        imageHeaders: null,
        meta: _metaText(context, movie),
        width: width,
        privacyId: privacyId,
        additional: _compactBadges(
          subscription: subscriptionCompleted ? null : subscriptionBadge,
          magnet: magnetBadge,
          play: playBadge,
        ),
        titleLeading: subscriptionCompleted
            ? _subscriptionCompletedDot(l)
            : null,
        onTap: handleTap,
      );
    }

    // dbonline 没有 OMM 影片库的多选链路，因此卡片长按不应出现按压反馈。
    // 保留共享卡片的展示层，把点击交给外层 GestureDetector，避免
    // CatalogMovieCard 内部 InkWell 在长按时产生额外的 Material 特效。
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: handleTap,
      child: CatalogMovieCard(
        title: movie.title.trim().isEmpty
            ? l.movieCardUntitledTitle
            : movie.title,
        code: movie.number,
        imageUrl: imageUrl,
        meta: _metaText(context, movie),
        width: width,
        rating: showRating ? normalizeMediaRating(movie.score) : null,
        canPlay: movie.canPlay,
        showOnlinePlayBadge: true,
        hasSubtitle: movie.hasCnsub,
        privacyId: privacyId,
        coverTopLeftOverlay: subscriptionBadge,
        coverBottomLeftBadge: magnetBadge,
        showTitle: !codeOnly,
        showMeta: !codeOnly,
        landscape: landscape,
      ),
    );
  }
}

Widget? _subscriptionStatusBadge(
  BuildContext context,
  DbOnlineSubscriptionStatus? subscription,
) {
  if (subscription?.subscribed != true) return null;
  final style = dbOnlineSubscriptionStatusStyle(
    AppL10n.of(context),
    subscribed: true,
    status: subscription!.status,
    overdue: subscription.overdue,
  );
  if (subscription.status == 'completed' && !subscription.overdue) {
    return _subscriptionCompletedDot(AppL10n.of(context));
  }
  return DbOnlineSubscriptionStatusBadge(
    label: style.label,
    color: style.color!,
    icon: style.icon,
  );
}

/// 订阅已完成（未逾期）时只显示绿点，不占用文字角标。
bool _isSubscriptionCompleted(DbOnlineSubscriptionStatus? subscription) =>
    subscription?.subscribed == true &&
    !subscription!.overdue &&
    subscription.status == 'completed';

/// 订阅已完成的绿点指示器；封面角标与预览条目名称行前共用。
Widget _subscriptionCompletedDot(AppL10n l) => Semantics(
  container: true,
  label: l.dbOnlineSubscriptionCompleted,
  child: Container(
    width: 11,
    height: 11,
    decoration: BoxDecoration(
      color: const Color(0xFF22C55E),
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 1.5),
    ),
  ),
);

Widget? _magnetBadge(AppL10n l, int count) {
  if (count <= 0) return null;
  final label = l.resourceMagnetCount(count);
  return Semantics(
    container: true,
    label: label,
    child: Tooltip(
      message: label,
      child: Container(
        constraints: const BoxConstraints(minHeight: 18),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF12B8C2),
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.link_rounded, color: Colors.white, size: 11),
            const SizedBox(width: 2),
            Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Inter',
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget? _compactBadges({
  required Widget? subscription,
  required Widget? magnet,
  required Widget? play,
}) {
  final badges = [
    if (subscription != null) subscription,
    if (magnet != null) magnet,
    if (play != null) play,
  ];
  if (badges.isEmpty) return null;
  return Wrap(spacing: 5, runSpacing: 4, children: badges);
}

String _metaText(BuildContext context, DbOnlineMovie movie) {
  final l = AppL10n.of(context);
  return formatMediaCardMeta(
    l,
    year: normalizeMediaYear(movie.releaseDate),
    duration: dboDurationToMinutes(movie.duration),
    emptyText: l.dbOnlineNoMeta,
  );
}

/// 榜单预览条目右侧的大图地址，大图优先、小图兜底。
List<String> _previewUrls(DbOnlineMovie movie, ServerConfig? config) {
  if (config == null) return const <String>[];
  final urls = <String>[];
  for (final preview in movie.previewImages) {
    final url = preview.largeUrl ?? preview.thumbUrl;
    if (url != null) urls.add(resolveServerUrl(config, url));
  }
  return urls;
}

/// 无预览图时右侧展示的大封面。
String? _fallbackPreviewUrl(DbOnlineMovie movie, ServerConfig? config) {
  final url = movie.coverUrl ?? movie.thumbUrl;
  if (url == null || config == null) return null;
  return resolveServerUrl(config, url);
}
