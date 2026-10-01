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
  });

  final DbOnlineMovie movie;
  final ServerConfig? config;
  final double width;
  final VoidCallback? onTap;
  final bool codeOnly;
  final bool landscape;
  final bool compact;

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

    if (compact) {
      return CatalogListMovieCard(
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
          subscription: subscriptionBadge,
          play: playBadge,
        ),
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
        rating: normalizeMediaRating(movie.score),
        canPlay: movie.canPlay,
        showOnlinePlayBadge: true,
        hasSubtitle: movie.hasCnsub,
        privacyId: privacyId,
        coverTopLeftOverlay: subscriptionBadge,
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
  final l = AppL10n.of(context);
  final status = subscription!.overdue
      ? 'overdue'
      : switch (subscription.status) {
          'completed' => 'completed',
          'skipped' => 'skipped',
          _ => 'pending',
        };
  final (label, color, icon) = switch (status) {
    'overdue' => (
      l.dbOnlineSubscriptionOverdue,
      const Color(0xFFF97316),
      Icons.schedule_rounded,
    ),
    'completed' => (
      l.dbOnlineSubscriptionCompleted,
      const Color(0xFF22C55E),
      Icons.check_circle_rounded,
    ),
    'skipped' => (
      l.dbOnlineSubscriptionSkipped,
      const Color(0xFFEF4444),
      Icons.skip_next_rounded,
    ),
    _ => (
      l.dbOnlineSubscriptionPendingBadge,
      const Color(0xFFEAB308),
      Icons.notifications_active_outlined,
    ),
  };
  if (status == 'completed') {
    return Semantics(
      container: true,
      label: label,
      child: Container(
        width: 11,
        height: 11,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
      ),
    );
  }
  return DbOnlineSubscriptionStatusBadge(
    label: label,
    color: color,
    icon: icon,
  );
}

Widget? _compactBadges({required Widget? subscription, required Widget? play}) {
  final badges = [
    if (subscription != null) subscription,
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
