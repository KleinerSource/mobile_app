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
import '../../l10n/generated/app_localizations.dart';

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
  final includeDevelopment = ref.read(includeDevelopmentUpdatesProvider);
  final platform = _currentUpdatePlatform;
  if (repositoryUrl == null || platform == null) return false;

  try {
    final packageInfo = await ref.read(appPackageInfoProvider.future);
    final currentVersion = AppReleaseVersion.fromPackageInfo(
      packageInfo.version,
      packageInfo.buildNumber,
    );
    final result = await ref
        .read(appUpdateCoordinatorProvider)
        .check(
          repositoryUrl: repositoryUrl,
          platform: platform,
          currentVersion: currentVersion,
          includeDevelopment: includeDevelopment,
        );
    if (!context.mounted) return true;

    if (!result.hasUpdate) {
      if (showLatestMessage) {
        _showUpdateMessage(context, AppL10n.of(context).settingsUpToDate);
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
      _showUpdateMessage(
        context,
        _updateErrorMessage(error, AppL10n.of(context)),
      );
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
        await ref
            .read(appUpdateCoordinatorProvider)
            .install(result, onReceiveProgress: onProgress);
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
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

String _updateErrorMessage(Object error, AppL10n l) {
  if (error is FormatException) return error.message.toString();
  if (error is UpdateException) return error.message;
  return l.settingsCheckUpdateFailed;
}

typedef StartupUpdateCheck =
    Future<bool> Function(BuildContext context, WidgetRef ref);

class StartupUpdateGate extends ConsumerStatefulWidget {
  const StartupUpdateGate({
    super.key,
    required this.enabled,
    required this.child,
    this.checkForUpdate,
    this.startDelay = const Duration(milliseconds: 700),
    this.retryDelays = const [
      Duration.zero,
      Duration(seconds: 3),
      Duration(seconds: 6),
    ],
    this.retryAfterFailure = const Duration(seconds: 15),
  });

  final bool enabled;
  final Widget child;
  final StartupUpdateCheck? checkForUpdate;
  final Duration startDelay;
  final List<Duration> retryDelays;
  final Duration retryAfterFailure;

  @override
  StartupUpdateGateState createState() => StartupUpdateGateState();
}

class StartupUpdateGateState extends ConsumerState<StartupUpdateGate> {
  late final ProviderSubscription<String?> _repositorySubscription;
  Timer? _startTimer;
  String? _scheduledRepository;
  bool _startupCheckConsumed = false;
  bool _checking = false;
  String? _failureRepository;
  int _failureRetryCount = 0;

  @override
  void initState() {
    super.initState();
    _repositorySubscription = ref.listenManual<String?>(
      updateRepositoryUrlProvider,
      (_, repositoryUrl) => _scheduleStart(repositoryUrl),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _repositorySubscription.close();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant StartupUpdateGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      _startTimer?.cancel();
      _scheduledRepository = null;
    } else if (!oldWidget.enabled) {
      _scheduleStart(ref.read(updateRepositoryUrlProvider));
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  void _scheduleStart(String? repositoryUrl) {
    final repository = repositoryUrl?.trim();
    if (!widget.enabled) {
      _startTimer?.cancel();
      _startTimer = null;
      _scheduledRepository = null;
      return;
    }
    if (_startupCheckConsumed) return;
    _startupCheckConsumed = true;
    if (repository == null || repository.isEmpty) {
      _startTimer?.cancel();
      _startTimer = null;
      _scheduledRepository = null;
      return;
    }
    if (_checking || _scheduledRepository == repository) return;
    if (_failureRepository != repository) {
      _failureRepository = repository;
      _failureRetryCount = 0;
    }
    _scheduledRepository = repository;
    _startTimer?.cancel();
    _startTimer = Timer(widget.startDelay, () {
      _startTimer = null;
      if (!mounted ||
          !widget.enabled ||
          ref.read(updateRepositoryUrlProvider)?.trim() != repository) {
        if (_scheduledRepository == repository) {
          _scheduledRepository = null;
        }
        return;
      }
      unawaited(_checkForUpdate(repository));
    });
  }

  Future<void> _checkForUpdate(String repository) async {
    if (_checking) return;
    _checking = true;
    var completed = false;
    try {
      for (final delay in widget.retryDelays) {
        if (!mounted ||
            !widget.enabled ||
            ref.read(updateRepositoryUrlProvider)?.trim() != repository) {
          return;
        }
        if (delay > Duration.zero) await Future<void>.delayed(delay);
        if (!mounted ||
            !widget.enabled ||
            ref.read(updateRepositoryUrlProvider)?.trim() != repository) {
          return;
        }
        final check = widget.checkForUpdate;
        completed = check == null
            ? await checkConfiguredAppUpdate(
                context: context,
                ref: ref,
                respectIgnored: true,
              )
            : await check(context, ref);
        if (completed || !mounted) break;
      }
      if (completed) {
        _failureRetryCount = 0;
      }
    } finally {
      _checking = false;
      if (_scheduledRepository == repository) {
        _scheduledRepository = null;
      }
    }

    if (!completed &&
        mounted &&
        widget.enabled &&
        _failureRetryCount < 1 &&
        ref.read(updateRepositoryUrlProvider)?.trim() == repository) {
      _failureRetryCount++;
      _startTimer = Timer(widget.retryAfterFailure, () {
        _startTimer = null;
        if (!mounted) return;
        if (ref.read(updateRepositoryUrlProvider)?.trim() != repository) {
          return;
        }
        unawaited(_checkForUpdate(repository));
      });
    }
  }
}

typedef UpdatePromptUpdate =
    Future<void> Function(void Function(int received, int total) onProgress);

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
    final l = AppL10n.of(context);
    final release = widget.result.candidate.release;
    final releaseTitle = release.name.isEmpty ? release.tagName : release.name;
    final updateNotes = release.updateNotes;
    final maxContentHeight = MediaQuery.sizeOf(context).height * 0.55;
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.system_update_alt_outlined, color: colors.accent),
          const SizedBox(width: 10),
          Expanded(child: Text(l.settingsNewVersionFound)),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxContentHeight),
        child: Scrollbar(
          child: SingleChildScrollView(
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
                const SizedBox(height: 14),
                Text(
                  l.settingsUpdateNotesTitle,
                  style: AppText.body(
                    context,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  updateNotes.isEmpty ? l.settingsNoUpdateNotes : updateNotes,
                  style: AppText.meta(context),
                ),
                if (_progress != null) ...[
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: _progress,
                    minHeight: 4,
                    valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
                    backgroundColor: colors.surfaceAlt,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l.settingsDownloadingUpdatePercent(
                      (100 * _progress!).round(),
                    ),
                    style: AppText.meta(context),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: colors.danger)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : _ignore,
          child: Text(l.commonIgnore),
        ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(l.commonLater),
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
          label: Text(l.settingsUpdateNow),
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
        final progress = normalizeDownloadProgress(received, total);
        if (!mounted || progress == null) return;
        setState(() {
          if (_progress == null || progress >= _progress!) {
            _progress = progress;
          }
        });
      });
      if (!mounted) return;
      AppHaptics.medium();
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error is UpdateException
            ? error.message
            : AppL10n.of(context).settingsUpdateFailed;
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
        _error = AppL10n.of(context).settingsSaveIgnoreFailed;
      });
    }
  }
}
