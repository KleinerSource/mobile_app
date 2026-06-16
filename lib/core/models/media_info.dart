import 'package:freezed_annotation/freezed_annotation.dart';

part 'media_info.freezed.dart';
part 'media_info.g.dart';

@freezed
abstract class MediaInfo with _$MediaInfo {
  const factory MediaInfo({
    String? container,
    @JsonKey(name: 'video_codec') String? videoCodec,
    @JsonKey(name: 'video_profile') String? videoProfile,
    @JsonKey(name: 'video_width') int? videoWidth,
    @JsonKey(name: 'video_height') int? videoHeight,
    @JsonKey(name: 'video_pix_fmt') String? videoPixFmt,
    @JsonKey(name: 'video_bit_rate') int? videoBitRate,
    @JsonKey(name: 'video_frame_rate') double? videoFrameRate,
    @JsonKey(name: 'audio_codec') String? audioCodec,
    @JsonKey(name: 'audio_channels') int? audioChannels,
    @JsonKey(name: 'audio_bit_rate') int? audioBitRate,
    @JsonKey(name: 'duration_sec') double? durationSec,
    @JsonKey(name: 'bit_rate') int? bitRate,
    @JsonKey(name: 'file_size') int? fileSize,
    @JsonKey(name: 'browser_compatible') bool? browserCompatible,
    @JsonKey(name: 'incompat_reason') String? incompatReason,
  }) = _MediaInfo;

  factory MediaInfo.fromJson(Map<String, dynamic> json) =>
      _$MediaInfoFromJson(json);
}
