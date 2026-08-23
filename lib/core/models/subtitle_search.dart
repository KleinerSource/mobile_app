import 'package:freezed_annotation/freezed_annotation.dart';

part 'subtitle_search.freezed.dart';
part 'subtitle_search.g.dart';

@freezed
abstract class SubtitleSearchItem with _$SubtitleSearchItem {
  const factory SubtitleSearchItem({
    required String name,
    required String url,
    String? ext,
    String? cid,
    @JsonKey(name: 'file_size') int? fileSize,

    /// 字幕时长 (毫秒) · 后端可能返回 null, 此时客户端从预览内容 extract
    int? duration,
  }) = _SubtitleSearchItem;

  factory SubtitleSearchItem.fromJson(Map<String, dynamic> json) =>
      _$SubtitleSearchItemFromJson(json);
}
