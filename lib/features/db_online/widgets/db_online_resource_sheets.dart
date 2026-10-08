import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'package:omm/core/sources/media/dbo/db_online_movie.dart';
import 'package:omm/core/sources/media/dbo/db_online_resource_merge.dart';
import 'package:omm/core/sources/media/dbo/db_online_subtitle.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/features/db_online/navigation/db_online_movie_navigation.dart'
    show dbOnlineDetailKey;
import 'package:omm/features/db_online/providers/db_online_home_providers.dart';
import 'package:omm/shared/movie_detail_formatters.dart' show formatFileSize;
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/glass.dart';
import 'package:omm/shared/localized_error_message.dart';
import 'package:omm/shared/resource_panel_components.dart';
import 'package:omm/shared/sheet_controls.dart';

import 'db_online_resource_download.dart';

enum _ResourceTab { magnet, ed2k }

class DbOnlineResourcesSheet extends ConsumerStatefulWidget {
  const DbOnlineResourcesSheet({super.key, required this.movie});

  final DbOnlineMovieDetail movie;

  static Future<void> show(BuildContext context, DbOnlineMovieDetail movie) {
    return showGlassSheet<void>(
      context: context,
      isScrollControlled: true,
      minHeight: sheetMinHeight(context),
      builder: (_) => DbOnlineResourcesSheet(movie: movie),
    );
  }

  @override
  ConsumerState<DbOnlineResourcesSheet> createState() =>
      _DbOnlineResourcesSheetState();
}

