import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/api/dio_factory.dart';
import 'package:omm/core/models/subtitle_search.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/glass.dart';
import 'package:omm/shared/sheet_controls.dart';
import 'package:omm/features/oh_my_media/movies/movies_providers.dart';

/// 迅雷字幕搜索 / 预览 / 下载 sheet
///
/// 列表项:
/// - 名称 + 后缀 + 文件大小
/// - 时长 (后端 item.duration 或客户端从预览内容 extract)
/// - 预览按钮 → push 独立全屏页面
/// - 下载按钮
class ThunderSubtitleSheet extends ConsumerStatefulWidget {
  const ThunderSubtitleSheet({
    super.key,
    required this.movieId,
    this.hostMessenger,
  });
  final int movieId;
  final ScaffoldMessengerState? hostMessenger;

  static Future<void> show(BuildContext context, int movieId) {
    final hostMessenger = ScaffoldMessenger.maybeOf(context);
    return showGlassSheet<void>(
      context: context,
      isScrollControlled: true,
      minHeight: sheetMinHeight(context),
      builder: (_) =>
          ThunderSubtitleSheet(movieId: movieId, hostMessenger: hostMessenger),
    );
  }

  @override
  ConsumerState<ThunderSubtitleSheet> createState() =>
      _ThunderSubtitleSheetState();
}

class _ThunderSubtitleSheetState extends ConsumerState<ThunderSubtitleSheet> {
  bool _loading = true;
  String? _error;
  String _keyword = '';
  List<SubtitleSearchItem> _items = const [];
  // 预览缓存
  final Map<String, String> _previewCache = {};
  // 从预览内容 extract 出来的 duration · 缓存到 ms
  final Map<String, int> _extractedDuration = {};
  int? _previewingIndex;
  int? _downloadingIndex;

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
    try {
      final res = await ref
          .read(mediaRepositoryProvider)
          .searchSubtitles(widget.movieId);
      if (!mounted) return;
      // 字母数字混合自然序排序 (frontend 同)
      final sorted = [...res.items]
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      setState(() {
        _items = sorted;
        _keyword = res.keyword;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = toApiException(e).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String?> _fetchPreview(SubtitleSearchItem item) async {
    if (_previewCache.containsKey(item.url)) return _previewCache[item.url];
    try {
      final content = await ref
          .read(mediaRepositoryProvider)
          .previewSubtitle(widget.movieId, item.url);
      _previewCache[item.url] = content;
      // extract duration 后缓存
      final ms = _extractMaxDurationMs(content, item.ext);
      if (ms > 0) _extractedDuration[item.url] = ms;
      return content;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppL10n.of(
                context,
              ).subtitlePreviewFailed(toApiException(e).message),
            ),
          ),
        );
      }
      return null;
    }
  }

  Future<void> _openPreview(int index, SubtitleSearchItem item) async {
    if (_previewingIndex == index) return;
    setState(() => _previewingIndex = index);
    try {
      final content = await _fetchPreview(item);
      if (!mounted || content == null) return;
      // 推一个独立路由展示预览, 关掉时回到 sheet
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _SubtitlePreviewPage(
            item: item,
            content: content,
            duration: _resolveDurationMs(item),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _previewingIndex = null);
    }
  }

  Future<void> _download(
    int index,
    SubtitleSearchItem item, {
    bool overwrite = false,
  }) async {
    if (_downloadingIndex == index) return;
    setState(() => _downloadingIndex = index);
    final messenger =
        widget.hostMessenger ?? ScaffoldMessenger.maybeOf(context);
    var shouldOverwrite = overwrite;
    try {
      while (true) {
        try {
          await ref
              .read(mediaRepositoryProvider)
              .downloadSubtitle(
                widget.movieId,
                url: item.url,
                ext: item.ext ?? 'srt',
                overwrite: shouldOverwrite,
              );
          // ignore: unused_result
          ref.refresh(movieDetailProvider(widget.movieId));
          if (!mounted) return;
          final l = AppL10n.of(context);
          Navigator.of(context).pop();
          messenger?.showSnackBar(
            SnackBar(
              content: Text(l.subtitleDownloaded(item.name)),
              duration: const Duration(seconds: 1),
            ),
          );
          return;
        } catch (e) {
          if (!shouldOverwrite && _isSubtitleAlreadyExistsError(e) && mounted) {
            final confirmed = await _confirmOverwrite();
            if (confirmed == true && mounted) {
              shouldOverwrite = true;
              continue;
            }
            return;
          }
          if (!mounted) return;
          messenger?.showSnackBar(
            SnackBar(
              content: Text(
                AppL10n.of(
                  context,
                ).subtitleDownloadFailed(toApiException(e).message),
              ),
            ),
          );
          return;
        }
      }
    } finally {
      if (mounted) setState(() => _downloadingIndex = null);
    }
  }

  Future<bool?> _confirmOverwrite() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppL10n.of(context).subtitleExistsTitle),
        content: Text(AppL10n.of(context).subtitleExistsMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppL10n.of(context).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppL10n.of(context).fileOverwrite),
          ),
        ],
      ),
    );
  }

  bool _isSubtitleAlreadyExistsError(Object error) {
    final message = toApiException(error).message;
    return message.contains('已存在') ||
        RegExp(r'SUBTITLE_EXISTS', caseSensitive: false).hasMatch(message);
  }

  int? _resolveDurationMs(SubtitleSearchItem item) {
    if (item.duration != null && item.duration! > 0) return item.duration;
    return _extractedDuration[item.url];
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final l = AppL10n.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetHeader(
          icon: Icons.subtitles_outlined,
          title: l.subtitleSearchTitle,
          subtitle: _keyword.isEmpty ? null : l.subtitleSearchKeyword(_keyword),
          trailing: IconButton(
            icon: Icon(Icons.refresh, color: c.muted, size: 20),
            onPressed: _loading ? null : _load,
          ),
        ),
        if (_loading)
          const SizedBox(
            height: 96,
            child: Center(child: CircularProgressIndicator()),
          )
        else
          _buildBody(c),
      ],
    );
  }

  Widget _buildBody(AppColors c) {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 36, color: c.danger),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.danger,
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.subtitles_off, size: 36, color: c.muted),
            const SizedBox(height: 12),
            Text(
              AppL10n.of(context).subtitleNoMatch,
              style: AppText.meta(context),
            ),
          ],
        ),
      );
    }
    return Flexible(
      fit: FlexFit.loose,
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        itemCount: _items.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: c.divider),
        itemBuilder: (ctx, i) => _SubtitleRow(
          index: i,
          item: _items[i],
          durationMs: _resolveDurationMs(_items[i]),
          previewing: _previewingIndex == i,
          downloading: _downloadingIndex == i,
          onPreview: () => _openPreview(i, _items[i]),
          onDownload: () => _download(i, _items[i]),
        ),
      ),
    );
  }
}

