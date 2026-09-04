import 'package:flutter/foundation.dart';

@immutable
class DbOnlineMovie {
  const DbOnlineMovie({
    required this.id,
    required this.number,
    required this.title,
    this.coverUrl,
    this.thumbUrl,
    this.releaseDate,
    this.duration,
    this.magnetsCount = 0,
    this.hasCnsub = false,
    this.library,
    this.score,
    this.canPlay = false,
  });

  final String id;
  final String number;
  final String title;
  final String? coverUrl;
  final String? thumbUrl;
  final String? releaseDate;
  final String? duration;
  final int magnetsCount;
  final bool hasCnsub;
  final String? library;
  final double? score;
  final bool canPlay;

  factory DbOnlineMovie.fromJson(Map<String, dynamic> json) {
    final scoreValue = json['score'];
    final number = json['number']?.toString() ?? json['code']?.toString() ?? '';
    return DbOnlineMovie(
      id: json['id']?.toString() ?? number,
      number: number,
      title: json['title']?.toString() ?? '',
      coverUrl: _stringOrNull(json['cover_url']),
      thumbUrl: _stringOrNull(json['thumb_url']),
      releaseDate: _stringOrNull(json['release_date'] ?? json['date']),
      duration: _stringOrNull(json['duration']),
      magnetsCount:
          _intValue(json['magnets_count'] ?? json['magnet_count']) ?? 0,
      hasCnsub:
          json['has_cnsub'] == true ||
          json['has_subtitle'] == true ||
          json['has_magnet_subtitle'] == true,
      library: _libraryLabel(json['library']),
      score: scoreValue is num
          ? scoreValue.toDouble()
          : double.tryParse('$scoreValue'),
      canPlay: json['can_play'] == true,
    );
  }
}

/// dbonline `/latest` 的分页结果。
///
/// 旧版服务只返回当前页的 `movies` 和页内 `total`，新版服务可能额外
/// 返回 `has_more`；调用方统一通过 [hasMore] 决定是否请求下一页。
@immutable
class DbOnlineMoviePage {
  const DbOnlineMoviePage({
    required this.movies,
    required this.page,
    required this.limit,
    this.total,
    required this.hasMore,
  });

  final List<DbOnlineMovie> movies;
  final int page;
  final int limit;
  final int? total;
  final bool hasMore;
}

/// dbonline 影片详情中的实体（导演、片商、演员、分类等）。
@immutable
class DbOnlinePerson {
  const DbOnlinePerson({
    this.externalId,
    required this.name,
    this.nameZht,
    this.gender,
    this.otherName,
    this.avatarUrl,
    this.uncensored = false,
  });

  final String? externalId;
  final String name;
  final String? nameZht;
  final String? gender;
  final String? otherName;
  final String? avatarUrl;
  final bool uncensored;

  factory DbOnlinePerson.fromJson(Object? raw) {
    if (raw is! Map) return const DbOnlinePerson(name: '');
    final json = Map<String, dynamic>.from(raw);
    return DbOnlinePerson(
      externalId: _stringOrNull(json['external_id']),
      name: json['name']?.toString().trim() ?? '',
      nameZht: _stringOrNull(json['name_zht']),
      gender: _stringOrNull(json['gender']),
      otherName: _stringOrNull(json['other_name']),
      avatarUrl: _stringOrNull(json['avatar_url']),
      uncensored: json['uncensored'] == true,
    );
  }
}

/// 详情接口中的关联/推荐影片。番号和 ID 均保持字符串，避免复用
/// Oh My Media 的整数影片模型。
@immutable
class DbOnlineRecommendedMovie {
  const DbOnlineRecommendedMovie({
    this.id,
    required this.number,
    this.title,
    this.originTitle,
    this.coverUrl,
    this.thumbUrl,
    this.releaseDate,
    this.duration,
    this.score,
    this.watchedCount,
    this.canPlay = false,
    this.library,
  });

  final String? id;
  final String number;
  final String? title;
  final String? originTitle;
  final String? coverUrl;
  final String? thumbUrl;
  final String? releaseDate;
  final int? duration;
  final String? score;
  final int? watchedCount;
  final bool canPlay;
  final DbOnlineLibraryInfo? library;

