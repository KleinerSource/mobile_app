import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/dio_factory.dart';
import '../../core/models/movie.dart';
import '../../core/platform/app_theme.dart';
import '../movies/movies_providers.dart';

/// 合并 magnets/ed2k 资源 sheet · 内部 tab 切换
///
/// 后端按 source (detail/custom/nyaa) 分别查,每个 source 返回
/// `{magnets:[], ed2ks:[], warnings:[]}`。这里合并三个 source 显示。
/// 同时拉下载器列表 + 下载历史,支持推送到下载器。
class ResourcesSheet extends ConsumerStatefulWidget {
  const ResourcesSheet({super.key, required this.movie});

  final MovieDetail movie;

  static Future<void> show(
    BuildContext context, {
    required MovieDetail movie,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: appColors(context).bg,
      isScrollControlled: true,
      showDragHandle: true,
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

class _ResourcesSheetState extends ConsumerState<ResourcesSheet> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _magnets = const [];
  List<Map<String, dynamic>> _ed2ks = const [];
  List<String> _warnings = const [];
  List<({String name, String displayName})> _downloaders = const [];
  Map<String, String> _downloadedMagnets = const {};
  Map<String, String> _downloadedEd2ks = const {};
  _ResTab _tab = _ResTab.magnet;
  String? _pushingKey;

  int get _movieId => widget.movie.id;
  String get _movieTitle => widget.movie.title;

  List<({String name, String displayName})> get _ed2kDownloaders =>
      _downloaders.where((d) => _kEd2kSupportedDownloaders.contains(d.name)).toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final repo = ref.read(moviesRepositoryProvider);
    try {
      final results = await Future.wait([
        repo.getAllResources(_movieId),
        repo.getDownloaders().catchError((_) =>
            <({String name, String displayName})>[]),
        repo.getDownloadHistory(_movieId).catchError((_) =>
            (magnets: <String, String>{}, ed2ks: <String, String>{})),
      ]);
      if (!mounted) return;
      final res = results[0] as ({
        List<Map<String, dynamic>> magnets,
        List<Map<String, dynamic>> ed2ks,
        List<String> warnings
      });
      final dls = results[1] as List<({String name, String displayName})>;
      final history = results[2] as ({
        Map<String, String> magnets,
        Map<String, String> ed2ks
      });
      setState(() {
        _magnets = res.magnets;
        _ed2ks = res.ed2ks;
        _warnings = res.warnings;
        _downloaders = dls;
        _downloadedMagnets = history.magnets;
        _downloadedEd2ks = history.ed2ks;
        if (_magnets.isEmpty && _ed2ks.isNotEmpty) {
          _tab = _ResTab.ed2k;
        } else {
          _tab = _ResTab.magnet;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = toApiException(e).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _activeList =>
      _tab == _ResTab.magnet ? _magnets : _ed2ks;

  List<({String name, String displayName})> get _activeDownloaders =>
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
    final downloaders = _activeDownloaders;
    if (downloaders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未配置可用下载器')),
      );
      return;
    }
    String? selected;
    if (downloaders.length == 1) {
      selected = downloaders.first.name;
    } else {
      selected = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: appColors(context).bg,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 8),
                child: Text('选择下载器', style: AppText.sectionTitle(ctx)),
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
    setState(() => _pushingKey = url);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final protocol = _tab == _ResTab.magnet ? 'magnet' : 'ed2k';
      final res = await ref.read(moviesRepositoryProvider).pushDownload(
        urls: [url],
        downloader: downloader,
        movieId: _movieId,
        videoInfo: _buildVideoInfo(),
        recordResources: [_buildRecordResource(item, protocol, url)],
      );
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(res.message),
        duration: const Duration(seconds: 2),
      ));
      // 刷新下载历史 (静默)
      try {
        final history =
            await ref.read(moviesRepositoryProvider).getDownloadHistory(_movieId);
        if (mounted) {
          setState(() {
            _downloadedMagnets = history.magnets;
            _downloadedEd2ks = history.ed2ks;
          });
        }
      } catch (_) {}
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('推送失败: ${toApiException(e).message}'),
        duration: const Duration(seconds: 2),
      ));
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
      'source_label':
          (item['site'] ?? (protocol == 'ed2k' ? 'ED2K' : '手动')).toString(),
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
    final lowered =
        tags.map((t) => t.toString().toLowerCase()).toList(growable: false);
    int flags = 1;
    if (lowered.any((t) => t == 'uhd' || t == '4k' || t.contains('4k'))) {
      flags = 4;
    } else if (lowered.any((t) =>
        (t.contains('hd') && !t.contains('uhd')) || t.contains('高清'))) {
      flags = 2;
    }
    if (lowered.any((t) => t.contains('字幕') || t.contains('sub'))) flags |= 8;
    if (lowered.any((t) => t.contains('破解') || t.contains('无码'))) flags |= 16;
    return flags;
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final mq = MediaQuery.of(context);
    return SizedBox(
      height: mq.size.height * 0.82,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // ===== 头部 =====
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 6, 22, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('在线资源', style: AppText.sectionTitle(context)),
                        const SizedBox(height: 2),
                        Text(_movieTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.meta(context)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 18),
                    onPressed: _loading ? null : _load,
                  ),
                ],
              ),
            ),
            // ===== Tab 切换 =====
            if (!_loading && _error == null)
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
                          label: '磁力 (${_magnets.length})',
                          active: _tab == _ResTab.magnet,
                          onTap: () => setState(() => _tab = _ResTab.magnet),
                        ),
                      ),
                      Expanded(
                        child: _TabBtn(
                          label: 'ED2K (${_ed2ks.length})',
                          active: _tab == _ResTab.ed2k,
                          onTap: () => setState(() => _tab = _ResTab.ed2k),
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
                      horizontal: 10, vertical: 6),
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
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(22),
                            child: Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: c.danger,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        )
                      : _activeList.isEmpty
                          ? Center(
                              child: Text(
                                _tab == _ResTab.magnet
                                    ? '没有磁力资源'
                                    : '没有 ED2K 资源',
                                style: AppText.body(context),
                              ),
                            )
                          : ListView.separated(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 22),
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
                                  pushDisabled: _pushingKey != null ||
                                      _activeDownloaders.isEmpty,
                                  onPush: () => _onPush(r),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

