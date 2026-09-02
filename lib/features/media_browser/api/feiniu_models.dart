import 'package:flutter/foundation.dart';

import '../models/media_browser_models.dart';

@immutable
class FeiniuUser {
  const FeiniuUser({required this.id, required this.name});

  final String id;
  final String name;

  factory FeiniuUser.fromJson(Map<String, dynamic> json) => FeiniuUser(
    id: _string(json['id'] ?? json['user_id'] ?? json['uid'] ?? json['guid']),
    name: _string(json['name'] ?? json['username'] ?? json['user_name']),
  );
}

@immutable
class FeiniuVersion {
  const FeiniuVersion({required this.version, this.mediaServiceVersion = ''});

  final String version;
  final String mediaServiceVersion;

  factory FeiniuVersion.fromJson(Map<String, dynamic> json) => FeiniuVersion(
    version: _string(json['version']),
    mediaServiceVersion: _string(json['mediasrvVersion']),
  );
}

@immutable
class FeiniuMediaDb {
  const FeiniuMediaDb({
    required this.guid,
    required this.name,
    this.category = '',
    this.topDir = '',
    this.dir = '',
  });

  final String guid;
  final String name;
  final String category;
  final String topDir;
  final String dir;

  factory FeiniuMediaDb.fromJson(Map<String, dynamic> json) => FeiniuMediaDb(
    guid: _string(json['guid'] ?? json['id'] ?? json['mdb_guid']),
    name: _string(json['name'] ?? json['mdb_name'] ?? json['title']),
    category: _string(json['category'] ?? json['mdb_category']),
    topDir: _string(json['top_dir']),
    dir: _string(json['dir']),
  );

  MediaBrowserItem toItem() => MediaBrowserItem(
    id: guid,
    name: name,
    type: 'CollectionFolder',
    collectionType: category,
    childCount: null,
  );
}

@immutable
class FeiniuItem {
  const FeiniuItem({
    required this.guid,
    required this.title,
    required this.type,
    this.parentGuid = '',
    this.ancestorGuid = '',
    this.tvTitle = '',
    this.parentTitle = '',
    this.poster,
    this.stillPath,
    this.overview,
    this.airDate,
    this.runtimeMinutes = 0,
    this.durationSeconds = 0,
    this.resumeSeconds = 0,
    this.isFavorite = false,
    this.isWatched = false,
    this.voteAverage,
    this.seasonNumber,
    this.episodeNumber,
    this.numberOfSeasons,
    this.numberOfEpisodes,
    this.localNumberOfSeasons,
    this.localNumberOfEpisodes,
    this.canPlay = false,
    this.mediaGuid = '',
    this.videoGuid = '',
    this.audioGuid = '',
    this.subtitleGuid = '',
    this.fileName = '',
  });

  final String guid;
  final String title;
  final String type;
  final String parentGuid;
  final String ancestorGuid;
  final String tvTitle;
  final String parentTitle;
  final String? poster;
  final String? stillPath;
  final String? overview;
  final String? airDate;
  final int runtimeMinutes;
  final int durationSeconds;
  final int resumeSeconds;
  final bool isFavorite;
  final bool isWatched;
  final double? voteAverage;
  final int? seasonNumber;
  final int? episodeNumber;
  final int? numberOfSeasons;
  final int? numberOfEpisodes;
  final int? localNumberOfSeasons;
  final int? localNumberOfEpisodes;
  final bool canPlay;
  final String mediaGuid;
  final String videoGuid;
  final String audioGuid;
  final String subtitleGuid;
  final String fileName;

  bool get isEpisode => type == 'Episode';
  bool get isAudio => type == 'Audio';
  bool get isPlayable => canPlay || type == 'Movie' || isEpisode || isAudio;