  factory DbOnlineRecommendedMovie.fromJson(Object? raw) {
    if (raw is! Map) {
      return const DbOnlineRecommendedMovie(number: '');
    }
    final json = Map<String, dynamic>.from(raw);
    final number =
        _stringOrNull(json['number']) ?? _stringOrNull(json['code']) ?? '';
    final score = _stringOrNull(json['score']);
    final title = _stringOrNull(json['title']) ?? number;
    return DbOnlineRecommendedMovie(
      id: _stringOrNull(json['id']),
      number: number,
      title: title,
      originTitle: _stringOrNull(json['origin_title']),
      coverUrl: _stringOrNull(json['cover_url']),
      thumbUrl:
          _stringOrNull(json['thumb_url']) ?? _stringOrNull(json['cover_url']),
      releaseDate: _stringOrNull(json['release_date'] ?? json['date']),
      duration: _intValue(json['duration']),
      score: score,
      watchedCount: _intValue(json['watched_count']),
      canPlay: json['can_play'] == true,
      library: json['library'] is Map
          ? DbOnlineLibraryInfo.fromJson(json['library'])
          : null,
    );
  }
}

@immutable
class DbOnlineLibraryInfo {
  const DbOnlineLibraryInfo({
    this.inLibrary = false,
    this.source,
    this.name,
    this.url,
  });

  final bool inLibrary;
  final String? source;
  final String? name;
  final String? url;

  factory DbOnlineLibraryInfo.fromJson(Object? raw) {
    if (raw is! Map) return const DbOnlineLibraryInfo();
    final json = Map<String, dynamic>.from(raw);
    return DbOnlineLibraryInfo(
      inLibrary: json['in_library'] == true,
      source: _stringOrNull(json['source']),
      name: _stringOrNull(json['name']),
      url: _stringOrNull(json['url']),
    );
  }
}

@immutable
class DbOnlineMagnet {
  const DbOnlineMagnet({
    required this.name,
    required this.magnet,
    this.sizeMb,
    this.fileCount,
    this.date,
    this.tags = const <String>[],
    this.site,
  });

  final String name;
  final String magnet;
  final double? sizeMb;
  final int? fileCount;
  final String? date;
  final List<String> tags;
  final String? site;

  factory DbOnlineMagnet.fromJson(Object? raw) {
    if (raw is! Map) return const DbOnlineMagnet(name: '', magnet: '');
    final json = Map<String, dynamic>.from(raw);
    return DbOnlineMagnet(
      name: json['name']?.toString() ?? '',
      magnet: json['magnet']?.toString() ?? '',
      sizeMb: _doubleValue(json['size_mb']),
      fileCount: _intValue(json['file_count']),
      date: _stringOrNull(json['date']),
      tags: _stringList(json['tags']),
      site: _stringOrNull(json['site']),
    );
  }
}

@immutable
class DbOnlineEd2k {
  const DbOnlineEd2k({
    required this.name,
    required this.ed2k,
    this.sizeMb,
    this.date,
    this.tags = const <String>[],
    this.site,
  });

  final String name;
  final String ed2k;
  final double? sizeMb;
  final String? date;
  final List<String> tags;
  final String? site;

  factory DbOnlineEd2k.fromJson(Object? raw) {
    if (raw is! Map) return const DbOnlineEd2k(name: '', ed2k: '');
    final json = Map<String, dynamic>.from(raw);
    return DbOnlineEd2k(
      name: json['name']?.toString() ?? '',
      ed2k: json['ed2k']?.toString() ?? '',
      sizeMb: _doubleValue(json['size_mb']),
      date: _stringOrNull(json['date']),
      tags: _stringList(json['tags']),
      site: _stringOrNull(json['site']),
    );
  }
}

@immutable
class DbOnlinePlaySource {
  const DbOnlinePlaySource({required this.id, required this.name});

  final int id;
  final String name;

  factory DbOnlinePlaySource.fromJson(Object? raw) {
    if (raw is! Map) return const DbOnlinePlaySource(id: 0, name: '');
    final json = Map<String, dynamic>.from(raw);
    return DbOnlinePlaySource(
      id: _intValue(json['id']) ?? 0,
      name: json['name']?.toString() ?? '',
    );
  }
}

