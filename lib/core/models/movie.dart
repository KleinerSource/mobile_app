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
    @JsonKey(name: 'file_path') String? filePath,
    @Default(<ActorRef>[]) List<ActorRef> actors,
    @JsonKey(name: 'watch_record') WatchRecordSummary? watchRecord,
  }) = _MovieListItem;

  factory MovieListItem.fromJson(Map<String, dynamic> json) =>
      _$MovieListItemFromJson(json);
}

/// 分辨率级别 · 用于卡片角标
enum ResolutionTier { sd, hd, fhd, uhd, none }

extension MovieListItemX on MovieListItem {
  /// 文件名 (无扩展名, 小写) · 用于按番号后缀识别 字幕/破解/分辨率
  String get _fileNameStem {
    final raw = (filePath ?? '').trim();
    if (raw.isEmpty) return '';
    final name = raw.split(RegExp(r'[\\/]')).last;
    return name.replaceFirst(RegExp(r'\.[^.]+$'), '').toLowerCase();
  }

  /// 内嵌字幕: 番号后缀 -C / -CH / -CHS / -CHT / -ZH / -SUB / -SUBS / -UC
  bool get hasEmbeddedSubtitle {
    if (hasInternalSubtitle) return true;
    final stem = _fileNameStem;
    if (stem.isEmpty) return false;
    return RegExp(
      r'(?:^|[-_. ])(c|ch|chs|cht|zh|sub|subs|uc)(?=$|[-_. ])',
    ).hasMatch(stem);
  }

  /// 破解 / 无码: -U / -UC / -UNCEN / -UNCENSORED / -LEAK / -LEAKED / UMR / UMR-C
  bool get hasCracked {
    final stem = _fileNameStem;
    if (stem.isEmpty) return false;
    if (RegExp(r'(?:^|[-_. ])umr(?:-c)?(?=$|[-_. ])').hasMatch(stem)) {
      return true;
    }
    return RegExp(
      r'(?:^|[-_. ])(u|uc|uncen|uncensored|leak|leaked)(?=$|[-_. ])',
    ).hasMatch(stem);
  }

  /// UHD: 视频高度 ≥ 2160, 或文件名含 2160p / 4k / uhd
  bool get _hasUhdFlag {
    final h = videoHeight ?? 0;
    if (h >= 2160) return true;
    final stem = _fileNameStem;
    if (stem.isEmpty) return false;
    return RegExp(r'(?:^|[-_. ])(2160p|4k|uhd)(?=$|[-_. ])').hasMatch(stem);
  }

  /// HD: 高度 [720, 2160) 或文件名含 720p/1080p/1440p/hd/fhd/qhd (与 UHD 互斥)
  bool get _hasHdFlag {
    if (_hasUhdFlag) return false;
    final h = videoHeight ?? 0;
    if (h >= 720 && h < 2160) return true;
    final stem = _fileNameStem;
    if (stem.isEmpty) return false;
    return RegExp(
      r'(?:^|[-_. ])(720p|1080p|1440p|hd|fhd|qhd)(?=$|[-_. ])',
    ).hasMatch(stem);
  }

  ResolutionTier get resolutionTier {
    if (_hasUhdFlag) return ResolutionTier.uhd;
    if (_hasHdFlag) {
      final h = videoHeight ?? 0;
      if (h >= 1080) return ResolutionTier.fhd;
      return ResolutionTier.hd;
    }
    return ResolutionTier.none;
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