class _DbOnlineResourcesSheetState
    extends ConsumerState<DbOnlineResourcesSheet> {
  _ResourceTab _tab = _ResourceTab.magnet;
  late List<DbOnlineMagnet> _javdbMagnets;
  late List<DbOnlineEd2k> _javdbEd2ks;
  final List<DbOnlineMagnet> _customMagnets = [];
  final List<DbOnlineEd2k> _customEd2ks = [];
  final List<DbOnlineMagnet> _nyaaMagnets = [];
  final Set<String> _loadingSources = {'custom', 'nyaa'};
  final Map<String, String> _sourceErrors = {};
  List<({String name, String displayName, bool? ed2kEnabled})> _downloaders =
      const [];
  bool _downloadersLoading = true;
  String? _pushingKey;
  Map<String, String> _downloadedMagnets = const {};
  Map<String, String> _downloadedEd2ks = const {};

  List<DbOnlineMagnet> get _magnets => mergeDbOnlineMagnets({
    'javdb': _javdbMagnets,
    'custom': _customMagnets,
    'nyaa': _nyaaMagnets,
  });

  List<DbOnlineEd2k> get _ed2ks =>
      mergeDbOnlineEd2ks({'javdb': _javdbEd2ks, 'custom': _customEd2ks});

  bool get _loadingResources => _loadingSources.isNotEmpty;

  List<({String name, String displayName, bool? ed2kEnabled})>
  get _ed2kDownloaders => _downloaders
      .where((downloader) => downloader.ed2kEnabled == true)
      .toList(growable: false);

  List<({String name, String displayName, bool? ed2kEnabled})>
  get _activeDownloaders =>
      _tab == _ResourceTab.magnet ? _downloaders : _ed2kDownloaders;

  @override
  void initState() {
    super.initState();
    _javdbMagnets = widget.movie.magnets;
    _javdbEd2ks = widget.movie.ed2ks;
    _selectDefaultTab();
    unawaited(_loadExternalSource('custom'));
    unawaited(_loadExternalSource('nyaa'));
    unawaited(_loadDownloadHistory());
    unawaited(_loadDownloaders());
  }

  Future<void> _loadResources() async {
    if (_loadingResources) return;
    setState(() {
      _loadingSources.addAll({'detail', 'custom', 'nyaa'});
      _sourceErrors.clear();
      _downloadersLoading = true;
    });
    unawaited(_loadDetailSource());
    unawaited(_loadExternalSource('custom'));
    unawaited(_loadExternalSource('nyaa'));
    unawaited(_loadDownloadHistory());
    unawaited(_loadDownloaders());
  }

  Future<void> _loadDetailSource() async {
    try {
      final movie = await ref
          .read(dboMediaRepositoryProvider)
          .getMovieDetail(
            dbOnlineDetailKey(widget.movie.videoId, widget.movie.code),
          );
      if (!mounted) return;
      setState(() {
        _javdbMagnets = movie.magnets;
        _javdbEd2ks = movie.ed2ks;
        _selectDefaultTab();
        _sourceErrors.remove('detail');
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        final l = AppL10n.of(context);
        _sourceErrors['detail'] =
            '${l.resourceSourceDetail}: ${localizedErrorMessage(l, error)}';
      });
    } finally {
      if (mounted) setState(() => _loadingSources.remove('detail'));
    }
  }

  Future<void> _loadDownloadHistory() async {
    try {
      final history = await ref
          .read(dboMediaRepositoryProvider)
          .getDownloadHistory(widget.movie.code);
      if (!mounted) return;
      setState(() {
        _downloadedMagnets = history.magnets;
        _downloadedEd2ks = history.ed2ks;
      });
    } catch (_) {
      // 下载历史不可用时继续展示在线资源。
    }
  }

  Future<void> _loadDownloaders() async {
    try {
      final downloaders = await ref
          .read(dboMediaRepositoryProvider)
          .getDownloaders();
      if (!mounted) return;
      setState(() => _downloaders = downloaders);
    } catch (_) {
      // 下载器配置失败不应阻塞资源列表。
    } finally {
      if (mounted) setState(() => _downloadersLoading = false);
    }
  }

  String? _downloadedAt(Map<String, String> history, String hash) {
    if (hash.isEmpty) return null;
    final value = history[hash];
    return value == null || value.isEmpty ? null : value;
  }

  Future<void> _onPush({
    required String url,
    required String protocol,
    required String name,
    required String? site,
    required String? date,
    required List<String> tags,
  }) async {
    if (_pushingKey != null) return;
    final pushed = await pushDbOnlineResource(
      context: context,
      repository: ref.read(dboMediaRepositoryProvider),
      downloaders: _downloaders,
      videoInfo: {
        'code': widget.movie.code.trim(),
        'title': widget.movie.title.trim(),
        'date': widget.movie.date?.trim() ?? '',
        'actors': widget.movie.actors
            .map(
              (actor) => {
                if (actor.externalId != null) 'external_id': actor.externalId,
                'name': actor.name,
                'gender': actor.gender ?? '',
              },
            )
            .toList(growable: false),
      },
      url: url,
      protocol: protocol,
      name: name,
      site: site,
      date: date,
      tags: tags,
      isCurrent: () => mounted,
      onPushing: (pushing) =>
          setState(() => _pushingKey = pushing ? url : null),
    );
    if (pushed && mounted) await _loadDownloadHistory();
  }

  Future<void> _loadExternalSource(String source) async {
    try {
      final repository = ref.read(dboMediaRepositoryProvider);
      final result = source == 'custom'
          ? await repository.getCustomResources(widget.movie.code)
          : await repository.getNyaaResources(widget.movie.code);
      if (!mounted) return;
      setState(() {
        if (source == 'custom') {
          _customMagnets
            ..clear()
            ..addAll(result.magnets);
          _customEd2ks
            ..clear()
            ..addAll(result.ed2ks);
        } else {
          _nyaaMagnets
            ..clear()
            ..addAll(result.magnets);
        }
        _sourceErrors.remove(source);
        _selectDefaultTab();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        final l = AppL10n.of(context);
        _sourceErrors[source] =
            '${source == 'custom' ? l.resourceSourceCustom : l.resourceSourceNyaa}: ${localizedErrorMessage(l, error)}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingSources.remove(source);
        });
      }
    }
  }

  Future<void> _copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppL10n.of(context).dbOnlineResourceCopied),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _selectDefaultTab() {
    if (_magnets.isEmpty && _ed2ks.isNotEmpty) {
      _tab = _ResourceTab.ed2k;
    } else if (_ed2ks.isEmpty) {
      _tab = _ResourceTab.magnet;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final l = AppL10n.of(context);
    final isMagnet = _tab == _ResourceTab.magnet;
    final magnetItems = _magnets;
    final ed2kItems = _ed2ks;
    final count = isMagnet ? magnetItems.length : ed2kItems.length;
    final showTabs = magnetItems.isNotEmpty && ed2kItems.isNotEmpty;
    return ResourcePanelShell(
      icon: Icons.cloud_download_outlined,
      title: l.resourceOnline,
      subtitle: widget.movie.code,
      trailing: IconButton(
        tooltip: l.actionRefresh,
        icon: const Icon(Icons.refresh_rounded, size: 18),
        onPressed: _loadingResources ? null : _loadResources,
      ),
      tabs: showTabs
          ? [
              ResourcePanelTab(
                label: l.resourceMagnetCount(magnetItems.length),
              ),
              ResourcePanelTab(label: l.resourceEd2kCount(ed2kItems.length)),
            ]
          : const [],
      selectedTabIndex: isMagnet ? 0 : 1,
      onTabSelected: (index) => setState(
        () => _tab = index == 0 ? _ResourceTab.magnet : _ResourceTab.ed2k,
      ),
      contentTopSpacing: 10,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_loadingResources)
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.accent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(l.resourceLoadingOnline, style: AppText.meta(context)),
                ],
              ),
            ),
          if (_sourceErrors.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _sourceErrors.values.join('\n'),
                  style: AppText.meta(context).copyWith(color: colors.danger),
                ),
              ),
            ),
          if (count == 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
              child: Text(
                _loadingResources
                    ? l.resourceWaitingSources
                    : isMagnet
                    ? l.resourceNoMagnet
                    : l.resourceNoEd2k,
                textAlign: TextAlign.center,
                style: AppText.body(context),
              ),
            )
          else
            ResourcePanelList(
              itemCount: count,
              dividerColor: colors.divider,
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
              itemBuilder: (context, index) => isMagnet
                  ? _MagnetRow(
                      item: magnetItems[index],
                      pushing: _pushingKey == magnetItems[index].magnet,
                      pushDisabled:
                          _pushingKey != null ||
                          _downloadersLoading ||
                          _activeDownloaders.isEmpty,
                      downloadedAt: _downloadedAt(
                        _downloadedMagnets,
                        dbOnlineMagnetHash(magnetItems[index].magnet),
                      ),
                      onPush: () => _onPush(
                        url: magnetItems[index].magnet,
                        protocol: 'magnet',
                        name: magnetItems[index].name,
                        site: magnetItems[index].site,
                        date: magnetItems[index].date,
                        tags: magnetItems[index].tags,
                      ),
                      onCopy: () => _copy(magnetItems[index].magnet),
                    )
                  : _Ed2kRow(
                      item: ed2kItems[index],
                      pushing: _pushingKey == ed2kItems[index].ed2k,
                      pushDisabled:
                          _pushingKey != null ||
                          _downloadersLoading ||
                          _activeDownloaders.isEmpty,
                      downloadedAt: _downloadedAt(
                        _downloadedEd2ks,
                        dbOnlineEd2kHash(ed2kItems[index].ed2k),
                      ),
                      onPush: () => _onPush(
                        url: ed2kItems[index].ed2k,
                        protocol: 'ed2k',
                        name: ed2kItems[index].name,
                        site: ed2kItems[index].site,
                        date: ed2kItems[index].date,
                        tags: ed2kItems[index].tags,
                      ),
                      onCopy: () => _copy(ed2kItems[index].ed2k),
                    ),
            ),
        ],
      ),
    );
  }
}

