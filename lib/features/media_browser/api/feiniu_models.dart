import 'package:flutter/foundation.dart';

import '../models/media_browser_models.dart';

@immutable
class FeiniuUser {
  const FeiniuUser({
    required this.id,
    required this.name,
    this.isAdmin = false,
  });

  final String id;
  final String name;
  final bool isAdmin;

  factory FeiniuUser.fromJson(Map<String, dynamic> json) {
    final role = _string(json['role'] ?? json['user_role']).toLowerCase();
    return FeiniuUser(
      id: _string(json['id'] ?? json['user_id'] ?? json['uid'] ?? json['guid']),
      name: _string(json['name'] ?? json['username'] ?? json['user_name']),
      isAdmin:
          _bool(
            json['is_admin'] ??
                json['isAdmin'] ??
                json['admin'] ??
                json['is_superuser'],
          ) ||
          role == 'admin' ||
          role == 'administrator',
    );
  }
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
    this.dirList = const <String>[],
    this.topDir = '',
    this.dir = '',
    this.poster,
    this.language = '',
    this.includeAdult = false,
    this.skipFilesize = 0,
    this.autoProgressThumb = true,
    this.preferLocalNfo = true,
    this.subtitleLanguage = '',
    this.autoScrapSubtitle = true,
    this.enabled = true,
  });

  final String guid;
  final String name;
  final String category;
  final List<String> dirList;
  final String topDir;
  final String dir;
  final String? poster;
  final String language;
  final bool includeAdult;
  final int skipFilesize;
  final bool autoProgressThumb;
  final bool preferLocalNfo;
  final String subtitleLanguage;
  final bool autoScrapSubtitle;
  final bool enabled;

  factory FeiniuMediaDb.fromJson(Map<String, dynamic> json) {
    final listedPaths = _pathList(
      json['dir_list'] ?? json['dirs'] ?? json['paths'],
    );
    final fallbackPaths = _pathList(json['dir'] ?? json['top_dir']);
    return FeiniuMediaDb(
      guid: _string(json['guid'] ?? json['id'] ?? json['mdb_guid']),
      name: _string(json['name'] ?? json['mdb_name'] ?? json['title']),
      category: _string(json['category'] ?? json['mdb_category']),
      dirList: listedPaths.isNotEmpty ? listedPaths : fallbackPaths,
      topDir: _string(json['top_dir']),
      dir: _string(json['dir']),
      poster: _imagePath(
        json['poster'] ?? json['posters'] ?? json['image'] ?? json['cover'],
      ),
      language: _string(json['lan'] ?? json['language']),
      includeAdult: _bool(json['include_adult'] ?? json['includeAdult']),
      skipFilesize: _int(json['skip_filesize'] ?? json['skipFilesize']),
      autoProgressThumb: _flag(
        json['auto_progress_thumb'] ?? json['autoProgressThumb'],
        defaultValue: true,
      ),
      preferLocalNfo: _flag(
        json['prefer_local_nfo'] ?? json['preferLocalNfo'],
        defaultValue: true,
      ),
      subtitleLanguage: _string(
        json['subtitle_lan'] ?? json['subtitleLanguage'],
      ),
      autoScrapSubtitle: _flag(
        json['auto_scrap_subtitle'] ?? json['autoScrapSubtitle'],
        defaultValue: true,
      ),
      enabled: _flag(
        json['enabled'] ?? json['enable'] ?? json['is_enabled'],
        defaultValue: true,
      ),
    );
  }

  /// `/mdb/create` 和 `/mdb/{guid}` 共用的飞牛配置字段。
  Map<String, dynamic> get managementOptions => {
    'lan': language,
    'include_adult': includeAdult,
    'skip_filesize': skipFilesize,
    'auto_progress_thumb': autoProgressThumb ? 1 : 0,
    'prefer_local_nfo': preferLocalNfo ? 1 : 0,
    'subtitle_lan': subtitleLanguage,
    'auto_scrap_subtitle': autoScrapSubtitle ? 1 : 0,
  };

  MediaBrowserItem toItem() => MediaBrowserItem(
    id: guid,
    name: name,
    type: 'CollectionFolder',
    collectionType: category,
    primaryImageTag: poster ?? '/mediadb/$guid/poster.jpg',
    childCount: null,
  );
}

