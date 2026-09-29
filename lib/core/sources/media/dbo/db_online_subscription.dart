import 'package:flutter/foundation.dart';

@immutable
class DbOnlineSubscriptionCapabilities {
  const DbOnlineSubscriptionCapabilities({
    required this.database,
    required this.onlineAccount,
    required this.onlineQuery,
    this.reason = '',
  });

  final bool database;
  final bool onlineAccount;
  final bool onlineQuery;
  final String reason;

  factory DbOnlineSubscriptionCapabilities.fromJson(Object? raw) {
    final root = _map(raw);
    final data = _map(root['data']).isEmpty ? root : _map(root['data']);
    final capabilities = _map(data['capabilities']);
    return DbOnlineSubscriptionCapabilities(
      database: capabilities['database'] == true,
      onlineAccount: capabilities['online_account'] == true,
      onlineQuery: capabilities['online_query'] == true,
      reason: data['reason']?.toString().trim() ?? '',
    );
  }
}

@immutable
class DbOnlineSubscriptionItem {
  const DbOnlineSubscriptionItem({
    required this.id,
    required this.title,
    required this.kind,
    required this.data,
  });

  final String id;
  final String title;
  final String kind;
  final Map<String, dynamic> data;

  String get status => data['status']?.toString() ?? '';
  bool get active => data['active'] != false;

  factory DbOnlineSubscriptionItem.fromJson(
    Object? raw, {
    required String kind,
  }) {
    final data = _map(raw);
    return DbOnlineSubscriptionItem(
      id: _first(data, const [
        'video_code',
        'code',
        'actor_id',
        'external_id',
        'id',
        'video_id',
      ]),
      title: _first(data, const [
        'video_title',
        'actor_name',
        'series_name',
        'title',
        'name',
        'video_code',
      ]),
      kind: kind,
      data: Map<String, dynamic>.unmodifiable(data),
    );
  }
}

@immutable
class DbOnlineSubscriptionPage {
  const DbOnlineSubscriptionPage({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
    required this.hasMore,
  });

  final List<DbOnlineSubscriptionItem> items;
  final int page;
  final int limit;
  final int total;
  final bool hasMore;

  factory DbOnlineSubscriptionPage.fromJson(
    Object? raw, {
    required String kind,
    required List<String> itemKeys,
    int defaultPage = 1,
    int defaultLimit = 24,
  }) {
    final root = _map(raw);
    final nested = _map(root['data']);
    final data = nested.isEmpty ? root : nested;
    List<dynamic> rawItems = const [];
    for (final key in itemKeys) {
      if (data[key] is List) {
        rawItems = data[key] as List<dynamic>;
        break;
      }
    }
    final items = rawItems
        .map((item) => DbOnlineSubscriptionItem.fromJson(item, kind: kind))
        .where((item) => item.id.isNotEmpty || item.title.isNotEmpty)
        .toList(growable: false);
    final page = _intValue(data['page'] ?? data['current_page']) ?? defaultPage;
    final limit = _intValue(data['limit'] ?? data['page_size']) ?? defaultLimit;
    final total = _intValue(data['total']) ?? items.length;
    final totalPages = _intValue(data['total_pages'] ?? data['total_page']);
    final explicitMore = data['has_more'];
    return DbOnlineSubscriptionPage(
      items: items,
      page: page,
      limit: limit,
      total: total,
      hasMore: explicitMore is bool
          ? explicitMore
          : totalPages != null
          ? page < totalPages
          : total > page * limit || (items.length >= limit && limit > 0),
    );
  }
}

Map<String, dynamic> _map(Object? raw) =>
    raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

String _first(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return '';
}

int? _intValue(Object? value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString().trim() ?? '');
