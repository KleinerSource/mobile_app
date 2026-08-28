import 'package:flutter/foundation.dart';

@immutable
class DbOnlineActorSearchItem {
  const DbOnlineActorSearchItem({
    required this.id,
    required this.name,
    this.nameZht,
    this.otherName,
    this.gender,
    this.avatarUrl,
    this.videosCount = 0,
  });

  final String id;
  final String name;
  final String? nameZht;
  final String? otherName;
  final int? gender;
  final String? avatarUrl;
  final int videosCount;

  factory DbOnlineActorSearchItem.fromJson(Object? raw) {
    if (raw is! Map) {
      return const DbOnlineActorSearchItem(id: '', name: '');
    }
    final json = Map<String, dynamic>.from(raw);
    return DbOnlineActorSearchItem(
      id: _searchString(json['id']) ?? _searchString(json['external_id']) ?? '',
      name: _searchString(json['name']) ?? '',
      nameZht: _searchString(json['name_zht']),
      otherName: _searchString(json['other_name']),
      gender: _searchInt(json['gender']),
      avatarUrl: _searchString(json['avatar_url']),
      videosCount:
          _searchInt(json['videos_count'] ?? json['movies_count']) ?? 0,
    );
  }
}

@immutable
class DbOnlineActorSearchResult {
  const DbOnlineActorSearchResult({required this.actors, this.total});

  final List<DbOnlineActorSearchItem> actors;
  final int? total;
}

@immutable
class DbOnlineSearchEntity {
  const DbOnlineSearchEntity({
    required this.id,
    required this.name,
    this.imageUrl,
    this.moviesCount = 0,
  });

  final String id;
  final String name;
  final String? imageUrl;
  final int moviesCount;

  factory DbOnlineSearchEntity.fromJson(Object? raw) {
    if (raw is! Map) {
      return const DbOnlineSearchEntity(id: '', name: '');
    }
    final json = Map<String, dynamic>.from(raw);
    return DbOnlineSearchEntity(
      id: _searchString(json['id']) ?? _searchString(json['external_id']) ?? '',
      name: _searchString(json['name']) ?? _searchString(json['title']) ?? '',
      imageUrl: _searchString(
        json['image_url'] ?? json['cover_url'] ?? json['thumb_url'],
      ),
      moviesCount:
          _searchInt(
            json['movies_count'] ?? json['videos_count'] ?? json['count'],
          ) ??
          0,
    );
  }
}

@immutable
class DbOnlineSearchEntityPage {
  const DbOnlineSearchEntityPage({
    required this.items,
    required this.page,
    required this.limit,
    this.total,
    required this.hasMore,
  });

  final List<DbOnlineSearchEntity> items;
  final int page;
  final int limit;
  final int? total;
  final bool hasMore;
}

String? _searchString(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

int? _searchInt(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString().trim() ?? '');
}
