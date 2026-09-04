import 'package:flutter/foundation.dart';

import 'package:omm/core/sources/media/media_metadata_normalizer.dart';

/// Emby / Jellyfin 共用的 MediaBrowser 协议 DTO。
///
/// Jellyfin fork 自 Emby，两家的 JSON wire format 完全一致，差异仅在
/// 路径前缀与鉴权细节（见 media_browser_config.dart），因此这里只保留
/// 一份模型。
///
/// 时间单位是 100 纳秒 tick；播放时长 / 播放位置统一换算成秒。
const mediaBrowserTicksPerSecond = 10000000;

int mediaBrowserTicksToSeconds(int? ticks) {
  if (ticks == null || ticks <= 0) return 0;
  return (ticks / mediaBrowserTicksPerSecond).round();
}

int secondsToMediaBrowserTicks(int seconds) =>
    seconds * mediaBrowserTicksPerSecond;

@immutable
class MediaBrowserUser {
  const MediaBrowserUser({
    required this.id,
    required this.name,
    this.isAdmin = false,
  });

  final String id;
  final String name;
  final bool isAdmin;

  factory MediaBrowserUser.fromJson(Map<String, dynamic> json) =>
      MediaBrowserUser(
        id: json['Id']?.toString() ?? '',
        name: json['Name']?.toString() ?? '',
        isAdmin:
            json['Policy'] is Map && json['Policy']['IsAdministrator'] == true,
      );
}

/// 条目上按用户维度的状态：收藏、已看、播放位置。
@immutable
class MediaBrowserUserData {
  const MediaBrowserUserData({
    this.playbackPositionTicks = 0,
    this.playCount = 0,
    this.unplayedItemCount = 0,
    this.isFavorite = false,
    this.played = false,
  });

  final int playbackPositionTicks;
  final int playCount;
  final int unplayedItemCount;
  final bool isFavorite;
  final bool played;

  /// 直链播放不支持 StartTimeTicks，恢复播放由客户端 seek 完成。
  int get resumeSeconds => mediaBrowserTicksToSeconds(playbackPositionTicks);

  factory MediaBrowserUserData.fromJson(Map<String, dynamic> json) =>
      MediaBrowserUserData(
        playbackPositionTicks: _intValue(json['PlaybackPositionTicks']) ?? 0,
        playCount: _intValue(json['PlayCount']) ?? 0,
        unplayedItemCount: _intValue(json['UnplayedItemCount']) ?? 0,
        isFavorite: json['IsFavorite'] == true,
        played: json['Played'] == true,
      );
}

@immutable
class MediaBrowserPerson {
  const MediaBrowserPerson({
    required this.id,
    required this.name,
    this.role,
    this.type = '',
    this.profilePath,
    this.primaryImageTag,
  });

  final String id;
  final String name;
  final String? role;

  /// 'Actor' / 'Director' 等；空字符串表示未标注。
  final String type;
  final String? profilePath;

  /// Emby/Jellyfin People 条目自带的头像版本号，用于拼 /Images/Primary 地址。
  final String? primaryImageTag;

  factory MediaBrowserPerson.fromJson(Object? raw) {
    if (raw is! Map) return const MediaBrowserPerson(id: '', name: '');
    final json = Map<String, dynamic>.from(raw);
    return MediaBrowserPerson(
      id: (json['Id'] ?? json['id'] ?? json['person_guid'])?.toString() ?? '',
      name:
          (json['Name'] ?? json['name'] ?? json['original_name'])?.toString() ??
          '',
      role: _stringOrNull(json['Role'] ?? json['role'] ?? json['character']),
      type: (json['Type'] ?? json['type'] ?? json['job'])?.toString() ?? '',
      profilePath: _stringOrNull(
        json['ProfilePath'] ??
            json['profile_path'] ??
            json['Image'] ??
            json['image'] ??
            json['ProfileImage'],
      ),
      primaryImageTag: _stringOrNull(
        json['PrimaryImageTag'] ?? json['primary_image_tag'],
      ),
    );
  }
}

