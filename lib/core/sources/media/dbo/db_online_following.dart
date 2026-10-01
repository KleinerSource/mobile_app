import 'package:flutter/foundation.dart';

import 'db_online_movie.dart';
import 'db_online_resource_merge.dart';

@immutable
class DbOnlineFollowingFilter {
  const DbOnlineFollowingFilter({
    this.category = '0',
    this.basic = const ['m'],
    this.styles = const [],
    this.year = '',
    this.month = '',
    this.sortBy = 'update',
    this.orderBy = 'desc',
  });

  final String category;
  final List<String> basic;
  final List<String> styles;
  final String year;
  final String month;
  final String sortBy;
  final String orderBy;
  String get filterBy => [
    category,
    't',
    basic.join(','),
    styles.join(','),
    year,
    '',
    month,
  ].join(':');

  List<String> get followStyleIds {
    final parts = filterBy.split(':');
    if (parts.length < 4 || parts[0] != '0' || parts[1] != 't') return const [];
    return _ids(parts[3]);
  }

  String get followExternalId {
    final ids = followStyleIds;
    return ids.isEmpty || ids.length > 5 ? '' : ids.join(',');
  }

  DbOnlineFollowingFilter copyWith({
    String? category,
    List<String>? basic,
    List<String>? styles,
    String? year,
    String? month,
    String? sortBy,
    String? orderBy,
  }) => DbOnlineFollowingFilter(
    category: category ?? this.category,
    basic: List.unmodifiable(basic ?? this.basic),
    styles: List.unmodifiable(styles ?? this.styles),
    year: year ?? this.year,
    month: month ?? this.month,
    sortBy: sortBy ?? this.sortBy,
    orderBy: orderBy ?? this.orderBy,
  );
}

@immutable
class DbOnlineFollowingPreset {
  const DbOnlineFollowingPreset({
    required this.id,
    required this.name,
    this.remark = '',
    required this.filter,
  });

  final int id;
  final String name;
  final String remark;
  final DbOnlineFollowingFilter filter;

  factory DbOnlineFollowingPreset.fromJson(Object? raw) {
    final json = _map(raw);
    return DbOnlineFollowingPreset(
      id: _int(json['id']),
      name: _text(json['name']),
      remark: _text(json['remark']),
      filter: DbOnlineFollowingFilter(
        category: _text(json['category']).isEmpty
            ? '0'
            : _text(json['category']),
        basic: _ids(
          json['basic'],
        ).where(const ['m', 'c', 's'].contains).toList(),
        styles: _ids(json['styles']),
        year: _text(json['year']),
        month: _text(json['month']),
        sortBy: _text(json['sort_by']) == 'release' ? 'release' : 'update',
      ),
    );
  }

  Map<String, dynamic> toJson({String? name, String? remark}) => {
    'name': name ?? this.name,
    'remark': remark ?? this.remark,
    'category': filter.category,
    'basic': filter.basic.join(','),
    'styles': filter.styles.join(','),
    'year': filter.year,
    'month': filter.month,
    'sort_by': filter.sortBy,
  };
}

@immutable
class DbOnlineFollowingStyle {
  const DbOnlineFollowingStyle({required this.id, required this.name});

  final String id;
  final String name;

  factory DbOnlineFollowingStyle.fromJson(Object? raw) {
    final json = _map(raw);
    final name = _text(json['name']);
    final id = _text(json['external_id']);
    return DbOnlineFollowingStyle(id: id.isEmpty ? name : id, name: name);
  }
}

@immutable
class DbOnlineFollowedUser {
  const DbOnlineFollowedUser({
    required this.userId,
    this.username = '',
    this.latestReviewAt = '',
    this.created = true,
  });

  final String userId;
  final String username;
  final String latestReviewAt;
  final bool created;

  String get displayName => username.isEmpty ? userId : username;

  bool get hasUpdate {
    final date = DateTime.tryParse(
      latestReviewAt.replaceAll('/', '-'),
    )?.toLocal();
    final today = DateTime.now();
    return date != null &&
        date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
  }

