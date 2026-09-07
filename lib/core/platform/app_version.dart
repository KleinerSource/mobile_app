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

/// 为媒体请求头补齐默认 User-Agent。
///
/// 直链或服务端返回的非空 User-Agent 具有更高优先级；其他鉴权头原样
/// 保留。匹配 User-Agent 时忽略大小写，避免重复添加不同大小写的键。
Future<Map<String, String>> mergeMediaRequestHeaders(
  Map<String, String>? headers,
) async {
  final merged = Map<String, String>.from(headers ?? const <String, String>{});
  String? userAgentKey;
  for (final entry in merged.entries) {
    if (entry.key.toLowerCase() != 'user-agent') continue;
    userAgentKey ??= entry.key;
    if (entry.value.trim().isNotEmpty) return merged;
  }

  final userAgent = await appUserAgent();
  if (userAgentKey == null) {
    merged['User-Agent'] = userAgent;
  } else {
    merged[userAgentKey] = userAgent;
  }
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
