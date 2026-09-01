import 'package:flutter/foundation.dart';

/// Emby 的时间单位是 100 纳秒 tick；播放时长 / 播放位置统一换算成秒。
const embyTicksPerSecond = 10000000;

int embyTicksToSeconds(int? ticks) {
  if (ticks == null || ticks <= 0) return 0;
  return (ticks / embyTicksPerSecond).round();
}

int secondsToEmbyTicks(int seconds) => seconds * embyTicksPerSecond;

@immutable
class EmbyUser {
  const EmbyUser({required this.id, required this.name, this.isAdmin = false});

  final String id;
  final String name;
  final bool isAdmin;

  factory EmbyUser.fromJson(Map<String, dynamic> json) => EmbyUser(
    id: json['Id']?.toString() ?? '',
    name: json['Name']?.toString() ?? '',
    isAdmin: json['Policy'] is Map && json['Policy']['IsAdministrator'] == true,
  );
}

/// 条目上按用户维度的状态：收藏、已看、播放位置。
@immutable
class EmbyUserData {
  const EmbyUserData({
    this.playbackPositionTicks = 0,
    this.playCount = 0,
    this.isFavorite = false,
    this.played = false,
  });

  final int playbackPositionTicks;
  final int playCount;
  final bool isFavorite;
  final bool played;

  /// 直链播放不支持 StartTimeTicks，恢复播放由客户端 seek 完成。
  int get resumeSeconds => embyTicksToSeconds(playbackPositionTicks);

  factory EmbyUserData.fromJson(Map<String, dynamic> json) => EmbyUserData(
    playbackPositionTicks: _intValue(json['PlaybackPositionTicks']) ?? 0,
    playCount: _intValue(json['PlayCount']) ?? 0,
    isFavorite: json['IsFavorite'] == true,
    played: json['Played'] == true,
  );
}

@immutable
class EmbyPerson {
  const EmbyPerson({
    required this.id,
    required this.name,
    this.role,
    this.type = '',
  });

  final String id;
  final String name;
  final String? role;
  /// 'Actor' / 'Director' 等；空字符串表示未标注。
  final String type;

  factory EmbyPerson.fromJson(Object? raw) {
    if (raw is! Map) return const EmbyPerson(id: '', name: '');
    final json = Map<String, dynamic>.from(raw);
    return EmbyPerson(
      id: json['Id']?.toString() ?? '',
      name: json['Name']?.toString() ?? '',
      role: _stringOrNull(json['Role']),
      type: json['Type']?.toString() ?? '',
    );
  }
}

