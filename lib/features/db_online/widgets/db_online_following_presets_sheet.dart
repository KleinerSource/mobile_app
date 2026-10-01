import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/sources/media/dbo/db_online_following.dart';
import 'package:omm/features/db_online/providers/db_online_following_providers.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/error_view.dart';
import 'package:omm/shared/glass.dart';
import 'package:omm/shared/localized_error_message.dart';
import 'package:omm/shared/sheet_controls.dart';

class DbOnlineFollowingPresetsSheet extends ConsumerStatefulWidget {
  const DbOnlineFollowingPresetsSheet({
    super.key,
    required this.serverId,
    required this.filter,
  });
  final String serverId;
  final DbOnlineFollowingFilter filter;

  @override
  ConsumerState<DbOnlineFollowingPresetsSheet> createState() => _PresetsState();
}

class _PresetsState extends ConsumerState<DbOnlineFollowingPresetsSheet> {
  List<DbOnlineFollowingPreset>? _ordered;
  bool _busy = false;
  bool get _current =>
      mounted && isDbOnlineFollowingServer(ref, widget.serverId);

  Future<void> _edit([DbOnlineFollowingPreset? preset]) async {
    final l = AppL10n.of(context);
    final form = GlobalKey<FormState>();
    final name = TextEditingController(text: preset?.name ?? '');
    final remark = TextEditingController(text: preset?.remark ?? '');
    final result = await showGlassDialog<DbOnlineFollowingPreset>(
      context: context,
      title: Text(
        preset == null
            ? l.dbOnlineFollowingSavePreset
            : l.dbOnlineFollowingEditPreset,
      ),
      content: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: name,
              autofocus: true,
              decoration: sheetInputDecoration(
                context,
                labelText: l.dbOnlineSubscriptionName,
              ),
              validator: (value) => value?.trim().isNotEmpty == true
                  ? null
                  : l.dbOnlineFollowingNameRequired,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: remark,
              maxLines: 2,
              decoration: sheetInputDecoration(
                context,
                labelText: l.dbOnlineSubscriptionRemark,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          child: Text(l.dbOnlineSubscriptionCancel),
        ),
        TextButton(
          onPressed: () {
            if (form.currentState!.validate()) {
              Navigator.of(context, rootNavigator: true).pop(
                DbOnlineFollowingPreset(
                  id: preset?.id ?? 0,
                  name: name.text.trim(),
                  remark: remark.text.trim(),
                  filter: preset?.filter ?? widget.filter,
                ),
              );
            }
          },
          child: Text(l.dbOnlineSubscriptionSave),
        ),
      ],
    );
    if (result != null && _current) {
      await _mutate(() async {
        await ref
            .read(dbOnlineFollowingApiProvider(widget.serverId))
            .savePreset(result);
      });
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
    name.dispose();
    remark.dispose();
  }

  Future<void> _delete(DbOnlineFollowingPreset preset) async {
    final l = AppL10n.of(context);
    final confirmed = await showGlassDialog<bool>(
      context: context,
      title: Text(l.dbOnlineFollowingDeletePreset),
      content: Text(l.dbOnlineFollowingDeletePresetConfirm(preset.name)),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop(false),
          child: Text(l.dbOnlineSubscriptionCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
          child: Text(l.dbOnlineFollowingDeletePreset),
        ),
      ],
    );
    if (confirmed == true && _current) {
      await _mutate(
        () => ref
            .read(dbOnlineFollowingApiProvider(widget.serverId))
            .deletePreset(preset.id),
      );
    }
  }

  Future<void> _mutate(Future<void> Function() action) async {
    if (_busy || !_current) return;
    final l = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
      if (!_current) return;
      ref.invalidate(dbOnlineFollowingPresetsProvider(widget.serverId));
      final items = await ref.read(
        dbOnlineFollowingPresetsProvider(widget.serverId).future,
      );
      if (_current) setState(() => _ordered = items);
    } catch (error) {
      if (_current) {
        messenger.showSnackBar(
          SnackBar(content: Text(localizedErrorMessage(l, error))),
        );
      }
    } finally {
      if (_current) setState(() => _busy = false);
    }
  }

  Future<void> _reorder(
    List<DbOnlineFollowingPreset> items,
    int from,
    int to,
  ) async {
    if (_busy || !_current) return;
    final l = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ordered = List<DbOnlineFollowingPreset>.of(items);
    ordered.insert(to, ordered.removeAt(from));
    setState(() {
      _ordered = ordered;
      _busy = true;
    });
    final api = ref.read(dbOnlineFollowingApiProvider(widget.serverId));
    try {
      await api.reorderPresets(ordered.map((preset) => preset.id).toList());
      if (_current) {
        ref.invalidate(dbOnlineFollowingPresetsProvider(widget.serverId));
      }
    } catch (error) {
      if (!_current) return;
      messenger.showSnackBar(
        SnackBar(content: Text(localizedErrorMessage(l, error))),
      );
      // 请求失败后重新读取服务端顺序，避免保留未保存的拖动结果。
      setState(() => _ordered = items);
      ref.invalidate(dbOnlineFollowingPresetsProvider(widget.serverId));
      try {
        final restored = await ref.read(
          dbOnlineFollowingPresetsProvider(widget.serverId).future,
        );
        if (_current) setState(() => _ordered = restored);
      } catch (_) {
        // 保留最后一次确认的服务端顺序，错误已由统一提示展示。
      }
    } finally {
      if (_current) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final presets = ref.watch(
      dbOnlineFollowingPresetsProvider(widget.serverId),
    );
    return SafeArea(
      top: false,
      child: SizedBox(
        height: sheetMaxHeight(context) * .8,
        child: Column(
          children: [
            SheetHeader(
              icon: Icons.bookmarks_outlined,
              title: l.dbOnlineFollowingPresets,
              subtitle: l.dbOnlineFollowingReorderHint,
              trailing: IconButton(
                tooltip: l.dbOnlineFollowingSavePreset,
                onPressed: _busy ? null : _edit,
                icon: const Icon(Icons.add_rounded),
              ),
            ),
            if (_busy) const LinearProgressIndicator(),
            Expanded(
              child: presets.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => ErrorView(
                  message: localizedErrorMessage(l, error),
                  onRetry: () => ref.invalidate(
                    dbOnlineFollowingPresetsProvider(widget.serverId),
                  ),
                ),
                data: (serverItems) {
                  final items = _ordered ?? serverItems;
                  if (items.isEmpty) {
                    return Center(child: Text(l.dbOnlineFollowingNoPresets));
                  }
                  return ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                    buildDefaultDragHandles: false,
                    itemCount: items.length,
                    onReorderItem: (from, to) => _reorder(items, from, to),
                    itemBuilder: (context, index) {
                      final preset = items[index];
                      return ListTile(
                        key: ValueKey(preset.id),
                        title: Text(preset.name),
                        subtitle: preset.remark.isEmpty
                            ? null
                            : Text(preset.remark),
                        onTap: _busy
                            ? null
                            : () => Navigator.pop(context, preset),
                        leading: _busy
                            ? const Icon(Icons.drag_handle_rounded)
                            : ReorderableDragStartListener(
                                index: index,
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(Icons.drag_handle_rounded),
                                ),
                              ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: l.dbOnlineFollowingEditPreset,
                              onPressed: _busy ? null : () => _edit(preset),
                              icon: const Icon(Icons.edit_outlined, size: 18),
                            ),
                            IconButton(
                              tooltip: l.dbOnlineFollowingDeletePreset,
                              onPressed: _busy ? null : () => _delete(preset),
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