@immutable
class MediaBrowserMediaStream {
  const MediaBrowserMediaStream({
    required this.index,
    required this.type,
    this.codec,
    this.displayTitle,
    this.language,
    this.isExternal = false,
    this.isDefault = false,
    this.isForced = false,
    this.width,
    this.height,
    this.bitRate,
    this.channels,
    this.sampleRate,
    this.bitDepth,
    this.profile,
    this.frameRate,
    this.channelLayout,
    this.format,
    this.resolution,
    this.pixelFormat,
    this.colorRange,
    this.colorSpace,
    this.colorTransfer,
    this.colorPrimaries,
    this.aspectRatio,
    this.title,
    this.videoRangeType,
    this.level,
    this.isBitmap = false,
  });

  final int index;

  /// 'Video' / 'Audio' / 'Subtitle'
  final String type;
  final String? codec;
  final String? displayTitle;
  final String? language;
  final bool isExternal;
  final bool isDefault;
  final bool isForced;
  final int? width;
  final int? height;
  final int? bitRate;
  final int? channels;
  final int? sampleRate;
  final int? bitDepth;
  final String? profile;
  final String? frameRate;
  final String? channelLayout;
  final String? format;
  final String? resolution;
  final String? pixelFormat;
  final String? colorRange;
  final String? colorSpace;

  /// HDR 判定与卡片展示用：smpte2084=HDR10、arib-std-b67=HLG 等。
  final String? colorTransfer;
  final String? colorPrimaries;
  final String? aspectRatio;
  final String? title;

  /// Emby/Jellyfin 的 VideoRangeType（SDR/HDR10/DOVI 等），用于 Dolby Vision 徽章。
  final String? videoRangeType;
  final int? level;
  final bool isBitmap;

  factory MediaBrowserMediaStream.fromJson(Object? raw) {
    if (raw is! Map) {
      return const MediaBrowserMediaStream(index: -1, type: '');
    }
    final json = Map<String, dynamic>.from(raw);
    return MediaBrowserMediaStream(
      index: _intValue(json['Index'] ?? json['index']) ?? -1,
      type: (json['Type'] ?? json['type'])?.toString() ?? '',
      codec: _stringOrNull(
        json['Codec'] ?? json['codec'] ?? json['codec_name'],
      ),
      displayTitle: _stringOrNull(
        json['DisplayTitle'] ?? json['displayTitle'] ?? json['title'],
      ),
      language: _stringOrNull(json['Language'] ?? json['language']),
      isExternal: json['IsExternal'] == true || json['is_external'] == true,
      isDefault: json['IsDefault'] == true || json['is_default'] == true,
      isForced: json['IsForced'] == true || json['forced'] == true,
      width: _intValue(json['Width'] ?? json['width']),
      height: _intValue(json['Height'] ?? json['height']),
      bitRate: _intValue(json['BitRate'] ?? json['bit_rate'] ?? json['bps']),
      channels: _intValue(json['Channels'] ?? json['channels']),
      sampleRate: _intValue(
        json['SampleRate'] ?? json['sample_rate'] ?? json['sampleRate'],
      ),
      bitDepth: _intValue(json['BitDepth'] ?? json['bit_depth']),
      profile: _stringOrNull(json['Profile'] ?? json['profile']),
      frameRate: _stringOrNull(
        json['RealFrameRate'] ??
            json['FrameRate'] ??
            json['frame_rate'] ??
            json['r_frame_rate'],
      ),
      channelLayout: _stringOrNull(
        json['ChannelLayout'] ?? json['channel_layout'],
      ),
      format: _stringOrNull(json['Format'] ?? json['format']),
      resolution: _stringOrNull(
        json['Resolution'] ?? json['resolution'] ?? json['resolution_type'],
      ),
      pixelFormat: _stringOrNull(
        json['PixelFormat'] ?? json['pixel_format'] ?? json['pix_fmt'],
      ),
      colorRange: _stringOrNull(json['ColorRange'] ?? json['color_range']),
      colorSpace: _stringOrNull(json['ColorSpace'] ?? json['color_space']),
      colorTransfer: _stringOrNull(
        json['ColorTransfer'] ?? json['color_transfer'],
      ),
      colorPrimaries: _stringOrNull(
        json['ColorPrimaries'] ?? json['color_primaries'],
      ),
      aspectRatio: _stringOrNull(
        json['AspectRatio'] ?? json['aspect_ratio'] ?? json['display_aspect'],
      ),
      title: _stringOrNull(json['Title'] ?? json['title_name']),
      videoRangeType: _stringOrNull(
        json['VideoRangeType'] ?? json['video_range_type'],
      ),
      level: _intValue(json['Level'] ?? json['level']),
      isBitmap: json['IsBitmap'] == true || json['is_bitmap'] == true,
    );
  }
}

