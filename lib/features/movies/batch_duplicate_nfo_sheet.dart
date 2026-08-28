import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/dio_factory.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/glass.dart';
import '../../shared/sheet_controls.dart';
import 'movies_providers.dart';

/// 重复 NFO 比较 sheet · 标量字段选择来源，列表字段保留各自
class BatchDuplicateNfoCompareSheet extends ConsumerStatefulWidget {
  const BatchDuplicateNfoCompareSheet({super.key, required this.movieIds});
  final List<int> movieIds;

  static Future<bool?> show(BuildContext context, List<int> ids) {
    return showGlassSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BatchDuplicateNfoCompareSheet(movieIds: ids),
    );
  }

  @override
  ConsumerState<BatchDuplicateNfoCompareSheet> createState() =>
      _BatchDuplicateNfoCompareSheetState();
}

class _BatchDuplicateNfoCompareSheetState
    extends ConsumerState<BatchDuplicateNfoCompareSheet> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;
  List<Map<String, dynamic>> _scalarFields = const [];
  List<Map<String, dynamic>> _movies = const [];
  // field -> selected value (raw, 可能是 String / num / null)
  final Map<String, dynamic> _selections = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<Map<String, dynamic>> _visibleScalarFields(
    List<Map<String, dynamic>> fields,
  ) {
    final visible = <Map<String, dynamic>>[];
    for (final field in fields) {
      final fieldName = (field['field'] ?? '').toString();
      final rawOptions = field['options'];
      final options = rawOptions is List
          ? rawOptions
                .whereType<Map>()
                .map((option) => Map<String, dynamic>.from(option))
                .toList()
          : const <Map<String, dynamic>>[];
      final seenValues = <String>{};
      final uniqueOptions = <Map<String, dynamic>>[];
      for (final option in options) {
        if (seenValues.add(_scalarValueKey(fieldName, option['value']))) {
          uniqueOptions.add(option);
        }
      }
      if (uniqueOptions.length <= 1) continue;

      final normalizedField = Map<String, dynamic>.from(field);
      normalizedField['options'] = uniqueOptions;
      visible.add(normalizedField);
    }
    return visible;
  }

  Future<void> _load() async {
    try {
      final data = await ref
          .read(moviesRepositoryProvider)
          .compareDuplicateNfo(widget.movieIds);
      if (!mounted) return;
      final rawScalarFields =
          (data['scalar_fields'] as List?)
              ?.whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          const <Map<String, dynamic>>[];
      final scalarFields = _visibleScalarFields(rawScalarFields);
      final movies =
          (data['movies'] as List?)
              ?.whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          const <Map<String, dynamic>>[];

      // 初始化选择: 取每个 field 第一个非空 option
      for (final f in scalarFields) {
        final fieldName = (f['field'] ?? '').toString();
        final options = (f['options'] as List?) ?? const [];
        dynamic chosen;
        for (final opt in options.whereType<Map>()) {
          final v = opt['value'];
          if (_scalarValueKey(fieldName, v).isNotEmpty) {
            chosen = v;
            break;
          }
        }
        chosen ??= options.isNotEmpty ? (options.first as Map)['value'] : null;
        _selections[fieldName] = chosen;
      }

      setState(() {
        _data = data;
        _scalarFields = scalarFields;
        _movies = movies;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = toApiException(e).message;
        _loading = false;
      });
    }
  }

  Future<void> _apply() async {
    if (_saving || _data == null) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      // 保留各影片自己的 list 字段 (tags / genres / actors)
      final movieLists = <Map<String, dynamic>>[];
      final listFields = (_data!['list_fields'] as List?) ?? const [];
      for (final m in _movies) {
        final id = m['id'];
        final entry = <String, dynamic>{'movie_id': id};
        for (final lf in listFields.whereType<Map>()) {
          final fieldName = (lf['field'] ?? '').toString();
          final movieValues = (lf['movie_values'] as List?) ?? const [];
          final mine = movieValues.whereType<Map>().firstWhere(
            (mv) => mv['movie_id'] == id,
            orElse: () => {},
          );
          final values = (mine['values'] as List?) ?? const [];
          if (fieldName == 'actors') {
            entry['actors'] = values.whereType<Map>().map((v) {
              return {
                'name': (v['name'] ?? '').toString(),
                'actor_type': (v['actor_type'] ?? '').toString(),
              };
            }).toList();
          } else {
            entry[fieldName] = values
                .whereType<Map>()
                .map((v) {
                  return (v['name'] ?? '').toString();
                })
                .where((s) => s.isNotEmpty)
                .toList();
          }
        }
        movieLists.add(entry);
      }

      await ref.read(moviesRepositoryProvider).applyDuplicateNfo({
        'movie_ids': widget.movieIds,
        'scalars': _selections,
        'movie_lists': movieLists,
      });
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('NFO 已同步')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('应用失败: ${toApiException(e).message}')),
      );
      setState(() => _saving = false);
    }
  }

  String _movieLabel(int id) {
    final m = _movies.firstWhere((x) => x['id'] == id, orElse: () => const {});
    final title = (m['title'] ?? '').toString();
    return title.isEmpty ? '影片 $id' : title;
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SheetHeader(
          icon: Icons.compare_arrows_outlined,
          title: '比较重复 NFO',
          subtitle: '为每个字段选择同步来源',
        ),
        Flexible(
          fit: FlexFit.loose,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Text(_error!, style: TextStyle(color: c.danger)),
                  ),
                )
              : _scalarFields.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Text(
                      '影片标题、描述、概要、评分均一致, 无需选择',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: c.muted),
                    ),
                  ),
                )
              : ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
                  children: [
                    for (final f in _scalarFields)
                      _FieldCard(
                        field: f,
                        selectedValue: _selections[f['field']],
                        onSelect: (v) =>
                            setState(() => _selections[f['field']] = v),
                        movieLabel: _movieLabel,
                      ),
                    const SizedBox(height: 20),
                  ],
                ),
        ),
        SheetActionBar(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving
                      ? null
                      : () => Navigator.of(context).pop(false),
                  style: sheetSecondaryButtonStyle(context),
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: (_saving || _loading || _error != null)
                      ? null
                      : _apply,
                  icon: _saving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check, size: 18),
                  style: sheetPrimaryButtonStyle(context),
                  label: Text(_saving ? '应用中...' : '应用同步'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FieldCard extends StatelessWidget {
  const _FieldCard({
    required this.field,
    required this.selectedValue,
    required this.onSelect,
    required this.movieLabel,
  });
  final Map<String, dynamic> field;
  final dynamic selectedValue;
  final ValueChanged<dynamic> onSelect;
  final String Function(int) movieLabel;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final fieldName = (field['field'] ?? '').toString();
    final label = (field['label'] ?? field['field'] ?? '').toString();
    final options = (field['options'] as List?) ?? const [];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: c.text,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          for (final opt in options.whereType<Map>())
            _ScalarOption(
              option: Map<String, dynamic>.from(opt),
              selected: _valEquals(fieldName, selectedValue, opt['value']),
              onTap: () => onSelect(opt['value']),
              movieLabel: movieLabel,
            ),
        ],
      ),
    );
  }

  static bool _valEquals(String fieldName, dynamic a, dynamic b) {
    return _scalarValueKey(fieldName, a) == _scalarValueKey(fieldName, b);
  }
}