class _MagnetRow extends StatelessWidget {
  const _MagnetRow({
    required this.item,
    required this.onCopy,
    required this.onPush,
    required this.pushing,
    required this.pushDisabled,
    this.downloadedAt,
  });

  final DbOnlineMagnet item;
  final VoidCallback onCopy;
  final VoidCallback onPush;
  final bool pushing;
  final bool pushDisabled;
  final String? downloadedAt;

  @override
  Widget build(BuildContext context) => DbOnlineResourceRow(
    name: item.name,
    value: item.magnet,
    sizeMb: item.sizeMb,
    fileCount: item.fileCount,
    date: item.date,
    site: item.site,
    tags: item.tags,
    downloadedAt: downloadedAt,
    pushing: pushing,
    pushDisabled: pushDisabled,
    onPush: onPush,
    onCopy: onCopy,
  );
}

class _Ed2kRow extends StatelessWidget {
  const _Ed2kRow({
    required this.item,
    required this.onCopy,
    required this.onPush,
    required this.pushing,
    required this.pushDisabled,
    this.downloadedAt,
  });

  final DbOnlineEd2k item;
  final VoidCallback onCopy;
  final VoidCallback onPush;
  final bool pushing;
  final bool pushDisabled;
  final String? downloadedAt;

  @override
  Widget build(BuildContext context) => DbOnlineResourceRow(
    name: item.name,
    value: item.ed2k,
    sizeMb: item.sizeMb,
    date: item.date,
    site: item.site,
    tags: item.tags,
    downloadedAt: downloadedAt,
    pushing: pushing,
    pushDisabled: pushDisabled,
    onPush: onPush,
    onCopy: onCopy,
  );
}

