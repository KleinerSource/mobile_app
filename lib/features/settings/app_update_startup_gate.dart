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

/// 检查已经配置的更新源，并在有新版本时直接展示更新引导。
///
/// `respectIgnored` 只用于启动检查；手动点击“检测更新”时始终重新展示
/// 当前检测到的版本，避免用户无法主动恢复被忽略的更新提示。
Future<bool> checkConfiguredAppUpdate({
  required BuildContext context,
  required WidgetRef ref,
  bool respectIgnored = false,
  bool showLatestMessage = false,
}) async {
  final repositoryUrl = ref.read(updateRepositoryUrlProvider);
  final platform = _currentUpdatePlatform;
  if (repositoryUrl == null || platform == null) return false;

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
    if (!context.mounted) return true;

    if (!result.hasUpdate) {
      if (showLatestMessage) {
        _showUpdateMessage(context, '当前已是最新版本');
      }
      return true;
    }

    final repository = ref.read(updateSettingsRepositoryProvider);
    if (respectIgnored &&
        repository.isUpdateIgnored(
          repositoryUrl: result.repository.canonicalUrl,
          platform: platform,
          version: result.candidate.version,
        )) {
      return true;
    }

    await _showUpdatePrompt(
      context: context,
      ref: ref,
      result: result,
      repository: repository,
      platform: platform,
    );
    return true;
  } catch (error) {
    if (showLatestMessage && context.mounted) {
      _showUpdateMessage(context, _updateErrorMessage(error));
    }
    return false;
  }
}

UpdatePlatform? get _currentUpdatePlatform {
  if (Platform.isIOS) return UpdatePlatform.ios;
  if (Platform.isAndroid) return UpdatePlatform.android;
  return null;
}

Future<void> _showUpdatePrompt({
  required BuildContext context,
  required WidgetRef ref,
  required UpdateCheckResult result,
  required UpdateSettingsRepository repository,
  required UpdatePlatform platform,
}) async {
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
}

void _showUpdateMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

String _updateErrorMessage(Object error) {
  if (error is FormatException) return error.message.toString();
  if (error is UpdateException) return error.message;
  return '检查更新失败，请稍后重试';
}

class StartupUpdateGate extends ConsumerStatefulWidget {
  const StartupUpdateGate({
    super.key,
    required this.enabled,
    required this.child,
  });

  final bool enabled;
  final Widget child;

  @override
  StartupUpdateGateState createState() => StartupUpdateGateState();
}

class StartupUpdateGateState extends ConsumerState<StartupUpdateGate> {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _scheduleStart();
  }

  @override
  void didUpdateWidget(covariant StartupUpdateGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.enabled && widget.enabled) _scheduleStart();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  void _scheduleStart() {
    if (_started || !widget.enabled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _started || !widget.enabled) return;
      _started = true;
      unawaited(_checkForUpdate());
    });
  }

  Future<void> _checkForUpdate() async {
    if (ref.read(updateRepositoryUrlProvider) == null) return;

    const retryDelays = [
      Duration.zero,
      Duration(seconds: 3),
      Duration(seconds: 6),
    ];
    for (final delay in retryDelays) {
      if (!mounted) return;
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      final completed = await checkConfiguredAppUpdate(
        context: context,
        ref: ref,
        respectIgnored: true,
      );
      if (completed || !mounted) return;
    }
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
