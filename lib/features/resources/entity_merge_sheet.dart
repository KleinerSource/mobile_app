import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/dio_factory.dart';
import '../../core/models/resource.dart';
import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/glass.dart';
import '../../shared/sheet_controls.dart';
import 'resources_providers.dart';
import 'resources_repository.dart';

/// 资源批量合并：从当前已选资源中选择保留的目标名称。
class EntityMergeSheet extends ConsumerStatefulWidget {
  const EntityMergeSheet({super.key, required this.kind, required this.items});

  final ResourceKind kind;
  final List<ResourceItem> items;

  static Future<bool?> show(
    BuildContext context,
    ResourceKind kind,
    List<ResourceItem> items,
  ) {
    return showGlassSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => EntityMergeSheet(kind: kind, items: items),
    );
  }

  @override
  ConsumerState<EntityMergeSheet> createState() => _EntityMergeSheetState();
}

class _EntityMergeSheetState extends ConsumerState<EntityMergeSheet> {
  late int _targetId;
  bool _saving = false;

  ResourceItem get _target => widget.items.firstWhere(
    (item) => item.id == _targetId,
    orElse: () => widget.items.first,
  );

  @override
  void initState() {
    super.initState();
    _targetId = widget.items.first.id;
  }

  Future<void> _submit() async {
    if (_saving || widget.items.length < 2) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(resourcesRepositoryProvider)
          .merge(
            widget.kind,
            sourceIds: widget.items.map((item) => item.id).toList(),
            targetName: _target.name,
          );
      if (!mounted) return;
      AppHaptics.medium();
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('合并失败: ${toApiException(error).message}')),
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        4,
        22,
        MediaQuery.of(context).viewInsets.bottom + 22,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SheetHeader(
            icon: Icons.merge_rounded,
            title: '批量合并${widget.kind.label}',
            subtitle:
                '将 ${widget.items.length} 个${widget.kind.label}合并为一个，影片关联会转移到保留项。',
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 14),
          Text('保留的${widget.kind.label}', style: AppText.eyebrow(context)),
          const SizedBox(height: 6),
          DropdownButtonFormField<int>(
            initialValue: _targetId,
            isExpanded: true,
            decoration: sheetInputDecoration(context),
            items: [
              for (final item in widget.items)
                DropdownMenuItem<int>(
                  value: item.id,
                  child: Text(
                    '${item.name} · ${item.movieCount} 部影片',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: _saving
                ? null
                : (value) {
                    if (value != null) setState(() => _targetId = value);
                  },
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.merge_rounded),
              label: Text(_saving ? '合并中' : '确认合并'),
              style: sheetPrimaryButtonStyle(context),
            ),
          ),
        ],
      ),
    );
  }
}