@immutable
class MediaBrowserMediaSourceDto {
  const MediaBrowserMediaSourceDto({
    required this.id,
    this.name,
    this.path,
    this.container,
    this.protocol,
    this.sizeInBytes,
    this.supportsDirectPlay = false,
    this.supportsDirectStream = false,
    this.supportsTranscoding = false,
    this.transcodingUrl,
    this.mediaStreams = const <MediaBrowserMediaStream>[],
  });

  final String id;
  final String? name;
  final String? path;
  final String? container;
  final String? protocol;
  final int? sizeInBytes;
  final bool supportsDirectPlay;
  final bool supportsDirectStream;
  final bool supportsTranscoding;

  /// 服务器生成的 HLS 转码地址（相对路径，含全部转码参数）。
  final String? transcodingUrl;
  final List<MediaBrowserMediaStream> mediaStreams;

  factory MediaBrowserMediaSourceDto.fromJson(Object? raw) {
    if (raw is! Map) {
      return const MediaBrowserMediaSourceDto(id: '');
    }
    final json = Map<String, dynamic>.from(raw);
    final streams = json['MediaStreams'];
    return MediaBrowserMediaSourceDto(
      id: json['Id']?.toString() ?? '',
      name: _stringOrNull(json['Name']),
      path: _stringOrNull(json['Path']),
      container: _stringOrNull(json['Container']),
      protocol: _stringOrNull(json['Protocol']),
      sizeInBytes: _intValue(json['Size']),
      supportsDirectPlay: json['SupportsDirectPlay'] == true,
      supportsDirectStream: json['SupportsDirectStream'] == true,
      supportsTranscoding: json['SupportsTranscoding'] == true,
      transcodingUrl: _stringOrNull(json['TranscodingUrl']),
      mediaStreams: streams is List
          ? streams
                .map(MediaBrowserMediaStream.fromJson)
                .toList(growable: false)
          : const <MediaBrowserMediaStream>[],
    );
  }
}

/// 视频条目的一个连续分集（例如 CD1 / CD2）。
///
/// Emby/Jellyfin 的分集是独立 Item，fnOS 的分集则共享父 Item、通过
/// [mediaSourceId] 指向 `stream/list.files` 中的文件。
@immutable
class MediaBrowserVideoPart {
  const MediaBrowserVideoPart({
    required this.id,
    required this.itemId,
    this.mediaSourceId,
    this.name,
    this.path,
    this.container,
    this.sizeInBytes,
    this.runTimeTicks,
    this.mediaStreams = const <MediaBrowserMediaStream>[],
  });

  final String id;
  final String itemId;
  final String? mediaSourceId;
  final String? name;
  final String? path;
  final String? container;
  final int? sizeInBytes;
  final int? runTimeTicks;
  final List<MediaBrowserMediaStream> mediaStreams;

  int get durationSeconds => mediaBrowserTicksToSeconds(runTimeTicks);

