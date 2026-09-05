import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/api/dio_factory.dart';
import 'package:omm/core/models/movie.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/glass.dart';
import 'package:omm/shared/sheet_controls.dart';
import 'package:omm/features/oh_my_media/movies/media_repository.dart';
import 'package:omm/features/oh_my_media/movies/movies_providers.dart';

/// 合并 magnets/ed2k 资源 sheet · 内部 tab 切换
///
/// 后端按 source (detail/custom/nyaa) 分别查,每个 source 返回
/// `{magnets:[], ed2ks:[], warnings:[]}`。这里合并三个 source 显示。
/// 同时拉下载器列表 + 下载历史,支持推送到下载器。
class ResourcesSheet extends ConsumerStatefulWidget {
  const ResourcesSheet({super.key, required this.movie});

  final MovieDetail movie;

  static Future<void> show(BuildContext context, {required MovieDetail movie}) {
    return showGlassSheet<void>(
      context: context,
      isScrollControlled: true,
      minHeight: sheetMinHeight(context),
      builder: (_) => ResourcesSheet(movie: movie),
    );
  }

  @override
  ConsumerState<ResourcesSheet> createState() => _ResourcesSheetState();
}

enum _ResTab { magnet, ed2k }

/// ED2K 仅这些下载器可处理
const _kEd2kSupportedDownloaders = {
  'openlist',
  'pan115',
  'clouddrive2',
  'thunder',
};

const _kResourceSources = ['detail', 'custom', 'nyaa'];

bool supportsEd2kDownloader(String name, bool? ed2kEnabled) {
  if (ed2kEnabled != null) return ed2kEnabled;

  final normalized = name.trim().toLowerCase();
  return _kEd2kSupportedDownloaders.contains(normalized) ||
      normalized.startsWith('openlist:');
}

DateTime? _epochToDate(double value) {
  // 1e11 毫秒约等于 1973 年,小于该值视为秒级时间戳。
  final millis = value >= 1e11 ? value : value * 1000;
  return DateTime.fromMillisecondsSinceEpoch(millis.round());
}

/// 解析资源日期,兼容 date/publish_date 字段、ISO 字符串与 epoch 时间戳。
DateTime? parseResourceDate(Map<String, dynamic> item) {
  final raw = item['date'] ?? item['publish_date'];
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  if (raw is num) return _epochToDate(raw.toDouble());

  final text = raw.toString().trim();
  if (text.isEmpty) return null;
  final parsed = DateTime.tryParse(text.replaceAll('/', '-'));
  if (parsed != null) return parsed;
  final epoch = double.tryParse(text);
  return epoch == null ? null : _epochToDate(epoch);
}

/// 按日期降序返回新列表,无法解析日期的项排在最后并保持原有相对顺序。
List<Map<String, dynamic>> sortResourcesByDateDesc(
  List<Map<String, dynamic>> items,
) {
  final decorated = List.generate(
    items.length,
    (i) => (index: i, item: items[i], date: parseResourceDate(items[i])),
  );
  decorated.sort((a, b) {
    if (a.date == null && b.date == null) return a.index.compareTo(b.index);
    if (a.date == null) return 1;
    if (b.date == null) return -1;
    final result = b.date!.compareTo(a.date!);
    return result != 0 ? result : a.index.compareTo(b.index);
  });
  return [for (final entry in decorated) entry.item];
}

/// 按固定渠道顺序合并、按资源 hash 去重再排序。
///
/// 相同 hash 保留日期更早的记录；日期相同或都无日期时，保留固定渠道
/// 顺序中的第一条。无法提取 hash 的记录不参与去重。
List<Map<String, dynamic>> mergeResourcesBySource(
  Map<String, List<Map<String, dynamic>>> bySource,
) {
  final merged = <Map<String, dynamic>>[];
  for (final source in _kResourceSources) {
    merged.addAll(bySource[source] ?? const []);
  }
  return sortResourcesByDateDesc(_deduplicateResourcesByHash(merged));
}

