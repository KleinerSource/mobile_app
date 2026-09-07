import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

Future<PackageInfo>? _packageInfoFuture;
Future<String>? _appUserAgentFuture;

final appPackageInfoProvider = FutureProvider<PackageInfo>(
  (_) => _loadPackageInfo(),
);

Future<PackageInfo> _loadPackageInfo() {
  final cached = _packageInfoFuture;
  if (cached != null) return cached;
  return _packageInfoFuture = PackageInfo.fromPlatform();
}

/// 返回所有 OMM 请求共用的默认 User-Agent。
///
/// 只使用 [PackageInfo.version]，不拼接 build number；插件不可用时统一
/// 回退到 `omm/unknown`，确保各播放器和 API 的默认值一致。
Future<String> appUserAgent() {
  final cached = _appUserAgentFuture;
  if (cached != null) return cached;
  return _appUserAgentFuture = _loadAppUserAgent();
}

Future<String> _loadAppUserAgent() async {
  try {
    return formatAppUserAgent((await _loadPackageInfo()).version);
  } catch (_) {
    return 'omm/unknown';
  }
}

/// 为媒体请求头强制设置唯一的 OMM User-Agent。
///
/// 媒体源可能携带平台、播放器或服务端下发的其他 UA；媒体请求统一忽略
/// 这些值，只使用 [appUserAgent]。其他鉴权头原样保留，且大小写不同的
/// User-Agent 键也会被清理，避免底层播放器再次发出多个 UA。
Future<Map<String, String>> mergeMediaRequestHeaders(
  Map<String, String>? headers,
) async {
  final merged = <String, String>{};
  for (final entry in (headers ?? const <String, String>{}).entries) {
    if (entry.key.toLowerCase() == 'user-agent') continue;
    merged[entry.key] = entry.value;
  }
  merged['User-Agent'] = await appUserAgent();
  return merged;
}

String formatAppUserAgent(String version) {
  final normalizedVersion = version.trim();
  return normalizedVersion.isEmpty ? 'omm/unknown' : 'omm/$normalizedVersion';
}

/// 仅供测试在不同 PackageInfo 场景间切换时清理进程级缓存。
void resetAppVersionCache() {
  _packageInfoFuture = null;
  _appUserAgentFuture = null;
}

String formatAppVersion(String version, String buildNumber) {
  final normalizedVersion = version.trim();
  final normalizedBuild = buildNumber.trim();
  if (normalizedVersion.isEmpty) return normalizedBuild;
  if (normalizedBuild.isEmpty ||
      normalizedVersion.endsWith('+$normalizedBuild')) {
    return normalizedVersion;
  }
  return '$normalizedVersion+$normalizedBuild';
}