  factory MediaBrowserVideoPart.fromJson(Object? raw) {
    if (raw is! Map) {
      return const MediaBrowserVideoPart(id: '', itemId: '');
    }
    final json = Map<String, dynamic>.from(raw);
    final rawSources = json['MediaSources'] ?? json['mediaSources'];
    final sources = rawSources is List
        ? rawSources
              .map(MediaBrowserMediaSourceDto.fromJson)
              .where((source) => source.id.trim().isNotEmpty)
              .toList(growable: false)
        : const <MediaBrowserMediaSourceDto>[];
    final source = sources.isEmpty ? null : sources.first;
    final rawStreams = json['MediaStreams'] ?? json['mediaStreams'];
    final streams = rawStreams is List
        ? rawStreams
              .map(MediaBrowserMediaStream.fromJson)
              .toList(growable: false)
        : const <MediaBrowserMediaStream>[];
    final itemId =
        (json['Id'] ?? json['id'] ?? json['ItemId'] ?? json['itemId'])
            ?.toString() ??
        '';
    return MediaBrowserVideoPart(
      id: itemId,
      itemId: itemId,
      mediaSourceId:
          source?.id ??
          _stringOrNull(json['MediaSourceId'] ?? json['mediaSourceId']),
      name: source?.name ?? _stringOrNull(json['Name'] ?? json['name']),
      path: source?.path ?? _stringOrNull(json['Path'] ?? json['path']),
      container:
          source?.container ??
          _stringOrNull(json['Container'] ?? json['container']),
      sizeInBytes:
          source?.sizeInBytes ??
          _intValue(json['Size'] ?? json['size'] ?? json['SizeInBytes']),
      runTimeTicks: _intValue(
        json['RunTimeTicks'] ?? json['runTimeTicks'] ?? json['DurationTicks'],
      ),
      mediaStreams: source?.mediaStreams.isNotEmpty == true
          ? source!.mediaStreams
          : streams,
    );
  }

  factory MediaBrowserVideoPart.fromItem(
    MediaBrowserItem item, {
    String? mediaSourceId,
  }) {
    final source = item.mediaSources.isEmpty
        ? null
        : mediaSourceId == null
        ? item.mediaSources.first
        : item.mediaSources.firstWhere(
            (candidate) => candidate.id == mediaSourceId,
            orElse: () => item.mediaSources.first,
          );
    return MediaBrowserVideoPart(
      id: item.id,
      itemId: item.id,
      mediaSourceId: mediaSourceId ?? source?.id,
      name: source?.name ?? item.name,
      path: source?.path,
      container: source?.container,
      sizeInBytes: source?.sizeInBytes,
      runTimeTicks: item.runTimeTicks,
      mediaStreams: source?.mediaStreams ?? const <MediaBrowserMediaStream>[],
    );
  }

  MediaBrowserVideoPart copyWith({
    String? mediaSourceId,
    String? name,
    String? path,
    String? container,
    int? sizeInBytes,
    int? runTimeTicks,
    List<MediaBrowserMediaStream>? mediaStreams,
  }) => MediaBrowserVideoPart(
    id: id,
    itemId: itemId,
    mediaSourceId: mediaSourceId ?? this.mediaSourceId,
    name: name ?? this.name,
    path: path ?? this.path,
    container: container ?? this.container,
    sizeInBytes: sizeInBytes ?? this.sizeInBytes,
    runTimeTicks: runTimeTicks ?? this.runTimeTicks,
    mediaStreams: mediaStreams ?? this.mediaStreams,
  );
}

@immutable
class MediaBrowserPlaybackInfo {
  const MediaBrowserPlaybackInfo({
    this.mediaSources = const <MediaBrowserMediaSourceDto>[],
    this.playSessionId = '',
  });

  final List<MediaBrowserMediaSourceDto> mediaSources;
  final String playSessionId;

