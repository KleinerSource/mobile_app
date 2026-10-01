import 'package:dio/dio.dart';

import '../../../api/envelope.dart';
import 'db_online_following.dart';
import 'db_online_movie.dart';

/// 关注列表沿用 DB Online 网页的接口及字段。
class DbOnlineFollowingApi {
  DbOnlineFollowingApi(this._dio);

  final Dio _dio;

  Future<List<DbOnlineFollowingPreset>> presets() async => _items(
    await _dio.get<dynamic>('/following/presets'),
    DbOnlineFollowingPreset.fromJson,
  );

  Future<DbOnlineFollowingPreset> savePreset(
    DbOnlineFollowingPreset preset,
  ) async {
    final response = preset.id == 0
        ? await _dio.post<dynamic>('/following/presets', data: preset.toJson())
        : await _dio.put<dynamic>(
            '/following/presets/${preset.id}',
            data: preset.toJson(),
          );
    return unwrapStd(response.data, DbOnlineFollowingPreset.fromJson);
  }

  Future<void> deletePreset(int id) async {
    final response = await _dio.delete<dynamic>('/following/presets/$id');
    unwrapStd(response.data, (_) {});
  }

  Future<void> reorderPresets(List<int> ids) async {
    final response = await _dio.put<dynamic>(
      '/following/presets/reorder',
      data: {'ids': ids},
    );
    unwrapStd(response.data, (_) {});
  }

  Future<List<DbOnlineFollowingStyle>> styles() async => _items(
    await _dio.get<dynamic>('/options/categories'),
    DbOnlineFollowingStyle.fromJson,
  );

  Future<List<DbOnlineFollowedUser>> users() async => _items(
    await _dio.get<dynamic>('/following/users'),
    DbOnlineFollowedUser.fromJson,
  );

  Future<DbOnlineFollowedUser> followUser(
    String userId, {
    String username = '',
  }) async {
    final response = await _dio.post<dynamic>(
      '/following/users',
      data: {
        'user_id': userId.trim(),
        if (username.trim().isNotEmpty) 'username': username.trim(),
      },
    );
    return unwrapStd<DbOnlineFollowedUser>(
      response.data,
      DbOnlineFollowedUser.fromJson,
    );
  }

  Future<void> unfollowUsers(List<String> ids) async {
    final response = await _dio.delete<dynamic>(
      '/following/users',
      data: {'user_ids': ids},
    );
    unwrapStd(response.data, (_) {});
  }

  Future<DbOnlineFollowedUsersRefresh> refreshUsers() async {
    final response = await _dio.post<dynamic>('/following/users/refresh');
    return unwrapStd(response.data, DbOnlineFollowedUsersRefresh.fromJson);
  }

  Future<DbOnlineReviewResourcePage> resources({
    required String userId,
    bool latest = false,
    String username = '',
    int page = 1,
    int limit = 24,
  }) async {
    final response = await _dio.get<dynamic>(
      latest
          ? '/reviews/latest/resources'
          : '/users/${Uri.encodeComponent(userId)}/resources',
      queryParameters: {
        'page': page,
        'limit': limit,
        if (!latest && username.trim().isNotEmpty) 'username': username.trim(),
      },
    );
    return unwrapStd(response.data, DbOnlineReviewResourcePage.fromJson);
  }

  Future<Map<int, List<DbOnlineMagnet>>> resourceMetadata(
    List<DbOnlineReviewResourceItem> items,
  ) async {
    final response = await _dio.post<dynamic>(
      '/users/resources/metadata',
      data: {
        'items': [
          for (final item in items)
            if (item.magnetPayload.isNotEmpty)
              {'review_id': item.reviewId, 'magnets': item.magnetPayload},
        ],
      },
    );
    return unwrapStd(response.data, (data) {
      final rawItems = data is Map ? data['items'] : null;
      return <int, List<DbOnlineMagnet>>{
        for (final item
            in rawItems is List ? rawItems.whereType<Map>() : <Map>[])
          (item['review_id'] is num
                  ? (item['review_id'] as num).toInt()
                  : int.parse(item['review_id'].toString())):
              (item['magnets'] is List
                      ? (item['magnets'] as List)
                      : <dynamic>[])
                  .map(DbOnlineMagnet.fromJson)
                  .where((magnet) => magnet.magnet.isNotEmpty)
                  .toList(),
      };
    });
  }

  List<T> _items<T>(Response<dynamic> response, T Function(Object?) decode) =>
      unwrapStd(
        response.data,
        (data) => data is List ? data.map(decode).toList() : <T>[],
      );
}