@immutable
class FeiniuPerson {
  const FeiniuPerson({
    required this.id,
    required this.name,
    this.originalName,
    this.role,
    this.job,
    this.profilePath,
    this.order = 0,
  });

  final String id;
  final String name;
  final String? originalName;
  final String? role;
  final String? job;
  final String? profilePath;
  final int order;

  factory FeiniuPerson.fromJson(Map<String, dynamic> json) => FeiniuPerson(
    id: _string(
      json['person_guid'] ?? json['person_id'] ?? json['guid'] ?? json['id'],
    ),
    name: _string(json['name'] ?? json['original_name'] ?? json['title']),
    originalName: _optional(json['original_name']),
    role: _optional(
      json['role'] ?? json['character'] ?? json['character_name'],
    ),
    job: _optional(json['job'] ?? json['department']),
    profilePath: _imagePath(
      json['profile_path'] ??
          json['profile'] ??
          json['avatar'] ??
          json['image'] ??
          json['poster'] ??
          json['profile_image'] ??
          json['headshot'],
    ),
    order: _int(json['order'] ?? json['sort'] ?? json['cast_order']),
  );

  MediaBrowserPerson toMediaBrowserPerson() {
    final rawJob = (job ?? '').toLowerCase();
    final type = rawJob.contains('director')
        ? 'Director'
        : rawJob.contains('actor') || rawJob.contains('cast')
        ? 'Actor'
        : (job ?? '');
    return MediaBrowserPerson(
      id: id,
      name: name,
      role: role,
      type: type,
      profilePath: profilePath,
    );
  }
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
    this.backdrops = const <String>[],
    this.thumbPath,
    this.overview,
    this.airDate,
    this.originalTitle,
    this.genres = const <String>[],
    this.people = const <MediaBrowserPerson>[],
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
    this.fileSize,
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
  final List<String> backdrops;
  final String? thumbPath;
  final String? overview;
  final String? airDate;
  final String? originalTitle;
  final List<String> genres;
  final List<MediaBrowserPerson> people;
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
  final int? fileSize;

  bool get isEpisode => type == 'Episode';
  bool get isAudio => type == 'Audio';
  bool get isPlayable => canPlay || type == 'Movie' || isEpisode || isAudio;

  factory FeiniuItem.fromJson(
    Map<String, dynamic> json, {
    Map<String, String>? genreNames,
  }) {
    final type = _itemType(json['type'] ?? json['item_type']);
    final mediaStream = json['media_stream'];
    final streamMap = mediaStream is Map
        ? Map<String, dynamic>.from(mediaStream)
        : const <String, dynamic>{};
    final duration = _int(json['duration']);
    final runtime = _int(json['runtime']);
    final resume = _int(json['watched_ts'] ?? json['ts']);
    final stillPath = _imagePath(
      json['still_path'] ?? json['still'] ?? json['backdrop_path'],
    );
    final backdrops = _imagePaths(
      json['backdrops'] ??
          json['backdrop'] ??
          json['backdrop_paths'] ??
          json['fanart'] ??
          json['fanarts'],
    );
    return FeiniuItem(
      guid: _string(json['guid'] ?? json['id']),
      title: _string(json['title'] ?? json['name'] ?? json['original_title']),
      type: type,
      parentGuid: _string(json['parent_guid']),
      ancestorGuid: _string(json['ancestor_guid']),
      tvTitle: _string(json['tv_title'] ?? json['series_name']),
      parentTitle: _string(json['parent_title'] ?? json['season_name']),
      poster: _imagePath(
        json['poster'] ??
            json['posters'] ??
            json['primary_image'] ??
            json['poster_path'] ??
            json['poster_url'] ??
            json['cover'] ??
            json['cover_path'] ??
            json['image'],
      ),
      stillPath: stillPath,
      backdrops: backdrops.isEmpty && stillPath != null
          ? [stillPath]
          : backdrops,
      thumbPath: _imagePath(
        json['thumb'] ??
            json['thumb_path'] ??
            json['thumbnail'] ??
            json['thumbnail_path'],
      ),
      overview: _optional(json['overview']),
      airDate: _optional(
        json['release_date'] ??
            json['first_air_date'] ??
            json['air_date'] ??
            json['last_air_date'],
      ),
      originalTitle: _optional(json['original_title'] ?? json['original_name']),
      genres: _stringList(json['genres'] ?? json['genre'], genreNames),
      people: _people(json['people'] ?? json['cast_and_crew']),
      runtimeMinutes: runtime,
      durationSeconds: duration > 0 ? duration : runtime * 60,
      resumeSeconds: resume,
      isFavorite: _bool(json['is_favorite']),
      isWatched: _bool(json['watched'] ?? json['is_watched']),
      voteAverage: _double(
        json['vote_average'] ?? json['rating'] ?? json['score'],
      ),
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
      fileName: _string(json['file_name'] ?? json['file_path'] ?? json['path']),
      fileSize: _optionalInt(
        json['file_size'] ?? json['size_bytes'] ?? json['size'],
      ),
    );
  }