class _ScalarOption extends StatelessWidget {
  const _ScalarOption({
    required this.option,
    required this.selected,
    required this.onTap,
    required this.movieLabel,
  });
  final Map<String, dynamic> option;
  final bool selected;
  final VoidCallback onTap;
  final String Function(int) movieLabel;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final movieId = (option['movie_id'] as num?)?.toInt();
    final value = option['value'];
    final displayValue = value?.toString().trim() ?? '';
    final display = displayValue.isEmpty ? '(空)' : displayValue;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            color: selected ? c.accent.withValues(alpha: 0.12) : c.bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? c.accent.withValues(alpha: 0.5) : c.cardBorder,
              width: 1,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: selected ? c.accent : c.muted,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (movieId != null)
                          Text(
                            movieLabel(movieId),
                            style: TextStyle(
                              color: c.muted,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w700,
                              fontSize: 10.5,
                            ),
                          ),
                        const SizedBox(height: 3),
                        Text(
                          display,
                          style: TextStyle(
                            color: c.text,
                            fontFamily: 'Inter',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _numericScalarFields = {'rating', 'runtime', 'year', 'duration'};

String _scalarValueKey(String fieldName, dynamic value) {
  final text = (value?.toString() ?? '').replaceAll('\r\n', '\n').trim();
  if (text.isEmpty) return '';

  if (_numericScalarFields.contains(fieldName)) {
    final number = num.tryParse(text);
    if (number != null) return 'number:${number.toDouble()}';
  }
  return 'text:$text';
}
