import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';
import '../../core/platform/app_version.dart';
import '../../core/update/update_coordinator.dart';
import '../../core/update/update_models.dart';
import '../../core/update/update_repository.dart';
import '../../core/update/update_service.dart';

class StartupUpdateGate extends ConsumerStatefulWidget {
  const StartupUpdateGate({super.key, required this.child});

  final Widget child;

  @override
  StartupUpdateGateState createState() => StartupUpdateGateState();
}

class StartupUpdateGateState extends ConsumerState<StartupUpdateGate> {
  bool _started = false;

  @override
  Widget build(BuildContext context) => widget.child;

  void startCheck() {
    if (_started || !mounted) return;
    _started = true;
    unawaited(_checkForUpdate());
  }

  Future<void> _checkForUpdate() async {
    final repositoryUrl = ref.read(updateRepositoryUrlProvider);
    final platform = _currentPlatform;
    if (repositoryUrl == null || platform == null) return;

    try {
      final packageInfo = await ref.read(appPackageInfoProvider.future);
      final currentVersion = AppReleaseVersion.fromPackageInfo(
        packageInfo.version,
        packageInfo.buildNumber,
      );
      final result = await ref.read(appUpdateCoordinatorProvider).check(
            repositoryUrl: repositoryUrl,
            platform: platform,
            currentVersion: currentVersion,
          );
      if (!mounted || !result.hasUpdate) return;

      final repository = ref.read(updateSettingsRepositoryProvider);
      if (repository.isUpdateIgnored(
        repositoryUrl: result.repository.canonicalUrl,
        platform: platform,
        version: result.candidate.version,
      )) {
        return;
      }

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => UpdatePromptDialog(
          result: result,
          onUpdate: (onProgress) async {
            await ref.read(appUpdateCoordinatorProvider).install(
                  result,
                  onReceiveProgress: onProgress,
                );
          },
          onIgnore: () => repository.ignoreUpdate(
            repositoryUrl: result.repository.canonicalUrl,
            platform: platform,
            version: result.candidate.version,
          ),
        ),
      );
    } catch (_) {
      // 启动检查失败不打断主界面，用户仍可从版本号后的按钮手动检查。
    }
  }

  UpdatePlatform? get _currentPlatform {
    if (Platform.isIOS) return UpdatePlatform.ios;
    if (Platform.isAndroid) return UpdatePlatform.android;
    return null;
  }
}

typedef UpdatePromptUpdate = Future<void> Function(
  void Function(int received, int total) onProgress,
);

class UpdatePromptDialog extends StatefulWidget {
  const UpdatePromptDialog({
    super.key,
    required this.result,
    required this.onUpdate,
    required this.onIgnore,
  });

  final UpdateCheckResult result;
  final UpdatePromptUpdate onUpdate;
  final Future<void> Function() onIgnore;

  @override
  State<UpdatePromptDialog> createState() => _UpdatePromptDialogState();
}

class _UpdatePromptDialogState extends State<UpdatePromptDialog> {
  bool _busy = false;
  double? _progress;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final release = widget.result.candidate.release;
    final releaseTitle = release.name.isEmpty ? release.tagName : release.name;
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.system_update_alt_outlined, color: colors.accent),
          const SizedBox(width: 10),
          const Expanded(child: Text('发现新版本')),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.result.candidate.version.display,
              style: AppText.sectionTitle(context),
            ),
            const SizedBox(height: 6),
            Text(releaseTitle, style: AppText.body(context)),
            if (release.body.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                release.body,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: AppText.meta(context),
              ),
            ],
            if (_progress != null) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 6),
              Text(
                '正在下载更新 ${(100 * _progress!).round()}%',
                style: AppText.meta(context),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: colors.danger),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : _ignore,
          child: const Text('忽略'),
        ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('稍后'),
        ),
        FilledButton.icon(
          onPressed: _busy ? null : _update,
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_outlined, size: 18),
          label: const Text('更新'),
        ),
      ],
    );
  }

  Future<void> _update() async {
    setState(() {
      _busy = true;
      _progress = null;
      _error = null;
    });
    try {
      await widget.onUpdate((received, total) {
        if (!mounted || total <= 0) return;
        setState(() => _progress = received / total);
      });
      if (!mounted) return;
      AppHaptics.medium();
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error is UpdateException ? error.message : '更新失败，请稍后重试';
      });
    }
  }

  Future<void> _ignore() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onIgnore();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '保存忽略设置失败';
      });
    }
  }
}
