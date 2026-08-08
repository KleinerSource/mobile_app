import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/dio_factory.dart';
import '../../core/models/movie.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/filter_chip.dart';
import '../movies/movies_providers.dart';
import '../translation/translation_providers.dart';
import 'entity_picker_sheet.dart';
import 'poster_crop_controller.dart';

/// 影片元数据编辑 bottom sheet (全功能)
/// - 字段: 标题 / 原标题 / 番号 / 年份 / 评分 / 时长 / 国家 / 简介
/// - 选择器: 系列 (单选) / 分类 / 标签 / 演员 (多选)
/// - 封面裁剪: 拖动 7:10 窗口 + 实时预览 + 保存时一并应用
class MovieEditorSheet extends ConsumerStatefulWidget {
  const MovieEditorSheet({super.key, required this.movie});
  final MovieDetail movie;

  static Future<bool?> show(BuildContext context, MovieDetail movie) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: appColors(context).bg,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => MovieEditorSheet(movie: movie),
    );
  }

  @override
  ConsumerState<MovieEditorSheet> createState() => _MovieEditorSheetState();
}

class _MovieEditorSheetState extends ConsumerState<MovieEditorSheet> {
  late final TextEditingController _title;
  late final TextEditingController _originalTitle;
  late final TextEditingController _num;
  late final TextEditingController _year;
  late final TextEditingController _rating;
  late final TextEditingController _runtime;
  late final TextEditingController _country;
  late final TextEditingController _plot;

  // 选择器状态 (id list/single)
  int? _seriesId;
  String? _seriesName;
  late List<({int id, String name})> _genres;
  late List<({int id, String name})> _tags;
  late List<({int id, String name})> _actors;

  // 封面裁剪 · 4 个水印快捷操作
  double _cropOffset = 1.0; // frontend_new 默认 1
  bool _cropDirty = false;
  bool _subtitle = false;
  bool _exsub = false;
  bool _crack = false;
  bool _uhd = false;

  bool get _anyFlagOn => _subtitle || _exsub || _crack || _uhd;

  bool _saving = false;
  String? _error;

  // 翻译中字段: title/country/plot
  final Set<String> _translating = {};
  bool _batchTranslating = false;

  @override
  void initState() {
    super.initState();
    final m = widget.movie;
    _title = TextEditingController(text: m.title);
    _originalTitle = TextEditingController(text: m.originalTitle ?? '');
    _num = TextEditingController(text: m.num ?? '');
    _year = TextEditingController(text: m.year?.toString() ?? '');
    _rating = TextEditingController(text: m.rating?.toString() ?? '');
    _runtime = TextEditingController(text: m.runtime?.toString() ?? '');
    _country = TextEditingController(text: m.country ?? '');
    _plot = TextEditingController(text: m.plot ?? '');

    _seriesId = m.series?.id;
    _seriesName = m.series?.name;
    _genres = m.genres.map((e) => (id: e.id, name: e.name)).toList();
    _tags = m.tags.map((e) => (id: e.id, name: e.name)).toList();
    _actors = m.actors.map((e) => (id: e.id, name: e.name)).toList();
  }

  @override
  void dispose() {
    _title.dispose();
    _originalTitle.dispose();
    _num.dispose();
    _year.dispose();
    _rating.dispose();
    _runtime.dispose();
    _country.dispose();
    _plot.dispose();
    super.dispose();
  }

  String? get _fanartUrl {
    final uuid = widget.movie.fanartUuid;
    if (uuid == null || uuid.isEmpty) return null;
    return ref.read(imageUrlBuilderProvider)(uuid);
  }

