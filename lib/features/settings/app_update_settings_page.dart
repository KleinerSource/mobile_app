import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';
import '../../core/platform/app_version.dart';
import '../../core/update/update_installer.dart';
import '../../core/update/update_models.dart';
import '../../core/update/update_repository.dart';
import '../../core/update/update_service.dart';
import '../../shared/glow_background.dart';
import 'settings_common.dart';

class AppUpdateSettingsPage extends ConsumerStatefulWidget {
  const AppUpdateSettingsPage({super.key});

  @override
  ConsumerState<AppUpdateSettingsPage> createState() =>
      _AppUpdateSettingsPageState();
}

class _AppUpdateSettingsPageState
    extends ConsumerState<AppUpdateSettingsPage> {
  late final TextEditingController _repositoryController;
  UpdateCheckResult? _result;
  String? _error;
  bool _checking = false;
  bool _downloading = false;
  double? _downloadProgress;

  @override
  void initState() {
    super.initState();
    _repositoryController = TextEditingController(
      text: ref.read(updateRepositoryUrlProvider) ?? '',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _repositoryController.text.trim().isEmpty) return;
      unawaited(_checkForUpdates(silent: true));
    });
  }

  @override
  void dispose() {
    _repositoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return Scaffold(
      backgroundColor: colors.bg,
      body: GlowBackground(
        child: SafeArea(
          child: ListView(
            children: [
              const SettingsSubPageHeader(
                eyebrow: '应用设置',
                title: '应用更新',
                subtitle: '填写 GitHub 仓库地址，自动检查对应平台的安装包',
              ),
              SettingsGroup(
                title: '更新源',
                items: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                    child: TextField(
                      controller: _repositoryController,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.done,
                      decoration: settingsInputDecoration(
                        context,
                        labelText: 'GitHub 仓库地址',
                        hintText: 'https://github.com/owner/repository',
                        prefixIcon: const Icon(Icons.code_outlined),
                      ),
                      onSubmitted: (_) => _checkForUpdates(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    child: Text(
                      '不会内置或自动替换仓库地址，只会读取你填写的公开 Release。',
                      style: AppText.meta(context),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: SettingsSaveButton(
                      onPressed: _checking || _downloading
                          ? null
                          : _checkForUpdates,
                      saving: _checking,
                      label: '保存并检查更新',
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
                ],
              ),
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
              if (_error != null)
                _buildError(context, _error!),
              if (_result != null) _buildResult(context, _result!),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
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
        if (candidate.release.body.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SelectableText(
              candidate.release.body,
              maxLines: 8,
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

  Widget _buildDownloadButton(
    BuildContext context,
    UpdateCheckResult result,
  ) {
    final colors = appColors(context);
    final isIos = Platform.isIOS;
    final progress = _downloadProgress;
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _downloading
            ? null
            : () => unawaited(_download(result)),
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
    );
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
      await ref
          .read(updateRepositoryUrlProvider.notifier)
          .save(repository.canonicalUrl);
      final platform = _currentPlatform;
      if (platform == null) {
        throw const UpdateException('当前平台不支持在线更新');
      }
      final packageInfo = await ref.read(appPackageInfoProvider.future);
      final currentVersion = AppReleaseVersion.fromPackageInfo(
        packageInfo.version,
        packageInfo.buildNumber,
      );
      final result = await ref.read(gitHubUpdateServiceProvider).check(
            repositoryUrl: repository.canonicalUrl,
            platform: platform,
            currentVersion: currentVersion,
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

    final asset = result.candidate.asset;
    setState(() {
      _downloading = true;
      _downloadProgress = null;
      _error = null;
    });
    try {
      if (Platform.isIOS) {
        await _openIosInstaller(asset.downloadUrl);
      } else {
        final file = await ref.read(gitHubUpdateServiceProvider).download(
              asset,
              onReceiveProgress: (received, total) {
                if (!mounted || total <= 0) return;
                setState(() => _downloadProgress = received / total);
              },
            );
        final installed = await AndroidUpdateInstaller.install(file);
        if (!installed && mounted) {
          _showMessage('无法打开系统安装器，请重新下载');
        }
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

  Future<void> _openIosInstaller(String downloadUrl) async {
    final installerUrl = IosUpdateInstaller.installUri(downloadUrl);
    final launched = await launchUrl(
      installerUrl,
      mode: LaunchMode.externalApplication,
    );
    if (!mounted) return;
    if (launched) {
      AppHaptics.medium();
      _showMessage('已打开 iOS 安装器');
    } else {
      _showMessage('无法打开 iOS 安装器，请确认已安装 TrollStore');
    }
  }

  UpdatePlatform? get _currentPlatform {
    if (Platform.isIOS) return UpdatePlatform.ios;
    if (Platform.isAndroid) return UpdatePlatform.android;
    return null;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
