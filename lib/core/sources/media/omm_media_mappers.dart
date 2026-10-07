import '../../models/movie.dart';
import '../common/source_id.dart';
import 'media_metadata_normalizer.dart';
import 'media_models.dart';

/// OMM 列表和收藏共用的影片摘要，保留原始 DTO 供来源专属展示使用。
MediaSummary ommMovieSummary(MovieListItem movie) => MediaSummary(
  ref: MediaRef(sourceId: const SourceId('omm'), value: '${movie.id}'),
  title: normalizeMediaText(movie.title) ?? '',
  code: normalizeMediaText(movie.num),
  year: normalizeMediaYear(movie.year),
  rating: normalizeMediaRating(movie.rating),
  duration: normalizeMediaDurationMinutes(movie.runtime),
  poster: movie.posterUuid,
  thumbnail: movie.thumbUuid,
  fanart: movie.fanartUuid,
  canPlay: true,
  attributes: {
    'file_size': movie.fileSize,
    'file_name': movie.fileName,
    'resolution_tier': resolutionTierToApi(movie.resolutionTier),
    'series_name': movie.seriesName,
    'preview_video_url': movie.previewVideoUrl,
    'has_new_resources': movie.hasNewResources,
    'actors': movie.actors,
    'watch_record': movie.watchRecord,
  },
  payload: movie,
);
