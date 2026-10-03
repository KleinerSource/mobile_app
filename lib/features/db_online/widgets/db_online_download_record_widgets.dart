import 'package:flutter/material.dart';

import 'package:omm/core/api/url_resolver.dart';
import 'package:omm/core/config/server_config.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/core/sources/media/dbo/db_online_download_record.dart';
import 'package:omm/features/oh_my_media/movie_detail/cover_badges.dart';
import 'package:omm/features/privacy/privacy_mask.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/glass.dart';
import 'package:omm/shared/media_list_row.dart';
import 'package:omm/shared/poster.dart';
import 'package:omm/shared/resource_panel_components.dart';

import 'db_online_following_widgets.dart';

List<({String value, String label})> downloadRecordSourceOptions(AppL10n l) => [
  (value: 'manual', label: l.dbOnlineDownloadRecordsManual),
  (value: 'video_subscription', label: l.dbOnlineDownloadRecordsVideoSub),
  (value: 'actor_subscription', label: l.dbOnlineDownloadRecordsActorSub),
  (value: 'series_subscription', label: l.dbOnlineDownloadRecordsSeriesSub),
  (value: 'watched', label: l.dbOnlineDownloadRecordsWatched),
  (value: 'download_check', label: l.dbOnlineDownloadRecordsCheck),
];

List<({String value, String label})> downloadRecordResourceOptions(AppL10n l) =>
    [
      (value: 'normal', label: l.dbOnlineDownloadRecordsNormal),
      (value: 'hd', label: l.dbOnlineDownloadRecordsHd),
      (value: 'uhd', label: 'UHD'),
      (value: 'sub', label: l.movieFlagSubtitle),
      (value: 'uncensored', label: l.movieFlagCrack),
    ];

class DbOnlineDownloadRecordCard extends StatelessWidget {
  const DbOnlineDownloadRecordCard({
    super.key,
    required this.record,
    required this.serverId,
    required this.config,
    required this.downloaderLabel,
    required this.styles,
    required this.expanded,
    required this.pushing,
    required this.onToggle,
    required this.onOpen,
    required this.onRepush,
  });

  final DbOnlineDownloadRecord record;
  final String serverId;
  final ServerConfig? config;
  final String downloaderLabel;
  final Map<String, String> styles;
  final bool expanded;
  final bool pushing;
  final VoidCallback onToggle;
  final VoidCallback? onOpen;
  final VoidCallback? onRepush;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final colors = appColors(context);
    final id = record.id;
    final privacyKey = record.videoId.isNotEmpty
        ? record.videoId
        : record.videoCode.isNotEmpty
        ? record.videoCode
        : '$serverId:download-record:$id';
    final title = record.videoTitle.isNotEmpty
        ? record.videoTitle
        : record.resourceName.isNotEmpty
        ? record.resourceName
        : l.dbOnlineDownloadRecordsNoName;
    final image = record.thumbUrl.isNotEmpty
        ? record.thumbUrl
        : record.coverUrl;
    final formatted = formatDbOnlineFollowingDate(record.downloadedAt);
    final sourceLabel = record.resolveSourceLabel(styles);
    final source = sourceLabel.isNotEmpty
        ? sourceLabel
        : downloadRecordSourceOptions(l)
                  .where((option) => option.value == record.sourceType)
                  .map((option) => option.label)
                  .firstOrNull ??
              (record.sourceType.isEmpty
                  ? l.dbOnlineDownloadRecordsUnknownSource
                  : record.sourceType);
    final protocol = switch (record.resourceProtocol) {
      'magnet' => l.dbOnlineDownloadRecordsMagnet,
      'ed2k' => 'ED2K',
      '' => l.dbOnlineDownloadRecordsUnknownProtocol,
      _ => record.resourceProtocol,
    };

    Widget detail(
      String label,
      String value, {
      bool private = false,
      bool error = false,
    }) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.meta(context)),
          const SizedBox(height: 3),
          if (private)
            PrivacyText(
              movieId: privacyKey,
              text: value,
              style: AppText.body(
                context,
              ).copyWith(color: error ? const Color(0xFFEF4444) : colors.text),
            )
          else
            Text(value, style: AppText.body(context)),
        ],
      ),
    );

    return GlassPanel(
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      CoverBadgePill(
                        icon: record.success
                            ? Icons.check_circle_outline
                            : Icons.error_outline,
                        label: record.success
                            ? l.dbOnlineDownloadRecordsSuccess
                            : l.dbOnlineDownloadRecordsFailed,
                        color: record.success
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                      ),
                      OutlinedButton.icon(
                        onPressed: onRepush,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.accent,
                          side: BorderSide(color: colors.cardBorder),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          minimumSize: const Size(0, 32),
                        ),
                        icon: pushing
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh_rounded, size: 16),
                        label: Text(
                          pushing
                              ? l.dbOnlineDownloadRecordsRepushing
                              : l.dbOnlineDownloadRecordsRepush,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: expanded
                      ? l.dbOnlineDownloadRecordsCollapse
                      : l.dbOnlineDownloadRecordsExpand,
                  onPressed: onToggle,
                  icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
                ),
              ],
            ),
            MediaListRow(
              thumbnailWidth: 60,
              padding: const EdgeInsets.symmetric(vertical: 8),
              privacyId: privacyKey,
              privacyAwareTap: true,
              onTap: onOpen,
              thumbnail: PrivacyMask(
                movieId: privacyKey,
                radius: 8,
                child: Poster(
                  url: image.isEmpty || config == null
                      ? null
                      : resolveServerUrl(config!, image),
                  title: title,
                  radius: 8,
                ),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.videoCode.isEmpty
                        ? l.dbOnlineDownloadRecordsUnknownVideo
                        : record.videoCode,
                    style: AppText.mono(context, color: colors.accent),
                  ),
                  const SizedBox(height: 3),
                  PrivacyText(
                    movieId: privacyKey,
                    text: title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(context),
                  ),
                ],
              ),
              meta: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatted.isEmpty ? '--' : formatted,
                    style: AppText.meta(context),
                  ),
                  Text(downloaderLabel, style: AppText.meta(context)),
                ],
              ),
              additional: ResourceTagBadges(
                tags: record.resourceTypes,
                showNormal: record.resourceTypes.contains('normal'),
              ),
            ),
            if (expanded) ...[
              detail(
                l.dbOnlineDownloadRecordsSource,
                [
                  source,
                  protocol,
                  record.resourceSite,
                ].where((value) => value.isNotEmpty).join(' / '),
              ),
              if (record.resourceDate.isNotEmpty)
                detail(
                  l.dbOnlineDownloadRecordsResourceDate,
                  formatDbOnlineFollowingDate(
                    record.resourceDate,
                  ).split(' ').first,
                ),
              detail(
                l.dbOnlineDownloadRecordsResourceName,
                record.resourceName.isEmpty
                    ? l.dbOnlineDownloadRecordsNoName
                    : record.resourceName,
                private: true,
              ),
              if (record.errorMessage.isNotEmpty)
                detail(
                  l.dbOnlineDownloadRecordsError,
                  record.errorMessage,
                  private: true,
                  error: true,
                ),
            ],
          ],
        ),
      ),
    );
  }
}
