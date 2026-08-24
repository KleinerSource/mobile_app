import 'package:freezed_annotation/freezed_annotation.dart';

part 'actor.freezed.dart';
part 'actor.g.dart';

@freezed
abstract class ActorRef with _$ActorRef {
  const factory ActorRef({required int id, required String name}) = _ActorRef;

  factory ActorRef.fromJson(Map<String, dynamic> json) =>
      _$ActorRefFromJson(json);
}

@freezed
abstract class ActorItem with _$ActorItem {
  const factory ActorItem({
    required int id,
    required String name,
    String? biography,
    @JsonKey(name: 'actor_type') String? actorType,
    // 后端改为返回 avatar_path 数组(按序多张头像),支持封面轮播
    @JsonKey(name: 'avatar_path') List<String>? avatarPaths,
    @JsonKey(name: 'movie_count') @Default(0) int movieCount,
  }) = _ActorItem;

  factory ActorItem.fromJson(Map<String, dynamic> json) =>
      _$ActorItemFromJson(json);
}