/// 单行字幕
class _SubtitleRow extends StatelessWidget {
  const _SubtitleRow({
    required this.index,
    required this.item,
    required this.durationMs,
    required this.previewing,
    required this.downloading,
    required this.onPreview,
    required this.onDownload,
  });

  final int index;
  final SubtitleSearchItem item;
  final int? durationMs;
  final bool previewing;
  final bool downloading;
  final VoidCallback onPreview;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final l = AppL10n.of(context);
    final ext = item.ext ?? '';
    final size = item.fileSize ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 序号
          SizedBox(
            width: 24,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: c.muted,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
          ),
          // 名称 + meta
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.text,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (ext.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: c.chipBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '.$ext',
                          style: TextStyle(
                            color: c.text2,
                            fontFamily: 'monospace',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    if (durationMs != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time, size: 11, color: c.muted),
                          const SizedBox(width: 3),
                          Text(
                            _formatDuration(durationMs!),
                            style: TextStyle(
                              color: c.muted,
                              fontFamily: 'monospace',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        '—',
                        style: TextStyle(
                          color: c.muted2,
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                      ),
                    if (size > 0)
                      Text(_fmtBytes(size), style: AppText.meta(context)),
                  ],
                ),
              ],
            ),
          ),
          // 操作
          const SizedBox(width: 6),
          _IconBtn(
            tooltip: l.subtitlePreview,
            loading: previewing,
            icon: Icons.visibility_outlined,
            onTap: onPreview,
          ),
          const SizedBox(width: 4),
          _IconBtn(
            tooltip: l.subtitleDownload,
            loading: downloading,
            icon: Icons.download,
            color: c.accent,
            onTap: onDownload,
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.tooltip,
    required this.loading,
    required this.icon,
    required this.onTap,
    this.color,
  });
  final String tooltip;
  final bool loading;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return IconButton(
      tooltip: tooltip,
      iconSize: 18,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      icon: loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, color: color ?? c.text2),
      onPressed: loading ? null : onTap,
    );
  }
}