  factory MediaBrowserPlaybackInfo.fromJson(Map<String, dynamic> json) {
    final sources = json['MediaSources'];
    return MediaBrowserPlaybackInfo(
      mediaSources: sources is List
          ? sources
                .map(MediaBrowserMediaSourceDto.fromJson)
                .toList(growable: false)
          : const <MediaBrowserMediaSourceDto>[],
      playSessionId: json['PlaySessionId']?.toString() ?? '',
    );
  }
}

/// /Users/{uid}/Items 返回的通用条目：电影、剧集、季、集、媒体库等。
@immutable
class MediaBrowserItem {
  const MediaBrowserItem({
    required this.id,
    required this.name,
    required this.type,
    this.serverId,
    this.collectionType,
    this.originalTitle,
    this.code,
    this.productionYear,
    this.endYear,
    this.status,
    this.communityRating,
    this.criticRating,
    this.runTimeTicks,
    this.overview,
    this.genres = const <String>[],
    this.tags = const <String>[],
    this.tagIds = const <String>[],
    this.people = const <MediaBrowserPerson>[],
    this.userData = const MediaBrowserUserData(),
    this.seriesId,
    this.seriesName,
    this.seasonId,
    this.parentIndexNumber,
    this.indexNumber,
    this.album,
    this.albumId,
    this.albumArtist,
    this.artistNames = const <String>[],
    this.primaryImageTag,
    this.previewPath,
    this.backdropImageTags = const <String>[],
    this.thumbImageTag,
    this.childCount,
    this.recursiveItemCount,
    this.episodeCount,
    this.partCount,
    this.additionalParts = const <MediaBrowserVideoPart>[],
    this.mediaSources = const <MediaBrowserMediaSourceDto>[],
    this.payload,
  });

  final String id;

  /// 'Movie' / 'Series' / 'Season' / 'Episode' / 'CollectionFolder' 等。
  final String type;
  final String? serverId;

  /// 媒体库类型：'movies' / 'tvshows' / 'music' 等，仅 Views 返回。
  final String? collectionType;
  final String name;
  final String? originalTitle;

  /// Stash 场景番号；Emby/Jellyfin/FNOS 适配器不会将其映射到公共模型。
  final String? code;
  final int? productionYear;
  final int? endYear;
  final String? status;
  final double? communityRating;
  final double? criticRating;
  final int? runTimeTicks;
  final String? overview;
  final List<String> genres;

  /// Emby/Jellyfin 返回的标签名称；[tagIds] 保留服务端原始 ID。
  final List<String> tags;
  final List<String> tagIds;
  final List<MediaBrowserPerson> people;
  final MediaBrowserUserData userData;
  final String? seriesId;
  final String? seriesName;
  final String? seasonId;

  /// 剧集的季号 / 集的集号；音频条目上是光盘号 / 曲号。
  final int? parentIndexNumber;
  final int? indexNumber;

  /// 音频条目所属专辑名与专辑 ID；专辑条目上为空。
  final String? album;
  final String? albumId;

  /// 专辑艺术家（音频与专辑条目都可能出现）。
  final String? albumArtist;

  /// 参与艺术家名列表（不含专辑艺术家语义，顺序与服务器一致）。
  final List<String> artistNames;
  final String? primaryImageTag;

  /// Stash Scene 的短预览视频路径；其他 MediaBrowser 来源为空。
  final String? previewPath;
  final List<String> backdropImageTags;
  final String? thumbImageTag;
  final int? childCount;
  final int? recursiveItemCount;
  final int? episodeCount;
  final int? partCount;
  final List<MediaBrowserVideoPart> additionalParts;
  final List<MediaBrowserMediaSourceDto> mediaSources;

  /// 来源适配器转换前的原始 DTO；Emby/Jellyfin 直接使用本模型本身。
  final Object? payload;

  bool get isMovie => type == 'Movie';
  bool get isSeries => type == 'Series';
  bool get isSeason => type == 'Season';
  bool get isEpisode => type == 'Episode';
  bool get isMusicAlbum => type == 'MusicAlbum';
  bool get isAudio => type == 'Audio';
  bool get isPlayable => isMovie || isEpisode;

