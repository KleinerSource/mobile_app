import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/dio_factory.dart';
import '../../../core/models/mapping_rule.dart';
import '../../../core/platform/app_haptics.dart';
import '../../../core/platform/app_theme.dart';
import '../actor_associations_providers.dart';
import '../actor_associations_repository.dart';

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
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: appColors(context).bg,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ActorAssociationEditorSheet(
        mode: mode,
        existing: existing,
      ),
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

  String get _title {
    switch (widget.mode) {
      case ActorAssocEditMode.create:
        return '新建演员关联';
      case ActorAssocEditMode.edit:
        return '编辑关联';
      case ActorAssocEditMode.append:
        return '追加别名';
    }
  }

  @override
  void initState() {
    super.initState();
    _mapped = TextEditingController(text: widget.existing?.mappedValue ?? '');
    final initialAliases =
        _isEdit ? (widget.existing?.originalValues ?? const []).join('\n') : '';
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
    final mapped = _mapped.text.trim();
    if (mapped.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入标准演员名称')),
      );
      return;
    }
    final inputAliases =
        ActorAssociationsRepository.parseAliases(_aliases.text, mapped);

    if (_isAppend && inputAliases.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入要追加的别名')),
      );
      return;
    }
    if (_isCreate && inputAliases.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少添加一个别名')),
      );
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
            const SnackBar(content: Text('没有可添加的新名称')),
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
      messenger.showSnackBar(SnackBar(content: Text('$_title 成功')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('$_title 失败: ${toApiException(e).message}'),
      ));
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom + 22),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_title, style: AppText.sectionTitle(context)),
            const SizedBox(height: 4),
            Text(
              _isAppend
                  ? '已有 ${widget.existing?.originalValues.length ?? 0} 个别名'
                  : '使用换行 / 逗号 / 顿号分隔多个别名',
              style: AppText.meta(context),
            ),
            const SizedBox(height: 16),
            Text('标准演员名称', style: AppText.eyebrow(context)),
            const SizedBox(height: 2),
            Text(
              _isCreate ? '用于匹配影片中的演员名称' : '标准名称不可修改',
              style: AppText.meta(context),
            ),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: _isCreate ? c.surface : c.chipBg,
                border: Border.all(color: c.cardBorder),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _mapped,
                enabled: _isCreate,
                autofocus: _isCreate,
                decoration: const InputDecoration(
                  hintText: '例: 加勒比海岛',
                  prefixIcon: Icon(Icons.person_outline),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                style: TextStyle(
                  color: c.text,
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              (_isAppend ? '新增别名' : '关联别名').toUpperCase(),
              style: AppText.eyebrow(context),
            ),
            const SizedBox(height: 2),
            Text('多个值用换行分隔', style: AppText.meta(context)),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: c.surface,
                border: Border.all(color: c.cardBorder),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _aliases,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: '一行一个, 或用 , ; 、 分隔',
                  prefixIcon: Icon(Icons.sell_outlined),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                style: TextStyle(
                  color: c.text,
                  fontFamily: 'monospace',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: c.text,
                  foregroundColor: c.bg,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
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
                        _isCreate ? '创建' : '保存',
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
