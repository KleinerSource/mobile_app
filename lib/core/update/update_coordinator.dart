import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'update_installer.dart';
import 'update_models.dart';
import 'update_repository.dart';
import 'update_service.dart';

enum UpdateInstallAction { iosInstallerOpened, androidInstallerOpened }

class AppUpdateCoordinator {
  const AppUpdateCoordinator(this._service);

  final GitHubUpdateService _service;

  Future<UpdateCheckResult> check({
    required String repositoryUrl,
    required UpdatePlatform platform,
    required AppReleaseVersion currentVersion,
    bool includeDevelopment = false,
  }) {
    return _service.check(
      repositoryUrl: repositoryUrl,
      platform: platform,
      currentVersion: currentVersion,
      includeDevelopment: includeDevelopment,
    );
  }

  Future<UpdateInstallAction> install(
    UpdateCheckResult result, {
    void Function(int received, int total)? onReceiveProgress,
  }) async {
    final asset = result.candidate.asset;
    if (Platform.isIOS) {
      final launched = await launchUrl(
        IosUpdateInstaller.installUri(asset.downloadUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw const UpdateException();
      }
      return UpdateInstallAction.iosInstallerOpened;
    }

    if (Platform.isAndroid) {
      final file = await _service.download(
        asset,
        onReceiveProgress: onReceiveProgress,
      );
      final installed = await AndroidUpdateInstaller.install(file);
      if (!installed) {
        throw const UpdateException();
      }
      return UpdateInstallAction.androidInstallerOpened;
    }

    throw const UpdateException();
  }
}

final appUpdateCoordinatorProvider = Provider<AppUpdateCoordinator>(
  (ref) => AppUpdateCoordinator(ref.watch(gitHubUpdateServiceProvider)),
);
