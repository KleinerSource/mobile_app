import 'package:freezed_annotation/freezed_annotation.dart';

part 'resource.freezed.dart';
part 'resource.g.dart';

@freezed
abstract class ResourceItem with _$ResourceItem {
  const factory ResourceItem({
    required int id,
    required String name,
    @JsonKey(name: 'movie_count') @Default(0) int movieCount,
  }) = _ResourceItem;

  factory ResourceItem.fromJson(Map<String, dynamic> json) =>
      _$ResourceItemFromJson(json);
}
