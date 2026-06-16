import 'package:freezed_annotation/freezed_annotation.dart';

import 'actor.dart';

part 'related_movie.freezed.dart';
part 'related_movie.g.dart';

@freezed
abstract class RelatedMovie with _$RelatedMovie {
  const factory RelatedMovie({
    required int id,
    required String title,
    String? num,
    @JsonKey(name: 'movie_part') String? moviePart,
    int? year,
    double? rating,
    int? runtime,
    @JsonKey(name: 'poster_uuid') String? posterUuid,
    @JsonKey(name: 'thumb_uuid') String? thumbUuid,
    @JsonKey(name: 'fanart_uuid') String? fanartUuid,
    @JsonKey(name: 'matching_actors')
    @Default(<ActorRef>[]) List<ActorRef> matchingActors,
  }) = _RelatedMovie;

  factory RelatedMovie.fromJson(Map<String, dynamic> json) =>
      _$RelatedMovieFromJson(json);
}
