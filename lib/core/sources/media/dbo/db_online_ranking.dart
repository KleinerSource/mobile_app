import 'package:flutter/foundation.dart';

/// 演员榜条目（`GET /actors`）。
@immutable
class DbOnlineRankingActor {
  const DbOnlineRankingActor({
    required this.id,
    required this.name,
    this.nameZht,
    this.otherName,
    this.avatarUrl,
    this.uncensored = false,
  });

  final String id;
  final String name;
  final String? nameZht;
  final String? otherName;
  final String? avatarUrl;
  final bool uncensored;

  factory DbOnlineRankingActor.fromJson(Object? raw) {
    if (raw is! Map) return const DbOnlineRankingActor(id: '', name: '');
    final json = Map<String, dynamic>.from(raw);
    return DbOnlineRankingActor(
      id: _string(json['id']) ?? _string(json['external_id']) ?? '',
      name: _string(json['name']) ?? '',
      nameZht: _string(json['name_zht']),
      otherName: _string(json['other_name']),
      avatarUrl: _string(json['avatar_url']),
      uncensored: json['uncensored'] == true,
    );
  }
}

@immutable
class DbOnlineRankingActorResult {
  const DbOnlineRankingActorResult({required this.actors, this.total});

  final List<DbOnlineRankingActor> actors;
  final int? total;

  factory DbOnlineRankingActorResult.fromJson(Object? raw) {
    if (raw is! Map) {
      return const DbOnlineRankingActorResult(
        actors: <DbOnlineRankingActor>[],
      );
    }
    final json = Map<String, dynamic>.from(raw);
    final actors = json['actors'] is List
        ? (json['actors'] as List)
              .map(DbOnlineRankingActor.fromJson)
              .where((actor) => actor.id.isNotEmpty && actor.name.isNotEmpty)
              .toList(growable: false)
        : const <DbOnlineRankingActor>[];
    return DbOnlineRankingActorResult(
      actors: actors,
      total: _int(json['total']) ?? actors.length,
    );
  }
}

/// Top250 一键订阅结果摘要（`POST /top250/subscribe`）。
@immutable
class DbOnlineTop250SubscribeResult {
  const DbOnlineTop250SubscribeResult({
    this.added = 0,
    this.failed = 0,
    this.skippedDuplicate = 0,
    this.skippedBlacklist = 0,
    this.skippedSubscribed = 0,
    this.skippedLibrary = 0,
    this.skippedInvalid = 0,
  });

  final int added;
  final int failed;
  final int skippedDuplicate;
  final int skippedBlacklist;
  final int skippedSubscribed;
  final int skippedLibrary;
  final int skippedInvalid;

  factory DbOnlineTop250SubscribeResult.fromJson(Object? raw) {
    if (raw is! Map) return const DbOnlineTop250SubscribeResult();
    final json = Map<String, dynamic>.from(raw);
    return DbOnlineTop250SubscribeResult(
      added: _int(json['added']) ?? 0,
      failed: _int(json['failed']) ?? 0,
      skippedDuplicate: _int(json['skipped_duplicate']) ?? 0,
      skippedBlacklist: _int(json['skipped_blacklist']) ?? 0,
      skippedSubscribed: _int(json['skipped_subscribed']) ?? 0,
      skippedLibrary: _int(json['skipped_library']) ?? 0,
      skippedInvalid: _int(json['skipped_invalid']) ?? 0,
    );
  }
}

/// 排行榜自动订阅配置（`GET/PUT /subs/ranking` 的 `config` 分区）。
@immutable
class DbOnlineRankingAutoConfig {
  const DbOnlineRankingAutoConfig({
    this.enabled = false,
    this.checkTime = '09:00',
    this.periods = const ['daily'],
    this.contentTypes = const [0],
    this.topN = 10,
  });

  final bool enabled;
  final String checkTime;
  final List<String> periods;
  final List<int> contentTypes;
  final int topN;

  static const validPeriods = {'daily', 'weekly', 'monthly'};
  static const minTopN = 1;
  static const maxTopN = 50;

  factory DbOnlineRankingAutoConfig.fromJson(Object? raw) {
    if (raw is! Map) return const DbOnlineRankingAutoConfig();
    final json = Map<String, dynamic>.from(raw);
    final periods = json['periods'] is List
        ? (json['periods'] as List)
              .map((item) => item.toString())
              .where(validPeriods.contains)
              .toList(growable: false)
        : const <String>['daily'];
    final contentTypes = json['content_types'] is List
        ? (json['content_types'] as List)
              .map(_int)
              .whereType<int>()
              .where((type) => type >= 0 && type <= 3)
              .toList(growable: false)
        : const <int>[0];
    final topN = _int(json['top_n']) ?? 10;
    return DbOnlineRankingAutoConfig(
      enabled: json['enabled'] == true,
      checkTime: _string(json['check_time']) ?? '09:00',
      periods: periods.isEmpty ? const ['daily'] : periods,
      contentTypes: contentTypes.isEmpty ? const [0] : contentTypes,
      topN: topN < minTopN || topN > maxTopN ? 10 : topN,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'check_time': checkTime,
    'periods': periods,
    'content_types': contentTypes,
    'top_n': topN,
  };

  DbOnlineRankingAutoConfig copyWith({
    bool? enabled,
    String? checkTime,
    List<String>? periods,
    List<int>? contentTypes,
    int? topN,
  }) => DbOnlineRankingAutoConfig(
    enabled: enabled ?? this.enabled,
    checkTime: checkTime ?? this.checkTime,
    periods: periods ?? this.periods,
    contentTypes: contentTypes ?? this.contentTypes,
    topN: topN ?? this.topN,
  );
}

String? _string(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

int? _int(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString().trim() ?? '');
}