  factory DbOnlineFollowedUser.fromJson(Object? raw) {
    final json = _map(raw);
    return DbOnlineFollowedUser(
      userId: _text(json['user_id']),
      username: _text(json['username']),
      latestReviewAt: _text(json['latest_review_at']),
      created: json['created'] != false,
    );
  }
}

@immutable
class DbOnlineFollowedUsersRefresh {
  const DbOnlineFollowedUsersRefresh({
    required this.users,
    required this.failed,
  });

  final List<DbOnlineFollowedUser> users;
  final int failed;

  factory DbOnlineFollowedUsersRefresh.fromJson(Object? raw) {
    final json = _map(raw);
    return DbOnlineFollowedUsersRefresh(
      users: _list(json['users']).map(DbOnlineFollowedUser.fromJson).toList(),
      failed: _int(json['failed']),
    );
  }
}

@immutable
class DbOnlineReviewResourceItem {
  const DbOnlineReviewResourceItem({
    required this.reviewId,
    required this.movie,
    this.createdAt = '',
    this.magnets = const [],
    this.ed2ks = const [],
    this.magnetPayload = const [],
  });

  final int reviewId;
  final DbOnlineMovie movie;
  final String createdAt;
  final List<DbOnlineMagnet> magnets;
  final List<DbOnlineEd2k> ed2ks;
  // 元数据接口复用后端 MagnetInfo 契约，保留原始 match_flags 等字段。
  final List<Map<String, dynamic>> magnetPayload;

  factory DbOnlineReviewResourceItem.fromJson(Object? raw) {
    final json = _map(raw);
    final magnets = _list(json['magnets'])
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .toList();
    return DbOnlineReviewResourceItem(
      reviewId: _int(json['review_id']),
      movie: DbOnlineMovie.fromJson(_map(json['movie'])),
      createdAt: _text(json['created_at']),
      magnets: mergeDbOnlineMagnets({
        'javdb': magnets
            .map(DbOnlineMagnet.fromJson)
            .where((item) => item.magnet.isNotEmpty)
            .toList(),
      }),
      ed2ks: mergeDbOnlineEd2ks({
        'javdb': _list(json['ed2ks'])
            .map(DbOnlineEd2k.fromJson)
            .where((item) => item.ed2k.isNotEmpty)
            .toList(),
      }),
      magnetPayload: magnets,
    );
  }

  DbOnlineReviewResourceItem withMagnets(List<DbOnlineMagnet> value) =>
      DbOnlineReviewResourceItem(
        reviewId: reviewId,
        movie: movie,
        createdAt: createdAt,
        magnets: mergeDbOnlineMagnets({'javdb': value}),
        ed2ks: ed2ks,
        magnetPayload: magnetPayload,
      );
}

@immutable
class DbOnlineReviewResourcePage {
  const DbOnlineReviewResourcePage({
    required this.items,
    required this.page,
    required this.hasNext,
    this.username = '',
  });

  final List<DbOnlineReviewResourceItem> items;
  final int page;
  final bool hasNext;
  final String username;

  factory DbOnlineReviewResourcePage.fromJson(Object? raw) {
    final json = _map(raw);
    return DbOnlineReviewResourcePage(
      items: _list(json['items'])
          .map(DbOnlineReviewResourceItem.fromJson)
          .where((item) => item.magnets.isNotEmpty || item.ed2ks.isNotEmpty)
          .toList(),
      page: _int(json['page'], fallback: 1),
      hasNext: json['has_next'] == true,
      username: _text(json['username']),
    );
  }
}

Map<String, dynamic> _map(Object? raw) =>
    raw is Map ? Map<String, dynamic>.from(raw) : const {};
List<dynamic> _list(Object? raw) => raw is List ? raw : const [];
String _text(Object? raw) => raw?.toString().trim() ?? '';
int _int(Object? raw, {int fallback = 0}) =>
    raw is num ? raw.toInt() : int.tryParse(_text(raw)) ?? fallback;
List<String> _ids(Object? raw) => _text(raw)
    .split(',')
    .map((id) => id.trim())
    .where((id) => id.isNotEmpty)
    .toSet()
    .toList();
