import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';
import '../../core/platform/app_version.dart';
import '../../core/update/update_coordinator.dart';
import '../../core/update/update_models.dart';
import '../../core/update/update_repository.dart';
import '../../core/update/update_service.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/glow_background.dart';
import '../player/common/playback_engine.dart';
import '../player/video/video_player_page.dart';
import '../player/common/player_settings.dart';
import 'app_log_page.dart';
import 'settings_common.dart';

class AppUpdateSettingsPage extends ConsumerStatefulWidget {
  const AppUpdateSettingsPage({super.key, this.checkOnOpen = false});

  final bool checkOnOpen;

  @override
  ConsumerState<AppUpdateSettingsPage> createState() =>
      _AppUpdateSettingsPageState();
}

class _AppUpdateSettingsPageState extends ConsumerState<AppUpdateSettingsPage> {
  late final TextEditingController _repositoryController;
  late final FocusNode _repositoryFocusNode;
  late final TextEditingController _m3u8Controller;
  UpdateCheckResult? _result;
  String? _error;
  bool _checking = false;
  bool _downloading = false;
  bool _editingRepository = false;
  double? _downloadProgress;
  PlaybackEngineSelection _manualEngine = PlaybackEngineSelection.libmpv;

  @override
  void initState() {
    super.initState();
    final savedRepository = ref.read(updateRepositoryUrlProvider);
    _repositoryController = TextEditingController(text: savedRepository ?? '');
    _repositoryFocusNode = FocusNode();
    _m3u8Controller = TextEditingController();
    _editingRepository = savedRepository == null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !widget.checkOnOpen ||
          _repositoryController.text.trim().isEmpty) {
        return;
      }
      unawaited(_checkForUpdates(silent: true));
    });
  }

  @override
  void dispose() {
    _repositoryController.dispose();
    _repositoryFocusNode.dispose();
    _m3u8Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final savedRepository = ref.watch(updateRepositoryUrlProvider);
    final includeDevelopment = ref.watch(includeDevelopmentUpdatesProvider);
    final playerSettings = ref.watch(playerSettingsProvider);
    AppL10n? l;
    try {
      l = AppL10n.of(context);
    } catch (_) {}
    final currentRepository = _repositoryController.text.trim();
    final hasSavedRepository =
        savedRepository != null && savedRepository.trim().isNotEmpty;
    final repositoryLocked = hasSavedRepository && !_editingRepository;
    return Scaffold(
      backgroundColor: colors.bg,
      body: GlowBackground(
        child: SafeArea(
          child: SettingsFixedHeaderLayout(
            header: const SettingsSubPageHeader(
              eyebrow: '应用设置',
              title: '应用更新',
              subtitle: '填写 GitHub 仓库地址，自动检查对应平台的安装包',
            ),
            body: ListView(
              primary: true,
              children: [
                SettingsGroup(
                  title: '更新源',
                  items: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _repositoryController,
                              focusNode: _repositoryFocusNode,
                              keyboardType: TextInputType.url,
                              autocorrect: false,
                              enableSuggestions: false,
                              readOnly: repositoryLocked,
                              textInputAction: TextInputAction.done,
                              textAlignVertical: TextAlignVertical.center,
                              decoration: settingsInputDecoration(
                                context,
                                labelText: 'GitHub 仓库地址',
                                hintText: 'https://github.com/owner/repository',
                                prefixIcon: const Icon(Icons.link),
                              ),
                              onChanged: (_) => setState(() {}),
                              onSubmitted: (_) => unawaited(_saveRepository()),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: IconButton.filled(
                              onPressed: _checking || _downloading
                                  ? null
                                  : _saveOrEditRepository,
                              tooltip: repositoryLocked ? '编辑更新源' : '保存更新源',
                              icon: Icon(
                                repositoryLocked
                                    ? Icons.edit_outlined
                                    : Icons.save_outlined,
                                size: 20,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: '清空更新源',
                            onPressed:
                                _checking ||
                                    _downloading ||
                                    (savedRepository == null &&
                                        currentRepository.isEmpty)
                                ? null
                                : () => unawaited(_clearRepository()),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      child: Text(
                        '保存后会在启动时自动检查更新；清空后将停止自动检查。',
                        style: AppText.meta(context),
                      ),
                    ),
                  ],
                ),
                SettingsGroup(
                  title: '当前版本',
                  items: [
                    FutureBuilder<PackageInfo>(
                      future: ref.read(appPackageInfoProvider.future),
                      builder: (context, snapshot) {
                        final version = snapshot.hasData
                            ? formatAppVersion(
                                snapshot.data!.version,
                                snapshot.data!.buildNumber,
                              )
                            : snapshot.hasError
                            ? '读取失败'
                            : '读取中…';
                        return SettingsTile(
                          title: '已安装版本',
                          subtitle: version,
                          leadingIcon: Icons.phone_android_outlined,
                        );
                      },
                    ),
                    SettingsTile(
                      title: '检测开发版',
                      subtitle: '开启后同时检测标准版与开发版，并选择版本更高的安装包',
                      leadingIcon: Icons.developer_mode_outlined,
                      trailing: SettingsSwitch(
                        value: includeDevelopment,
                        onChanged: _checking || _downloading
                            ? null
                            : (value) =>
                                  unawaited(_setIncludeDevelopment(value)),
                      ),
                    ),
                  ],
                ),
                SettingsGroup(
                  title: '调试',
                  items: [
                    SettingsTile(
                      title: '播放器 Debug 模式',
                      subtitle: '在播放画面显示内核、编码、码率、帧率等信息',
                      leadingIcon: Icons.bug_report_outlined,
                      trailing: SettingsSwitch(
                        value: playerSettings.debugMode,
                        onChanged: (value) => unawaited(
                          ref
                              .read(playerSettingsProvider.notifier)
                              .update(
                                ref
                                    .read(playerSettingsProvider)
                                    .copyWith(debugMode: value),
                              ),
                        ),
                      ),
                    ),
                    SettingsTile(
                      title: l?.settingsPerformanceMonitor ?? '性能监视器',
                      subtitle:
                          l?.settingsPerformanceMonitorSub ??
                          '显示 FPS、应用 CPU 和 RAM 使用量',
                      leadingIcon: Icons.speed_outlined,
                      trailing: SettingsSwitch(
                        value: playerSettings.performanceMonitorEnabled,
                        onChanged: playerSettings.debugMode
                            ? (value) => unawaited(
                                ref
                                    .read(playerSettingsProvider.notifier)
                                    .update(
                                      ref
                                          .read(playerSettingsProvider)
                                          .copyWith(
                                            performanceMonitorEnabled: value,
                                          ),
                                    ),
                              )
                            : null,
                      ),
                    ),
                    SettingsTile(
                      title: '查看播放日志',
                      subtitle: 'SMB / WebDAV 视频持续加载时，复制日志给开发者',
                      leadingIcon: Icons.receipt_long_outlined,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AppLogPage()),
                      ),
                    ),
                  ],
                ),
                _buildManualPlaybackGroup(context),
                if (_checking)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      borderRadius: BorderRadius.circular(10),
                      color: colors.accent,
                      backgroundColor: colors.surfaceAlt,
                    ),
                  ),
                if (_error != null) _buildError(context, _error!),
                if (_result != null) _buildResult(context, _result!),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildManualPlaybackGroup(BuildContext context) {
    final supportsKsPlayer = Platform.isIOS;
    return SettingsGroup(
      title: '开发接口',
      items: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
          child: TextField(
            key: const ValueKey('manual-m3u8-url'),
            controller: _m3u8Controller,
            keyboardType: TextInputType.url,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            decoration: settingsInputDecoration(
              context,
              labelText: 'm3u8 地址',
              hintText: 'https://example.com/video.m3u8',
              prefixIcon: const Icon(Icons.link_outlined),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => unawaited(_openManualM3u8()),
          ),
        ),
        SettingsTile(
          key: const ValueKey('manual-player-engine'),
          title: '播放器内核',
          subtitle: supportsKsPlayer
              ? _manualEngine.label
              : '${_manualEngine.label} · KSPlayer 仅支持 iOS',
          leadingIcon: Icons.video_settings_outlined,
          onTap: () => unawaited(_pickManualEngine()),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey('manual-m3u8-play'),
              onPressed: _m3u8Controller.text.trim().isEmpty
                  ? null
                  : () => unawaited(_openManualM3u8()),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('播放 m3u8'),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Text(
            '用于开发排查 HLS 播放问题，不会保存地址。KSPlayer 选项仅在 iOS 可用。',
            style: AppText.meta(context),
          ),
        ),
      ],
    );
  }

  Future<void> _pickManualEngine() async {
    final selected = await showDialog<PlaybackEngineSelection>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('选择播放器内核'),
        contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in PlaybackEngineSelection.values)
              ListTile(
                key: ValueKey('manual-engine-${option.name}'),
                title: Text(option.label),
                subtitle:
                    option.engineKind == PlaybackEngineKind.ksPlayer &&
                        !Platform.isIOS
                    ? const Text('仅 iOS 可用')
                    : null,
                trailing: option == _manualEngine
                    ? const Icon(Icons.check)
                    : null,
                enabled:
                    option.engineKind != PlaybackEngineKind.ksPlayer ||
                    Platform.isIOS,
                onTap:
                    option.engineKind != PlaybackEngineKind.ksPlayer ||
                        Platform.isIOS
                    ? () => Navigator.of(dialogContext).pop(option)
                    : null,
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
        ],
      ),
    );
    if (selected == null || selected == _manualEngine || !mounted) return;
    setState(() => _manualEngine = selected);
    AppHaptics.selection();
  }

  Future<void> _openManualM3u8() async {
    final value = _m3u8Controller.text.trim();
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      setState(() => _error = '请输入有效的 http/https m3u8 地址');
      return;
    }
    if (_manualEngine.engineKind == PlaybackEngineKind.ksPlayer &&
        !Platform.isIOS) {
      setState(() => _error = 'KSPlayer 仅支持 iOS，请选择 libmpv');
      return;
    }
    setState(() => _error = null);
    AppHaptics.selection();
    await VideoPlayerPage.openDirect(
      context,
      title: '开发接口 · m3u8',
      directUrl: value,
      directFormatHint: 'm3u8',
      engineKind: _manualEngine.engineKind,
      directPreferFfmpegForHls: _manualEngine.preferFfmpegForHls,
    );
  }

  Widget _buildError(BuildContext context, String message) {
    final colors = appColors(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.danger.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.danger.withValues(alpha: 0.28)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: colors.danger),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: colors.danger,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult(BuildContext context, UpdateCheckResult result) {
    final colors = appColors(context);
    final candidate = result.candidate;
    final releaseTitle = candidate.release.name.isEmpty
        ? candidate.release.tagName
        : candidate.release.name;
    final hasAsset = candidate.asset.downloadUrl.isNotEmpty;

    return SettingsGroup(
      title: '检测结果',
      items: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                result.hasUpdate
                    ? Icons.system_update_alt_outlined
                    : Icons.check_circle_outline,
                color: result.hasUpdate ? colors.accent : Colors.green,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.hasUpdate
                          ? '发现新版本 ${candidate.version.display}'
                          : '当前已是最新版本',
                      style: AppText.cardTitle(context),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      releaseTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(context).copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${result.repository.owner}/${result.repository.name} · ${candidate.asset.name}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.meta(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (candidate.release.updateNotes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SelectableText(
              '本次构建包含以下更新：\n\n${candidate.release.updateNotes}',
              style: AppText.body(context),
            ),
          ),
        if (result.hasUpdate && hasAsset)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _buildDownloadButton(context, result),
          ),
      ],
    );
  }

  Widget _buildDownloadButton(BuildContext context, UpdateCheckResult result) {
    final colors = appColors(context);
    final isIos = Platform.isIOS;
    final progress = _downloadProgress;
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _downloading ? null : () => unawaited(_download(result)),
        icon: _downloading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: progress,
                  color: colors.bg,
                ),
              )
            : Icon(
                isIos
                    ? Icons.system_update_alt_outlined
                    : Icons.install_mobile_outlined,
              ),
        label: Text(
          _downloading
              ? isIos
                    ? '正在打开安装器…'
                    : progress == null
                    ? '下载中…'
                    : '下载中 ${(progress * 100).round()}%'
              : isIos
              ? '安装更新'
              : '下载并安装',
        ),
      ),
    );
  }

  Future<void> _saveOrEditRepository() async {
    final saved = ref.read(updateRepositoryUrlProvider);
    final hasSavedRepository = saved != null && saved.trim().isNotEmpty;
    if (hasSavedRepository && !_editingRepository) {
      setState(() => _editingRepository = true);
      AppHaptics.selection();
      _repositoryFocusNode.requestFocus();
      _repositoryController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _repositoryController.text.length,
      );
      return;
    }
    await _saveRepository();
  }

  Future<void> _saveRepository() async {
    if (_checking || _downloading) return;
    try {
      final repository = GitHubRepository.parse(_repositoryController.text);
      await ref
          .read(updateRepositoryUrlProvider.notifier)
          .save(repository.canonicalUrl);
      if (!mounted) return;
      _repositoryController.value = TextEditingValue(
        text: repository.canonicalUrl,
        selection: TextSelection.collapsed(
          offset: repository.canonicalUrl.length,
        ),
      );
      setState(() {
        _editingRepository = false;
        _error = null;
      });
      AppHaptics.selection();
      _showMessage('更新源已保存');
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = '保存更新源失败，请稍后重试');
    }
  }

  Future<void> _clearRepository() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清空更新源？'),
        content: const Text('清空后，应用启动时将不再自动检查更新。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await ref.read(updateRepositoryUrlProvider.notifier).save(null);
    if (!mounted) return;
    _repositoryController.clear();
    setState(() {
      _editingRepository = true;
      _result = null;
      _error = null;
    });
    AppHaptics.medium();
    _showMessage('更新源已清空');
  }

  Future<void> _checkForUpdates({bool silent = false}) async {
    if (_checking || _downloading) return;
    final raw = _repositoryController.text.trim();
    setState(() {
      _checking = true;
      _error = null;
      if (!silent) _result = null;
    });
    try {
      final repository = GitHubRepository.parse(raw);
      final platform = _currentPlatform;
      if (platform == null) {
        throw const UpdateException('当前平台不支持在线更新');
      }
      final packageInfo = await ref.read(appPackageInfoProvider.future);
      final currentVersion = AppReleaseVersion.fromPackageInfo(
        packageInfo.version,
        packageInfo.buildNumber,
      );
      final result = await ref
          .read(appUpdateCoordinatorProvider)
          .check(
            repositoryUrl: repository.canonicalUrl,
            platform: platform,
            currentVersion: currentVersion,
            includeDevelopment: ref.read(includeDevelopmentUpdatesProvider),
          );
      if (!mounted) return;
      setState(() => _result = result);
      if (!silent) {
        AppHaptics.selection();
        _showMessage(result.hasUpdate ? '发现新版本' : '当前已是最新版本');
      }
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on UpdateException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = '检查更新失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _download(UpdateCheckResult result) async {
    if (_downloading) return;
    if (!Platform.isIOS && !Platform.isAndroid) {
      _showMessage('当前平台不支持安装此更新');
      return;
    }

    setState(() {
      _downloading = true;
      _downloadProgress = null;
      _error = null;
    });
    try {
      final action = await ref
          .read(appUpdateCoordinatorProvider)
          .install(
            result,
            onReceiveProgress: (received, total) {
              if (!mounted || total <= 0) return;
              setState(() => _downloadProgress = received / total);
            },
          );
      if (mounted) {
        AppHaptics.medium();
        _showMessage(
          action == UpdateInstallAction.iosInstallerOpened
              ? '已打开 iOS 安装器'
              : '已打开系统安装器',
        );
      }
    } on UpdateException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = '下载更新失败，请稍后重试');
    } finally {
      if (mounted) {
        setState(() {
          _downloading = false;
          _downloadProgress = null;
        });
      }
    }
  }

  Future<void> _setIncludeDevelopment(bool value) async {
    try {
      await ref
          .read(includeDevelopmentUpdatesProvider.notifier)
          .setEnabled(value);
      if (!mounted) return;
      setState(() {
        _result = null;
        _error = null;
      });
    } catch (_) {
      if (mounted) _showMessage('保存开发版检测设置失败，请稍后重试');
    }
  }

  UpdatePlatform? get _currentPlatform {
    if (Platform.isIOS) return UpdatePlatform.ios;
    if (Platform.isAndroid) return UpdatePlatform.android;
    return null;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
