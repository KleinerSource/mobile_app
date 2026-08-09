import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/api_client.dart';
import '../../core/api/providers.dart';
import '../../core/api/url_resolver.dart';
import '../../core/auth/auth_session_provider.dart';
import '../../core/auth/auth_session_repository.dart';
import '../../core/config/server_config.dart';
import '../../core/config/server_config_provider.dart';

enum CacheSizeOption {
  disabled,
  mb300,
  mb500,
  mb750,
  gb1,
  gb2,
  gb4,
}

extension CacheSizeOptionX on CacheSizeOption {
  String get label => switch (this) {
        CacheSizeOption.disabled => '禁用',
        CacheSizeOption.mb300 => '300MB',
        CacheSizeOption.mb500 => '500MB',
        CacheSizeOption.mb750 => '750MB',
        CacheSizeOption.gb1 => '1GB',
        CacheSizeOption.gb2 => '2GB',
        CacheSizeOption.gb4 => '4GB',
      };

  int get bytes => switch (this) {
        CacheSizeOption.disabled => 0,
        CacheSizeOption.mb300 => 300 * 1024 * 1024,
        CacheSizeOption.mb500 => 500 * 1024 * 1024,
        CacheSizeOption.mb750 => 750 * 1024 * 1024,
        CacheSizeOption.gb1 => 1 * 1024 * 1024 * 1024,
        CacheSizeOption.gb2 => 2 * 1024 * 1024 * 1024,
        CacheSizeOption.gb4 => 4 * 1024 * 1024 * 1024,
      };
}

const cacheSizeOptions = <CacheSizeOption>[
  CacheSizeOption.disabled,
  CacheSizeOption.mb300,
  CacheSizeOption.mb500,
  CacheSizeOption.mb750,
  CacheSizeOption.gb1,
  CacheSizeOption.gb2,
  CacheSizeOption.gb4,
];

@immutable
class DiskPrecacheSettings {
  const DiskPrecacheSettings({
    this.wifiLimit = CacheSizeOption.gb1,
    this.mobileLimit = CacheSizeOption.disabled,
  });

  static const defaults = DiskPrecacheSettings();

  final CacheSizeOption wifiLimit;
  final CacheSizeOption mobileLimit;

  DiskPrecacheSettings copyWith({
    CacheSizeOption? wifiLimit,
    CacheSizeOption? mobileLimit,
  }) {
    return DiskPrecacheSettings(
      wifiLimit: wifiLimit ?? this.wifiLimit,
      mobileLimit: mobileLimit ?? this.mobileLimit,
    );
  }
}

class DiskPrecacheSettingsRepository {
  DiskPrecacheSettingsRepository(this._prefs);

  static const _wifiKey = 'cache.precache_wifi_limit';
  static const _mobileKey = 'cache.precache_mobile_limit';

  final SharedPreferences _prefs;

  DiskPrecacheSettings load() {
    return DiskPrecacheSettings(
      wifiLimit: _read(_wifiKey, DiskPrecacheSettings.defaults.wifiLimit),
      mobileLimit: _read(_mobileKey, DiskPrecacheSettings.defaults.mobileLimit),
    );
  }

  Future<void> save(DiskPrecacheSettings settings) async {
    await Future.wait([
      _prefs.setInt(_wifiKey, settings.wifiLimit.index),
      _prefs.setInt(_mobileKey, settings.mobileLimit.index),
    ]);
  }

  CacheSizeOption _read(String key, CacheSizeOption fallback) {
    final index = _prefs.getInt(key);
    if (index == null || index < 0 || index >= CacheSizeOption.values.length) {
      return fallback;
    }
    return CacheSizeOption.values[index];
  }
}

class DiskPrecacheSettingsNotifier extends Notifier<DiskPrecacheSettings> {
  @override
  DiskPrecacheSettings build() {
    return DiskPrecacheSettingsRepository(ref.watch(sharedPrefsProvider)).load();
  }

  Future<void> update(DiskPrecacheSettings next) async {
    state = next;
    await DiskPrecacheSettingsRepository(ref.read(sharedPrefsProvider))
        .save(next);
  }
}

final diskPrecacheSettingsProvider =
    NotifierProvider<DiskPrecacheSettingsNotifier, DiskPrecacheSettings>(
  DiskPrecacheSettingsNotifier.new,
);

enum CacheCategory { video, image, other }

extension CacheCategoryX on CacheCategory {
  String get label => switch (this) {
        CacheCategory.video => '视频缓存',
        CacheCategory.image => '图片缓存',
        CacheCategory.other => '其他缓存',
      };
}

@immutable
class CacheUsage {
  const CacheUsage({
    required this.videoBytes,
    required this.imageBytes,
    required this.otherBytes,
  });