List<Map<String, dynamic>> _deduplicateResourcesByHash(
  List<Map<String, dynamic>> items,
) {
  final result = <Map<String, dynamic>>[];
  final indexByHash = <String, int>{};

  for (final item in items) {
    final hash = _resourceHashForDedup(item);
    if (hash.isEmpty) {
      result.add(item);
      continue;
    }

    final existingIndex = indexByHash[hash];
    if (existingIndex == null) {
      indexByHash[hash] = result.length;
      result.add(item);
    } else if (_isOlderResource(item, result[existingIndex])) {
      result[existingIndex] = item;
    }
  }

  return result;
}

bool _isOlderResource(
  Map<String, dynamic> candidate,
  Map<String, dynamic> current,
) {
  final candidateDate = parseResourceDate(candidate);
  final currentDate = parseResourceDate(current);
  if (candidateDate == null) return false;
  if (currentDate == null) return true;
  return candidateDate.isBefore(currentDate);
}

class _ResourcesSheetState extends ConsumerState<ResourcesSheet> {
  bool _loadingResources = true;
  String? _error;
  List<Map<String, dynamic>> _magnets = const [];
  List<Map<String, dynamic>> _ed2ks = const [];
  final Map<String, List<Map<String, dynamic>>> _sourceMagnets = {};
  final Map<String, List<Map<String, dynamic>>> _sourceEd2ks = {};
  List<String> _warnings = const [];
  List<({String name, String displayName, bool? ed2kEnabled})> _downloaders =
      const [];
  Map<String, String> _downloadedMagnets = const {};
  Map<String, String> _downloadedEd2ks = const {};
  _ResTab _tab = _ResTab.magnet;
  String? _pushingKey;
  Set<String> _pendingSources = {..._kResourceSources};
  final Map<String, String> _sourceErrors = {};
  int _loadGeneration = 0;
  bool _tabPicked = false;

  int get _movieId => widget.movie.id;
  String get _movieTitle => widget.movie.title;

  List<({String name, String displayName, bool? ed2kEnabled})>
  get _ed2kDownloaders => _downloaders.where(_supportsEd2k).toList();

  bool _supportsEd2k(
    ({String name, String displayName, bool? ed2kEnabled}) downloader,
  ) {
    return supportsEd2kDownloader(downloader.name, downloader.ed2kEnabled);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final generation = ++_loadGeneration;
    setState(() {
      _loadingResources = true;
      _error = null;
      _magnets = const [];
      _ed2ks = const [];
      _sourceMagnets.clear();
      _sourceEd2ks.clear();
      _warnings = const [];
      _pendingSources = {..._kResourceSources};
      _sourceErrors.clear();
      _tab = _ResTab.magnet;
      _tabPicked = false;
    });
    final repo = ref.read(mediaRepositoryProvider);
    for (final source in _kResourceSources) {
      unawaited(_loadResourceSource(repo, source, generation));
    }
    unawaited(_loadDownloaders(repo, generation));
    unawaited(_loadHistory(repo, generation));
  }

  Future<void> _loadResourceSource(
    MediaRepository repo,
    String source,
    int generation,
  ) async {
    try {
      final res = await repo
          .getResourcesBySource(_movieId, source)
          .timeout(const Duration(seconds: 20));
      if (!_isCurrentLoad(generation)) return;
      setState(() {
        _sourceMagnets[source] = res.magnets;
        _sourceEd2ks[source] = res.ed2ks;
        _magnets = mergeResourcesBySource(_sourceMagnets);
        _ed2ks = mergeResourcesBySource(_sourceEd2ks);
        _warnings = [..._warnings, ...res.warnings];
        _pendingSources.remove(source);
        _loadingResources = _pendingSources.isNotEmpty;
        _selectDefaultTab();
      });
    } catch (e) {
      if (!mounted || !_isCurrentLoad(generation)) return;
      final message =
          '${_sourceLabel(AppL10n.of(context), source)}: ${toApiException(e).message}';
      setState(() {
        _sourceErrors[source] = message;
        _warnings = [..._warnings, message];
        _pendingSources.remove(source);
        _loadingResources = _pendingSources.isNotEmpty;
        if (_pendingSources.isEmpty &&
            _magnets.isEmpty &&
            _ed2ks.isEmpty &&
            _sourceErrors.length == _kResourceSources.length) {
          _error = message;
        }
      });
    }
  }

