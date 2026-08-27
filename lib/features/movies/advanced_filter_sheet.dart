import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/resource.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/glass.dart';
import '../movie_detail/entity_picker_sheet.dart';
import '../resources/resources_providers.dart';
import '../resources/resources_repository.dart';
import 'movie_filter.dart';

/// 高级筛选 bottom sheet · 对齐 frontend_new AdvancedSearchModal
class AdvancedFilterSheet extends ConsumerStatefulWidget {
  const AdvancedFilterSheet({super.key, required this.initial});
  final MovieFilter initial;

  static Future<MovieFilter?> show(
    BuildContext context, {
    required MovieFilter initial,
  }) {
    return showGlassSheet<MovieFilter>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AdvancedFilterSheet(initial: initial),
    );
  }

  @override
  ConsumerState<AdvancedFilterSheet> createState() =>
      _AdvancedFilterSheetState();
}

enum _SetMode { include, exclude }

class _AdvancedFilterSheetState extends ConsumerState<AdvancedFilterSheet> {
  late _SetMode _tagMode;
  late _SetMode _genreMode;
  late Set<int> _tagIds;
  late Set<int> _genreIds;
  late Set<int> _seriesIds;
  late TextEditingController _yearFromCtl;
  late TextEditingController _yearToCtl;
  int? _ratingFrom;
  int? _ratingTo;

  /// '' / 'include' / 'exclude'
  late String _subtitleMode;

  /// '' / standard / crack / subtitle / subtitle_crack
  late String _fileFilterMode;

  @override
  void initState() {
    super.initState();
    final f = widget.initial;
    _tagMode = f.excludeTagIds.isNotEmpty ? _SetMode.exclude : _SetMode.include;
    _genreMode = f.excludeGenreIds.isNotEmpty
        ? _SetMode.exclude
        : _SetMode.include;
    _tagIds = {
      ...f.tagIds,
      if (_tagMode == _SetMode.exclude) ...f.excludeTagIds,
    };
    _genreIds = {
      ...f.genreIds,
      if (_genreMode == _SetMode.exclude) ...f.excludeGenreIds,
    };
    _seriesIds = {...f.seriesIds};
    _yearFromCtl = TextEditingController(text: f.yearFrom?.toString() ?? '');
    _yearToCtl = TextEditingController(text: f.yearTo?.toString() ?? '');
    _ratingFrom = f.ratingFrom;
    _ratingTo = f.ratingTo;
    if (f.hasExternalSubtitle == true) {
      _subtitleMode = 'include';
    } else if (f.excludeHasExternalSubtitle == true) {
      _subtitleMode = 'exclude';
    } else {
      _subtitleMode = '';
    }
    _fileFilterMode = f.fileFilterMode ?? '';
  }

  @override
  void dispose() {
    _yearFromCtl.dispose();
    _yearToCtl.dispose();
    super.dispose();
  }

  bool get _yearError {
    final from = int.tryParse(_yearFromCtl.text.trim());
    final to = int.tryParse(_yearToCtl.text.trim());
    return from != null && to != null && from > to;
  }

  void _onReset() {
    setState(() {
      _tagMode = _SetMode.include;
      _genreMode = _SetMode.include;
      _tagIds.clear();
      _genreIds.clear();
      _seriesIds.clear();
      _yearFromCtl.clear();
      _yearToCtl.clear();
      _ratingFrom = null;
      _ratingTo = null;
      _subtitleMode = '';
      _fileFilterMode = '';
    });
  }

