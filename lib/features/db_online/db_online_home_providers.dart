import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/providers.dart';
import '../../core/models/db_online_movie.dart';

final dbOnlineRecommendProvider =
    FutureProvider.autoDispose<List<DbOnlineMovie>>((ref) async {
      return ref.watch(requiredApiClientProvider).dbOnline.recommend();
    });

final dbOnlineLatestUpdatedProvider =
    FutureProvider.autoDispose<List<DbOnlineMovie>>((ref) async {
      return ref
          .watch(requiredApiClientProvider)
          .dbOnline
          .latest(sortBy: 'update');
    });

final dbOnlineLatestReleasedProvider =
    FutureProvider.autoDispose<List<DbOnlineMovie>>((ref) async {
      return ref
          .watch(requiredApiClientProvider)
          .dbOnline
          .latest(sortBy: 'release');
    });

final dbOnlineMovieDetailProvider = FutureProvider.autoDispose
    .family<DbOnlineMovieDetail, String>((ref, code) {
      return ref.watch(requiredApiClientProvider).dbOnline.detail(code);
    });

final dbOnlineMovieDetailByVideoIdProvider = FutureProvider.autoDispose
    .family<DbOnlineMovieDetail, String>((ref, videoId) {
      return ref
          .watch(requiredApiClientProvider)
          .dbOnline
          .detailByVideoId(videoId);
    });

final dbOnlinePlayEpisodesProvider = FutureProvider.autoDispose
    .family<DbOnlinePlayEpisodes, DbOnlinePlayRequest>((ref, request) {
      return ref
          .watch(requiredApiClientProvider)
          .dbOnline
          .onlinePlayEpisodes(
            request.code,
            sourceId: request.sourceId,
            videoId: request.videoId,
          );
    });

class DbOnlinePlayRequest {
  const DbOnlinePlayRequest({
    required this.code,
    required this.sourceId,
    this.videoId,
  });

  final String code;
  final int sourceId;
  final String? videoId;

  @override
  bool operator ==(Object other) =>
      other is DbOnlinePlayRequest &&
      other.code == code &&
      other.sourceId == sourceId &&
      other.videoId == videoId;

  @override
  int get hashCode => Object.hash(code, sourceId, videoId);
}
