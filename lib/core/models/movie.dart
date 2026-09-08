import 'package:freezed_annotation/freezed_annotation.dart';

import 'actor.dart';
import 'related_file.dart';
import 'related_movie.dart';
import 'resource.dart';
import 'movie_subtitle.dart';

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
    @JsonKey(name: 'has_external_subtitle')
    @Default(false)
    bool hasExternalSubtitle,
    @JsonKey(name: 'has_ai_subtitle') @Default(false) bool hasAiSubtitle,
    @JsonKey(name: 'has_internal_subtitle')
    @Default(false)
    bool hasInternalSubtitle,
    @JsonKey(name: 'file_name') String? fileName,
    // 后端统一计算的清晰度档位(媒体宽高优先，缺失回退 file_resolution)，
    // 由 resolution_tier 解析而来；徽章只消费该字段，不再自行推导。
    @ResolutionTierConverter()
    @JsonKey(name: 'resolution_tier')
    @Default(ResolutionTier.none)
    ResolutionTier resolutionTier,
    @JsonKey(name: 'preview_video_url') String? previewVideoUrl,
    @Default(<ActorRef>[]) List<ActorRef> actors,
    @JsonKey(name: 'watch_record') WatchRecordSummary? watchRecord,
  }) = _MovieListItem;

  factory MovieListItem.fromJson(Map<String, dynamic> json) =>
      _$MovieListItemFromJson(json);
}

/// 分辨率级别 · 用于卡片角标
enum ResolutionTier { sd, hd, fhd, k2, uhd, none }

/// 解析后端统一返回的 resolution_tier 档位字符串
/// ('4k' | '2k' | 'fhd' | 'hd' | 'sd')，其余(含 unknown/缺失)视为 none。
ResolutionTier resolutionTierFromApi(String? tier) {
  switch ((tier ?? '').trim().toLowerCase()) {
    case '4k':
      return ResolutionTier.uhd;
    case '2k':
      return ResolutionTier.k2;
    case 'fhd':
      return ResolutionTier.fhd;
    case 'hd':
      return ResolutionTier.hd;
    case 'sd':
      return ResolutionTier.sd;
  }
  return ResolutionTier.none;
}

String? resolutionTierToApi(ResolutionTier tier) {
  switch (tier) {
    case ResolutionTier.uhd:
      return '4k';
    case ResolutionTier.k2:
      return '2k';
    case ResolutionTier.fhd:
      return 'fhd';
    case ResolutionTier.hd:
      return 'hd';
    case ResolutionTier.sd:
      return 'sd';
    case ResolutionTier.none:
      return null;
  }
}

/// resolution_tier 字段与 ResolutionTier 枚举的 JSON 转换。
class ResolutionTierConverter implements JsonConverter<ResolutionTier, String?> {
  const ResolutionTierConverter();

  @override
  ResolutionTier fromJson(String? json) => resolutionTierFromApi(json);

  @override
  String? toJson(ResolutionTier object) => resolutionTierToApi(object);
}

// 番号后缀识别 · 规则参考 frontend_new PlyrPlayer
//
// 后缀 → badge 映射
//   -c    / -chs / -ch / -cht / -zh / -sub / -subs   →  内嵌字幕
//   -u    / -umr                                      →  破解
//   -uc   / -umr-c                                    →  破解 + 内嵌字幕
//   -uncen / -uncensored / -leak / -leaked            →  破解
//
// 前后必须是独立 token 边界 (^ / $ / - / _ / . / 空格 / 括号)

// 内嵌字幕标识 (单独后缀, 例: -c, -chs)
final _kEmbeddedSubtitleRegex = RegExp(
  r'(?:^|[-_. ()\[\]{}])(c|ch|chs|cht|zh|sub|subs)(?=$|[-_. ()\[\]{}])',
);

// 破解标识 (UMR 系列, 例: -umr, -umr-c)
final _kUmrCrackRegex = RegExp(
  r'(?:^|[-_. ()\[\]{}])umr(?:-c)?(?=$|[-_. ()\[\]{}])',
);

// 破解标识 (单字符 / 长形, 例: -u, -uc, -uncen)
final _kCrackRegex = RegExp(
  r'(?:^|[-_. ()\[\]{}])(u|uc|uncen|uncensored|leak|leaked)(?=$|[-_. ()\[\]{}])',
);

// "uc" / "umr-c" 同时含字幕标识 (规则 -uc / -umr-c → 破解+内嵌字幕)
final _kCrackWithSubRegex = RegExp(
  r'(?:^|[-_. ()\[\]{}])(uc|umr-c)(?=$|[-_. ()\[\]{}])',
);

// AI 字幕标识 · 文件名中独立的 "ai" 标记段 (例: aaa.ai.chs.srt),
// 大小写不敏感; "ks"/"chs"/"default" 等其它段不命中。
// 规则与 Web 端 useCoverBadges.ts 及后端 IsAISubtitlePath 保持一致。
final _kAISubtitleRegex = RegExp(r'(?:^|[-_. ()\[\]{}])ai(?=$|[-_. ()\[\]{}])');

/// 判断外挂字幕文件路径是否带 .ai. 标记段 (AI 生成/云转译字幕)
bool isAISubtitlePath(String? path) {
  final raw = (path ?? '').trim();
  if (raw.isEmpty) return false;
  final name = raw.split(RegExp(r'[\\/]')).last;
  if (name.isEmpty) return false;
  final stem = name.replaceFirst(RegExp(r'\.[^.]+$'), '').toLowerCase();
  return _kAISubtitleRegex.hasMatch(stem);
}

extension MovieListItemX on MovieListItem {
  /// 文件名 (无扩展名, 小写) · 用于按番号后缀识别字幕/破解
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
    @ResolutionTierConverter()
    @JsonKey(name: 'resolution_tier')
    @Default(ResolutionTier.none)
    ResolutionTier resolutionTier,
    @JsonKey(name: 'last_downloaded_at') String? lastDownloadedAt,
    @JsonKey(name: 'movie_part') String? moviePart,
    @JsonKey(name: 'poster_uuid') String? posterUuid,
    @JsonKey(name: 'fanart_uuid') String? fanartUuid,
    @JsonKey(name: 'thumb_uuid') String? thumbUuid,
    @JsonKey(name: 'has_external_subtitle')
    @Default(false)
    bool hasExternalSubtitle,
    @JsonKey(name: 'has_ai_subtitle') @Default(false) bool hasAiSubtitle,
    @JsonKey(name: 'has_internal_subtitle')
    @Default(false)
    bool hasInternalSubtitle,
    @JsonKey(name: 'is_favorited') @Default(false) bool isFavorited,
    @Default(<ResourceItem>[]) List<ResourceItem> tags,
    @Default(<ResourceItem>[]) List<ResourceItem> genres,
    @Default(<ActorItem>[]) List<ActorItem> actors,
    ResourceItem? series,
    @JsonKey(name: 'watch_record') WatchRecordSummary? watchRecord,
    @JsonKey(name: 'part_movies')
    @Default(<RelatedMovie>[])
    List<RelatedMovie> partMovies,
    @JsonKey(name: 'actor_related_movies')
    @Default(<RelatedMovie>[])
    List<RelatedMovie> actorRelatedMovies,
    @JsonKey(name: 'related_files')
    @Default(<RelatedFile>[])
    List<RelatedFile> relatedFiles,
    @Default(<MovieSubtitle>[]) List<MovieSubtitle> subtitles,
  }) = _MovieDetail;

  factory MovieDetail.fromJson(Map<String, dynamic> json) =>
      _$MovieDetailFromJson(json);
}