  /// 当前条目及服务器返回的额外分集，顺序与服务器保持一致。
  List<MediaBrowserVideoPart> get videoParts {
    final primary = MediaBrowserVideoPart.fromItem(this);
    final parts = <MediaBrowserVideoPart>[primary, ...additionalParts];
    final seen = <String>{};
    return parts
        .where((part) {
          final key = '${part.itemId}\u0000${part.mediaSourceId ?? ''}';
          return part.itemId.trim().isNotEmpty && seen.add(key);
        })
        .toList(growable: false);
  }

  bool get hasAdditionalParts => additionalParts.isNotEmpty;

  MediaBrowserItem copyWithAdditionalParts(
    List<MediaBrowserVideoPart> parts, {
    int? partCount,
  }) => MediaBrowserItem(
    id: id,
    name: name,
    type: type,
    serverId: serverId,
    collectionType: collectionType,
    originalTitle: originalTitle,
    code: code,
    productionYear: productionYear,
    endYear: endYear,
    status: status,
    communityRating: communityRating,
    criticRating: criticRating,
    runTimeTicks: runTimeTicks,
    overview: overview,
    genres: genres,
    tags: tags,
    tagIds: tagIds,
    people: people,
    userData: userData,
    seriesId: seriesId,
    seriesName: seriesName,
    seasonId: seasonId,
    parentIndexNumber: parentIndexNumber,
    indexNumber: indexNumber,
    album: album,
    albumId: albumId,
    albumArtist: albumArtist,
    artistNames: artistNames,
    primaryImageTag: primaryImageTag,
    previewPath: previewPath,
    backdropImageTags: backdropImageTags,
    thumbImageTag: thumbImageTag,
    childCount: childCount,
    recursiveItemCount: recursiveItemCount,
    episodeCount: episodeCount,
    partCount: partCount ?? this.partCount,
    additionalParts: parts,
    mediaSources: mediaSources,
    payload: payload,
  );

  /// 音乐条目的展示艺术家：专辑艺术家优先，缺省时合并参与艺术家。
  String? get displayArtist {
    final album = albumArtist?.trim();
    if (album?.isNotEmpty == true) return album;
    final joined = artistNames
        .where((name) => name.trim().isNotEmpty)
        .join(' / ');
    return joined.isEmpty ? null : joined;
  }

  int get runtimeMinutes => mediaBrowserTicksToMinutes(runTimeTicks) ?? 0;

  /// 剧集总集数。Emby/Jellyfin 的剧集列表通常通过 [childCount] 返回，
  /// Emby 也可能只在 UserData 中返回已看与未看数量之和。
  int? get totalEpisodeCount {
    if (!isSeries) return null;
    final userDataCount = userData.playCount + userData.unplayedItemCount;
    if (userDataCount > 0) return userDataCount;
    for (final count in [childCount, recursiveItemCount, episodeCount]) {
      if (count != null && count > 0) return count;
    }
    return null;
  }

  String? get seriesTitle => seriesName;