  final int videoBytes;
  final int imageBytes;
  final int otherBytes;

  int get totalBytes => videoBytes + imageBytes + otherBytes;

  int bytesFor(CacheCategory category) => switch (category) {
        CacheCategory.video => videoBytes,
        CacheCategory.image => imageBytes,
        CacheCategory.other => otherBytes,
  };
}

String formatCacheBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final digits = unit == 0 ? 0 : value >= 10 ? 1 : 2;
  return '${value.toStringAsFixed(digits)} ${units[unit]}';
}

@immutable
class VideoCacheResult {
  const VideoCacheResult({
    required this.path,
    required this.bytes,
    required this.fromCache,
  });

  final String path;
  final int bytes;
  final bool fromCache;
}

enum PrecacheNetwork { wifi, mobile }

extension PrecacheNetworkX on PrecacheNetwork {
  String get label => this == PrecacheNetwork.wifi ? 'Wi-Fi' : '流量';
}

class CacheDisabledException implements Exception {
  const CacheDisabledException(this.network);

  final PrecacheNetwork network;

  @override
  String toString() => '${network.label}预缓存已禁用';
}

class CacheLimitExceededException implements Exception {
  const CacheLimitExceededException(this.limitBytes);

  final int limitBytes;

  @override
  String toString() => '影片大小超过当前缓存上限';
}

class CacheNetworkUnavailableException implements Exception {
  const CacheNetworkUnavailableException();

  @override
  String toString() => '当前没有可用网络';
}

class DiskCacheService {
  DiskCacheService({
    Dio? downloadClient,
    Directory? rootDirectory,
  })  : _downloadClient = downloadClient ?? Dio(),
        _rootOverride = rootDirectory;

  static const _rootName = 'md_center_cache';
  static const _videoDirName = 'video';
  static const _otherDirName = 'other';
  static const _indexName = 'index.json';

  final Dio _downloadClient;
  final Directory? _rootOverride;
  Directory? _root;
  Future<void> _operationQueue = Future<void>.value();

  Future<Directory> _rootDirectory() async {
    final existing = _root;
    if (existing != null) return existing;
    final base = _rootOverride ?? await getTemporaryDirectory();
    final directory = Directory('${base.path}${Platform.pathSeparator}$_rootName');
    await directory.create(recursive: true);
    _root = directory;
    return directory;
  }

  Future<Directory> _categoryDirectory(String name) async {
    final root = await _rootDirectory();
    final directory = Directory('${root.path}${Platform.pathSeparator}$name');
    await directory.create(recursive: true);
    return directory;
  }

  Future<CacheUsage> usage() async {
    final root = await _rootDirectory();
    final temporary = _rootOverride ?? await getTemporaryDirectory();
    final image = Directory(
      '${temporary.path}${Platform.pathSeparator}${DefaultCacheManager.key}',
    );
    return CacheUsage(
      videoBytes: await _directorySize(
        Directory('${root.path}${Platform.pathSeparator}$_videoDirName'),
      ),
      imageBytes: await _directorySize(image),
      otherBytes: await _directorySize(
        Directory('${root.path}${Platform.pathSeparator}$_otherDirName'),
      ),
    );
  }

  Future<String?> cachedMovieFile(int movieId) async {
    return _enqueue(() async {
      final video = await _categoryDirectory(_videoDirName);
      final index = await _readIndex(video);
      final item = index['$movieId'];
      if (item is! Map) return null;
      final fileName = item['file']?.toString() ?? '';
      if (fileName.isEmpty) return null;
      final file = File('${video.path}${Platform.pathSeparator}$fileName');
      if (!await file.exists()) {
        index.remove('$movieId');
        await _writeIndex(video, index);
        return null;
      }
      index['$movieId'] = {
        ...Map<String, dynamic>.from(item),
        'last_accessed': DateTime.now().millisecondsSinceEpoch,
      };
      await _writeIndex(video, index);
      return file.path;
    });
  }

