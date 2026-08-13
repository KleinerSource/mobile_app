import 'package:freezed_annotation/freezed_annotation.dart';

part 'actor.freezed.dart';
part 'actor.g.dart';

@freezed
abstract class ActorRef with _$ActorRef {
  const factory ActorRef({
    required int id,
    required String name,
  }) = _ActorRef;

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
    @JsonKey(name: 'avatar_path') String? avatarPath,
    @JsonKey(name: 'movie_count') @Default(0) int movieCount,
  }) = _ActorItem;

  factory ActorItem.fromJson(Map<String, dynamic> json) =>
      _$ActorItemFromJson(json);
}