  factory MediaBrowserItem.fromJson(Map<String, dynamic> json) {
    final genres = json['Genres'];
    final people = json['People'];
    final tags = json['Tags'];
    final backdrops = json['BackdropImageTags'];
    final sources = json['MediaSources'];
    final imageTags = json['ImageTags'];
    final artists = json['Artists'];
    return MediaBrowserItem(
      id: json['Id']?.toString() ?? '',
      name: json['Name']?.toString() ?? '',
      type: json['Type']?.toString() ?? '',
      serverId: _stringOrNull(json['ServerId']),
      collectionType: _stringOrNull(json['CollectionType']),
      originalTitle: _stringOrNull(json['OriginalTitle']),
      code: _stringOrNull(json['Code'] ?? json['code']),
      productionYear:
          _intValue(json['ProductionYear']) ?? _yearValue(json['PremiereDate']),
      endYear: _yearValue(json['EndDate']),
      status: _stringOrNull(json['Status']),
      communityRating: _doubleValue(json['CommunityRating']),
      criticRating: _doubleValue(json['CriticRating']),
      runTimeTicks: _intValue(json['RunTimeTicks']),
      overview: _stringOrNull(json['Overview']),
      genres: genres is List
          ? genres.map((item) => item.toString()).toList(growable: false)
          : const <String>[],
      tags: tags is List
          ? tags.map((item) => item.toString()).toList(growable: false)
          : const <String>[],
      tagIds: _stringList(json['TagIds'] ?? json['tagIds'] ?? json['tag_ids']),
      people: people is List
          ? people.map(MediaBrowserPerson.fromJson).toList(growable: false)
          : const <MediaBrowserPerson>[],
      userData: json['UserData'] is Map
          ? MediaBrowserUserData.fromJson(
              Map<String, dynamic>.from(json['UserData'] as Map),
            )
          : const MediaBrowserUserData(),
      seriesId: _stringOrNull(json['SeriesId']),
      seriesName: _stringOrNull(json['SeriesName']),
      seasonId: _stringOrNull(json['SeasonId']),
      parentIndexNumber: _intValue(json['ParentIndexNumber']),
      indexNumber: _intValue(json['IndexNumber']),
      album: _stringOrNull(json['Album']),
      albumId: _stringOrNull(json['AlbumId']),
      albumArtist: _stringOrNull(json['AlbumArtist']),
      artistNames: artists is List
          ? artists.map((item) => item.toString()).toList(growable: false)
          : const <String>[],
      primaryImageTag: imageTags is Map
          ? _stringOrNull(imageTags['Primary'])
          : null,
      backdropImageTags: backdrops is List
          ? backdrops.map((item) => item.toString()).toList(growable: false)
          : const <String>[],
      thumbImageTag: imageTags is Map
          ? _stringOrNull(imageTags['Thumb'])
          : null,
      childCount: _intValue(json['ChildCount']),
      recursiveItemCount: _intValue(json['RecursiveItemCount']),
      episodeCount: _intValue(json['EpisodeCount']),
      partCount: _intValue(json['PartCount'] ?? json['partCount']),
      additionalParts: _videoParts(
        json['AdditionalParts'] ??
            json['additionalParts'] ??
            json['additional_parts'],
      ),
      mediaSources: sources is List
          ? sources
                .map(MediaBrowserMediaSourceDto.fromJson)
                .toList(growable: false)
          : const <MediaBrowserMediaSourceDto>[],
    );
  }
}

/// Emby / Jellyfin 管理端返回的虚拟媒体库。
///
/// [libraryOptions] 保留服务器返回的完整选项，修改启用状态时原样带回，
/// 避免只提交一个字段导致服务器重置元数据、字幕等高级配置。
@immutable
class MediaBrowserLibrary {
  const MediaBrowserLibrary({
    required this.id,
    required this.name,
    required this.collectionType,
    required this.paths,
    required this.enabled,
    required this.libraryOptions,
    this.refreshCategory,
  });

  final String id;
  final String name;
  final String? collectionType;
  final List<String> paths;
  final bool enabled;
  final Map<String, dynamic> libraryOptions;

  /// 任务接口使用的原始媒体库分类；fnOS 与展示用的规范化分类不同。
  final String? refreshCategory;