  Future<void> _save() async {
    final body = <String, dynamic>{
      'title': _title.text.trim(),
      'original_title': _originalTitle.text.trim(),
      'num': _num.text.trim(),
      'country': _country.text.trim(),
      'plot': _plot.text,
      'series_id': _seriesId,
      'genre_ids': _genres.map((e) => e.id).toList(),
      'tag_ids': _tags.map((e) => e.id).toList(),
      'actor_ids': _actors.map((e) => e.id).toList(),
    };
    final year = int.tryParse(_year.text.trim());
    if (year != null) body['year'] = year;
    final rating = double.tryParse(_rating.text.trim());
    if (rating != null) body['rating'] = rating;
    final runtime = int.tryParse(_runtime.text.trim());
    if (runtime != null) body['runtime'] = runtime;

    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repo = ref.read(moviesRepositoryProvider);
      await repo.updateMovie(widget.movie.id, body);
      // 应用裁剪 · 仅在有任意水印开关被勾选时
      if (_cropDirty && _fanartUrl != null && _anyFlagOn) {
        await repo.applyPosterCrop(
          widget.movie.id,
          cropOffset: _cropOffset,
          subtitle: _subtitle,
          exsub: _exsub,
          crack: _crack,
          uhd: _uhd,
        );
      }
      // 触发详情 provider 刷新
      // ignore: unused_result
      ref.refresh(movieDetailProvider(widget.movie.id));
      messenger.showSnackBar(const SnackBar(
        content: Text('已保存'),
        duration: Duration(seconds: 1),
      ));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _error = toApiException(e).message);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickSeries() async {
    final picked = await EntityPickerSheet.pickSingle(
      context: context,
      kind: EntityPickerKind.series,
      selected: _seriesId,
    );
    if (picked == null) return;
    if (picked == -1) {
      setState(() {
        _seriesId = null;
        _seriesName = null;
      });
    } else {
      // 用 entity picker 返回 id, 但我们没拿名字 — 临时存 id, 显示用 id (后续 detail refresh 会带名字回来)
      setState(() {
        _seriesId = picked;
        _seriesName = '#$picked';
      });
    }
  }

