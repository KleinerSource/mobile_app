import 'package:omm/core/sources/media/media_browser/media_browser_models.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

String mediaBrowserHomeMetaText(AppL10n l, MediaBrowserItem item) {
  final parts = <String>[];
  final series = item.seriesName?.trim();
  if (series?.isNotEmpty == true) parts.add(series!);
  if (item.isEpisode) {
    final season = item.parentIndexNumber ?? 0;
    final episode = item.indexNumber ?? 0;
    parts.add(
      'S${season.toString().padLeft(2, '0')}'
      'E${episode.toString().padLeft(2, '0')}',
    );
  } else if (item.productionYear != null) {
    parts.add('${item.productionYear}');
  }
  final minutes = item.runtimeMinutes;
  if (minutes > 0) parts.add(l.mediaDurationMinutes(minutes));
  return parts.join(' · ');
}