  MediaBrowserItem toMediaBrowserItem({
    List<String>? resolvedGenres,
    List<MediaBrowserPerson>? resolvedPeople,
    FeiniuStreamList? streamList,
  }) {
    final isSeasonItem = type == 'Season';
    final seconds = durationSeconds > 0 ? durationSeconds : runtimeMinutes * 60;
    final fallbackBackdrop = stillPath;
    final imageBackdrops = backdrops.isEmpty && fallbackBackdrop != null
        ? <String>[fallbackBackdrop]
        : backdrops;
    final streams = streamList ?? const FeiniuStreamList();
    final primaryImage =
        poster ??
        (guid.isEmpty
            ? null
            : '/mediadb/${Uri.encodeComponent(guid)}/poster.jpg');
    final file = streams.files.isEmpty
        ? null
        : streams.files.firstWhere(
            (item) => item.mediaGuid == mediaGuid && item.mediaGuid.isNotEmpty,
            orElse: () => streams.files.first,
          );
    final resolvedMediaGuid = mediaGuid.isNotEmpty
        ? mediaGuid
        : file?.mediaGuid ?? '';
    final resolvedPath = file?.path.isNotEmpty == true ? file!.path : fileName;
    final mediaSource = resolvedMediaGuid.isEmpty
        ? const <MediaBrowserMediaSourceDto>[]
        : [
            MediaBrowserMediaSourceDto(
              id: resolvedMediaGuid,
              path: resolvedPath.isEmpty ? null : resolvedPath,
              container: file?.container?.trim().isNotEmpty == true
                  ? file!.container
                  : _extension(resolvedPath),
              protocol: 'http',
              sizeInBytes: file?.sizeInBytes ?? fileSize,
              supportsDirectPlay: true,
              supportsDirectStream: true,
              mediaStreams: [
                for (final stream in [
                  ...streams.video,
                  ...streams.audio,
                  ...streams.subtitle,
                ])
                  stream.toMediaBrowserStream(),
              ],
            ),
          ];
    return MediaBrowserItem(
      id: guid,
      name: title,
      type: type,
      collectionType: type == 'CollectionFolder' ? parentTitle : null,
      originalTitle: originalTitle,
      productionYear: _year(airDate),
      communityRating: voteAverage,
      runTimeTicks: secondsToMediaBrowserTicks(seconds),
      overview: overview,
      genres: resolvedGenres ?? genres,
      people: resolvedPeople ?? people,
      userData: MediaBrowserUserData(
        playbackPositionTicks: secondsToMediaBrowserTicks(resumeSeconds),
        isFavorite: isFavorite,
        played: isWatched,
      ),
      seriesId: ancestorGuid.isEmpty ? null : ancestorGuid,
      seriesName: tvTitle.isEmpty ? null : tvTitle,
      seasonId: parentGuid.isEmpty ? null : parentGuid,
      // 飞牛的 Season 返回项把该季集数放在 episode_number；通用模型的
      // indexNumber 对 Season 表示季度号，对 Episode 才表示集号。
      parentIndexNumber: isSeasonItem ? null : seasonNumber,
      indexNumber: isSeasonItem ? seasonNumber : episodeNumber,
      album: type == 'Audio' && parentTitle.isNotEmpty ? parentTitle : null,
      albumId: type == 'Audio' && parentGuid.isNotEmpty ? parentGuid : null,
      albumArtist: null,
      primaryImageTag: primaryImage,
      backdropImageTags: imageBackdrops,
      thumbImageTag: thumbPath,
      childCount: numberOfEpisodes ?? localNumberOfEpisodes,
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
              .map(
                (item) => FeiniuItem.fromJson(Map<String, dynamic>.from(item)),
              )
              .where((item) => item.guid.isNotEmpty)
              .toList(growable: false)
        : const <FeiniuItem>[];
    final responseLimit = _int(map['limit'] ?? map['page_size']);
    final resolvedLimit = responseLimit > 0 ? responseLimit : limit;
    final responsePage = _int(map['page']);
    final resolvedStartIndex = map.containsKey('start_index')
        ? _int(map['start_index'])
        : responsePage > 0 && resolvedLimit > 0
        ? (responsePage - 1) * resolvedLimit
        : startIndex;
    return FeiniuItemPage(
      items: items,
      total: _int(map['total'] ?? map['total_count'] ?? items.length),
      startIndex: resolvedStartIndex,
      limit: resolvedLimit,
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
    this.isForced = false,
    this.isBitmap = false,
    this.codecName,
    this.format,
    this.width,
    this.height,
    this.bitRate,
    this.bitDepth,
    this.profile,
    this.frameRate,
    this.channels,
    this.sampleRate,
    this.channelLayout,
    this.extraFile,
    this.resolution,
    this.pixelFormat,
    this.colorRange,
    this.colorSpace,
    this.level,
  });

  final String guid;
  final String title;
  final String kind;
  final String? language;
  final int index;
  final bool isDefault;
  final bool isExternal;
  final bool isForced;
  final bool isBitmap;
  final String? codecName;
  final String? format;
  final int? width;
  final int? height;
  final int? bitRate;
  final int? bitDepth;
  final String? profile;
  final String? frameRate;
  final int? channels;
  final int? sampleRate;
  final String? channelLayout;
  final String? extraFile;
  final String? resolution;
  final String? pixelFormat;
  final String? colorRange;
  final String? colorSpace;
  final int? level;

  factory FeiniuStream.fromJson(Map<String, dynamic> json, String kind) {
    final codec = _optional(json['codec_name'] ?? json['codec']);
    return FeiniuStream(
      guid: _string(json['guid'] ?? json['id']),
      title: _string(json['title'] ?? json['name'] ?? codec),
      kind: kind,
      language: _optional(json['language'] ?? json['lan']),
      index: _optionalInt(json['index'] ?? json['stream_index']) ?? -1,
      isDefault: _bool(json['is_default'] ?? json['default']),
      isExternal: _bool(json['is_external'] ?? json['external']),
      isForced: _bool(json['forced'] ?? json['is_forced']),
      isBitmap: _bool(json['is_bitmap'] ?? json['bitmap']),
      codecName: codec,
      format: _optional(json['format'] ?? json['codec_long_name']),
      width: _optionalInt(json['width']),
      height: _optionalInt(json['height']),
      bitRate: _optionalInt(json['bps'] ?? json['bit_rate'] ?? json['bitrate']),
      bitDepth: _optionalInt(json['bit_depth']),
      profile: _optional(json['profile']),
      frameRate: _optional(
        json['r_frame_rate'] ?? json['avg_frame_rate'] ?? json['frame_rate'],
      ),
      channels: _optionalInt(json['channels']),
      sampleRate: _optionalInt(json['sample_rate'] ?? json['sampleRate']),
      channelLayout: _optional(json['channel_layout']),
      extraFile:
          _optionalPath(json['extra_file']) ??
          _optionalPath(json['path']) ??
          _optionalPath(json['url']) ??
          _optionalPath(json['file']),
      resolution: _optional(json['resolution_type'] ?? json['resolution']),
      pixelFormat: _optional(json['pix_fmt'] ?? json['pixel_format']),
      colorRange: _optional(json['color_range']),
      colorSpace: _optional(json['color_space']),
      level: _optionalInt(json['level']),
    );
  }

  MediaBrowserMediaStream toMediaBrowserStream() => MediaBrowserMediaStream(
    index: index,
    type: switch (kind) {
      'video' => 'Video',
      'audio' => 'Audio',
      'subtitle' => 'Subtitle',
      _ => kind,
    },
    codec: codecName,
    displayTitle: title.isEmpty ? null : title,
    language: language,
    isExternal: isExternal,
    isDefault: isDefault,
    isForced: isForced,
    width: width,
    height: height,
    bitRate: bitRate,
    channels: channels,
    sampleRate: sampleRate,
    bitDepth: bitDepth,
    profile: profile,
    frameRate: frameRate,
    channelLayout: channelLayout,
    format: format,
    resolution: resolution,
    pixelFormat: pixelFormat,
    colorRange: colorRange,
    colorSpace: colorSpace,
    level: level,
    isBitmap: isBitmap,
  );
}

@immutable
class FeiniuMediaFile {
  const FeiniuMediaFile({
    required this.guid,
    required this.mediaGuid,
    required this.path,
    this.name = '',
    this.sizeInBytes,
    this.container,
  });