class DbOnlineResourceRow extends StatelessWidget {
  const DbOnlineResourceRow({
    super.key,
    required this.name,
    required this.value,
    required this.onCopy,
    this.titleMaxLines = 2,
    this.sizeMb,
    this.fileCount,
    this.date,
    this.site,
    this.tags = const [],
    this.downloadedAt,
    required this.pushing,
    required this.pushDisabled,
    required this.onPush,
  });

  final String name;
  final String value;
  final VoidCallback onCopy;
  final int titleMaxLines;
  final double? sizeMb;
  final int? fileCount;
  final String? date;
  final String? site;
  final List<String> tags;
  final String? downloadedAt;
  final bool pushing;
  final bool pushDisabled;
  final VoidCallback onPush;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final l = AppL10n.of(context);
    final metadata = <Widget>[
      if (sizeMb != null && sizeMb! > 0)
        Text(
          formatFileSize((sizeMb! * 1024 * 1024).round()),
          style: AppText.meta(context),
        ),
      if (fileCount != null && fileCount! > 0)
        Text(
          l.dbOnlineResourceFileCount(fileCount!),
          style: AppText.meta(context),
        ),
      if (site?.trim().isNotEmpty == true)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: colors.chipBg,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            l.resourceFrom(site!.trim()),
            style: TextStyle(
              color: colors.muted,
              fontFamily: 'monospace',
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
    ];
    return ResourcePanelRow(
      title: name.trim().isEmpty ? value : name,
      titleMaxLines: titleMaxLines,
      metadata: metadata.isEmpty
          ? null
          : Wrap(spacing: 8, runSpacing: 4, children: metadata),
      tags: tags,
      downloadedTooltip: downloadedAt?.isNotEmpty == true
          ? formatResourceDownloadedTooltip(l, downloadedAt!)
          : null,
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (date?.trim().isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(right: 6, bottom: 2),
              child: Text(
                date!.trim(),
                style: TextStyle(
                  color: colors.muted,
                  fontFamily: 'monospace',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: l.resourceCopy,
                onPressed: value.trim().isEmpty ? null : onCopy,
                icon: Icon(Icons.copy_rounded, size: 18, color: colors.accent),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              IconButton(
                tooltip: pushing ? l.resourcePushing : l.resourcePushDownload,
                onPressed: pushDisabled || value.trim().isEmpty ? null : onPush,
                icon: pushing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.send_rounded, size: 18, color: colors.warning),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _SubtitleTab { local, thunder }

class DbOnlineSubtitleSheet extends ConsumerStatefulWidget {
  const DbOnlineSubtitleSheet({super.key, required this.code});

  final String code;

  static Future<void> show(BuildContext context, String code) {
    return showGlassSheet<void>(
      context: context,
      isScrollControlled: true,
      minHeight: sheetMinHeight(context),
      builder: (_) => DbOnlineSubtitleSheet(code: code),
    );
  }

  @override
  ConsumerState<DbOnlineSubtitleSheet> createState() =>
      _DbOnlineSubtitleSheetState();
}

class _DbOnlineSubtitleSheetState extends ConsumerState<DbOnlineSubtitleSheet> {
  _SubtitleTab _tab = _SubtitleTab.local;
  bool _localLoading = true;
  bool _thunderLoading = true;
  String? _localError;
  String? _thunderError;
  List<DbOnlineSubtitleFile> _localFiles = const [];
  List<DbOnlineSubtitleCandidate> _thunderItems = const [];
  final Set<String> _busyKeys = <String>{};

  @override
  void initState() {
    super.initState();
    _loadLocal();
    _loadThunder();
  }

  Future<void> _loadLocal() async {
    setState(() {
      _localLoading = true;
      _localError = null;
    });
    try {
      final result = await ref
          .read(dboMediaRepositoryProvider)
          .findSubtitles(widget.code);
      if (mounted) setState(() => _localFiles = result);
    } catch (error) {
      if (mounted) {
        setState(
          () => _localError = localizedErrorMessage(AppL10n.of(context), error),
        );
      }
    } finally {
      if (mounted) setState(() => _localLoading = false);
    }
  }

  Future<void> _loadThunder() async {
    setState(() {
      _thunderLoading = true;
      _thunderError = null;
    });
    try {
      final result = await ref
          .read(dboMediaRepositoryProvider)
          .searchExternalSubtitles(widget.code);
      if (mounted) {
        final sorted = [
          ...result,
        ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        setState(() => _thunderItems = sorted);
      }
    } catch (error) {
      if (mounted) {
        setState(
          () =>
              _thunderError = localizedErrorMessage(AppL10n.of(context), error),
        );
      }
    } finally {
      if (mounted) setState(() => _thunderLoading = false);
    }
  }

  Future<void> _previewLocal(DbOnlineSubtitleFile item) async {
    final key = 'local-preview:${item.id}';
    if (!_busyKeys.add(key)) return;
    setState(() {});
    try {
      final result = await ref
          .read(dboMediaRepositoryProvider)
          .previewLocalSubtitle(item.id);
      if (!mounted) return;
      await _openPreview(item.name, result.content);
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        AppL10n.of(context).subtitlePreviewFailed(
          localizedErrorMessage(AppL10n.of(context), error),
        ),
      );
    } finally {
      _busyKeys.remove(key);
      if (mounted) setState(() {});
    }
  }

  Future<void> _previewThunder(DbOnlineSubtitleCandidate item) async {
    final key = 'thunder-preview:${item.url}';
    if (!_busyKeys.add(key)) return;
    setState(() {});
    try {
      final result = await ref
          .read(dboMediaRepositoryProvider)
          .previewExternalSubtitle(item.url);
      if (!mounted) return;
      await _openPreview(item.name, result.content);
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        AppL10n.of(context).subtitlePreviewFailed(
          localizedErrorMessage(AppL10n.of(context), error),
        ),
      );
    } finally {
      _busyKeys.remove(key);
      if (mounted) setState(() {});
    }
  }

  Future<void> _downloadLocal(DbOnlineSubtitleFile item) async {
    await _shareSubtitle(
      key: 'local-download:${item.id}',
      name: item.name,
      load: () =>
          ref.read(dboMediaRepositoryProvider).downloadLocalSubtitle(item.id),
    );
  }

  Future<void> _downloadThunder(DbOnlineSubtitleCandidate item) async {
    final ext = item.extension.trim().replaceFirst(RegExp(r'^\.'), '');
    await _shareSubtitle(
      key: 'thunder-download:${item.url}',
      name: '${widget.code}.chs${ext.isEmpty ? '' : '.$ext'}',
      load: () => ref
          .read(dboMediaRepositoryProvider)
          .downloadExternalSubtitle(
            url: item.url,
            name: item.name,
            extension: ext,
          ),
    );
  }

  Future<void> _shareSubtitle({
    required String key,
    required String name,
    required Future<Uint8List> Function() load,
  }) async {
    if (!_busyKeys.add(key)) return;
    setState(() {});
    final l = AppL10n.of(context);
    try {
      final data = await load();
      if (!mounted) return;
      final renderObject = context.findRenderObject();
      final origin = renderObject is RenderBox
          ? renderObject.localToGlobal(Offset.zero) & renderObject.size
          : null;
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              data,
              name: _safeFileName(name),
              mimeType: 'text/plain',
            ),
          ],
          sharePositionOrigin: origin,
        ),
      );
      if (mounted && result.status == ShareResultStatus.unavailable) {
        _showMessage(l.playerErrorExportUnsupported);
      }
    } catch (error) {
      if (mounted) {
        _showMessage(l.subtitleDownloadFailed(localizedErrorMessage(l, error)));
      }
    } finally {
      _busyKeys.remove(key);
      if (mounted) setState(() {});
    }
  }

  Future<void> _openPreview(String title, String content) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _SubtitlePreviewPage(title: title, content: content),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final l = AppL10n.of(context);
    final isLocal = _tab == _SubtitleTab.local;
    final loading = isLocal ? _localLoading : _thunderLoading;
    final error = isLocal ? _localError : _thunderError;
    final count = isLocal ? _localFiles.length : _thunderItems.length;
    return ResourcePanelShell(
      icon: Icons.subtitles_outlined,
      title: l.subtitleSearchTitle,
      subtitle: widget.code,
      trailing: IconButton(
        tooltip: l.dbOnlineRetry,
        icon: Icon(Icons.refresh_rounded, color: colors.muted, size: 20),
        onPressed: loading ? null : (isLocal ? _loadLocal : _loadThunder),
      ),
      tabs: [
        ResourcePanelTab(label: l.dbOnlineLocalSubtitles(_localFiles.length)),
        ResourcePanelTab(
          label: l.dbOnlineThunderSubtitles(_thunderItems.length),
        ),
      ],
      selectedTabIndex: isLocal ? 0 : 1,
      onTabSelected: (index) => setState(
        () => _tab = index == 0 ? _SubtitleTab.local : _SubtitleTab.thunder,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            const SizedBox(
              height: 112,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 30, color: colors.danger),
                  const SizedBox(height: 9),
                  Text(
                    error,
                    textAlign: TextAlign.center,
                    style: AppText.meta(context),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: isLocal ? _loadLocal : _loadThunder,
                    child: Text(l.dbOnlineRetry),
                  ),
                ],
              ),
            )
          else if (count == 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
              child: Text(
                l.subtitleNoMatch,
                textAlign: TextAlign.center,
                style: AppText.body(context),
              ),
            )
          else
            ResourcePanelList(
              itemCount: count,
              dividerColor: colors.divider,
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 20),
              itemBuilder: (context, index) => isLocal
                  ? _LocalSubtitleRow(
                      item: _localFiles[index],
                      previewing: _busyKeys.contains(
                        'local-preview:${_localFiles[index].id}',
                      ),
                      downloading: _busyKeys.contains(
                        'local-download:${_localFiles[index].id}',
                      ),
                      onPreview: () => _previewLocal(_localFiles[index]),
                      onDownload: () => _downloadLocal(_localFiles[index]),
                    )
                  : _ThunderSubtitleRow(
                      item: _thunderItems[index],
                      previewing: _busyKeys.contains(
                        'thunder-preview:${_thunderItems[index].url}',
                      ),
                      downloading: _busyKeys.contains(
                        'thunder-download:${_thunderItems[index].url}',
                      ),
                      onPreview: () => _previewThunder(_thunderItems[index]),
                      onDownload: () => _downloadThunder(_thunderItems[index]),
                    ),
            ),
        ],
      ),
    );
  }
}

