import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/server_config_provider.dart';

enum CacheSizeOption { disabled, mb300, mb500, mb750, gb1, gb2, gb4 }

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
    return DiskPrecacheSettingsRepository(
      ref.watch(sharedPrefsProvider),
    ).load();
  }

  Future<void> update(DiskPrecacheSettings next) async {
    state = next;
    await DiskPrecacheSettingsRepository(
      ref.read(sharedPrefsProvider),
    ).save(next);
  }
}

final diskPrecacheSettingsProvider =
    NotifierProvider<DiskPrecacheSettingsNotifier, DiskPrecacheSettings>(
      DiskPrecacheSettingsNotifier.new,
    );

/// 播放器没有启用磁盘缓存时仍保留一段基础内存缓冲，避免“禁用缓存”变成
/// 播放器完全没有网络缓冲能力。
const defaultVideoBufferBytes = 32 * 1024 * 1024;
const maxVideoPrefetchBufferBytes = 256 * 1024 * 1024;

/// 根据媒体平均码率估算 15% 预载所需的 demuxer 缓冲上限。
///
/// 该值只用于进程内缓冲,与用户设置的磁盘缓存额度严格分离。上限是
/// 256 MiB,避免把 1/2/4 GiB 磁盘额度直接变成 iOS native 内存分配。
int videoBufferBytesForPrefetch({
  required bool diskCacheEnabled,
  required double durationSeconds,
  int bitRate = 0,
  int targetBitrate = 0,
  int fallbackBytes = defaultVideoBufferBytes,
}) {
  final safeFallback = fallbackBytes > 0
      ? fallbackBytes
      : defaultVideoBufferBytes;
  if (!diskCacheEnabled) return safeFallback;
  // 后端旧版本或 .strm 可能暂时没有时长/码率元数据。磁盘缓存已明确开启
  // 时仍给一个受控的最大窗口,待 mpv 得到时长后由 cache-secs 再收敛到 15%。
  if (durationSeconds <= 0) return maxVideoPrefetchBufferBytes;
  final effectiveBitrate = targetBitrate > 0 ? targetBitrate : bitRate;
  if (effectiveBitrate <= 0) return maxVideoPrefetchBufferBytes;

  // 额外 25% 给音视频交错、码率波动和容器开销,不是磁盘缓存额度。
  final estimated = effectiveBitrate * durationSeconds * 0.15 * 1.25 / 8;
  if (estimated <= safeFallback) return safeFallback;
  if (estimated >= maxVideoPrefetchBufferBytes) {
    return maxVideoPrefetchBufferBytes;
  }
  return estimated.ceil();
}

@immutable
class VideoBufferPolicy {
  const VideoBufferPolicy({
    required this.bufferSize,
    required this.diskCacheEnabled,
    required this.diskCacheLimitBytes,
  });

  /// media_kit 的进程内 demuxer 缓冲大小，不能与磁盘缓存上限混用。
  final int bufferSize;
  final bool diskCacheEnabled;

  /// 持久化视频文件的磁盘淘汰上限。
  final int diskCacheLimitBytes;
}

