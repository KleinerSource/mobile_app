import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'package:omm/core/sources/media/dbo/db_online_movie.dart';
import 'package:omm/core/sources/media/dbo/db_online_subtitle.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/features/db_online/providers/db_online_home_providers.dart';
import 'package:omm/features/oh_my_media/movie_detail/movie_detail_formatters.dart'
    show formatFileSize;
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/glass.dart';
import 'package:omm/shared/localized_error_message.dart';
import 'package:omm/shared/resource_panel_components.dart';
import 'package:omm/shared/sheet_controls.dart';

enum _ResourceTab { magnet, ed2k }

class DbOnlineResourcesSheet extends StatefulWidget {
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
  State<DbOnlineResourcesSheet> createState() => _DbOnlineResourcesSheetState();
}

class _DbOnlineResourcesSheetState extends State<DbOnlineResourcesSheet> {
  _ResourceTab _tab = _ResourceTab.magnet;

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

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final l = AppL10n.of(context);
    final isMagnet = _tab == _ResourceTab.magnet;
    final count = isMagnet
        ? widget.movie.magnets.length
        : widget.movie.ed2ks.length;
    return SafeArea(
      top: false,
      bottom: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SheetHeader(
              icon: Icons.cloud_download_outlined,
              title: l.detailFetchResources,
              subtitle: widget.movie.code,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: colors.chipBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ResourcePanelTabButton(
                        label: l.resourceMagnetCount(
                          widget.movie.magnets.length,
                        ),
                        active: isMagnet,
                        onTap: () => setState(() => _tab = _ResourceTab.magnet),
                      ),
                    ),
                    Expanded(
                      child: ResourcePanelTabButton(
                        label: l.resourceEd2kCount(widget.movie.ed2ks.length),
                        active: !isMagnet,
                        onTap: () => setState(() => _tab = _ResourceTab.ed2k),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (count == 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
                child: Text(
                  isMagnet ? l.resourceNoMagnet : l.resourceNoEd2k,
                  textAlign: TextAlign.center,
                  style: AppText.body(context),
                ),
              )
            else
              Flexible(
                fit: FlexFit.loose,
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
                  itemCount: count,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: colors.divider),
                  itemBuilder: (context, index) => isMagnet
                      ? _MagnetRow(
                          item: widget.movie.magnets[index],
                          onCopy: () =>
                              _copy(widget.movie.magnets[index].magnet),
                        )
                      : _Ed2kRow(
                          item: widget.movie.ed2ks[index],
                          onCopy: () => _copy(widget.movie.ed2ks[index].ed2k),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MagnetRow extends StatelessWidget {
  const _MagnetRow({required this.item, required this.onCopy});

  final DbOnlineMagnet item;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) => _ResourceRow(
    name: item.name,
    value: item.magnet,
    sizeMb: item.sizeMb,
    fileCount: item.fileCount,
    date: item.date,
    site: item.site,
    tags: item.tags,
    onCopy: onCopy,
  );
}

class _Ed2kRow extends StatelessWidget {
  const _Ed2kRow({required this.item, required this.onCopy});

  final DbOnlineEd2k item;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) => _ResourceRow(
    name: item.name,
    value: item.ed2k,
    sizeMb: item.sizeMb,
    date: item.date,
    site: item.site,
    tags: item.tags,
    onCopy: onCopy,
  );
}

class _ResourceRow extends StatelessWidget {
  const _ResourceRow({
    required this.name,
    required this.value,
    required this.onCopy,
    this.sizeMb,
    this.fileCount,
    this.date,
    this.site,
    this.tags = const [],
  });

  final String name;
  final String value;
  final VoidCallback onCopy;
  final double? sizeMb;
  final int? fileCount;
  final String? date;
  final String? site;
  final List<String> tags;

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
      metadata: metadata.isEmpty
          ? null
          : Wrap(spacing: 8, runSpacing: 4, children: metadata),
      tags: tags,
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
          IconButton(
            tooltip: l.subtitleCopy,
            onPressed: value.trim().isEmpty ? null : onCopy,
            icon: Icon(Icons.copy_rounded, size: 18, color: colors.accent),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
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
    return SafeArea(
      top: false,
      bottom: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SheetHeader(
              icon: Icons.subtitles_outlined,
              title: l.subtitleSearchTitle,
              subtitle: widget.code,
              trailing: IconButton(
                tooltip: l.dbOnlineRetry,
                icon: Icon(
                  Icons.refresh_rounded,
                  color: colors.muted,
                  size: 20,
                ),
                onPressed: loading
                    ? null
                    : (isLocal ? _loadLocal : _loadThunder),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: colors.chipBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ResourcePanelTabButton(
                        label: l.dbOnlineLocalSubtitles(_localFiles.length),
                        active: isLocal,
                        onTap: () => setState(() => _tab = _SubtitleTab.local),
                      ),
                    ),
                    Expanded(
                      child: ResourcePanelTabButton(
                        label: l.dbOnlineThunderSubtitles(_thunderItems.length),
                        active: !isLocal,
                        onTap: () =>
                            setState(() => _tab = _SubtitleTab.thunder),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
              Flexible(
                fit: FlexFit.loose,
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 20),
                  itemCount: count,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: colors.divider),
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
                          onPreview: () =>
                              _previewThunder(_thunderItems[index]),
                          onDownload: () =>
                              _downloadThunder(_thunderItems[index]),
                        ),
                ),
              ),
          ],
        ),
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
    final l = AppL10n.of(context);
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
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
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
