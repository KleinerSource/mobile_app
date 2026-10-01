import 'package:omm/core/sources/media/dbo/db_online_subscription.dart';
import 'package:omm/core/sources/media/dbo/db_online_subscription_api.dart';

class DboSubscriptionRepository {
  DboSubscriptionRepository({required this.api, required this.activeServerId});

  final DbOnlineSubscriptionApi api;
  final String activeServerId;

  void checkServer(String serverId) {
    if (serverId.isNotEmpty && serverId != activeServerId) {
      throw StateError('The active DB Online server changed.');
    }
  }

  Future<DbOnlineSubscriptionCapabilities> capabilities(String serverId) async {
    checkServer(serverId);
    return DbOnlineSubscriptionCapabilities.fromJson(await api.health());
  }

  Future<DbOnlineSubscriptionStatus> subscriptionStatus(
    DbOnlineSubscriptionStatusQuery query,
  ) async {
    checkServer(query.serverId);
    final result = await api.subscriptionStatus(
      type: query.kind,
      id: query.id,
      subType: query.subType,
    );
    final value = result is Map
        ? result[query.id] ?? result[query.id.toUpperCase()]
        : null;
    return _subscriptionStatusFromValue(value, sourceType: query.kind);
  }

  Future<Map<String, DbOnlineSubscriptionStatus>> videoSubscriptionStatuses({
    required String serverId,
    required List<String> codes,
  }) async {
    checkServer(serverId);
    final result = await api.videoSubscriptionStatuses(codes);
    final data = result is Map
        ? Map<String, dynamic>.from(result)
        : <String, dynamic>{};
    return {
      for (final code in codes)
        code: _subscriptionStatusFromValue(
          data[code] ?? data[code.toUpperCase()],
          sourceType: 'video',
        ),
    };
  }

  Future<DbOnlineSubscriptionPage> list(DbOnlineSubscriptionQuery query) async {
    checkServer(query.serverId);
    final payload = switch (query.kind) {
      'pending' || 'completed' => await api.subscriptionVideos(
        sourceType: 'video',
        status: query.kind,
        page: query.page,
        limit: query.limit,
        keyword: query.keyword,
        sortBy: 'created_at',
        orderBy: 'desc',
      ),
      'actor-videos' || 'series-videos' => await api.subscriptionVideos(
        sourceType: query.sourceType!,
        sourceId: query.sourceId,
        status: query.queueStatus,
        page: query.page,
        limit: query.limit,
        keyword: query.keyword,
        sortBy: 'created_at',
        orderBy: 'desc',
      ),
      'online' => await api.onlineSubscriptions(
        query: {'page': query.page, 'limit': query.limit},
      ),
      'actor' => await api.actorSubscriptions(
        query: {
          'page': query.page,
          'limit': query.limit,
          'sort_by': 'created_at',
          'order_by': 'desc',
          if (query.keyword.trim().isNotEmpty) 'keyword': query.keyword.trim(),
        },
      ),
      'series' => await api.seriesSubscriptions(
        query: {
          'page': query.page,
          'limit': query.limit,
          'sub_type': 'all',
          'sort_by': 'created_at',
          'order_by': 'desc',
          if (query.keyword.trim().isNotEmpty) 'keyword': query.keyword.trim(),
        },
      ),
      'blacklist' => await api.blacklist(
        query: {
          'page': query.page,
          'page_size': query.limit,
          if (query.keyword.trim().isNotEmpty) 'keyword': query.keyword.trim(),
        },
      ),
      _ => const <String, dynamic>{},
    };

    final keys = switch (query.kind) {
      'pending' ||
      'completed' ||
      'actor-videos' ||
      'series-videos' => const ['items', 'videos'],
      'online' => const ['movies', 'items'],
      'actor' => const ['subscriptions', 'actors', 'items'],
      'series' => const ['subscriptions', 'series', 'items'],
      'blacklist' => const ['list', 'items', 'entries', 'blacklist'],
      _ => const <String>[],
    };
    return DbOnlineSubscriptionPage.fromJson(
      payload,
      kind: query.kind,
      itemKeys: keys,
      defaultPage: query.page,
      defaultLimit: query.limit,
    );
  }
}

DbOnlineSubscriptionStatus _subscriptionStatusFromValue(
  Object? value, {
  required String sourceType,
}) {
  if (value is Map) {
    final data = Map<String, dynamic>.from(value);
    final rawStatus = data['status']?.toString().trim() ?? '';
    final completed =
        rawStatus == 'completed' ||
        (data['completed_at']?.toString().trim().isNotEmpty ?? false);
    final subscribed =
        data['subscribed'] == true ||
        data['active'] == true ||
        completed ||
        rawStatus == 'skipped';
    return DbOnlineSubscriptionStatus(
      subscribed: subscribed,
      id: _intValue(data['id']),
      sourceType: data['source_type']?.toString() ?? sourceType,
      sourceId: _intValue(data['source_id']),
      status: subscribed
          ? rawStatus.isNotEmpty
                ? rawStatus
                : completed
                ? 'completed'
                : 'pending'
          : '',
      active: data['active'] == true,
      overdue: data['overdue'] == true,
    );
  }
  final subscribed = value == true;
  return DbOnlineSubscriptionStatus(
    subscribed: subscribed,
    sourceType: sourceType,
    status: subscribed ? 'pending' : '',
    active: subscribed,
  );
}

int? _intValue(Object? value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');

class DbOnlineSubscriptionQuery {
  const DbOnlineSubscriptionQuery({
    required this.serverId,
    required this.kind,
    required this.page,
    required this.limit,
    this.keyword = '',
    this.sourceType,
    this.sourceId,
    this.queueStatus = '',
  });

  final String serverId;
  final String kind;
  final int page;
  final int limit;
  final String keyword;
  final String? sourceType;
  final Object? sourceId;
  final String queueStatus;

  @override
  bool operator ==(Object other) =>
      other is DbOnlineSubscriptionQuery &&
      other.serverId == serverId &&
      other.kind == kind &&
      other.page == page &&
      other.limit == limit &&
      other.keyword == keyword &&
      other.sourceType == sourceType &&
      other.sourceId == sourceId &&
      other.queueStatus == queueStatus;

  @override
  int get hashCode => Object.hash(
    serverId,
    kind,
    page,
    limit,
    keyword,
    sourceType,
    sourceId,
    queueStatus,
  );
}

class DbOnlineSubscriptionStatusQuery {
  const DbOnlineSubscriptionStatusQuery({
    required this.serverId,
    required this.kind,
    required this.id,
    this.subType = 'series',
  });

  final String serverId;
  final String kind;
  final String id;
  final String subType;

  @override
  bool operator ==(Object other) =>
      other is DbOnlineSubscriptionStatusQuery &&
      other.serverId == serverId &&
      other.kind == kind &&
      other.id == id &&
      other.subType == subType;

  @override
  int get hashCode => Object.hash(serverId, kind, id, subType);
}

class DbOnlineSubscriptionStatus {
  const DbOnlineSubscriptionStatus({
    required this.subscribed,
    required this.sourceType,
    required this.status,
    required this.active,
    this.id,
    this.sourceId,
    this.overdue = false,
  });

  final bool subscribed;
  final int? id;
  final String sourceType;
  final int? sourceId;
  final String status;
  final bool active;
  final bool overdue;
}
