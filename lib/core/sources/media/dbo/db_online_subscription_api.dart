import 'package:dio/dio.dart';

import '../../../api/envelope.dart';
import 'db_online_following.dart';

/// DBO subscription endpoints hosted by the selected DB Online server.
class DbOnlineSubscriptionApi {
  DbOnlineSubscriptionApi(this._dio);

  final Dio _dio;

  Future<dynamic> health() async {
    final response = await _dio.get<dynamic>(
      '/health',
      options: Options(
        validateStatus: (status) => status != null && status < 600,
      ),
    );
    return response.data;
  }

  Future<dynamic> videoSubscriptions({
    String filter = 'pending',
    int page = 1,
    int limit = 24,
    String keyword = '',
  }) => _send(
    () => _dio.get<dynamic>(
      '/subs',
      queryParameters: {
        'filter': filter,
        'page': page,
        'limit': limit,
        if (keyword.trim().isNotEmpty) 'keyword': keyword.trim(),
      },
    ),
  );

  Future<dynamic> subscriptionVideos({
    required String sourceType,
    Object? sourceId,
    String status = '',
    int page = 1,
    int limit = 24,
    String keyword = '',
    String? sortBy,
    String? orderBy,
  }) => _send(
    () => _dio.get<dynamic>(
      '/subscription-videos',
      queryParameters: {
        'source_type': sourceType,
        if (sourceId != null) 'source_id': sourceId,
        if (status.isNotEmpty) 'status': status,
        'page': page,
        'limit': limit,
        if (keyword.trim().isNotEmpty) 'keyword': keyword.trim(),
        if (sortBy != null) 'sort_by': sortBy,
        if (orderBy != null) 'order_by': orderBy,
      },
    ),
  );

  Future<dynamic> updateSubscriptionVideoStatus(Map<String, dynamic> body) =>
      _send(
        () => _dio.patch<dynamic>('/subscription-videos/status', data: body),
      );

  Future<dynamic> createVideoSubscription(Map<String, dynamic> body) =>
      _send(() => _dio.post<dynamic>('/subs', data: body));

  Future<dynamic> updateVideoSubscription(
    String code,
    Map<String, dynamic> body,
  ) => _send(
    () => _dio.put<dynamic>('/subs/${Uri.encodeComponent(code)}', data: body),
  );

  Future<dynamic> deleteVideoSubscription(String code) =>
      _send(() => _dio.delete<dynamic>('/subs/${Uri.encodeComponent(code)}'));

  Future<dynamic> checkVideoSubscription(String code) => _send(
    () => _dio.post<dynamic>('/subs/check/${Uri.encodeComponent(code)}'),
  );

  Future<dynamic> runVideoSubscriptionChecks([List<String> codes = const []]) =>
      _send(() => _dio.post<dynamic>('/subs/check', data: {'codes': codes}));

  Future<dynamic> subscriptionStatus({
    required String type,
    required String id,
    String subType = 'series',
  }) => _send(
    () => _dio.post<dynamic>(
      '/subs/status',
      data: switch (type) {
        'actor' => {
          'type': type,
          'actor_ids': [id],
        },
        'series' => {
          'type': type,
          'sub_type': subType,
          'external_ids': [id],
        },
        _ => {
          'type': 'video',
          'codes': [id],
          'detail': true,
        },
      },
    ),
  );

  Future<dynamic> videoSubscriptionStatuses(List<String> codes) => _send(
    () => _dio.post<dynamic>(
      '/subs/status',
      data: {'type': 'video', 'codes': codes, 'detail': true},
    ),
  );

  Future<dynamic> onlineSubscriptions({
    Map<String, dynamic> query = const {},
  }) =>
      _send(() => _dio.get<dynamic>('/subs/live-sub', queryParameters: query));

  Future<dynamic> syncOnlineSubscriptions() =>
      _send(() => _dio.post<dynamic>('/subs/sync'));

  Future<dynamic> getAutoSync() =>
      _send(() => _dio.get<dynamic>('/subs/auto-sync'));

  Future<dynamic> updateAutoSync(Map<String, dynamic> body) =>
      _send(() => _dio.put<dynamic>('/subs/auto-sync', data: body));

  Future<dynamic> getSubscriptionPreset() =>
      _send(() => _dio.get<dynamic>('/subs/preset'));

  Future<dynamic> updateSubscriptionPreset(Map<String, dynamic> body) =>
      _send(() => _dio.put<dynamic>('/subs/preset', data: body));

  Future<dynamic> overwriteSubscriptionPreset(Map<String, dynamic> body) =>
      _send(() => _dio.post<dynamic>('/subs/preset/overwrite', data: body));

  Future<dynamic> exportSubscriptionShare(Map<String, dynamic> body) =>
      _send(() => _dio.post<dynamic>('/subs/share/export', data: body));

  Future<dynamic> analyzeSubscriptionShare(Map<String, dynamic> body) =>
      _send(() => _dio.post<dynamic>('/subs/share/analyze', data: body));

  Future<dynamic> importSubscriptionShare(Map<String, dynamic> body) =>
      _send(() => _dio.post<dynamic>('/subs/share/import', data: body));

  Future<dynamic> actorSubscriptions({Map<String, dynamic> query = const {}}) =>
      _send(() => _dio.get<dynamic>('/actor-subs', queryParameters: query));

  Future<dynamic> createActorSubscription(Map<String, dynamic> body) =>
      _send(() => _dio.post<dynamic>('/actor-subs', data: body));

