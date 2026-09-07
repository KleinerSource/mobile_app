import 'package:freezed_annotation/freezed_annotation.dart';

part 'movie_subtitle.freezed.dart';
part 'movie_subtitle.g.dart';

/// 影片详情接口返回的外挂字幕记录。
///
/// 详情接口同时提供 `subtitles` 和 `related_files` 两种形态；移动端只需
/// 保留字幕 ID 与文件路径即可完成 AI 字幕识别。
@freezed
abstract class MovieSubtitle with _$MovieSubtitle {
  const factory MovieSubtitle({
    int? id,
    @JsonKey(name: 'file_path') @Default('') String filePath,
  }) = _MovieSubtitle;

  factory MovieSubtitle.fromJson(Map<String, dynamic> json) =>
      _$MovieSubtitleFromJson(json);
}
