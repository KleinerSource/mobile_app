import 'package:freezed_annotation/freezed_annotation.dart';

import 'actor.dart';
import 'related_file.dart';
import 'related_movie.dart';
import 'resource.dart';

part 'movie.freezed.dart';
part 'movie.g.dart';

@freezed
class MovieListItem with _$MovieListItem {
  const factory MovieListItem({
    required int id,
    @JsonKey(defaultValue: '') @Default('') String title,
    String? num,
    int? year,
    double? rating,
    int? runtime,
    @JsonKey(name: 'file_size') int? fileSize,
    @JsonKey(name: 'poster_uuid') String? posterUuid,
    @JsonKey(name: 'fanart_uuid') String? fanartUuid,
    @JsonKey(name: 'thumb_uuid') String? thumbUuid,
    @JsonKey(name: 'series_name') String? seriesName,
    @JsonKey(name: 'is_favorited') @Default(false) bool isFavorited,
    @JsonKey(name: 'is_updated') @Default(false) bool isUpdated,
    @JsonKey(name: 'has_external_subtitle') @Default(false) bool hasExternalSubtitle,
    @JsonKey(name: 'has_internal_subtitle') @Default(false) bool hasInternalSubtitle,
    @JsonKey(name: 'video_width') int? videoWidth,
    @JsonKey(name: 'video_height') int? videoHeight,
    @Default(<ActorRef>[]) List<ActorRef> actors,
    @JsonKey(name: 'watch_record') WatchRecordSummary? watchRecord,
  }) = _MovieListItem;

  factory MovieListItem.fromJson(Map<String, dynamic> json) =>
      _$MovieListItemFromJson(json);
}

/// 分辨率级别 · 用于卡片角标
enum ResolutionTier { sd, hd, fhd, uhd, none }

extension MovieListItemX on MovieListItem {
  ResolutionTier get resolutionTier {
    final w = videoWidth ?? 0;
    final h = videoHeight ?? 0;
    final m = w > h ? w : h; // 长边
    if (m <= 0) return ResolutionTier.none;
    if (m >= 3000) return ResolutionTier.uhd; // 4K
    if (m >= 1900) return ResolutionTier.fhd; // 1080p
    if (m >= 1200) return ResolutionTier.hd; // 720p
    return ResolutionTier.sd;
  }
}

@freezed
class WatchRecordSummary with _$WatchRecordSummary {
  const factory WatchRecordSummary({
    @JsonKey(name: 'progress_ratio') @Default(0.0) double progressRatio,
    @Default(false) bool completed,
  }) = _WatchRecordSummary;

  factory WatchRecordSummary.fromJson(Map<String, dynamic> json) =>
      _$WatchRecordSummaryFromJson(json);
}

@freezed
class MovieDetail with _$MovieDetail {
  const factory MovieDetail({
    required int id,
    @JsonKey(defaultValue: '') @Default('') String title,
    String? num,
    @JsonKey(name: 'original_title') String? originalTitle,
    int? year,
    double? rating,
    int? runtime,
    String? plot,
    String? outline,
    String? country,
    String? trailer,
    @JsonKey(name: 'file_path') String? filePath,
    @JsonKey(name: 'file_size') int? fileSize,
    @JsonKey(name: 'last_downloaded_at') String? lastDownloadedAt,
    @JsonKey(name: 'movie_part') String? moviePart,
    @JsonKey(name: 'poster_uuid') String? posterUuid,
    @JsonKey(name: 'fanart_uuid') String? fanartUuid,
    @JsonKey(name: 'has_external_subtitle') @Default(false) bool hasExternalSubtitle,
    @JsonKey(name: 'is_favorited') @Default(false) bool isFavorited,
    @Default(<ResourceItem>[]) List<ResourceItem> tags,
    @Default(<ResourceItem>[]) List<ResourceItem> genres,
    @Default(<ActorItem>[]) List<ActorItem> actors,
    ResourceItem? series,
    @JsonKey(name: 'watch_record') WatchRecordSummary? watchRecord,
    @JsonKey(name: 'part_movies')
    @Default(<RelatedMovie>[]) List<RelatedMovie> partMovies,
    @JsonKey(name: 'actor_related_movies')
    @Default(<RelatedMovie>[]) List<RelatedMovie> actorRelatedMovies,
    @JsonKey(name: 'related_files')
    @Default(<RelatedFile>[]) List<RelatedFile> relatedFiles,
  }) = _MovieDetail;

  factory MovieDetail.fromJson(Map<String, dynamic> json) =>
      _$MovieDetailFromJson(json);
}
