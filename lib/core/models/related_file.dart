import 'package:freezed_annotation/freezed_annotation.dart';

part 'related_file.freezed.dart';
part 'related_file.g.dart';

@freezed
class RelatedFile with _$RelatedFile {
  const factory RelatedFile({
    String? type,
    String? label,
    required String path,
  }) = _RelatedFile;

  factory RelatedFile.fromJson(Map<String, dynamic> json) =>
      _$RelatedFileFromJson(json);
}
