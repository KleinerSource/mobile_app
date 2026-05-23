import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/dio_factory.dart';
import '../../core/models/movie.dart';
import '../../core/platform/app_theme.dart';
import '../movies/movies_providers.dart';

/// 从 DBO 接口拉元数据 · 弹出 diff sheet 让用户挑选要应用的字段
///
/// 流程:
/// 1. 显示 loading 调 getDbonlineMetadata
/// 2. 把 DBO 数据 vs 当前影片对比,生成可选 diff 项
/// 3. 用户勾选要应用的字段 → updateMovie(local) → refresh detail
class DboDiffSheet extends ConsumerStatefulWidget {
  const DboDiffSheet({super.key, required this.movie});
  final MovieDetail movie;

  static Future<void> show(BuildContext context, MovieDetail movie) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: appColors(context).bg,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DboDiffSheet(movie: movie),
    );
  }

  @override
  ConsumerState<DboDiffSheet> createState() => _DboDiffSheetState();
}

class _DboDiffItem {
  _DboDiffItem({
    required this.field,
    required this.label,
    required this.localValue,
    required this.dboValue,
  });
  final String field;
  final String label;
  final String? localValue;
  final dynamic dboValue;
  bool selected = false;
}

class _DboDiffSheetState extends ConsumerState<DboDiffSheet> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<_DboDiffItem> _items = const [];
  Map<String, dynamic>? _meta;

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
      final data = await ref
          .read(moviesRepositoryProvider)
          .getDbonlineMetadata(widget.movie.id);
      if (!mounted) return;
      _meta = data;
      _items = _buildDiff(widget.movie, data);
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = toApiException(e).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 简化 diff: 仅对比顶层标量字段
  /// frontend 也对系列/分类/演员做关联同步, 这里先不做以避免大量代码
  List<_DboDiffItem> _buildDiff(MovieDetail m, Map<String, dynamic> dbo) {
    final res = <_DboDiffItem>[];
    void check(String field, String label, String? local, dynamic remote) {
      if (remote == null) return;
      final localStr = local?.trim() ?? '';
      final remoteStr = remote.toString().trim();
      if (remoteStr.isEmpty || remoteStr == localStr) return;
      res.add(_DboDiffItem(
        field: field,
        label: label,
        localValue: localStr.isEmpty ? null : localStr,
        dboValue: remote,
      ));
    }

    check('title', '标题', m.title, dbo['title']);
    check('original_title', '原标题', m.originalTitle, dbo['original_title']);
    check('plot', '剧情', m.plot, dbo['plot']);
    check('outline', '简介', m.outline, dbo['outline']);
    check('country', '产地', m.country, dbo['country']);
    check('rating', '评分', m.rating?.toString(), dbo['rating']);
    check('year', '年份', m.year?.toString(), dbo['year']);
    check('runtime', '时长', m.runtime?.toString(), dbo['runtime']);
    check('num', '番号', m.num, dbo['num']);
    check('trailer', '预告片', m.trailer, dbo['trailer']);
    return res;
  }

  bool get _anySelected => _items.any((i) => i.selected);

  Future<void> _apply() async {
    final selected = _items.where((i) => i.selected).toList();
    if (selected.isEmpty) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final payload = <String, dynamic>{};
      for (final s in selected) {
        if (s.field == 'rating') {
          final v = double.tryParse(s.dboValue.toString());
          if (v != null) payload['rating'] = v;
        } else if (s.field == 'year' || s.field == 'runtime') {
          final v = int.tryParse(s.dboValue.toString());
          if (v != null) payload[s.field] = v;
        } else {
          payload[s.field] = s.dboValue.toString();
        }
      }
      await ref
          .read(moviesRepositoryProvider)
          .updateMovie(widget.movie.id, payload);
      // ignore: unused_result
      ref.refresh(movieDetailProvider(widget.movie.id));
      messenger.showSnackBar(SnackBar(
        content: Text('已应用 ${selected.length} 个字段'),
        duration: const Duration(seconds: 1),
      ));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('应用失败: ${toApiException(e).message}')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _selectAll(bool v) {
    setState(() {
      for (final it in _items) {
        it.selected = v;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final mq = MediaQuery.of(context);
    final dboTitle = _meta?['title']?.toString() ?? '';
    final dboCode = _meta?['num']?.toString() ?? _meta?['code']?.toString() ?? '';

    return SizedBox(
      height: mq.size.height * 0.85,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // ===== 头部 =====
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 6, 22, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('DBO 元数据', style: AppText.sectionTitle(context)),
                        const SizedBox(height: 2),
                        if (dboTitle.isNotEmpty || dboCode.isNotEmpty)
                          Text(
                            [
                              if (dboCode.isNotEmpty) dboCode,
                              if (dboTitle.isNotEmpty) dboTitle
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.meta(context),
                          ),
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
            // ===== 主体 =====
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(22),
                            child: Text(_error!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: c.danger,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w600)),
                          ),
                        )
                      : _items.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(36),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle_outline,
                                        size: 36, color: c.muted),
                                    const SizedBox(height: 10),
                                    Text('本地元数据已是最新',
                                        style: AppText.body(context)
                                            .copyWith(
                                                fontWeight:
                                                    FontWeight.w700)),
                                    const SizedBox(height: 4),
                                    Text('没有可覆盖的字段',
                                        style: AppText.meta(context)),
                                  ],
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 22, vertical: 4),
                              itemCount: _items.length,
                              separatorBuilder: (_, __) =>
                                  Divider(height: 1, color: c.divider),
                              itemBuilder: (ctx, i) {
                                final item = _items[i];
                                return InkWell(
                                  onTap: () => setState(
                                      () => item.selected = !item.selected),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        AnimatedContainer(
                                          duration: const Duration(
                                              milliseconds: 150),
                                          width: 22,
                                          height: 22,
                                          margin:
                                              const EdgeInsets.only(top: 2),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: item.selected
                                                ? c.accent
                                                : Colors.transparent,
                                            border: Border.all(
                                              color: item.selected
                                                  ? c.accent
                                                  : c.muted2,
                                              width: 1.5,
                                            ),
                                          ),
                                          child: item.selected
                                              ? const Icon(Icons.check,
                                                  color: Colors.white,
                                                  size: 14)
                                              : null,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(item.label,
                                                  style: TextStyle(
                                                    color: c.text,
                                                    fontFamily: 'Inter',
                                                    fontWeight:
                                                        FontWeight.w700,
                                                    fontSize: 13.5,
                                                  )),
                                              const SizedBox(height: 4),
                                              if (item.localValue != null)
                                                Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .start,
                                                  children: [
                                                    Text('当前:',
                                                        style: AppText.meta(
                                                            context)),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Text(
                                                        item.localValue!,
                                                        maxLines: 2,
                                                        overflow:
                                                            TextOverflow
                                                                .ellipsis,
                                                        style: TextStyle(
                                                          color:
                                                              c.muted,
                                                          fontFamily:
                                                              'Inter',
                                                          fontSize: 12,
                                                          decoration:
                                                              TextDecoration
                                                                  .lineThrough,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              const SizedBox(height: 3),
                                              Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Icon(
                                                      Icons
                                                          .arrow_forward,
                                                      size: 12,
                                                      color: c.accent),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      item.dboValue
                                                          .toString(),
                                                      maxLines: 3,
                                                      overflow:
                                                          TextOverflow
                                                              .ellipsis,
                                                      style: TextStyle(
                                                        color: c.accent,
                                                        fontFamily: 'Inter',
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
            // ===== 底部 actions =====
            if (!_loading && _items.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 8),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () => _selectAll(!_anySelected),
                      child: Text(
                        _anySelected ? '清空' : '全选',
                        style: TextStyle(
                          color: c.muted,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: (_anySelected && !_saving) ? _apply : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: c.accent,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              _anySelected
                                  ? '应用 (${_items.where((i) => i.selected).length})'
                                  : '请选择字段',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