VideoBufferPolicy videoBufferPolicyFor(CacheSizeOption option) {
  if (option == CacheSizeOption.disabled) {
    return const VideoBufferPolicy(
      bufferSize: defaultVideoBufferBytes,
      diskCacheEnabled: false,
      diskCacheLimitBytes: 0,
    );
  }
  return VideoBufferPolicy(
    // CacheSizeOption controls disk retention only. Passing 1-4GB here would
    // make media_kit allocate an equally large native demuxer buffer.
    bufferSize: defaultVideoBufferBytes,
    diskCacheEnabled: true,
    diskCacheLimitBytes: option.bytes,
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
  final digits = unit == 0
      ? 0
      : value >= 10
      ? 1
      : 2;
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
    final base = await _cacheBaseDirectory();
    final directory = Directory(
      '${base.path}${Platform.pathSeparator}$_rootName',
    );
    await directory.create(recursive: true);
    _root = directory;
    return directory;
  }

  Future<Directory> _cacheBaseDirectory() {
    final override = _rootOverride;
    return override == null
        ? getApplicationSupportDirectory()
        : Future.value(override);
  }

  Future<Directory> _categoryDirectory(String name) async {
    final root = await _rootDirectory();
    final directory = Directory('${root.path}${Platform.pathSeparator}$name');
    await directory.create(recursive: true);
    return directory;
  }

  Future<CacheUsage> usage() async {
    final root = await _rootDirectory();
    // DefaultCacheManager 仍使用临时目录，图片统计要跟随它的实际位置；
    // 播放缓存使用应用缓存目录，避免与图片缓存路径混淆。
    final imageBase = _rootOverride ?? await getTemporaryDirectory();
    final image = Directory(
      '${imageBase.path}${Platform.pathSeparator}${DefaultCacheManager.key}',
    );
    final videoDirectories = await _videoCacheDirectories(root: root);
    return CacheUsage(
      videoBytes: await _sumDirectorySizes(videoDirectories),
      imageBytes: await _directorySize(image),
      otherBytes: await _directorySize(
        Directory('${root.path}${Platform.pathSeparator}$_otherDirName'),
      ),
    );
  }

  /// media_kit/libmpv 的磁盘缓冲和持久化录制缓存使用此目录。
  Future<Directory> videoBufferDirectory() => _categoryDirectory(_videoDirName);

  /// 为单个影片/画质生成稳定的持久化缓存文件名。
  ///
  /// mpv 的 `stream-record` 会在媒体关闭时关闭文件但保留文件内容，
  /// 因此不能使用临时文件名，否则缓存管理无法跨播放会话工作。
  Future<File> videoCacheFile({
    required int movieId,
    required String quality,
    String extension = '.mkv',
  }) async {
    final directory = await videoBufferDirectory();
    final safeQuality = quality.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final safeExtension = _videoCacheExtension(extension);
    return File(
      '${directory.path}${Platform.pathSeparator}movie-$movieId-$safeQuality$safeExtension',
    );
  }

  /// 查找可用于快速恢复的持久化视频片段。
  ///
  /// 片段的扩展名可能来自旧版本或旧的播放路线，因此优先匹配调用方
  /// 计算出的扩展名，找不到时再按最近修改时间回退到其他支持的容器。
  Future<File?> findVideoCacheFile({
    required int movieId,
    required String quality,
    String? preferredExtension,
  }) async {
    final root = await _rootDirectory();
    final safeQuality = quality.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final prefix = 'movie-$movieId-$safeQuality';
    final preferred = preferredExtension == null
        ? null
        : _videoCacheExtension(preferredExtension);
    final candidates = <File>[];
    final seen = <String>{};
    for (final directory in await _videoCacheDirectories(root: root)) {
      if (!await directory.exists()) continue;
      await for (final entity in directory.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File || !seen.add(entity.path)) continue;
        final name = entity.path.split(Platform.pathSeparator).last;
        if (!name.startsWith('$prefix.') ||
            !_isPersistentVideoCacheFile(entity.path)) {
          continue;
        }
        try {
          if (await entity.length() > 0) candidates.add(entity);
        } on FileSystemException {
          // 播放器可能正好在关闭文件，下一次打开时再尝试查找。
        }
      }
    }
    if (candidates.isEmpty) return null;

    final entries = <({File file, DateTime modified})>[];
    for (final file in candidates) {
      try {
        entries.add((file: file, modified: await file.lastModified()));
      } on FileSystemException {
        // 文件可能在扫描后被系统清理。
      }
    }
    entries.sort((a, b) {
      final aPreferred =
          preferred != null && a.file.path.toLowerCase().endsWith(preferred);
      final bPreferred =
          preferred != null && b.file.path.toLowerCase().endsWith(preferred);
      if (aPreferred != bPreferred) return aPreferred ? -1 : 1;
      return b.modified.compareTo(a.modified);
    });
    if (entries.isEmpty) return null;
    final selected = entries.first.file;
    try {
      await selected.setLastModified(DateTime.now());
    } on FileSystemException {
      // 更新访问时间失败不影响继续使用缓存片段。
    }
    return selected;
  }

  /// 按缓存上限淘汰最旧的持久化视频文件。
  Future<void> pruneVideoCache({required int maxBytes}) {
    if (maxBytes <= 0) return Future<void>.value();
    return _enqueue(() async {
      final root = await _rootDirectory();
      final directories = await _videoCacheDirectories(root: root);
      final files = <File>[];
      for (final directory in directories) {
        if (!await directory.exists()) continue;
        await for (final entity in directory.list(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is File && _isPersistentVideoCacheFile(entity.path)) {
            files.add(entity);
          }
        }
      }
      final entries = <({File file, int bytes, DateTime modified})>[];
      for (final file in files) {
        try {
          entries.add((
            file: file,
            bytes: await file.length(),
            modified: await file.lastModified(),
          ));
        } on FileSystemException {
          // 文件可能在播放器或系统清理过程中刚刚被删除。
        }
      }
      entries.sort((a, b) => a.modified.compareTo(b.modified));
      var total = entries.fold<int>(0, (sum, item) => sum + item.bytes);
      for (final item in entries) {
        // 即使单个视频超过上限，也保留最近一次缓存；缓存管理页仍可
        // 通过“视频缓存”清理它，关闭视频不能把唯一缓存直接删掉。
        if (total <= maxBytes || entries.length <= 1) break;
        try {
          await item.file.delete();
          total -= item.bytes;
        } on FileSystemException {
          // 忽略单个文件删除失败，下一次清理继续处理。
        }
      }
    });
  }

  Future<void> clear(CacheCategory category) {
    return _enqueue(() async {
      if (category == CacheCategory.image) {
        await DefaultCacheManager().emptyCache();
        return;
      }
      if (category == CacheCategory.video) {
        final root = await _rootDirectory();
        for (final directory in await _videoCacheDirectories(root: root)) {
          if (await directory.exists()) {
            await directory.delete(recursive: true);
          }
        }
        await _categoryDirectory(_videoDirName);
        return;
      }
      final directory = await _categoryDirectory(_otherDirName);
      if (await directory.exists()) await directory.delete(recursive: true);
      await directory.create(recursive: true);
    });
  }

  Future<void> clearAll() {
    return _enqueue(() async {
      await DefaultCacheManager().emptyCache();
      final root = await _rootDirectory();
      final videoDirectories = await _videoCacheDirectories(root: root);
      if (await root.exists()) await root.delete(recursive: true);
      await root.create(recursive: true);
      for (final directory in videoDirectories) {
        if (directory.path == root.path) continue;
        if (await directory.exists()) await directory.delete(recursive: true);
      }
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
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }

  bool _isPersistentVideoCacheFile(String path) {
    final lowerPath = path.toLowerCase();
    return lowerPath.endsWith('.mp4') ||
        lowerPath.endsWith('.mkv') ||
        lowerPath.endsWith('.ts') ||
        lowerPath.endsWith('.mov') ||
        lowerPath.endsWith('.webm');
  }

  String _videoCacheExtension(String extension) {
    final normalized = extension.trim().toLowerCase();
    return switch (normalized) {
      '.mp4' || '.mkv' || '.ts' || '.mov' || '.webm' => normalized,
      _ => '.mkv',
    };
  }

  Future<List<Directory>> _videoCacheDirectories({
    required Directory root,
  }) async {
    final configured = Directory(
      '${root.path}${Platform.pathSeparator}$_videoDirName',
    );
    if (_rootOverride != null) return [configured];

    // Older media_kit/mpv builds can ignore a runtime demuxer-cache-dir and
    // fall back to their platform cache directory. Include those locations so
    // the management page can still show and clear the files.
    final bases = <Directory>[
      await getApplicationCacheDirectory(),
      await getTemporaryDirectory(),
      await getApplicationSupportDirectory(),
    ];
    final candidates = <Directory>[configured];
    for (final base in bases) {
      candidates.add(
        Directory(
          '${base.path}${Platform.pathSeparator}$_rootName${Platform.pathSeparator}$_videoDirName',
        ),
      );
      candidates.add(Directory('${base.path}${Platform.pathSeparator}mpv'));
      candidates.add(
        Directory(
          '${base.path}${Platform.pathSeparator}.cache${Platform.pathSeparator}mpv',
        ),
      );
    }
    final seen = <String>{};
    return [
      for (final directory in candidates)
        if (seen.add(directory.path)) directory,
    ];
  }

  Future<int> _sumDirectorySizes(Iterable<Directory> directories) async {
    var total = 0;
    for (final directory in directories) {
      total += await _directorySize(directory);
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
    final policy = videoBufferPolicyFor(option);
    debugPrint(
      '[VideoBufferPolicy] network=${networkType.label} '
      'option=${option.label} diskCacheEnabled=${policy.diskCacheEnabled} '
      'diskCacheLimitBytes=${policy.diskCacheLimitBytes}',
    );
    return policy;
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