  Future<void> _loadDownloaders(MediaRepository repo, int generation) async {
    try {
      final downloaders = await repo.getDownloaders();
      if (!_isCurrentLoad(generation)) return;
      setState(() => _downloaders = downloaders);
    } catch (_) {
      // 下载器列表失败不应阻塞在线资源展示。
    }
  }

  Future<void> _loadHistory(MediaRepository repo, int generation) async {
    try {
      final history = await repo.getDownloadHistory(_movieId);
      if (!_isCurrentLoad(generation)) return;
      setState(() {
        _downloadedMagnets = history.magnets;
        _downloadedEd2ks = history.ed2ks;
      });
    } catch (_) {
      // 下载历史失败不应阻塞在线资源展示。
    }
  }

  bool _isCurrentLoad(int generation) =>
      mounted && generation == _loadGeneration;

  void _selectDefaultTab() {
    if (_tabPicked) return;
    if (_magnets.isNotEmpty) {
      _tab = _ResTab.magnet;
    } else if (_ed2ks.isNotEmpty) {
      _tab = _ResTab.ed2k;
    }
  }

  String _sourceLabel(AppL10n l, String source) {
    switch (source) {
      case 'detail':
        return l.resourceSourceDetail;
      case 'custom':
        return l.resourceSourceCustom;
      case 'nyaa':
        return l.resourceSourceNyaa;
      default:
        return source;
    }
  }

  List<Map<String, dynamic>> get _activeList =>
      _tab == _ResTab.magnet ? _magnets : _ed2ks;

  List<({String name, String displayName, bool? ed2kEnabled})>
  get _activeDownloaders =>
      _tab == _ResTab.magnet ? _downloaders : _ed2kDownloaders;

  String? _getDownloadedAt(Map<String, dynamic> item) {
    final hash = _tab == _ResTab.magnet
        ? _extractMagnetHash(_pickUrl(item))
        : _extractEd2kHash(_pickUrl(item));
    if (hash.isEmpty) return null;
    final map = _tab == _ResTab.magnet ? _downloadedMagnets : _downloadedEd2ks;
    final v = map[hash];
    return (v == null || v.isEmpty) ? null : v;
  }