String _pickUrl(Map<String, dynamic> item) {
  return (item['url'] ??
          item['link'] ??
          item['magnet'] ??
          item['ed2k'] ??
          '')
      .toString();
}

String _extractMagnetHash(String magnet) {
  final t = magnet.trim();
  if (t.isEmpty) return '';
  final m = RegExp(r'xt=urn:btih:([A-Za-z0-9]+)', caseSensitive: false)
      .firstMatch(t);
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

String _formatDownloadedTooltip(String value) {
  if (value.isEmpty) return '';
  final dt = DateTime.tryParse(value);
  if (dt == null) return '最近下载 $value';
  final local = dt.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final mo = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  final h = local.hour.toString().padLeft(2, '0');
  final mi = local.minute.toString().padLeft(2, '0');
  return '最近下载 $y-$mo-$d $h:$mi';
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
                      offset: Offset(0, 1))
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
    final title = (item['title'] ??
            item['name'] ??
            item['filename'] ??
            '资源')
        .toString();
    final size = item['size']?.toString() ?? '';
    final date =
        item['date']?.toString() ?? item['publish_date']?.toString() ?? '';
    final source = item['source']?.toString() ?? '';
    final isDownloaded = downloadedAt != null && downloadedAt!.isNotEmpty;
    final tile = ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      title: Text(
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
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            if (size.isNotEmpty)
              Text(size, style: AppText.meta(context)),
            if (date.isNotEmpty)
              Text(date, style: AppText.meta(context)),
            if (source.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: c.chipBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  source,
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
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: '复制',
            icon: Icon(Icons.copy, size: 18, color: c.accent),
            onPressed: url.isEmpty
                ? null
                : () async {
                    await Clipboard.setData(ClipboardData(text: url));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('已复制'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
          ),
          IconButton(
            tooltip: pushing ? '推送中' : '推送下载',
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
        message: _formatDownloadedTooltip(downloadedAt!),
        child: content,
      );
    }
    return content;
  }
}