  factory FeiniuItem.fromJson(Map<String, dynamic> json) {
    final type = _itemType(json['type']);
    final mediaStream = json['media_stream'];
    final streamMap = mediaStream is Map
        ? Map<String, dynamic>.from(mediaStream)
        : const <String, dynamic>{};
    final duration = _int(json['duration']);
    final runtime = _int(json['runtime']);
    final resume = _int(json['watched_ts'] ?? json['ts']);
    return FeiniuItem(
      guid: _string(json['guid'] ?? json['id']),
      title: _string(json['title'] ?? json['name']),
      type: type,
      parentGuid: _string(json['parent_guid']),
      ancestorGuid: _string(json['ancestor_guid']),
      tvTitle: _string(json['tv_title'] ?? json['series_name']),
      parentTitle: _string(json['parent_title'] ?? json['season_name']),
      poster: _optional(json['poster'] ?? json['posters']),
      stillPath: _optional(json['still_path']),
      overview: _optional(json['overview']),
      airDate: _optional(json['air_date']),
      runtimeMinutes: runtime,
      durationSeconds: duration > 0 ? duration : runtime * 60,
      resumeSeconds: resume,
      isFavorite: _bool(json['is_favorite']),
      isWatched: _bool(json['watched'] ?? json['is_watched']),
      voteAverage: _double(json['vote_average']),
      seasonNumber: _optionalInt(json['season_number']),
      episodeNumber: _optionalInt(json['episode_number']),
      numberOfSeasons: _optionalInt(json['number_of_seasons']),
      numberOfEpisodes: _optionalInt(json['number_of_episodes']),
      localNumberOfSeasons: _optionalInt(json['local_number_of_seasons']),
      localNumberOfEpisodes: _optionalInt(json['local_number_of_episodes']),
      canPlay: _bool(json['can_play']),
      mediaGuid: _string(json['media_guid'] ?? streamMap['media_guid']),
      videoGuid: _string(json['video_guid']),
      audioGuid: _string(json['audio_guid']),
      subtitleGuid: _string(json['subtitle_guid']),
      fileName: _string(json['file_name']),
    );
  }

  MediaBrowserItem toMediaBrowserItem() {
    final seconds = durationSeconds > 0 ? durationSeconds : runtimeMinutes * 60;
    final mediaSource = mediaGuid.isEmpty
        ? const <MediaBrowserMediaSourceDto>[]
        : [
            MediaBrowserMediaSourceDto(
              id: mediaGuid,
              path: fileName.isEmpty ? null : fileName,
              container: _extension(fileName),
            ),
          ];
    return MediaBrowserItem(
      id: guid,
      name: title,
      type: type,
      collectionType: type == 'CollectionFolder' ? parentTitle : null,
      productionYear: _year(airDate),
      communityRating: voteAverage,
      runTimeTicks: secondsToMediaBrowserTicks(seconds),
      overview: overview,
      userData: MediaBrowserUserData(
        playbackPositionTicks: secondsToMediaBrowserTicks(resumeSeconds),
        isFavorite: isFavorite,
        played: isWatched,
      ),
      seriesId: ancestorGuid.isEmpty ? null : ancestorGuid,
      seriesName: tvTitle.isEmpty ? null : tvTitle,
      seasonId: parentGuid.isEmpty ? null : parentGuid,
      parentIndexNumber: seasonNumber,
      indexNumber: episodeNumber,
      album: type == 'Audio' && parentTitle.isNotEmpty ? parentTitle : null,
      albumId: type == 'Audio' && parentGuid.isNotEmpty ? parentGuid : null,
      albumArtist: null,
      primaryImageTag: poster,
      backdropImageTags: stillPath == null ? const [] : [stillPath!],
      childCount: numberOfEpisodes,
      mediaSources: mediaSource,
    );
  }
}

@immutable
class FeiniuItemPage {
  const FeiniuItemPage({
    required this.items,
    required this.total,
    this.startIndex = 0,
    this.limit = 0,
  });

  final List<FeiniuItem> items;
  final int total;
  final int startIndex;
  final int limit;

  bool get hasMore => startIndex + items.length < total;

  factory FeiniuItemPage.fromData(
    Object? data, {
    int startIndex = 0,
    int limit = 0,
  }) {
    final map = data is Map ? Map<String, dynamic>.from(data) : const {};
    final raw = map['list'] ?? map['items'] ?? (data is List ? data : null);
    final items = raw is List
        ? raw
              .whereType<Map>()
              .map((item) => FeiniuItem.fromJson(Map<String, dynamic>.from(item)))
              .where((item) => item.guid.isNotEmpty)
              .toList(growable: false)
        : const <FeiniuItem>[];
    return FeiniuItemPage(
      items: items,
      total: _int(map['total'] ?? map['total_count'] ?? items.length),
      startIndex: _int(map['start_index'] ?? startIndex),
      limit: _int(map['limit'] ?? limit),
    );
  }
}

@immutable
class FeiniuStream {
  const FeiniuStream({
    required this.guid,
    required this.title,
    required this.kind,
    this.language,
    this.index = -1,
    this.isDefault = false,
    this.isExternal = false,
  });

  final String guid;
  final String title;
  final String kind;
  final String? language;
  final int index;
  final bool isDefault;
  final bool isExternal;

  factory FeiniuStream.fromJson(Map<String, dynamic> json, String kind) =>
      FeiniuStream(
        guid: _string(json['guid'] ?? json['id']),
        title: _string(json['title'] ?? json['name'] ?? json['codec_name']),
        kind: kind,
        language: _optional(json['language'] ?? json['lan']),
        index: _int(json['index']),
        isDefault: _bool(json['is_default']),
        isExternal: _bool(json['is_external']),
      );
}