  Future<void> _pickMulti(EntityPickerKind kind) async {
    final current = switch (kind) {
      EntityPickerKind.genre => _genres,
      EntityPickerKind.tag => _tags,
      EntityPickerKind.actor => _actors,
      _ => <({int id, String name})>[],
    };
    final selected = current.map((e) => e.id).toList();
    final result = await EntityPickerSheet.pickMulti(
      context: context,
      kind: kind,
      selected: selected,
    );
    if (result == null) return;
    // 保留旧名字, 新增 id 用 '#id' 临时占位 (detail refresh 后会更新)
    final nameMap = {for (final e in current) e.id: e.name};
    final next = result
        .map((id) => (id: id, name: nameMap[id] ?? '#$id'))
        .toList();
    setState(() {
      switch (kind) {
        case EntityPickerKind.genre:
          _genres = next;
          break;
        case EntityPickerKind.tag:
          _tags = next;
          break;
        case EntityPickerKind.actor:
          _actors = next;
          break;
        case EntityPickerKind.series:
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 0,
        right: 0,
        top: 4,
        bottom: MediaQuery.of(context).viewInsets.bottom + 22,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              children: [
                IconButton(
                  tooltip: '返回',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _saving
                      ? null
                      : () => Navigator.of(context).maybePop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('编辑影片',
                      style: AppText.sectionTitle(context)),
                ),
                TextButton(
                  onPressed: _saving ? null : _save,
                  child: Text(
                    '保存',
                    style: TextStyle(
                      color: c.accent,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ===== 海报裁剪 + 快捷操作 =====
                  if (_fanartUrl != null) ...[
                    _label('封面水印 · 快捷操作'),
                    const SizedBox(height: 4),
                    _FlagsRow(
                      subtitle: _subtitle,
                      exsub: _exsub,
                      crack: _crack,
                      uhd: _uhd,
                      onChanged: ({sub, ex, ck, uh}) {
                        setState(() {
                          if (sub != null) _subtitle = sub;
                          if (ex != null) _exsub = ex;
                          if (ck != null) _crack = ck;
                          if (uh != null) _uhd = uh;
                          // 任一开启 → 标记裁剪 dirty
                          if (_anyFlagOn) _cropDirty = true;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _label('封面裁剪 (Fanart)'),
                    const SizedBox(height: 4),
                    PosterCropController(
                      movieId: widget.movie.id,
                      fanartUrl: _fanartUrl!,
                      cropOffset: _cropOffset,
                      subtitle: _subtitle,
                      exsub: _exsub,
                      crack: _crack,
                      uhd: _uhd,
                      enabled: _anyFlagOn,
                      onChanged: (v) {
                        setState(() {
                          _cropOffset = v;
                          _cropDirty = true;
                        });
                      },
                    ),
                    const SizedBox(height: 18),
                  ],

                  // ===== 文本字段 =====
                  _label('标题', trailing: _translateBtn('title')),
                  _input(_title),
                  const SizedBox(height: 14),
                  _label('原标题'),
                  _input(_originalTitle),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            _label('番号'),
                            _input(_num, mono: true),
                          ])),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            _label('国家', trailing: _translateBtn('country')),
                            _input(_country),
                          ])),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            _label('年份'),
                            _input(_year, mono: true, numeric: true),
                          ])),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            _label('评分'),
                            _input(_rating, mono: true, numeric: true),
                          ])),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            _label('时长 (min)'),
                            _input(_runtime, mono: true, numeric: true),
                          ])),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _label('简介', trailing: _translateBtn('plot')),
                  _input(_plot, maxLines: 6),
                  const SizedBox(height: 10),
                  // 批量翻译按钮
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: (_batchTranslating || _translating.isNotEmpty)
                          ? null
                          : _translateAll,
                      icon: _batchTranslating
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.translate_rounded, size: 16),
                      label: Text(_batchTranslating ? '批量翻译中' : '批量翻译'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: c.accent,
                        side: BorderSide(color: c.accent.withValues(alpha: 0.4)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // ===== 选择器 =====
                  _PickerSection(
                    title: '系列',
                    icon: Icons.collections_bookmark_outlined,
                    onTap: _pickSeries,
                    onClear: _seriesId != null
                        ? () => setState(() {
                              _seriesId = null;
                              _seriesName = null;
                            })
                        : null,
                    emptyHint: '点击选择系列',
                    children: _seriesId != null
                        ? [
                            HueChip(
                              label: _seriesName ?? '#$_seriesId',
                              hue: AppHues.sky,
                            ),
                          ]
                        : null,
                  ),
                  _PickerSection(
                    title: '分类',
                    icon: Icons.category_outlined,
                    onTap: () => _pickMulti(EntityPickerKind.genre),
                    emptyHint: '点击选择分类',
                    children: _genres.isEmpty
                        ? null
                        : [
                            for (var i = 0; i < _genres.length; i++)
                              HueChip(
                                label: _genres[i].name,
                                hue: AppHues
                                    .all[i % AppHues.all.length],
                              ),
                          ],
                  ),
                  _PickerSection(
                    title: '标签',
                    icon: Icons.tag,
                    onTap: () => _pickMulti(EntityPickerKind.tag),
                    emptyHint: '点击选择标签',
                    children: _tags.isEmpty
                        ? null
                        : [
                            for (var i = 0; i < _tags.length; i++)
                              HueChip(
                                label: '# ${_tags[i].name}',
                                hue: AppHues
                                    .all[(i + 2) % AppHues.all.length],
                              ),
                          ],
                  ),
                  _PickerSection(
                    title: '演员',
                    icon: Icons.person_outline,
                    onTap: () => _pickMulti(EntityPickerKind.actor),
                    emptyHint: '点击选择演员',
                    children: _actors.isEmpty
                        ? null
                        : [
                            for (var i = 0; i < _actors.length; i++)
                              HueChip(
                                label: _actors[i].name,
                                hue: AppHues
                                    .all[(i + 4) % AppHues.all.length],
                              ),
                          ],
                  ),

                  // ===== 错误/加载 =====
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: c.danger.withValues(alpha: 0.1),
                        border: Border.all(
                            color: c.danger.withValues(alpha: 0.4)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, size: 16, color: c.danger),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(_error!,
                                  style: TextStyle(
                                      color: c.danger,
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600))),
                        ],
                      ),
                    ),
                  ],
                  if (_saving) ...[
                    const SizedBox(height: 14),
                    const Center(child: CircularProgressIndicator()),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String label, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
              child: Text(label.toUpperCase(),
                  style: AppText.eyebrow(context))),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  // 字段映射: key → 后端 field_name
  static const _fieldTypeMap = {
    'title': 'movie_title',
    'country': 'movie_country',
    'plot': 'movie_plot',
  };

  TextEditingController _ctlOf(String key) {
    switch (key) {
      case 'title':
        return _title;
      case 'country':
        return _country;
      case 'plot':
        return _plot;
      default:
        throw StateError('unknown translate field: $key');
    }
  }

  Future<void> _translateField(String key, String label) async {
    if (_translating.contains(key) || _batchTranslating) return;
    final ctl = _ctlOf(key);
    final text = ctl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label 内容为空, 无需翻译')),
      );
      return;
    }
    setState(() => _translating.add(key));
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repo = ref.read(translationRepositoryProvider);
      final translated = await repo.translateText(text,
          fieldName: _fieldTypeMap[key] ?? key);
      if (!mounted) return;
      if (translated.isEmpty) {
        messenger.showSnackBar(
          SnackBar(content: Text('$label 翻译为空')),
        );
      } else {
        ctl.text = translated;
        messenger.showSnackBar(
          SnackBar(content: Text('$label 翻译成功')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('$label 翻译失败: ${toApiException(e).message}')),
      );
    } finally {
      if (mounted) setState(() => _translating.remove(key));
    }
  }

  Future<void> _translateAll() async {
    if (_batchTranslating || _translating.isNotEmpty) return;
    final fields = <String, String>{};
    for (final entry in _fieldTypeMap.entries) {
      final txt = _ctlOf(entry.key).text.trim();
      if (txt.isNotEmpty) fields[entry.value] = txt;
    }
    if (fields.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有可翻译的内容')),
      );
      return;
    }
    setState(() => _batchTranslating = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repo = ref.read(translationRepositoryProvider);
      final result = await repo.translateBatch(fields);
      if (!mounted) return;
      final inverse = {
        for (final e in _fieldTypeMap.entries) e.value: e.key,
      };
      var ok = 0;
      result.forEach((apiKey, translated) {
        final formKey = inverse[apiKey];
        if (formKey != null && translated.isNotEmpty) {
          _ctlOf(formKey).text = translated;
          ok++;
        }
      });
      setState(() {});
      messenger.showSnackBar(SnackBar(
        content:
            Text(ok > 0 ? '批量翻译: 成功 $ok / ${fields.length}' : '批量翻译未返回结果'),
      ));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('批量翻译失败: ${toApiException(e).message}')),
      );
    } finally {
      if (mounted) setState(() => _batchTranslating = false);
    }
  }

  /// 单字段翻译按钮
  Widget _translateBtn(String key) {
    final c = appColors(context);
    final loading = _translating.contains(key);
    final disabled = loading || _batchTranslating;
    final label = switch (key) {
      'title' => '标题',
      'country' => '国家',
      'plot' => '简介',
      _ => key,
    };
    return InkWell(
      onTap: disabled ? null : () => _translateField(key, label),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(Icons.translate_rounded, size: 13, color: c.accent),
            const SizedBox(width: 4),
            Text(
              loading ? '翻译中' : '翻译',
              style: TextStyle(
                color: disabled ? c.muted : c.accent,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _input(
    TextEditingController controller, {
    int maxLines = 1,
    bool mono = false,
    bool numeric = false,
  }) {
    final c = appColors(context);
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.cardBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: numeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : null,
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding:
              EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        style: TextStyle(
          color: c.text,
          fontFamily: mono ? 'monospace' : 'Inter',
          fontSize: mono ? 13 : 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// 选择器分组容器
class _PickerSection extends StatelessWidget {
  const _PickerSection({
    required this.title,
    required this.icon,
    required this.onTap,
    required this.children,
    required this.emptyHint,
    this.onClear,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final List<Widget>? children;
  final String emptyHint;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.cardBorder),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: c.muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: c.text,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (onClear != null)
                  IconButton(
                    icon: Icon(Icons.close, size: 16, color: c.muted),
                    onPressed: onClear,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                  ),
                Icon(Icons.chevron_right, size: 18, color: c.muted),
              ],
            ),
            const SizedBox(height: 8),
            if (children == null || children!.isEmpty)
              Text(emptyHint, style: AppText.meta(context))
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: children!,
              ),
          ],
        ),
      ),
    );
  }
}