  Future<dynamic> actorSubscription(String actorId) => _send(
    () => _dio.get<dynamic>('/actor-subs/${Uri.encodeComponent(actorId)}'),
  );

  Future<dynamic> updateActorSubscription(
    String actorId,
    Map<String, dynamic> body,
  ) => _send(
    () => _dio.put<dynamic>(
      '/actor-subs/${Uri.encodeComponent(actorId)}',
      data: body,
    ),
  );

  Future<dynamic> deleteActorSubscription(String actorId) => _send(
    () => _dio.delete<dynamic>('/actor-subs/${Uri.encodeComponent(actorId)}'),
  );

  Future<dynamic> checkActorSubscription(String actorId) => _send(
    () =>
        _dio.post<dynamic>('/actor-subs/check/${Uri.encodeComponent(actorId)}'),
  );

  Future<dynamic> batchCheckActorSubscriptions([
    List<String> actorIds = const [],
  ]) => _send(
    () =>
        _dio.post<dynamic>('/actor-subs/check', data: {'actor_ids': actorIds}),
  );

  Future<dynamic> runActorSubscriptions() =>
      _send(() => _dio.post<dynamic>('/actor-subs/run'));

  Future<dynamic> runActorSubscription(String actorId) => _send(
    () => _dio.post<dynamic>('/actor-subs/run/${Uri.encodeComponent(actorId)}'),
  );

  /// 演员订阅类别过滤的可选类别（该演员的标签），沿用网页端
  /// `GET /options/categories/{actorId}` 的 `{name, external_id}` 结构。
  Future<List<DbOnlineFollowingStyle>> actorCategories(String actorId) async {
    final data = await _send(
      () => _dio.get<dynamic>(
        '/options/categories/${Uri.encodeComponent(actorId)}',
      ),
    );
    final items = data is List ? data : const <Object?>[];
    return items.map(DbOnlineFollowingStyle.fromJson).toList(growable: false);
  }

  Future<dynamic> seriesSubscriptions({
    Map<String, dynamic> query = const {},
  }) => _send(() => _dio.get<dynamic>('/series-subs', queryParameters: query));

  Future<dynamic> createSeriesSubscription(Map<String, dynamic> body) =>
      _send(() => _dio.post<dynamic>('/series-subs', data: body));

  Future<dynamic> seriesSubscription(
    String externalId, {
    String subType = 'series',
  }) => _send(
    () => _dio.get<dynamic>(
      '/series-subs/${Uri.encodeComponent(externalId)}',
      queryParameters: {'sub_type': subType},
    ),
  );

  Future<dynamic> updateSeriesSubscription(
    String externalId,
    Map<String, dynamic> body, {
    String subType = 'series',
  }) => _send(
    () => _dio.put<dynamic>(
      '/series-subs/${Uri.encodeComponent(externalId)}',
      data: body,
      queryParameters: {'sub_type': subType},
    ),
  );

  Future<dynamic> deleteSeriesSubscription(
    String externalId, {
    String subType = 'series',
  }) => _send(
    () => _dio.delete<dynamic>(
      '/series-subs/${Uri.encodeComponent(externalId)}',
      queryParameters: {'sub_type': subType},
    ),
  );

  Future<dynamic> checkSeriesSubscription(
    String externalId, {
    String subType = 'series',
  }) => _send(
    () => _dio.post<dynamic>(
      '/series-subs/check/${Uri.encodeComponent(externalId)}',
      queryParameters: {'sub_type': subType},
    ),
  );

  Future<dynamic> batchCheckSeriesSubscriptions({
    List<String> externalIds = const [],
    String subType = 'series',
  }) => _send(
    () => _dio.post<dynamic>(
      '/series-subs/check',
      data: {'external_ids': externalIds, 'sub_type': subType},
    ),
  );

  Future<dynamic> runSeriesSubscriptions({String subType = 'series'}) => _send(
    () => _dio.post<dynamic>(
      '/series-subs/run',
      queryParameters: {'sub_type': subType},
    ),
  );

  Future<dynamic> runSeriesSubscription(
    String externalId, {
    String subType = 'series',
  }) => _send(
    () => _dio.post<dynamic>(
      '/series-subs/run/${Uri.encodeComponent(externalId)}',
      queryParameters: {'sub_type': subType},
    ),
  );

  Future<dynamic> blacklist({Map<String, dynamic> query = const {}}) =>
      _send(() => _dio.get<dynamic>('/blacklist', queryParameters: query));

  Future<dynamic> addToBlacklist(Map<String, dynamic> body) =>
      _send(() => _dio.post<dynamic>('/blacklist', data: body));

  Future<dynamic> removeFromBlacklist(
    String code, {
    String entryType = 'video_code',
  }) => _send(
    () => _dio.delete<dynamic>(
      '/blacklist/${Uri.encodeComponent(code)}',
      queryParameters: {'entry_type': entryType},
    ),
  );

  Future<dynamic> batchRemoveFromBlacklist(
    List<Map<String, dynamic>> entries,
  ) => _send(
    () => _dio.delete<dynamic>('/blacklist', data: {'entries': entries}),
  );

  Future<dynamic> testBlacklist({
    required List<String> codes,
    String entryType = 'video_code',
    String categoryRule = '',
  }) => _send(
    () => _dio.post<dynamic>(
      '/blacklist/test',
      data: {
        'entry_type': entryType,
        'video_codes': codes,
        'category_rule': categoryRule,
      },
    ),
  );

  Future<dynamic> _send(Future<Response<dynamic>> Function() request) async {
    final response = await request();
    return unwrapStd<dynamic>(response.data, (data) => data);
  }
}