@immutable
class DbOnlineMovieDetail {
  const DbOnlineMovieDetail({
    required this.code,
    required this.title,
    this.originTitle,
    this.overview,
    this.videoId,
    this.coverUrl,
    this.thumbUrl,
    this.previews = const <String>[],
    this.date,
    this.duration,
    this.director,
    this.maker,
    this.publisher,
    this.series,
    this.score,
    this.watchedCount,
    this.tags = const <String>[],
    this.categories = const <DbOnlinePerson>[],
    this.actors = const <DbOnlinePerson>[],
    this.relativeMovies = const <DbOnlineRecommendedMovie>[],
    this.actorMovies = const <DbOnlineRecommendedMovie>[],
    this.magnets = const <DbOnlineMagnet>[],
    this.ed2ks = const <DbOnlineEd2k>[],
    this.library,
    this.canPlay = false,
    this.hasCnsub = false,
    this.playSources = const <DbOnlinePlaySource>[],
  });

  final String code;
  final String title;
  final String? originTitle;
  final String? overview;
  final String? videoId;
  final String? coverUrl;
  final String? thumbUrl;
  final List<String> previews;
  final String? date;
  final int? duration;
  final DbOnlinePerson? director;
  final DbOnlinePerson? maker;
  final DbOnlinePerson? publisher;
  final DbOnlinePerson? series;
  final double? score;
  final int? watchedCount;
  final List<String> tags;
  final List<DbOnlinePerson> categories;
  final List<DbOnlinePerson> actors;
  final List<DbOnlineRecommendedMovie> relativeMovies;
  final List<DbOnlineRecommendedMovie> actorMovies;
  final List<DbOnlineMagnet> magnets;
  final List<DbOnlineEd2k> ed2ks;
  final DbOnlineLibraryInfo? library;
  final bool canPlay;
  final bool hasCnsub;
  final List<DbOnlinePlaySource> playSources;

  factory DbOnlineMovieDetail.fromJson(Map<String, dynamic> json) {
    return DbOnlineMovieDetail(
      code: json['code']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      originTitle: _stringOrNull(
        json['origin_title'] ?? json['original_title'],
      ),
      overview: _stringOrNull(json['overview']),
      videoId: _stringOrNull(json['video_id']),
      coverUrl: _stringOrNull(json['cover_url']),
      thumbUrl: _stringOrNull(json['thumb_url']),
      previews: _stringList(json['previews']),
      date: _stringOrNull(json['date'] ?? json['release_date']),
      duration: _intValue(json['duration']),
      director: _personOrNull(json['director']),
      maker: _personOrNull(json['maker']),
      publisher: _personOrNull(json['publisher']),
      series: _personOrNull(json['series']),
      score: _doubleValue(json['score']),
      watchedCount: _intValue(json['watched_count']),
      tags: _stringList(json['tags']),
      categories: _personList(json['categories']),
      actors: _personList(json['actors']),
      relativeMovies: _recommendedMovieList(json['relative_movies']),
      actorMovies: _recommendedMovieList(json['actor_movies']),
      magnets: _magnetList(json['magnets']),
      ed2ks: _ed2kList(json['ed2ks']),
      library: json['library'] is Map
          ? DbOnlineLibraryInfo.fromJson(json['library'])
          : null,
      canPlay: json['can_play'] == true,
      hasCnsub: json['has_cnsub'] == true,
      playSources: _playSourceList(json['play_sources']),
    );
  }
}

@immutable
class DbOnlinePlayQuality {
  const DbOnlinePlayQuality({required this.name, required this.url});

  final String name;
  final String url;

  factory DbOnlinePlayQuality.fromJson(Object? raw) {
    if (raw is! Map) return const DbOnlinePlayQuality(name: '', url: '');
    final json = Map<String, dynamic>.from(raw);
    return DbOnlinePlayQuality(
      name: json['name']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
    );
  }
}

@immutable
class DbOnlinePlayEpisode {
  const DbOnlinePlayEpisode({
    required this.index,
    required this.name,
    required this.url,
    this.quality,
    this.duration,
    this.size,
    this.qualities = const <DbOnlinePlayQuality>[],
  });

  final int index;
  final String name;
  final String url;
  final String? quality;
  final int? duration;
  final int? size;
  final List<DbOnlinePlayQuality> qualities;

