import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/dio_factory.dart';
import '../../../core/models/mapping_rule.dart';
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
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: SizedBox(
        height: mq.size.height * 0.7,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 6, 22, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_title, style: AppText.sectionTitle(context)),
                    const SizedBox(height: 2),
                    Text(
                      _isAppend
                          ? '已有 ${widget.existing?.originalValues.length ?? 0} 个别名'
                          : '使用换行 / 逗号 / 顿号分隔多个别名',
                      style: AppText.meta(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
                  children: [
                    Text('标准演员名称', style: AppText.meta(context)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _mapped,
                      enabled: _isCreate,
                      decoration: InputDecoration(
                        hintText: '例: 加勒比海岛',
                        isDense: true,
                        border: const OutlineInputBorder(),
                        filled: !_isCreate,
                        fillColor: c.chipBg,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _isAppend ? '新增别名' : '关联别名',
                      style: AppText.meta(context),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _aliases,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        hintText: '一行一个, 或用 , ; 、 分隔',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
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
                        onPressed:
                            _saving ? null : () => Navigator.of(context).pop(false),
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.check, size: 18),
                        label: Text(_saving ? '保存中...' : '保存'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
