import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/api/dio_factory.dart';
import 'package:omm/core/models/resource.dart';
import 'package:omm/core/platform/app_haptics.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/shared/glass.dart';
import 'package:omm/shared/sheet_controls.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
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
        SnackBar(
          content: Text(
            AppL10n.of(
              context,
            ).resourceMergeFailed(toApiException(error).message),
          ),
        ),
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final kindLabel = widget.kind.label(l);
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
            title: l.resourceMergeTitle(kindLabel),
            subtitle: l.resourceMergeSubtitle(widget.items.length, kindLabel),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 14),
          Text(l.resourceMergeKeep(kindLabel), style: AppText.eyebrow(context)),
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
                    l.resourceMovieCountWithName(item.name, item.movieCount),
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
              label: Text(_saving ? l.merging : l.confirmMerge),
              style: sheetPrimaryButtonStyle(context),
            ),
          ),
        ],
      ),
    );
  }
}
