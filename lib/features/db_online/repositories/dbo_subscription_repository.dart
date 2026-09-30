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

  Future<bool> isSubscribed(DbOnlineSubscriptionStatusQuery query) async {
    checkServer(query.serverId);
    final result = await api.subscriptionStatus(
      type: query.kind,
      id: query.id,
      subType: query.subType,
    );
    if (result is! Map) return false;
    final value = result[query.id] ?? result[query.id.toUpperCase()];
    if (value is Map) return value['subscribed'] == true;
    return value == true;
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
          if (query.keyword.trim().isNotEmpty) 'keyword': query.keyword.trim(),
        },
      ),
      'series' => await api.seriesSubscriptions(
        query: {
          'page': query.page,
          'limit': query.limit,
          'sub_type': 'all',
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