/// 字幕预览独立页 · 整个内容可滚动 + 顶部 copy 按钮
class _SubtitlePreviewPage extends StatefulWidget {
  const _SubtitlePreviewPage({
    required this.item,
    required this.content,
    required this.duration,
  });

  final SubtitleSearchItem item;
  final String content;
  final int? duration;

  @override
  State<_SubtitlePreviewPage> createState() => _SubtitlePreviewPageState();
}

class _SubtitlePreviewPageState extends State<_SubtitlePreviewPage> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final l = AppL10n.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l.subtitlePreviewTitle,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            Text(
              widget.item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: c.muted,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          if (widget.duration != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: c.chipBg,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.access_time, size: 11, color: c.muted),
                      const SizedBox(width: 4),
                      Text(
                        _formatDuration(widget.duration!),
                        style: TextStyle(
                          color: c.text2,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          IconButton(
            tooltip: l.subtitleCopy,
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: widget.content));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l.subtitleCopied),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              trackVisibility: true,
              scrollbarOrientation: ScrollbarOrientation.right,
              child: SingleChildScrollView(
                controller: _scrollController,
                primary: false,
                child: SizedBox(
                  width: constraints.maxWidth,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 28, 24),
                    child: SelectableText(
                      widget.content,
                      style: TextStyle(
                        color: c.text2,
                        fontFamily: 'monospace',
                        fontSize: 12,
                        height: 1.55,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// =================================================
// helpers
// =================================================

String _fmtBytes(int n) {
  const units = ['B', 'KB', 'MB', 'GB'];
  double v = n.toDouble();
  int i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(v < 10 && i > 0 ? 1 : 0)} ${units[i]}';
}

/// ms → HH:MM:SS 或 MM:SS
String _formatDuration(int ms) {
  if (ms <= 0) return '';
  final total = ms ~/ 1000;
  final hh = total ~/ 3600;
  final mm = (total % 3600) ~/ 60;
  final ss = total % 60;
  String pad(int n) => n.toString().padLeft(2, '0');
  return hh > 0 ? '$hh:${pad(mm)}:${pad(ss)}' : '${pad(mm)}:${pad(ss)}';
}

/// 从字幕内容里 extract 最大时间戳作为时长 · 兼容 srt/vtt/ass/ssa
int _extractMaxDurationMs(String content, String? ext) {
  if (content.isEmpty) return 0;
  int maxMs = 0;

  // srt / vtt: HH:MM:SS,mmm  或 HH:MM:SS.mmm
  final hms = RegExp(r'(\d{1,3}):(\d{2}):(\d{2})[.,](\d{1,3})');
  for (final m in hms.allMatches(content)) {
    final h = int.parse(m.group(1)!);
    final mn = int.parse(m.group(2)!);
    final s = int.parse(m.group(3)!);
    final fracStr = m.group(4)!.padRight(3, '0').substring(0, 3);
    final f = int.parse(fracStr);
    final ms = h * 3600000 + mn * 60000 + s * 1000 + f;
    if (ms > maxMs) maxMs = ms;
  }

  // ass / ssa: H:MM:SS.cc (百分秒)
  final extLow = (ext ?? '').toLowerCase();
  if (extLow == 'ass' || extLow == 'ssa' || content.contains('Dialogue:')) {
    final ass = RegExp(r'(\d{1,3}):(\d{2}):(\d{2})\.(\d{2})');
    for (final m in ass.allMatches(content)) {
      final h = int.parse(m.group(1)!);
      final mn = int.parse(m.group(2)!);
      final s = int.parse(m.group(3)!);
      final cs = int.parse(m.group(4)!);
      final ms = h * 3600000 + mn * 60000 + s * 1000 + cs * 10;
      if (ms > maxMs) maxMs = ms;
    }
  }
  return maxMs;
}