class _LocalSubtitleRow extends StatelessWidget {
  const _LocalSubtitleRow({
    required this.item,
    required this.previewing,
    required this.downloading,
    required this.onPreview,
    required this.onDownload,
  });

  final DbOnlineSubtitleFile item;
  final bool previewing;
  final bool downloading;
  final VoidCallback onPreview;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) => _SubtitleRow(
    name: item.name,
    details: [
      if (item.extension.isNotEmpty) item.extension.toUpperCase(),
      if (item.size > 0) formatFileSize(item.size),
    ],
    previewing: previewing,
    downloading: downloading,
    onPreview: onPreview,
    onDownload: onDownload,
  );
}

class _ThunderSubtitleRow extends StatelessWidget {
  const _ThunderSubtitleRow({
    required this.item,
    required this.previewing,
    required this.downloading,
    required this.onPreview,
    required this.onDownload,
  });

  final DbOnlineSubtitleCandidate item;
  final bool previewing;
  final bool downloading;
  final VoidCallback onPreview;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) => _SubtitleRow(
    name: item.name,
    details: [
      if (item.extension.isNotEmpty) item.extension.toUpperCase(),
      ...item.languages,
      if (item.durationMs > 0) _durationLabel(item.durationMs),
    ],
    previewing: previewing,
    downloading: downloading,
    onPreview: onPreview,
    onDownload: onDownload,
  );
}