@immutable
class FeiniuStreamList {
  const FeiniuStreamList({
    this.video = const [],
    this.audio = const [],
    this.subtitle = const [],
  });

  final List<FeiniuStream> video;
  final List<FeiniuStream> audio;
  final List<FeiniuStream> subtitle;

  factory FeiniuStreamList.fromData(Object? data) {
    final map = data is Map ? Map<String, dynamic>.from(data) : const {};
    List<FeiniuStream> read(String key, String kind) {
      final raw = map[key];
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((item) => FeiniuStream.fromJson(Map<String, dynamic>.from(item), kind))
          .where((item) => item.guid.isNotEmpty)
          .toList(growable: false);
    }
    return FeiniuStreamList(
      video: read('video_streams', 'video'),
      audio: read('audio_streams', 'audio'),
      subtitle: read('subtitle_streams', 'subtitle'),
    );
  }
}

@immutable
class FeiniuPlayInfo {
  const FeiniuPlayInfo({
    required this.itemGuid,
    this.mediaGuid = '',
    this.videoGuid = '',
    this.audioGuid = '',
    this.subtitleGuid = '',
    this.playLink = '',
    this.positionSeconds = 0,
    this.durationSeconds = 0,
  });

  final String itemGuid;
  final String mediaGuid;
  final String videoGuid;
  final String audioGuid;
  final String subtitleGuid;
  final String playLink;
  final int positionSeconds;
  final int durationSeconds;

  factory FeiniuPlayInfo.fromData(Object? data) {
    final map = data is Map ? Map<String, dynamic>.from(data) : const {};
    final item = map['item'];
    final itemMap = item is Map ? Map<String, dynamic>.from(item) : const {};
    return FeiniuPlayInfo(
      itemGuid: _string(map['item_guid'] ?? map['guid'] ?? itemMap['guid']),
      mediaGuid: _string(map['media_guid'] ?? itemMap['media_guid']),
      videoGuid: _string(map['video_guid'] ?? itemMap['video_guid']),
      audioGuid: _string(map['audio_guid'] ?? itemMap['audio_guid']),
      subtitleGuid: _string(map['subtitle_guid'] ?? itemMap['subtitle_guid']),
      playLink: _string(map['play_link'] ?? map['url']),
      positionSeconds: _int(map['ts'] ?? itemMap['watched_ts']),
      durationSeconds: _int(map['duration'] ?? itemMap['duration']),
    );
  }
}

@immutable
class FeiniuPlayRecord {
  const FeiniuPlayRecord({
    required this.itemGuid,
    required this.mediaGuid,
    required this.videoGuid,
    required this.audioGuid,
    required this.subtitleGuid,
    required this.playLink,
    required this.positionSeconds,
    required this.durationSeconds,
  });

  final String itemGuid;
  final String mediaGuid;
  final String videoGuid;
  final String audioGuid;
  final String subtitleGuid;
  final String playLink;
  final int positionSeconds;
  final int durationSeconds;

  Map<String, dynamic> toJson() => {
    'item_guid': itemGuid,
    'media_guid': mediaGuid,
    'video_guid': videoGuid,
    'audio_guid': audioGuid,
    'subtitle_guid': subtitleGuid,
    'play_link': playLink,
    'ts': positionSeconds,
    'duration': durationSeconds,
  };
}

String _itemType(Object? value) {
  final normalized = _string(value).toLowerCase();
  return switch (normalized) {
    'movie' => 'Movie',
    'series' || 'tv' || 'tvshow' => 'Series',
    'season' => 'Season',
    'episode' => 'Episode',
    'musicalbum' || 'album' => 'MusicAlbum',
    'audio' || 'song' || 'track' => 'Audio',
    'collectionfolder' || 'folder' => 'CollectionFolder',
    _ => _string(value),
  };
}

String _string(Object? value) => value?.toString().trim() ?? '';

String? _optional(Object? value) {
  final result = _string(value);
  return result.isEmpty ? null : result;
}

int _int(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(_string(value)) ?? 0;
}

int? _optionalInt(Object? value) {
  final result = _int(value);
  return result == 0 && _string(value).isEmpty ? null : result;
}

double? _double(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(_string(value));
}

bool _bool(Object? value) => value == true || value == 1 || value == '1';

int? _year(String? value) {
  final match = RegExp(r'^(\d{4})').firstMatch(value ?? '');
  return match == null ? null : int.tryParse(match.group(1)!);
}

String? _extension(String value) {
  final index = value.lastIndexOf('.');
  if (index < 0 || index == value.length - 1) return null;
  return value.substring(index + 1).toLowerCase();
}