  factory DbOnlinePlayEpisode.fromJson(Map<String, dynamic> json) {
    final rawQualities = json['qualities'];
    return DbOnlinePlayEpisode(
      index: _intValue(json['index']) ?? 0,
      name: json['name']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      quality: _stringOrNull(json['quality']),
      duration: _intValue(json['duration']),
      size: _intValue(json['size']),
      qualities: rawQualities is List
          ? rawQualities
                .map(DbOnlinePlayQuality.fromJson)
                .where((item) => item.url.isNotEmpty)
                .toList(growable: false)
          : const <DbOnlinePlayQuality>[],
    );
  }

  String urlForQuality(String? qualityName) {
    final requested = qualityName?.trim() ?? '';
    if (requested.isNotEmpty) {
      for (final item in qualities) {
        if (item.name == requested && item.url.isNotEmpty) return item.url;
      }
    }
    if (url.isNotEmpty) return url;
    return qualities.isEmpty ? '' : qualities.first.url;
  }
}

@immutable
class DbOnlinePlayEpisodes {
  const DbOnlinePlayEpisodes({
    required this.code,
    this.videoId,
    required this.sourceId,
    this.episodes = const <DbOnlinePlayEpisode>[],
  });

  final String code;
  final String? videoId;
  final int sourceId;
  final List<DbOnlinePlayEpisode> episodes;

  factory DbOnlinePlayEpisodes.fromJson(Map<String, dynamic> json) {
    final rawEpisodes = json['episodes'];
    return DbOnlinePlayEpisodes(
      code: json['code']?.toString() ?? '',
      videoId: _stringOrNull(json['video_id']),
      sourceId: _intValue(json['source_id']) ?? 0,
      episodes: rawEpisodes is List
          ? rawEpisodes
                .whereType<Map>()
                .map(
                  (item) => DbOnlinePlayEpisode.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(growable: false)
          : const <DbOnlinePlayEpisode>[],
    );
  }
}

String? _stringOrNull(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

String? _libraryLabel(Object? value) {
  if (value is Map) {
    final json = Map<String, dynamic>.from(value);
    return _stringOrNull(json['name']) ?? _stringOrNull(json['source']);
  }
  return _stringOrNull(value);
}

int? _intValue(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString().trim() ?? '');
}

double? _doubleValue(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString().trim() ?? '');
}

List<String> _stringList(Object? value) {
  if (value is! List) return const <String>[];
  return value
      .map((item) => item?.toString().trim() ?? '')
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

DbOnlinePerson? _personOrNull(Object? value) {
  if (value is! Map) return null;
  final person = DbOnlinePerson.fromJson(value);
  return person.name.isEmpty && person.externalId == null ? null : person;
}

List<DbOnlinePerson> _personList(Object? value) {
  if (value is! List) return const <DbOnlinePerson>[];
  return value
      .whereType<Map>()
      .map((item) => DbOnlinePerson.fromJson(item))
      .where((item) => item.name.isNotEmpty)
      .toList(growable: false);
}

List<DbOnlineRecommendedMovie> _recommendedMovieList(Object? value) {
  if (value is! List) return const <DbOnlineRecommendedMovie>[];
  return value
      .map(DbOnlineRecommendedMovie.fromJson)
      .where((item) => item.number.isNotEmpty || item.title?.isNotEmpty == true)
      .toList(growable: false);
}

List<DbOnlineMagnet> _magnetList(Object? value) {
  if (value is! List) return const <DbOnlineMagnet>[];
  return value
      .map(DbOnlineMagnet.fromJson)
      .where((item) => item.magnet.isNotEmpty || item.name.isNotEmpty)
      .toList(growable: false);
}

List<DbOnlineEd2k> _ed2kList(Object? value) {
  if (value is! List) return const <DbOnlineEd2k>[];
  return value
      .map(DbOnlineEd2k.fromJson)
      .where((item) => item.ed2k.isNotEmpty || item.name.isNotEmpty)
      .toList(growable: false);
}

List<DbOnlinePlaySource> _playSourceList(Object? value) {
  if (value is! List) return const <DbOnlinePlaySource>[];
  return value
      .map(DbOnlinePlaySource.fromJson)
      .where((item) => item.id > 0)
      .toList(growable: false);
}
