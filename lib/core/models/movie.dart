import 'package:freezed_annotation/freezed_annotation.dart';

import 'actor.dart';
import 'related_file.dart';
import 'related_movie.dart';
import 'resource.dart';

part 'movie.freezed.dart';
part 'movie.g.dart';

@freezed
abstract class MovieListItem with _$MovieListItem {
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
    @JsonKey(name: 'movie_created_at') DateTime? movieCreatedAt,
    @JsonKey(name: 'is_favorited') @Default(false) bool isFavorited,
    @JsonKey(name: 'is_updated') @Default(false) bool isUpdated,
    @JsonKey(name: 'has_new_resources') @Default(false) bool hasNewResources,
    @JsonKey(name: 'has_external_subtitle') @Default(false) bool hasExternalSubtitle,
    @JsonKey(name: 'has_internal_subtitle') @Default(false) bool hasInternalSubtitle,
    @JsonKey(name: 'video_width') int? videoWidth,
    @JsonKey(name: 'video_height') int? videoHeight,
    @JsonKey(name: 'file_name') String? fileName,
    @Default(<ActorRef>[]) List<ActorRef> actors,
    @JsonKey(name: 'watch_record') WatchRecordSummary? watchRecord,
  }) = _MovieListItem;

  factory MovieListItem.fromJson(Map<String, dynamic> json) =>
      _$MovieListItemFromJson(json);
}

/// 分辨率级别 · 用于卡片角标
enum ResolutionTier { sd, hd, fhd, uhd, none }

// 番号后缀识别 · 规则参考 frontend_new PlyrPlayer
//
// 后缀 → badge 映射
//   -c    / -chs / -ch / -cht / -zh / -sub / -subs   →  内嵌字幕
//   -u    / -umr                                      →  破解
//   -uc   / -umr-c                                    →  破解 + 内嵌字幕
//   -uncen / -uncensored / -leak / -leaked            →  破解
//
// 前后必须是单词边界 (^ / $ / - / _ / . / 空格)

// 内嵌字幕标识 (单独后缀, 例: -c, -chs)
final _kEmbeddedSubtitleRegex = RegExp(
  r'(?:^|[-_. ])(c|ch|chs|cht|zh|sub|subs)(?=$|[-_. ])',
);

// 破解标识 (UMR 系列, 例: -umr, -umr-c)
final _kUmrCrackRegex = RegExp(r'(?:^|[-_. ])umr(?:-c)?(?=$|[-_. ])');

// 破解标识 (单字符 / 长形, 例: -u, -uc, -uncen)
final _kCrackRegex = RegExp(
  r'(?:^|[-_. ])(u|uc|uncen|uncensored|leak|leaked)(?=$|[-_. ])',
);

// "uc" / "umr-c" 同时含字幕标识 (规则 -uc / -umr-c → 破解+内嵌字幕)
final _kCrackWithSubRegex = RegExp(
  r'(?:^|[-_. ])(uc|umr-c)(?=$|[-_. ])',
);

final _kUhdRegex = RegExp(r'(?:^|[-_. ])(2160p|4k|uhd)(?=$|[-_. ])');
final _kProb4Regex = RegExp(r'(?:^|[-_. ])prob[-_. ]?4(?=$|[-_. ])');
final _kHdRegex =
    RegExp(r'(?:^|[-_. ])(720p|1080p|1440p|hd|fhd|qhd)(?=$|[-_. ])');
const _kUhdSizeThreshold = 15 * 1024 * 1024 * 1024;

extension MovieListItemX on MovieListItem {
  /// 文件名 (无扩展名, 小写) · 用于按番号后缀识别 字幕/破解/分辨率
  String get _fileNameStem {
    final raw = (fileName ?? '').trim();
    if (raw.isEmpty) return '';
    return raw.replaceFirst(RegExp(r'\.[^.]+$'), '').toLowerCase();
  }

  /// 内嵌字幕(视频容器内字幕轨道) · 详情接口字段,与文件名标识相互独立
  bool get hasMuxedSubtitle => hasInternalSubtitle;

  /// 文件名内嵌字幕标识: -c / -chs / -ch / -cht / -zh / -sub / -subs / -uc / -umr-c
  bool get hasFilenameSubtitle {
    final stem = _fileNameStem;
    if (stem.isEmpty) return false;
    return _kEmbeddedSubtitleRegex.hasMatch(stem) ||
        _kCrackWithSubRegex.hasMatch(stem);
  }

  /// 破解: -u / -uc / -umr / -umr-c / -uncen / -uncensored / -leak / -leaked
  bool get hasCracked {
    final stem = _fileNameStem;
    if (stem.isEmpty) return false;
    return _kUmrCrackRegex.hasMatch(stem) || _kCrackRegex.hasMatch(stem);
  }

  /// UHD: 视频高度 ≥ 2160, 文件名含 2160p / 4k / uhd, 或 prob4 且文件大于 15GiB
  bool get _hasUhdFlag {
    final h = videoHeight ?? 0;
    if (h >= 2160) return true;
    final stem = _fileNameStem;
    if (stem.isEmpty) return false;
    if (_kUhdRegex.hasMatch(stem)) return true;
    final size = fileSize ?? 0;
    return size > _kUhdSizeThreshold && _kProb4Regex.hasMatch(stem);
  }

  /// HD: 高度 [720, 2160) 或文件名含 720p/1080p/1440p/hd/fhd/qhd
  bool get _hasHdFlag {
    if (_hasUhdFlag) return false;
    final h = videoHeight ?? 0;
    if (h >= 720 && h < 2160) return true;
    final stem = _fileNameStem;
    if (stem.isEmpty) return false;
    return _kHdRegex.hasMatch(stem);
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
abstract class WatchRecordSummary with _$WatchRecordSummary {
  const factory WatchRecordSummary({
    @JsonKey(name: 'progress_ratio') @Default(0.0) double progressRatio,
    @Default(false) bool completed,
  }) = _WatchRecordSummary;

  factory WatchRecordSummary.fromJson(Map<String, dynamic> json) =>
      _$WatchRecordSummaryFromJson(json);
}

@freezed
abstract class MovieDetail with _$MovieDetail {
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
    @JsonKey(name: 'thumb_uuid') String? thumbUuid,
    @JsonKey(name: 'has_external_subtitle') @Default(false) bool hasExternalSubtitle,
    @JsonKey(name: 'has_internal_subtitle') @Default(false) bool hasInternalSubtitle,
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
