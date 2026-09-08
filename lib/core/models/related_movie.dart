import 'package:freezed_annotation/freezed_annotation.dart';

import 'actor.dart';
import 'movie.dart';

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
    // 后端统一计算的清晰度档位，供详情页多分卷多分辨率徽章展示。
    @ResolutionTierConverter()
    @JsonKey(name: 'resolution_tier')
    @Default(ResolutionTier.none)
    ResolutionTier resolutionTier,
    @JsonKey(name: 'matching_actors')
    @Default(<ActorRef>[])
    List<ActorRef> matchingActors,
  }) = _RelatedMovie;

  factory RelatedMovie.fromJson(Map<String, dynamic> json) =>
      _$RelatedMovieFromJson(json);
}
