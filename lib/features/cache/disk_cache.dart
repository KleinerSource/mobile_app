import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// 播放器没有启用磁盘缓存时仍保留一段基础内存缓冲，避免“禁用缓存”变成
/// 播放器完全没有网络缓冲能力。
const defaultVideoBufferBytes = 32 * 1024 * 1024;

@immutable
class VideoBufferPolicy {
  const VideoBufferPolicy({
    required this.bufferSize,
    required this.diskCacheEnabled,
  });

  final int bufferSize;
  final bool diskCacheEnabled;
}

VideoBufferPolicy videoBufferPolicyFor(CacheSizeOption option) {
  if (option == CacheSizeOption.disabled) {
    return const VideoBufferPolicy(
      bufferSize: defaultVideoBufferBytes,
      diskCacheEnabled: false,
    );
  }
  return VideoBufferPolicy(
    bufferSize: option.bytes,
    diskCacheEnabled: true,
  );
}

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

enum PrecacheNetwork { wifi, mobile }

extension PrecacheNetworkX on PrecacheNetwork {
  String get label => this == PrecacheNetwork.wifi ? 'Wi-Fi' : '流量';
}

class CacheNetworkUnavailableException implements Exception {
  const CacheNetworkUnavailableException();

  @override
  String toString() => '当前没有可用网络';
}

class DiskCacheService {
  DiskCacheService({Directory? rootDirectory}) : _rootOverride = rootDirectory;

  static const _rootName = 'md_center_cache';
  static const _videoDirName = 'video';
  static const _otherDirName = 'other';

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

  /// media_kit 的 `demuxer-cache-dir` 使用此目录写入播放中的临时缓冲。
  /// 缓冲文件由 mpv 在媒体关闭后自动删除，不会变成完整视频文件。
  Future<Directory> videoBufferDirectory() =>
      _categoryDirectory(_videoDirName);

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

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final result = _operationQueue.then((_) => action());
    _operationQueue = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
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

class VideoBufferPolicyService {
  const VideoBufferPolicyService({Connectivity? connectivity})
      : _connectivity = connectivity;

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

  Future<VideoBufferPolicy> policy(DiskPrecacheSettings settings) async {
    final networkType = await network();
    final option = networkType == PrecacheNetwork.wifi
        ? settings.wifiLimit
        : settings.mobileLimit;
    return videoBufferPolicyFor(option);
  }
}

final diskCacheServiceProvider = Provider<DiskCacheService>(
  (ref) => DiskCacheService(),
);

final cacheUsageProvider = FutureProvider.autoDispose<CacheUsage>((ref) {
  return ref.watch(diskCacheServiceProvider).usage();
});

final videoBufferPolicyProvider = Provider<VideoBufferPolicyService>((ref) {
  return const VideoBufferPolicyService();
});
