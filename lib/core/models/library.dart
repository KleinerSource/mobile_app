import 'package:freezed_annotation/freezed_annotation.dart';

part 'library.freezed.dart';
part 'library.g.dart';

@freezed
class LibraryItem with _$LibraryItem {
  const factory LibraryItem({
    required int id,
    required String name,
    String? description,
    @Default(true) bool enabled,
    @JsonKey(name: 'file_count') @Default(0) int fileCount,
    @JsonKey(name: 'cover_uuid') String? coverUuid,
  }) = _LibraryItem;

  factory LibraryItem.fromJson(Map<String, dynamic> json) =>
      _$LibraryItemFromJson(json);
}
