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