  Future<VideoCacheResult> cacheMovie({
    required int movieId,
    required String sourceUrl,
    required int maxBytes,
    Map<String, String>? headers,
    CancelToken? cancelToken,
    void Function(int received, int total)? onProgress,
  }) {
    return _enqueue(() async {
      if (maxBytes <= 0) {
        throw const CacheLimitExceededException(0);
      }
      final video = await _categoryDirectory(_videoDirName);
      final index = await _readIndex(video);
      final cached = await _existingFile(video, index, movieId);
      if (cached != null) {
        index['$movieId'] = {
          ...Map<String, dynamic>.from(index['$movieId'] as Map),
          'last_accessed': DateTime.now().millisecondsSinceEpoch,
        };
        await _writeIndex(video, index);
        return VideoCacheResult(
          path: cached.path,
          bytes: await cached.length(),
          fromCache: true,
        );
      }

      await _removeEntry(video, index, movieId);
      final response = await _downloadClient.get<ResponseBody>(
        sourceUrl,
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          headers: headers,
          followRedirects: true,
          receiveTimeout: null,
        ),
      );
      final body = response.data;
      if (body == null) throw StateError('服务器没有返回视频内容');
      final contentLength = int.tryParse(
        response.headers.value(Headers.contentLengthHeader) ?? '',
      );
      final total = contentLength != null && contentLength > 0
          ? contentLength
          : null;
      if (total != null && total > maxBytes) {
        throw CacheLimitExceededException(maxBytes);
      }

      await _evictToFit(
        video,
        index,
        maxBytes: maxBytes,
        requiredBytes: total ?? 0,
        protectedMovieId: movieId,
      );
      final currentUsage = await _directorySize(video);
      final fileName = _fileName(
        movieId,
        sourceUrl,
        contentType: response.headers.value(Headers.contentTypeHeader),
      );
      final target = File('${video.path}${Platform.pathSeparator}$fileName');
      final partial = File('${target.path}.part');
      if (await partial.exists()) await partial.delete();

      var received = 0;
      var completed = false;
      final sink = partial.openWrite();
      try {
        await for (final chunk in body.stream) {
          received += chunk.length;
          if (currentUsage + received > maxBytes) {
            throw CacheLimitExceededException(maxBytes);
          }
          sink.add(chunk);
          onProgress?.call(received, total ?? 0);
        }
        await sink.flush();
        completed = true;
      } finally {
        await sink.close();
        if (!completed && await partial.exists()) await partial.delete();
      }

      if (await target.exists()) await target.delete();
      await partial.rename(target.path);
      index['$movieId'] = {
        'file': fileName,
        'bytes': received,
        'last_accessed': DateTime.now().millisecondsSinceEpoch,
      };
      await _writeIndex(video, index);
      return VideoCacheResult(
        path: target.path,
        bytes: received,
        fromCache: false,
      );
    });
  }

  Future<void> clear(CacheCategory category) {
    return _enqueue(() async {
      if (category == CacheCategory.image) {
        await DefaultCacheManager().emptyCache();
        return;
      }
      final name = category == CacheCategory.video
          ? _videoDirName
          : _otherDirName;
      final directory = await _categoryDirectory(name);
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
      await directory.create(recursive: true);
    });
  }

  Future<void> clearAll() {
    return _enqueue(() async {
      await DefaultCacheManager().emptyCache();
      final root = await _rootDirectory();
      if (await root.exists()) await root.delete(recursive: true);
      await root.create(recursive: true);
    });
  }

  Future<void> trimVideoCache(int maxBytes) {
    return _enqueue(() async {
      final video = await _categoryDirectory(_videoDirName);
      final index = await _readIndex(video);
      await _evictToFit(
        video,
        index,
        maxBytes: maxBytes,
        requiredBytes: 0,
      );
    });
  }

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final result = _operationQueue.then((_) => action());
    _operationQueue = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }

  Future<File?> _existingFile(
    Directory video,
    Map<String, dynamic> index,
    int movieId,
  ) async {
    final item = index['$movieId'];
    if (item is! Map) return null;
    final fileName = item['file']?.toString() ?? '';
    if (fileName.isEmpty) return null;
    final file = File('${video.path}${Platform.pathSeparator}$fileName');
    if (await file.exists()) return file;
    index.remove('$movieId');
    await _writeIndex(video, index);
    return null;
  }

  Future<void> _removeEntry(
    Directory video,
    Map<String, dynamic> index,
    int movieId,
  ) async {
    final item = index.remove('$movieId');
    if (item is Map) {
      final fileName = item['file']?.toString() ?? '';
      if (fileName.isNotEmpty) {
        final file = File('${video.path}${Platform.pathSeparator}$fileName');
        if (await file.exists()) await file.delete();
      }
    }
    await _writeIndex(video, index);
  }

  Future<void> _evictToFit(
    Directory video,
    Map<String, dynamic> index, {
    required int maxBytes,
    required int requiredBytes,
    int? protectedMovieId,
  }) async {
    if (requiredBytes > maxBytes) {
      throw CacheLimitExceededException(maxBytes);
    }
    var usage = await _directorySize(video);
    if (usage + requiredBytes <= maxBytes) return;

    final entries = index.entries
        .where((entry) =>
            protectedMovieId == null || entry.key != '$protectedMovieId')
        .where((entry) => entry.value is Map)
        .toList()
      ..sort((a, b) => _lastAccessed(a.value).compareTo(_lastAccessed(b.value)));

    for (final entry in entries) {
      if (usage + requiredBytes <= maxBytes) break;
      final value = Map<String, dynamic>.from(entry.value as Map);
      final fileName = value['file']?.toString() ?? '';
      if (fileName.isNotEmpty) {
        final file = File('${video.path}${Platform.pathSeparator}$fileName');
        if (await file.exists()) {
          final bytes = await file.length();
          await file.delete();
          usage -= bytes;
        }
      }
      index.remove(entry.key);
    }
    await _writeIndex(video, index);
    if (usage + requiredBytes > maxBytes) {
      throw CacheLimitExceededException(maxBytes);
    }
  }

  int _lastAccessed(Object? value) {
    if (value is! Map) return 0;
    return (value['last_accessed'] as num?)?.toInt() ?? 0;
  }

  Future<Map<String, dynamic>> _readIndex(Directory video) async {
    final file = File('${video.path}${Platform.pathSeparator}$_indexName');
    if (!await file.exists()) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return <String, dynamic>{};
  }

  Future<void> _writeIndex(
    Directory video,
    Map<String, dynamic> index,
  ) async {
    final file = File('${video.path}${Platform.pathSeparator}$_indexName');
    await file.writeAsString(jsonEncode(index));
  }

  String _fileName(
    int movieId,
    String sourceUrl, {
    String? contentType,
  }) {
    final uri = Uri.tryParse(sourceUrl);
    final segment = uri?.pathSegments.isNotEmpty == true
        ? uri!.pathSegments.last
        : '';
    final extension = RegExp(r'\.[A-Za-z0-9]{1,8}$')
            .firstMatch(segment)
            ?.group(0)
            ?.toLowerCase() ??
        _extensionForContentType(contentType) ?? '.mp4';
    return 'movie_$movieId$extension';
  }

  String? _extensionForContentType(String? contentType) {
    final value = contentType?.split(';').first.trim().toLowerCase();
    return switch (value) {
      'video/x-matroska' || 'video/mkv' => '.mkv',
      'video/webm' => '.webm',
      'video/quicktime' => '.mov',
      'video/mpeg' => '.mpeg',
      'video/mp4' => '.mp4',
      _ => null,
    };
  }

  Future<int> _directorySize(Directory directory) async {
    if (!await directory.exists()) return 0;
    var total = 0;
    await for (final entity in directory.list(recursive: true, followLinks: false)) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }
}

