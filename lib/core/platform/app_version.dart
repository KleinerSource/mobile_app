import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

final appPackageInfoProvider = FutureProvider<PackageInfo>(
  (_) => PackageInfo.fromPlatform(),
);

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