/// 水印快捷操作横排 (字幕 / 外挂字幕 / 破解 / UHD)
class _FlagsRow extends StatelessWidget {
  const _FlagsRow({
    required this.subtitle,
    required this.exsub,
    required this.crack,
    required this.uhd,
    required this.onChanged,
  });

  final bool subtitle;
  final bool exsub;
  final bool crack;
  final bool uhd;
  final void Function({bool? sub, bool? ex, bool? ck, bool? uh}) onChanged;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('字幕', subtitle, (bool v) => onChanged(sub: v)),
      ('外挂字幕', exsub, (bool v) => onChanged(ex: v)),
      ('破解', crack, (bool v) => onChanged(ck: v)),
      ('UHD', uhd, (bool v) => onChanged(uh: v)),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (label, value, setter) in items)
          _FlagChip(label: label, value: value, onChanged: setter),
      ],
    );
  }
}

class _FlagChip extends StatelessWidget {
  const _FlagChip({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return InkWell(
      borderRadius: BorderRadius.circular(100),
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: value ? c.accent.withValues(alpha: 0.18) : c.chipBg,
          border: Border.all(
            color: value
                ? c.accent.withValues(alpha: 0.6)
                : Colors.transparent,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(
                value ? Icons.check_circle : Icons.circle_outlined,
                key: ValueKey(value),
                size: 14,
                color: value ? c.accent : c.muted2,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: value ? c.accent : c.text,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