  void _onApply() {
    if (_yearError) return;
    final yearFrom = int.tryParse(_yearFromCtl.text.trim());
    final yearTo = int.tryParse(_yearToCtl.text.trim());
    final tagInc = _tagMode == _SetMode.include ? _tagIds.toList() : <int>[];
    final tagExc = _tagMode == _SetMode.exclude ? _tagIds.toList() : <int>[];
    final genreInc = _genreMode == _SetMode.include
        ? _genreIds.toList()
        : <int>[];
    final genreExc = _genreMode == _SetMode.exclude
        ? _genreIds.toList()
        : <int>[];
    final next = widget.initial.copyWith(
      tagIds: tagInc,
      excludeTagIds: tagExc,
      genreIds: genreInc,
      excludeGenreIds: genreExc,
      seriesIds: _seriesIds.toList(),
      yearFrom: yearFrom,
      yearTo: yearTo,
      clearYearFrom: yearFrom == null,
      clearYearTo: yearTo == null,
      ratingFrom: _ratingFrom,
      ratingTo: _ratingTo,
      clearRatingFrom: _ratingFrom == null,
      clearRatingTo: _ratingTo == null,
      hasExternalSubtitle: _subtitleMode == 'include' ? true : null,
      clearHasExternalSubtitle: _subtitleMode != 'include',
      excludeHasExternalSubtitle: _subtitleMode == 'exclude' ? true : null,
      clearExcludeHasExternalSubtitle: _subtitleMode != 'exclude',
      fileFilterMode: _fileFilterMode.isEmpty ? null : _fileFilterMode,
      clearFileFilterMode: _fileFilterMode.isEmpty,
    );
    Navigator.of(context).pop(next);
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final mq = MediaQuery.of(context);
    return SizedBox(
      height: mq.size.height * 0.9,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // 头部
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 6, 22, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('高级筛选', style: AppText.sectionTitle(context)),
                        const SizedBox(height: 2),
                        Text(
                          '按标签、分类、系列、年份评分和文件属性组合筛选',
                          style: AppText.meta(context),
                        ),
                      ],
                    ),
                  ),
                  TextButton(onPressed: _onReset, child: const Text('重置')),
                ],
              ),
            ),
            const Divider(height: 1),
            // 内容
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
                children: [
                  _SectionCard(
                    title: '标签',
                    trailing: _ModeToggle(
                      mode: _tagMode,
                      onChanged: (m) => setState(() => _tagMode = m),
                    ),
                    child: _ResourceMultiSelect(
                      kind: ResourceKind.tag,
                      selected: _tagIds,
                      onChanged: (s) => setState(() => _tagIds = s),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: '分类',
                    trailing: _ModeToggle(
                      mode: _genreMode,
                      onChanged: (m) => setState(() => _genreMode = m),
                    ),
                    child: _ResourceMultiSelect(
                      kind: ResourceKind.genre,
                      selected: _genreIds,
                      onChanged: (s) => setState(() => _genreIds = s),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: '系列',
                    child: _ResourceMultiSelect(
                      kind: ResourceKind.series,
                      selected: _seriesIds,
                      onChanged: (s) => setState(() => _seriesIds = s),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: '年份与评分',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('年份范围', style: AppText.meta(context)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: _NumberField(
                                controller: _yearFromCtl,
                                hint: '起始年份',
                                icon: Icons.calendar_today_outlined,
                                hasError: _yearError,
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _NumberField(
                                controller: _yearToCtl,
                                hint: '结束年份',
                                icon: Icons.calendar_today_outlined,
                                hasError: _yearError,
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                        if (_yearError) ...[
                          const SizedBox(height: 6),
                          Text(
                            '起始年份不能大于结束年份',
                            style: TextStyle(
                              color: c.danger,
                              fontFamily: 'Inter',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        Text('评分范围', style: AppText.meta(context)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: _DropdownField<int?>(
                                value: _ratingFrom,
                                hint: '最低评分',
                                items: <DropdownMenuItem<int?>>[
                                  const DropdownMenuItem<int?>(
                                    value: null,
                                    child: Text('最低评分'),
                                  ),
                                  for (var i = 1; i <= 9; i++)
                                    DropdownMenuItem<int?>(
                                      value: i,
                                      child: Text('$i 分以上'),
                                    ),
                                ],
                                onChanged: (v) =>
                                    setState(() => _ratingFrom = v),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _DropdownField<int?>(
                                value: _ratingTo,
                                hint: '最高评分',
                                items: <DropdownMenuItem<int?>>[
                                  const DropdownMenuItem<int?>(
                                    value: null,
                                    child: Text('最高评分'),
                                  ),
                                  for (var i = 10; i >= 2; i--)
                                    DropdownMenuItem<int?>(
                                      value: i,
                                      child: Text('$i 分以下'),
                                    ),
                                ],
                                onChanged: (v) => setState(() => _ratingTo = v),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: '字幕与文件',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('外挂字幕', style: AppText.meta(context)),
                        const SizedBox(height: 6),
                        _DropdownField<String>(
                          value: _subtitleMode,
                          hint: '不限',
                          items: const [
                            DropdownMenuItem(value: '', child: Text('不限')),
                            DropdownMenuItem(
                              value: 'include',
                              child: Text('包含外挂字幕'),
                            ),
                            DropdownMenuItem(
                              value: 'exclude',
                              child: Text('排除外挂字幕'),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _subtitleMode = v ?? ''),
                        ),
                        const SizedBox(height: 14),
                        Text('文件过滤器', style: AppText.meta(context)),
                        const SizedBox(height: 6),
                        _DropdownField<String>(
                          value: _fileFilterMode,
                          hint: '不限',
                          items: const [
                            DropdownMenuItem(value: '', child: Text('不限')),
                            DropdownMenuItem(
                              value: 'standard',
                              child: Text('仅限标准'),
                            ),
                            DropdownMenuItem(
                              value: 'crack',
                              child: Text('仅限破解'),
                            ),
                            DropdownMenuItem(
                              value: 'subtitle',
                              child: Text('仅限中字'),
                            ),
                            DropdownMenuItem(
                              value: 'subtitle_crack',
                              child: Text('仅限中字破解'),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _fileFilterMode = v ?? ''),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            // 底部按钮
            Container(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 10),
              decoration: BoxDecoration(
                color: c.bg,
                border: Border(top: BorderSide(color: c.divider)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _yearError ? null : _onApply,
                      icon: const Icon(Icons.filter_alt, size: 16),
                      label: const Text('应用筛选'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.trailing});
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: c.text,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.mode, required this.onChanged});
  final _SetMode mode;
  final ValueChanged<_SetMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    Widget btn(String label, _SetMode m) {
      final active = mode == m;
      return GestureDetector(
        onTap: () => onChanged(m),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: active
                ? c.accent.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? c.accent : c.muted,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.chipBg,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: c.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [btn('包含', _SetMode.include), btn('排除', _SetMode.exclude)],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.hint,
    required this.hasError,
    required this.onChanged,
    this.icon,
  });
  final TextEditingController controller;
  final String hint;
  final bool hasError;
  final ValueChanged<String> onChanged;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: c.muted),
        prefixIcon: icon == null ? null : Icon(icon),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: hasError ? c.danger : c.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: hasError ? c.danger : c.cardBorder),
        ),
      ),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });
  final T? value;
  final String hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return InputDecorator(
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: c.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: c.cardBorder),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          hint: Text(hint, style: TextStyle(color: c.muted)),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _ResourceMultiSelect extends ConsumerStatefulWidget {
  const _ResourceMultiSelect({
    required this.kind,
    required this.selected,
    required this.onChanged,
  });
  final ResourceKind kind;
  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;

  @override
  ConsumerState<_ResourceMultiSelect> createState() =>
      _ResourceMultiSelectState();
}

class _ResourceMultiSelectState extends ConsumerState<_ResourceMultiSelect> {
  bool _loading = false;
  String? _error;
  final Map<int, String> _names = {};

  @override
  void initState() {
    super.initState();
    _loadSelectedNames();
  }

  @override
  void didUpdateWidget(covariant _ResourceMultiSelect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kind != widget.kind ||
        oldWidget.selected != widget.selected) {
      _loadSelectedNames();
    }
  }

  Future<void> _loadSelectedNames() async {
    if (widget.selected.isEmpty) return;
    setState(() => _loading = true);
    try {
      final repository = ref.read(resourcesRepositoryProvider);
      final items = await Future.wait(
        widget.selected.take(100).map((id) => repository.get(widget.kind, id)),
      );
      if (!mounted) return;
      setState(() {
        for (final item in items) {
          _names[item.id] = item.name;
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openPicker() async {
    final kind = switch (widget.kind) {
      ResourceKind.genre => EntityPickerKind.genre,
      ResourceKind.tag => EntityPickerKind.tag,
      ResourceKind.series => EntityPickerKind.series,
    };
    final updated = await EntityPickerSheet.pickMulti(
      context: context,
      kind: kind,
      selected: widget.selected.toList(),
      selectedNames: _names,
    );
    if (updated != null) {
      _names.addAll(updated.names);
      widget.onChanged(updated.ids.toSet());
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    if (_loading) {
      return SizedBox(
        height: 40,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: c.muted),
          ),
        ),
      );
    }
    if (_error != null) {
      return Text(
        '加载失败: $_error',
        style: TextStyle(color: c.danger, fontSize: 12),
      );
    }
    final selectedItems = widget.selected
        .map((id) => ResourceItem(id: id, name: _names[id] ?? '#$id'))
        .toList();
    return GestureDetector(
      onTap: _openPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: c.chipBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.cardBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: selectedItems.isEmpty
                  ? Text(
                      '选择${widget.kind.label}...',
                      style: TextStyle(color: c.muted),
                    )
                  : Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final r in selectedItems.take(3))
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: c.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              r.name,
                              style: TextStyle(
                                color: c.accent,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w700,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                        if (selectedItems.length > 3)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: c.chipBg,
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(color: c.cardBorder),
                            ),
                            child: Text(
                              '+${selectedItems.length - 3}',
                              style: TextStyle(
                                color: c.muted,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w700,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
            Icon(Icons.expand_more, color: c.muted, size: 18),
          ],
        ),
      ),
    );
  }
}
