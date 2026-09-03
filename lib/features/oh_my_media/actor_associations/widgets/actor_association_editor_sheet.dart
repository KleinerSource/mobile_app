import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/api/dio_factory.dart';
import 'package:omm/core/models/mapping_rule.dart';
import 'package:omm/core/platform/app_haptics.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/shared/glass.dart';
import 'package:omm/shared/sheet_controls.dart';
import 'package:omm/features/oh_my_media/actor_associations/actor_associations_providers.dart';
import 'package:omm/features/oh_my_media/actor_associations/actor_associations_repository.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

enum ActorAssocEditMode { create, edit, append }

/// 演员关联编辑 sheet · 三种模式共用
/// - create: 标准名 + 别名 (新建)
/// - edit:  标准名(只读) + 别名 (替换原别名)
/// - append: 标准名(只读) + 新增别名 (合并到 original_values)
class ActorAssociationEditorSheet extends ConsumerStatefulWidget {
  const ActorAssociationEditorSheet({
    super.key,
    required this.mode,
    this.existing,
  });

  final ActorAssocEditMode mode;

  /// edit/append 模式需要传入
  final MappingRule? existing;

  static Future<bool?> show(
    BuildContext context, {
    required ActorAssocEditMode mode,
    MappingRule? existing,
  }) {
    return showGlassSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          ActorAssociationEditorSheet(mode: mode, existing: existing),
    );
  }

  @override
  ConsumerState<ActorAssociationEditorSheet> createState() =>
      _ActorAssociationEditorSheetState();
}

class _ActorAssociationEditorSheetState
    extends ConsumerState<ActorAssociationEditorSheet> {
  late final TextEditingController _mapped;
  late final TextEditingController _aliases;
  bool _saving = false;

  bool get _isCreate => widget.mode == ActorAssocEditMode.create;
  bool get _isEdit => widget.mode == ActorAssocEditMode.edit;
  bool get _isAppend => widget.mode == ActorAssocEditMode.append;

  String _title(AppL10n l) {
    switch (widget.mode) {
      case ActorAssocEditMode.create:
        return l.actorAssocEditorTitleCreate;
      case ActorAssocEditMode.edit:
        return l.actorAssocEditorTitleEdit;
      case ActorAssocEditMode.append:
        return l.actorAssocEditorTitleAppend;
    }
  }

  @override
  void initState() {
    super.initState();
    _mapped = TextEditingController(text: widget.existing?.mappedValue ?? '');
    final initialAliases = _isEdit
        ? (widget.existing?.originalValues ?? const []).join('\n')
        : '';
    _aliases = TextEditingController(text: initialAliases);
  }

  @override
  void dispose() {
    _mapped.dispose();
    _aliases.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final l = AppL10n.of(context);
    final title = _title(l);
    final mapped = _mapped.text.trim();
    if (mapped.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.actorAssocErrNameRequired)));
      return;
    }
    final inputAliases = ActorAssociationsRepository.parseAliases(
      _aliases.text,
      mapped,
    );

    if (_isAppend && inputAliases.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.actorAssocErrAliasRequired)));
      return;
    }
    if (_isCreate && inputAliases.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.actorAssocErrAtLeastOneAlias)));
      return;
    }

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repo = ref.read(actorAssociationsRepositoryProvider);
      if (_isCreate) {
        await repo.create(mappedValue: mapped, originalValues: inputAliases);
      } else if (_isEdit) {
        await repo.update(
          id: widget.existing!.id,
          mappedValue: mapped,
          originalValues: inputAliases,
        );
      } else {
        // append
        final merged = ActorAssociationsRepository.mergeAliases(
          widget.existing!.originalValues,
          inputAliases,
          mapped,
        );
        if (merged.length == widget.existing!.originalValues.length) {
          messenger.showSnackBar(
            SnackBar(content: Text(l.actorAssocNoNewAliases)),
          );
          setState(() => _saving = false);
          return;
        }
        await repo.update(
          id: widget.existing!.id,
          mappedValue: mapped,
          originalValues: merged,
        );
      }
      if (!mounted) return;
      AppHaptics.medium();
      messenger.showSnackBar(SnackBar(content: Text(l.actorAssocSaved(title))));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l.actorAssocSaveFailed(title, toApiException(e).message),
          ),
        ),
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final l = AppL10n.of(context);
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom + 22),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SheetHeader(
              icon: Icons.person_outline,
              title: _title(l),
              subtitle: _isAppend
                  ? l.actorAssocEditorExistingAliases(
                      widget.existing?.originalValues.length ?? 0,
                    )
                  : l.actorAssocEditorSeparatorHint,
              padding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),
            Text(
              l.actorAssocEditorCanonicalLabel,
              style: AppText.eyebrow(context),
            ),
            const SizedBox(height: 2),
            Text(
              _isCreate
                  ? l.actorAssocEditorCanonicalHint
                  : l.actorAssocEditorCanonicalLocked,
              style: AppText.meta(context),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _mapped,
              enabled: _isCreate,
              autofocus: _isCreate,
              textAlignVertical: TextAlignVertical.center,
              decoration: sheetInputDecoration(
                context,
                hintText: l.actorAssocEditorCanonicalExample,
                prefixIcon: const Icon(Icons.person_outline),
              ).copyWith(fillColor: _isCreate ? c.surface : c.chipBg),
              style: TextStyle(
                color: c.text,
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              (_isAppend
                      ? l.actorAssocEditorNewAliasLabel
                      : l.actorAssocEditorAliasLabel)
                  .toUpperCase(),
              style: AppText.eyebrow(context),
            ),
            const SizedBox(height: 2),
            Text(l.actorAssocEditorAliasHint, style: AppText.meta(context)),
            const SizedBox(height: 6),
            TextField(
              controller: _aliases,
              minLines: 2,
              maxLines: 5,
              decoration: sheetInputDecoration(
                context,
                hintText: l.actorAssocEditorAliasPlaceholder,
                prefixIcon: const Icon(Icons.sell_outlined),
              ),
              style: TextStyle(
                color: c.text,
                fontFamily: 'monospace',
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: sheetPrimaryButtonStyle(context),
                child: _saving
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: c.bg,
                        ),
                      )
                    : Text(
                        _isCreate ? l.actorAssocEditorCreate : l.save,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
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