  factory MediaBrowserLibrary.fromJson(Map<String, dynamic> json) {
    final options = json['LibraryOptions'] is Map
        ? Map<String, dynamic>.from(json['LibraryOptions'] as Map)
        : <String, dynamic>{};
    final locations = _stringList(json['Locations']);
    final optionPaths = _pathsFromOptions(options['PathInfos']);
    final paths = _uniqueStrings(
      locations.isNotEmpty ? locations : optionPaths,
    );
    if (paths.isNotEmpty && options['PathInfos'] == null) {
      options['PathInfos'] = [
        for (final path in paths) {'Path': path},
      ];
    }
    return MediaBrowserLibrary(
      id: _stringOrNull(json['ItemId'] ?? json['Id'] ?? json['id']) ?? '',
      name: _stringOrNull(json['Name'] ?? json['name']) ?? '',
      collectionType: _stringOrNull(
        json['CollectionType'] ?? json['collectionType'],
      ),
      paths: paths,
      enabled: options['Enabled'] is bool ? options['Enabled'] as bool : true,
      libraryOptions: options,
      refreshCategory: _stringOrNull(
        json['RefreshCategory'] ?? json['refreshCategory'],
      ),
    );
  }
}

/// MediaBrowser 首页媒体库统计。
@immutable
class MediaBrowserLibraryStats {
  const MediaBrowserLibraryStats({
    required this.movieCount,
    required this.seriesCount,
    required this.episodeCount,
  });

  final int movieCount;
  final int seriesCount;
  final int episodeCount;
}

/// /Users/{uid}/Items 系列接口的分页结果。
@immutable
class MediaBrowserItemPage {
  const MediaBrowserItemPage({
    required this.items,
    required this.total,
    required this.startIndex,
    required this.limit,
  });

  final List<MediaBrowserItem> items;
  final int total;
  final int startIndex;
  final int limit;

  bool get hasMore => startIndex + items.length < total;

  factory MediaBrowserItemPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['Items'];
    return MediaBrowserItemPage(
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map(
                  (item) => MediaBrowserItem.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .where((item) => item.id.isNotEmpty)
                .toList(growable: false)
          : const <MediaBrowserItem>[],
      total: _intValue(json['TotalRecordCount']) ?? 0,
      startIndex: _intValue(json['StartIndex']) ?? 0,
      limit: _intValue(json['limit']) ?? 0,
    );
  }
}

/// AuthenticateByName 的响应：令牌 + 用户。
@immutable
class MediaBrowserAuthResult {
  const MediaBrowserAuthResult({
    required this.accessToken,
    required this.user,
    this.serverId,
  });

  final String accessToken;
  final MediaBrowserUser user;
  final String? serverId;

  factory MediaBrowserAuthResult.fromJson(Map<String, dynamic> json) =>
      MediaBrowserAuthResult(
        accessToken: json['AccessToken']?.toString() ?? '',
        user: json['User'] is Map
            ? MediaBrowserUser.fromJson(
                Map<String, dynamic>.from(json['User'] as Map),
              )
            : const MediaBrowserUser(id: '', name: ''),
        serverId: _stringOrNull(json['ServerId']),
      );
}

String? _stringOrNull(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

List<MediaBrowserVideoPart> _videoParts(Object? value) {
  if (value is! List) return const <MediaBrowserVideoPart>[];
  return value
      .map(MediaBrowserVideoPart.fromJson)
      .where((part) => part.itemId.trim().isNotEmpty)
      .toList(growable: false);
}

int? _intValue(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString().trim() ?? '');
}

int? _yearValue(Object? value) {
  final date = DateTime.tryParse(value?.toString().trim() ?? '');
  return date?.year;
}

List<String> _stringList(Object? value) {
  if (value is! List) return const <String>[];
  return value
      .map((item) => item?.toString().trim() ?? '')
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

List<String> _pathsFromOptions(Object? value) {
  if (value is! List) return const <String>[];
  return value
      .whereType<Map>()
      .map((item) => item['Path'] ?? item['path'])
      .map((item) => item?.toString().trim() ?? '')
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

List<String> _uniqueStrings(Iterable<String> values) {
  final result = <String>[];
  final seen = <String>{};
  for (final value in values) {
    if (seen.add(value)) result.add(value);
  }
  return result;
}

double? _doubleValue(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString().trim() ?? '');
}