  final String guid;
  final String mediaGuid;
  final String path;
  final String name;
  final int? sizeInBytes;
  final String? container;

  factory FeiniuMediaFile.fromJson(Map<String, dynamic> json) {
    final path = _string(
      json['path'] ?? json['file_path'] ?? json['file'] ?? json['url'],
    );
    final name = _string(json['file_name'] ?? json['name'] ?? json['filename']);
    final displayPath = path.isNotEmpty ? path : name;
    return FeiniuMediaFile(
      guid: _string(json['guid'] ?? json['file_guid'] ?? json['id']),
      mediaGuid: _string(
        json['media_guid'] ?? json['mediaGuid'] ?? json['guid'] ?? json['id'],
      ),
      path: displayPath,
      name: name.isEmpty ? _baseName(displayPath) : name,
      sizeInBytes: _optionalInt(
        json['size'] ?? json['size_bytes'] ?? json['file_size'],
      ),
      container:
          _optional(json['container'] ?? json['wrapper']) ??
          _extension(displayPath),
    );
  }
}

@immutable
class FeiniuStreamList {
  const FeiniuStreamList({
    this.video = const [],
    this.audio = const [],
    this.subtitle = const [],
    this.files = const [],
  });

  final List<FeiniuStream> video;
  final List<FeiniuStream> audio;
  final List<FeiniuStream> subtitle;
  final List<FeiniuMediaFile> files;