class _SubtitleRow extends StatelessWidget {
  const _SubtitleRow({
    required this.name,
    required this.details,
    required this.previewing,
    required this.downloading,
    required this.onPreview,
    required this.onDownload,
  });

  final String name;
  final List<String> details;
  final bool previewing;
  final bool downloading;
  final VoidCallback onPreview;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return SubtitlePanelRow(
      title: name,
      details: details.isEmpty
          ? null
          : Text(
              details.join(' · '),
              style: AppText.meta(
                context,
              ).copyWith(color: appColors(context).muted),
            ),
      previewing: previewing,
      downloading: downloading,
      disableOtherActionWhileBusy: true,
      onPreview: onPreview,
      onDownload: onDownload,
    );
  }
}

class _SubtitlePreviewPage extends StatelessWidget {
  const _SubtitlePreviewPage({required this.title, required this.content});

  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.pageTitle(context),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Scrollbar(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    22,
                    12,
                    22,
                    28 + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: SelectableText(
                    content,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _durationLabel(int milliseconds) {
  final totalSeconds = milliseconds ~/ 1000;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  String pad(int value) => value.toString().padLeft(2, '0');
  return hours > 0
      ? '${pad(hours)}:${pad(minutes)}:${pad(seconds)}'
      : '${pad(minutes)}:${pad(seconds)}';
}

String _safeFileName(String value) =>
    value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