  Future<void> _onPush(Map<String, dynamic> item) async {
    if (_pushingKey != null) return;
    final l = AppL10n.of(context);
    final downloaders = _activeDownloaders;
    if (downloaders.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.resourceNoDownloaders)));
      return;
    }
    String? selected;
    if (downloaders.length == 1) {
      selected = downloaders.first.name;
    } else {
      selected = await showGlassSheet<String>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SheetHeader(
                icon: Icons.download_outlined,
                title: l.resourceSelectDownloader,
                padding: const EdgeInsets.fromLTRB(22, 6, 22, 8),
              ),
              for (final d in downloaders)
                ListTile(
                  leading: const Icon(Icons.download_outlined, size: 20),
                  title: Text(d.displayName),
                  onTap: () => Navigator.pop(ctx, d.name),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    }
    if (selected == null || !mounted) return;
    await _push(item, selected);
  }

  Future<void> _push(Map<String, dynamic> item, String downloader) async {
    final url = _pickUrl(item);
    if (url.isEmpty) return;
    final l = AppL10n.of(context);
    setState(() => _pushingKey = url);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final protocol = _tab == _ResTab.magnet ? 'magnet' : 'ed2k';
      final res = await ref
          .read(mediaRepositoryProvider)
          .pushDownload(
            urls: [url],
            downloader: downloader,
            movieId: _movieId,
            videoInfo: _buildVideoInfo(),
            recordResources: [_buildRecordResource(item, protocol, url)],
          );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(res.message),
          duration: const Duration(seconds: 2),
        ),
      );
      // 刷新下载历史 (静默)
      try {
        final history = await ref
            .read(mediaRepositoryProvider)
            .getDownloadHistory(_movieId);
        if (mounted) {
          setState(() {
            _downloadedMagnets = history.magnets;
            _downloadedEd2ks = history.ed2ks;
          });
        }
      } catch (_) {}
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(l.resourcePushFailed(toApiException(e).message)),
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) setState(() => _pushingKey = null);
    }
  }

  Map<String, dynamic> _buildVideoInfo() => {
    'code': (widget.movie.num ?? '').trim(),
    'title': _movieTitle.trim(),
    'video_id': '',
    'date': (widget.movie.year != null ? widget.movie.year.toString() : ''),
  };

  Map<String, dynamic> _buildRecordResource(
    Map<String, dynamic> item,
    String protocol,
    String url,
  ) {
    return {
      'url': url,
      'name': (item['name'] ?? item['title'] ?? '').toString(),
      'source_type': protocol == 'ed2k'
          ? 'ed2k'
          : (item['source_type'] ??
                    (item['is_external'] == true ? 'external' : 'javdb'))
                .toString(),
      'source_label': (item['site'] ?? (protocol == 'ed2k' ? 'ED2K' : '手动'))
          .toString(),
      'resource_protocol': protocol,
      'resource_site': (item['site'] ?? '').toString(),
      'resource_flags': _buildResourceFlags(item),
      'resource_date': (item['date'] ?? '').toString(),
      'video_code': (widget.movie.num ?? '').trim(),
      'video_title': _movieTitle.trim(),
    };
  }

  int _buildResourceFlags(Map<String, dynamic> item) {
    final tags = (item['tags'] is List) ? (item['tags'] as List) : const [];
    final lowered = tags
        .map((t) => t.toString().toLowerCase())
        .toList(growable: false);
    int flags = 1;
    if (lowered.any((t) => t == 'uhd' || t == '4k' || t.contains('4k'))) {
      flags = 4;
    } else if (lowered.any(
      (t) => (t.contains('hd') && !t.contains('uhd')) || t.contains('高清'),
    )) {
      flags = 2;
    }
    if (lowered.any((t) => t.contains('字幕') || t.contains('sub'))) flags |= 8;
    if (lowered.any((t) => t.contains('破解') || t.contains('无码'))) flags |= 16;
    return flags;
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final l = AppL10n.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;
    return SafeArea(
      top: false,
      bottom: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SheetHeader(
              icon: Icons.cloud_download_outlined,
              title: l.resourceOnline,
              subtitle: _movieTitle,
              trailing: IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                onPressed: _loadingResources ? null : _load,
              ),
            ),
            // ===== Tab 切换 =====
            if (_error == null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: c.chipBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _TabBtn(
                          label: l.resourceMagnetCount(_magnets.length),
                          active: _tab == _ResTab.magnet,
                          onTap: () => setState(() {
                            _tab = _ResTab.magnet;
                            _tabPicked = true;
                          }),
                        ),
                      ),
                      Expanded(
                        child: _TabBtn(
                          label: l.resourceEd2kCount(_ed2ks.length),
                          active: _tab == _ResTab.ed2k,
                          onTap: () => setState(() {
                            _tab = _ResTab.ed2k;
                            _tabPicked = true;
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            // ===== Warnings =====
            if (_warnings.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: c.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 14, color: c.warning),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _warnings.first,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: c.warning,
                            fontFamily: 'Inter',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // ===== 内容 =====
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(22),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: c.danger,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else ...[
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
                          color: c.accent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l.resourceLoadingOnline,
                        style: AppText.meta(context),
                      ),
                    ],
                  ),
                ),
              if (_activeList.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
                  child: Text(
                    _loadingResources
                        ? l.resourceWaitingSources
                        : _tab == _ResTab.magnet
                        ? l.resourceNoMagnet
                        : l.resourceNoEd2k,
                    textAlign: TextAlign.center,
                    style: AppText.body(context),
                  ),
                )
              else
                Flexible(
                  fit: FlexFit.loose,
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    itemCount: _activeList.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: c.divider),
                    itemBuilder: (ctx, i) {
                      final r = _activeList[i];
                      final url = _pickUrl(r);
                      final downloadedAt = _getDownloadedAt(r);
                      return _ResourceTile(
                        item: r,
                        url: url,
                        downloadedAt: downloadedAt,
                        pushing: _pushingKey == url,
                        pushDisabled:
                            _pushingKey != null || _activeDownloaders.isEmpty,
                        onPush: () => _onPush(r),
                      );
                    },
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

String _pickUrl(Map<String, dynamic> item) {
  return (item['url'] ?? item['link'] ?? item['magnet'] ?? item['ed2k'] ?? '')
      .toString();
}

String _resourceHashForDedup(Map<String, dynamic> item) {
  final magnet = item['magnet']?.toString().trim() ?? '';
  final magnetHash = _magnetHashOnly(magnet);
  if (magnetHash.isNotEmpty) return 'magnet:$magnetHash';

  final ed2k = item['ed2k']?.toString().trim() ?? '';
  final ed2kHash = _ed2kHashOnly(ed2k);
  if (ed2kHash.isNotEmpty) return 'ed2k:$ed2kHash';

  final url = _pickUrl(item).trim();
  if (url.toLowerCase().startsWith('ed2k:')) {
    final hash = _ed2kHashOnly(url);
    if (hash.isNotEmpty) return 'ed2k:$hash';
  }
  final hash = _magnetHashOnly(url);
  return hash.isEmpty ? '' : 'magnet:$hash';
}

String _magnetHashOnly(String value) {
  final match = RegExp(
    r'(?:^|[?&])xt=urn:btih:([A-Za-z0-9]+)',
    caseSensitive: false,
  ).firstMatch(value);
  return match?.group(1)?.toUpperCase() ?? '';
}

String _ed2kHashOnly(String value) {
  final parts = value.split('|');
  if (parts.length < 5) return '';
  return parts[4].trim().toUpperCase();
}

String _extractMagnetHash(String magnet) {
  final t = magnet.trim();
  if (t.isEmpty) return '';
  final m = RegExp(
    r'xt=urn:btih:([A-Za-z0-9]+)',
    caseSensitive: false,
  ).firstMatch(t);
  if (m != null) return m.group(1)!.toUpperCase();
  return t.toUpperCase();
}

String _extractEd2kHash(String ed2k) {
  final t = ed2k.trim();
  if (t.isEmpty) return '';
  final parts = t.split('|');
  if (parts.length >= 5) {
    final h = parts[4].trim();
    if (h.isNotEmpty) return h.toUpperCase();
  }
  return t.toUpperCase();
}

String _formatDownloadedTooltip(AppL10n l, String value) {
  if (value.isEmpty) return '';
  final dt = DateTime.tryParse(value);
  if (dt == null) return l.resourceRecentlyDownloaded(value);
  final local = dt.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final mo = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  final h = local.hour.toString().padLeft(2, '0');
  final mi = local.minute.toString().padLeft(2, '0');
  return l.resourceRecentlyDownloadedAt('$y-$mo-$d $h:$mi');
}

String _formatResourceSize(dynamic value) {
  final sizeMb = value is num
      ? value.toDouble()
      : double.tryParse(value?.toString().trim() ?? '');
  if (sizeMb == null || sizeMb <= 0) return '';

  if (sizeMb >= 1024) {
    return '${(sizeMb / 1024).toStringAsFixed(2)} GB';
  }
  final display = sizeMb == sizeMb.roundToDouble()
      ? sizeMb.toInt().toString()
      : sizeMb.toStringAsFixed(2);
  return '$display MB';
}

class _TabBtn extends StatelessWidget {
  const _TabBtn({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? c.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: active
              ? const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? c.text : c.muted,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _ResourceTile extends StatelessWidget {
  const _ResourceTile({
    required this.item,
    required this.url,
    required this.downloadedAt,
    required this.pushing,
    required this.pushDisabled,
    required this.onPush,
  });
  final Map<String, dynamic> item;
  final String url;
  final String? downloadedAt;
  final bool pushing;
  final bool pushDisabled;
  final VoidCallback onPush;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final l = AppL10n.of(context);
    final title =
        (item['title'] ??
                item['name'] ??
                item['filename'] ??
                l.resourceFallbackTitle)
            .toString();
    final size = _formatResourceSize(item['size_mb'] ?? item['size']);
    final date =
        item['date']?.toString() ?? item['publish_date']?.toString() ?? '';
    final source = (item['site'] ?? item['source'] ?? '').toString().trim();
    final isDownloaded = downloadedAt != null && downloadedAt!.isNotEmpty;
    final tile = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.text,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (size.isNotEmpty)
                      Text(size, style: AppText.meta(context)),
                    if (source.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: c.chipBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          l.resourceFrom(source),
                          style: TextStyle(
                            color: c.muted,
                            fontFamily: 'monospace',
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                _ResourceTagBadges(item: item),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // 右侧: 上方日期, 下方按钮
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (date.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 6, bottom: 2),
                  child: Text(
                    date,
                    style: TextStyle(
                      color: c.muted,
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
                    icon: Icon(Icons.copy, size: 18, color: c.accent),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    onPressed: url.isEmpty
                        ? null
                        : () async {
                            await Clipboard.setData(ClipboardData(text: url));
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(l.resourceCopied),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                  ),
                  IconButton(
                    tooltip: pushing
                        ? l.resourcePushing
                        : l.resourcePushDownload,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    icon: pushing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(Icons.send, size: 18, color: c.warning),
                    onPressed: pushDisabled ? null : onPush,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    Widget content = Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: isDownloaded
            ? Border.all(color: const Color(0xFF2E9C7A), width: 1)
            : null,
      ),
      child: tile,
    );

    if (isDownloaded) {
      content = Tooltip(
        message: _formatDownloadedTooltip(l, downloadedAt!),
        child: content,
      );
    }
    return content;
  }
}

/// 在线资源 tag badge 行 · UHD/HD · 字幕 · 破解/LADA
class _ResourceTagBadges extends StatelessWidget {
  const _ResourceTagBadges({required this.item});
  final Map<String, dynamic> item;

  List<String> get _tagsLower {
    final raw = item['tags'];
    if (raw is! List) return const [];
    return raw
        .map((t) => t.toString().toLowerCase())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  bool get _hasUHD {
    return _tagsLower.any(
      (t) => t == '4k' || t.contains('uhd') || t.contains('4k'),
    );
  }

  bool get _hasHD {
    if (_hasUHD) return false;
    return _tagsLower.any(
      (t) => t == 'hd' || t.contains('hd') || t.contains('高清'),
    );
  }

  bool get _hasSub =>
      _tagsLower.any((t) => t.contains('字幕') || t.contains('sub'));

  bool get _hasCrack =>
      _tagsLower.any((t) => t.contains('破解') || t.contains('无码'));

  bool get _hasLADA => _tagsLower.any((t) => t == 'lada');

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final hasUHD = _hasUHD;
    final hasHD = _hasHD;
    final hasSub = _hasSub;
    final hasCrack = _hasCrack;
    final hasLADA = _hasLADA;

    if (!hasUHD && !hasHD && !hasSub && !hasCrack && !hasLADA) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          if (hasUHD)
            const _ResBadge(
              label: 'UHD',
              icon: Icons.tv_rounded,
              color: Color(0xFF2D6CDF),
            )
          else if (hasHD)
            const _ResBadge(
              label: 'HD',
              icon: Icons.tv_rounded,
              color: Color(0xFF10B981),
            ),
          if (hasSub)
            _ResBadge(
              label: l.movieFlagSubtitle,
              icon: Icons.closed_caption_rounded,
              color: const Color(0xFFFF9F1C),
            ),
          if (hasLADA)
            const _ResBadge(
              label: 'LADA',
              icon: Icons.auto_awesome_rounded,
              color: Color(0xFFA855F7),
            )
          else if (hasCrack)
            _ResBadge(
              label: l.movieFlagCrack,
              icon: Icons.lock_open_rounded,
              color: const Color(0xFFE91E63),
            ),
        ],
      ),
    );
  }
}

class _ResBadge extends StatelessWidget {
  const _ResBadge({
    required this.label,
    required this.icon,
    required this.color,
  });
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 10),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w800,
              fontSize: 9.5,
              height: 1,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