class VideoPrecacheService {
  const VideoPrecacheService({
    required this.cache,
    required this.client,
    required this.config,
    required this.auth,
    Connectivity? connectivity,
  }) : _connectivity = connectivity;

  final DiskCacheService cache;
  final ApiClient client;
  final ServerConfig? config;
  final AuthSessionRepository auth;
  final Connectivity? _connectivity;

  Future<PrecacheNetwork> network() async {
    final results = await (_connectivity ?? Connectivity()).checkConnectivity();
    if (results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet)) {
      return PrecacheNetwork.wifi;
    }
    if (results.contains(ConnectivityResult.mobile)) {
      return PrecacheNetwork.mobile;
    }
    throw const CacheNetworkUnavailableException();
  }

  Future<VideoCacheResult> precacheMovie({
    required int movieId,
    required DiskPrecacheSettings settings,
    CancelToken? cancelToken,
    void Function(int received, int total)? onProgress,
  }) async {
    final existing = await cache.cachedMovieFile(movieId);
    if (existing != null) {
      return VideoCacheResult(
        path: existing,
        bytes: await File(existing).length(),
        fromCache: true,
      );
    }
    final networkType = await network();
    final limit = networkType == PrecacheNetwork.wifi
        ? settings.wifiLimit.bytes
        : settings.mobileLimit.bytes;
    if (limit <= 0) throw CacheDisabledException(networkType);

    final server = config;
    if (server == null) throw StateError('未配置服务器');
    final rawUrl = await client.playback.streamUrl(movieId);
    if (rawUrl.trim().isEmpty) throw StateError('服务器没有返回视频地址');
    final token = await auth.accessToken();
    final url = resolveProtectedUrl(server, rawUrl, token);
    return cache.cacheMovie(
      movieId: movieId,
      sourceUrl: url,
      maxBytes: limit,
      cancelToken: cancelToken,
      onProgress: onProgress,
    );
  }
}

final diskCacheServiceProvider = Provider<DiskCacheService>(
  (ref) => DiskCacheService(),
);

final cacheUsageProvider = FutureProvider.autoDispose<CacheUsage>((ref) {
  return ref.watch(diskCacheServiceProvider).usage();
});

final videoPrecacheServiceProvider = Provider<VideoPrecacheService>((ref) {
  return VideoPrecacheService(
    cache: ref.watch(diskCacheServiceProvider),
    client: ref.watch(requiredApiClientProvider),
    config: ref.watch(serverConfigProvider),
    auth: ref.watch(authSessionRepositoryProvider),
  );
});