  factory FeiniuStreamList.fromData(Object? data) {
    final map = data is Map ? Map<String, dynamic>.from(data) : const {};
    List<FeiniuStream> read(List<String> keys, String kind) {
      Object? raw;
      for (final key in keys) {
        if (map[key] != null) {
          raw = map[key];
          break;
        }
      }
      if (raw is Map) raw = [raw];
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map(
            (item) =>
                FeiniuStream.fromJson(Map<String, dynamic>.from(item), kind),
          )
          .where((item) => item.guid.isNotEmpty || item.index >= 0)
          .toList(growable: false);
    }

    return FeiniuStreamList(
      video: read(const ['video_streams', 'video_stream'], 'video'),
      audio: read(const ['audio_streams', 'audio_stream'], 'audio'),
      subtitle: read(const ['subtitle_streams', 'subtitle_stream'], 'subtitle'),
      files: _readFiles(map['files'] ?? map['file_stream']),
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

String? _optionalPath(Object? value) {
  // 飞牛原生 extra_file 是数字 0/1，表示是否存在外置字幕文件，
  // 不是可以拼接到 URL 的路径。
  if (value is num || value is bool) return null;
  return _optional(value);
}

String? _imagePath(Object? value) {
  if (value is List) {
    for (final item in value) {
      final path = _imagePath(item);
      if (path != null) return path;
    }
    return null;
  }
  if (value is Map) {
    final map = Map<String, dynamic>.from(value);
    for (final key in const ['path', 'url', 'src', 'file', 'image']) {
      final path = _imagePath(map[key]);
      if (path != null) return path;
    }
    for (final key in const ['poster', 'Primary', 'backdrop', 'Backdrop']) {
      final path = _imagePath(map[key]);
      if (path != null) return path;
    }
    return null;
  }
  return _optional(value);
}

List<String> _imagePaths(Object? value) {
  if (value is List) {
    return value
        .expand((item) => _imagePaths(item))
        .where((path) => path.isNotEmpty)
        .toList(growable: false);
  }
  final path = _imagePath(value);
  return path == null ? const <String>[] : [path];
}

List<String> _pathList(Object? value) {
  if (value is List) {
    return value
        .map(
          (item) => item is Map
              ? _string(item['path'] ?? item['dir'] ?? item['value'])
              : _string(item),
        )
        .where((path) => path.isNotEmpty)
        .toList(growable: false);
  }
  final path = _string(value);
  return path.isEmpty ? const <String>[] : [path];
}

List<String> _stringList(Object? value, [Map<String, String>? names]) {
  if (value is List) {
    return value
        .map((item) {
          final raw = item is Map
              ? _string(item['name'] ?? item['title'] ?? item['label'])
              : _string(item);
          return names?[raw] ?? raw;
        })
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  final values = _string(value)
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
  return values.map((item) => names?[item] ?? item).toList(growable: false);
}

List<FeiniuMediaFile> _readFiles(Object? value) {
  final raw = value is Map
      ? value['list'] ??
            value['items'] ??
            value['files'] ??
            (value.containsKey('path') ||
                    value.containsKey('file_path') ||
                    value.containsKey('file_name') ||
                    value.containsKey('media_guid')
                ? [value]
                : null)
      : value;
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((item) => FeiniuMediaFile.fromJson(Map<String, dynamic>.from(item)))
      .where((item) => item.path.isNotEmpty || item.mediaGuid.isNotEmpty)
      .toList(growable: false);
}

String _baseName(String path) {
  final normalized = path.replaceAll('\\', '/');
  final index = normalized.lastIndexOf('/');
  return index < 0 ? normalized : normalized.substring(index + 1);
}

List<MediaBrowserPerson> _people(Object? value, [String? forcedType]) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map(
          (item) =>
              _person(Map<String, dynamic>.from(item), forcedType: forcedType),
        )
        .where((person) => person.name.isNotEmpty)
        .toList(growable: false);
  }
  if (value is Map) {
    final map = Map<String, dynamic>.from(value);
    final groups = <MediaBrowserPerson>[];
    for (final key in const ['cast', 'actors']) {
      groups.addAll(_people(map[key], 'Actor'));
    }
    for (final key in const ['crew', 'directors']) {
      groups.addAll(_people(map[key], 'Director'));
    }
    if (groups.isNotEmpty) return groups;
    final person = _person(map, forcedType: forcedType);
    return person.name.isEmpty ? const [] : [person];
  }
  return const [];
}

MediaBrowserPerson _person(Map<String, dynamic> json, {String? forcedType}) {
  final rawType = _string(
    forcedType ?? json['type'] ?? json['department'] ?? json['job'],
  ).toLowerCase();
  final type = rawType.contains('director')
      ? 'Director'
      : rawType.contains('actor') || rawType.contains('cast')
      ? 'Actor'
      : rawType.isEmpty
      ? ''
      : _string(json['type'] ?? json['department']);
  return MediaBrowserPerson(
    id: _string(
      json['id'] ?? json['person_id'] ?? json['person_guid'] ?? json['guid'],
    ),
    name: _string(json['name'] ?? json['original_name'] ?? json['Name']),
    role: _optional(
      json['role'] ??
          json['character'] ??
          json['character_name'] ??
          json['job'],
    ),
    type: type,
    profilePath: _imagePath(
      json['profile_path'] ??
          json['profile'] ??
          json['avatar'] ??
          json['image'] ??
          json['poster'] ??
          json['profile_image'] ??
          json['headshot'],
    ),
  );
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

bool _flag(Object? value, {required bool defaultValue}) {
  if (value == null || _string(value).isEmpty) return defaultValue;
  return _bool(value);
}

int? _year(String? value) {
  final match = RegExp(r'^(\d{4})').firstMatch(value ?? '');
  return match == null ? null : int.tryParse(match.group(1)!);
}

String? _extension(String value) {
  final index = value.lastIndexOf('.');
  if (index < 0 || index == value.length - 1) return null;
  return value.substring(index + 1).toLowerCase();
}