@immutable
class EmbyMediaStream {
  const EmbyMediaStream({
    required this.index,
    required this.type,
    this.codec,
    this.displayTitle,
    this.language,
    this.isExternal = false,
    this.isDefault = false,
    this.isForced = false,
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

  factory EmbyMediaStream.fromJson(Object? raw) {
    if (raw is! Map) {
      return const EmbyMediaStream(index: -1, type: '');
    }
    final json = Map<String, dynamic>.from(raw);
    return EmbyMediaStream(
      index: _intValue(json['Index']) ?? -1,
      type: json['Type']?.toString() ?? '',
      codec: _stringOrNull(json['Codec']),
      displayTitle: _stringOrNull(json['DisplayTitle']),
      language: _stringOrNull(json['Language']),
      isExternal: json['IsExternal'] == true,
      isDefault: json['IsDefault'] == true,
      isForced: json['IsForced'] == true,
    );
  }
}

@immutable
class EmbyMediaSourceDto {
  const EmbyMediaSourceDto({
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
    this.mediaStreams = const <EmbyMediaStream>[],
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
  final List<EmbyMediaStream> mediaStreams;

  factory EmbyMediaSourceDto.fromJson(Object? raw) {
    if (raw is! Map) {
      return const EmbyMediaSourceDto(id: '');
    }
    final json = Map<String, dynamic>.from(raw);
    final streams = json['MediaStreams'];
    return EmbyMediaSourceDto(
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
          ? streams.map(EmbyMediaStream.fromJson).toList(growable: false)
          : const <EmbyMediaStream>[],
    );
  }
}

@immutable
class EmbyPlaybackInfo {
  const EmbyPlaybackInfo({
    this.mediaSources = const <EmbyMediaSourceDto>[],
    this.playSessionId = '',
  });

  final List<EmbyMediaSourceDto> mediaSources;
  final String playSessionId;

  factory EmbyPlaybackInfo.fromJson(Map<String, dynamic> json) {
    final sources = json['MediaSources'];
    return EmbyPlaybackInfo(
      mediaSources: sources is List
          ? sources.map(EmbyMediaSourceDto.fromJson).toList(growable: false)
          : const <EmbyMediaSourceDto>[],
      playSessionId: json['PlaySessionId']?.toString() ?? '',
    );
  }
}

/// Emby /Users/{uid}/Items 返回的通用条目：电影、剧集、季、集、媒体库等。
@immutable
class EmbyItem {
  const EmbyItem({
    required this.id,
    required this.name,
    required this.type,
    this.serverId,
    this.collectionType,
    this.productionYear,
    this.communityRating,
    this.criticRating,
    this.runTimeTicks,
    this.overview,
    this.genres = const <String>[],
    this.people = const <EmbyPerson>[],
    this.userData = const EmbyUserData(),
    this.seriesId,
    this.seriesName,
    this.seasonId,
    this.parentIndexNumber,
    this.indexNumber,
    this.primaryImageTag,
    this.backdropImageTags = const <String>[],
    this.thumbImageTag,
    this.childCount,
    this.recursiveItemCount,
    this.mediaSources = const <EmbyMediaSourceDto>[],
  });

  final String id;
  /// 'Movie' / 'Series' / 'Season' / 'Episode' / 'CollectionFolder' 等。
  final String type;
  final String? serverId;
  /// 媒体库类型：'movies' / 'tvshows' / 'music' 等，仅 Views 返回。
  final String? collectionType;
  final String name;
  final int? productionYear;
  final double? communityRating;
  final double? criticRating;
  final int? runTimeTicks;
  final String? overview;
  final List<String> genres;
  final List<EmbyPerson> people;
  final EmbyUserData userData;
  final String? seriesId;
  final String? seriesName;
  final String? seasonId;
  /// 剧集的季号 / 集的集号。
  final int? parentIndexNumber;
  final int? indexNumber;
  final String? primaryImageTag;
  final List<String> backdropImageTags;
  final String? thumbImageTag;
  final int? childCount;
  final int? recursiveItemCount;
  final List<EmbyMediaSourceDto> mediaSources;

  bool get isMovie => type == 'Movie';
  bool get isSeries => type == 'Series';
  bool get isSeason => type == 'Season';
  bool get isEpisode => type == 'Episode';
  bool get isPlayable => isMovie || isEpisode;

  int get runtimeMinutes =>
      (embyTicksToSeconds(runTimeTicks) / 60).ceil().clamp(0, 1 << 31);

  String? get seriesTitle => seriesName;

  factory EmbyItem.fromJson(Map<String, dynamic> json) {
    final genres = json['Genres'];
    final people = json['People'];
    final backdrops = json['BackdropImageTags'];
    final sources = json['MediaSources'];
    final imageTags = json['ImageTags'];
    return EmbyItem(
      id: json['Id']?.toString() ?? '',
      name: json['Name']?.toString() ?? '',
      type: json['Type']?.toString() ?? '',
      serverId: _stringOrNull(json['ServerId']),
      collectionType: _stringOrNull(json['CollectionType']),
      productionYear: _intValue(json['ProductionYear']),
      communityRating: _doubleValue(json['CommunityRating']),
      criticRating: _doubleValue(json['CriticRating']),
      runTimeTicks: _intValue(json['RunTimeTicks']),
      overview: _stringOrNull(json['Overview']),
      genres: genres is List
          ? genres.map((item) => item.toString()).toList(growable: false)
          : const <String>[],
      people: people is List
          ? people.map(EmbyPerson.fromJson).toList(growable: false)
          : const <EmbyPerson>[],
      userData: json['UserData'] is Map
          ? EmbyUserData.fromJson(
              Map<String, dynamic>.from(json['UserData'] as Map),
            )
          : const EmbyUserData(),
      seriesId: _stringOrNull(json['SeriesId']),
      seriesName: _stringOrNull(json['SeriesName']),
      seasonId: _stringOrNull(json['SeasonId']),
      parentIndexNumber: _intValue(json['ParentIndexNumber']),
      indexNumber: _intValue(json['IndexNumber']),
      primaryImageTag: imageTags is Map
          ? _stringOrNull(imageTags['Primary'])
          : null,
      backdropImageTags: backdrops is List
          ? backdrops.map((item) => item.toString()).toList(growable: false)
          : const <String>[],
      thumbImageTag: imageTags is Map ? _stringOrNull(imageTags['Thumb']) : null,
      childCount: _intValue(json['ChildCount']),
      recursiveItemCount: _intValue(json['RecursiveItemCount']),
      mediaSources: sources is List
          ? sources.map(EmbyMediaSourceDto.fromJson).toList(growable: false)
          : const <EmbyMediaSourceDto>[],
    );
  }
}

/// /Users/{uid}/Items 系列接口的分页结果。
@immutable
class EmbyItemPage {
  const EmbyItemPage({
    required this.items,
    required this.total,
    required this.startIndex,
    required this.limit,
  });

  final List<EmbyItem> items;
  final int total;
  final int startIndex;
  final int limit;

  bool get hasMore => startIndex + items.length < total;

  factory EmbyItemPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['Items'];
    return EmbyItemPage(
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map((item) => EmbyItem.fromJson(Map<String, dynamic>.from(item)))
                .where((item) => item.id.isNotEmpty)
                .toList(growable: false)
          : const <EmbyItem>[],
      total: _intValue(json['TotalRecordCount']) ?? 0,
      startIndex: _intValue(json['StartIndex']) ?? 0,
      limit: _intValue(json['limit']) ?? 0,
    );
  }
}

/// AuthenticateByName 的响应：令牌 + 用户。
@immutable
class EmbyAuthResult {
  const EmbyAuthResult({
    required this.accessToken,
    required this.user,
    this.serverId,
  });

  final String accessToken;
  final EmbyUser user;
  final String? serverId;

  factory EmbyAuthResult.fromJson(Map<String, dynamic> json) => EmbyAuthResult(
    accessToken: json['AccessToken']?.toString() ?? '',
    user: json['User'] is Map
        ? EmbyUser.fromJson(Map<String, dynamic>.from(json['User'] as Map))
        : const EmbyUser(id: '', name: ''),
    serverId: _stringOrNull(json['ServerId']),
  );
}

String? _stringOrNull(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

int? _intValue(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString().trim() ?? '');
}

double? _doubleValue(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString().trim() ?? '');
}
