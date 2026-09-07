import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/server_config_provider.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/glass.dart';

typedef HomeLayoutModuleBuilder = Widget Function(BuildContext context);

/// 首页中除 hero 外可被用户调整的一个模块。
@immutable
class HomeLayoutModule {
  const HomeLayoutModule({
    required this.id,
    required this.title,
    required this.builder,
  });

  final String id;
  final String title;
  final HomeLayoutModuleBuilder builder;
}

@immutable
class HomeLayoutPreferences {
  const HomeLayoutPreferences({
    this.order = const <String>[],
    this.hidden = const <String>{},
  });

  final List<String> order;
  final Set<String> hidden;

  HomeLayoutPreferences copyWith({List<String>? order, Set<String>? hidden}) {
    return HomeLayoutPreferences(
      order: order ?? this.order,
      hidden: hidden ?? this.hidden,
    );
  }
}

/// 首页布局偏好按服务器保存，避免切换服务器后复用另一台服务器的布局。
class HomeLayoutPreferencesRepository {
  HomeLayoutPreferencesRepository(this._prefs);

  static const _storageKeyPrefix = 'home.layout.v1.';

  final SharedPreferences _prefs;
  Future<void> _writeQueue = Future<void>.value();

  HomeLayoutPreferences load(String serverId) {
    final raw = _prefs.getString(_key(serverId));
    if (raw == null || raw.isEmpty) return const HomeLayoutPreferences();

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const HomeLayoutPreferences();
      return HomeLayoutPreferences(
        order: _stringList(decoded['order']),
        hidden: _stringList(decoded['hidden']).toSet(),
      );
    } on FormatException {
      return const HomeLayoutPreferences();
    }
  }

  Future<void> save(String serverId, HomeLayoutPreferences preferences) {
    final result = _writeQueue.then((_) async {
      await _prefs.setString(
        _key(serverId),
        jsonEncode({
          'order': preferences.order,
          'hidden': preferences.hidden.toList(),
        }),
      );
    });
    _writeQueue = result.then<void>((_) {}, onError: (_, __) {});
    return result;
  }

  String _key(String serverId) {
    final normalized = serverId.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(serverId, 'serverId', '服务器 ID 不能为空');
    }
    final encoded = base64Url
        .encode(utf8.encode(normalized))
        .replaceAll('=', '');
    return '$_storageKeyPrefix$encoded';
  }

  List<String> _stringList(Object? value) {
    if (value is! List) return const <String>[];
    return [
      for (final item in value)
        if (item is String && item.trim().isNotEmpty) item.trim(),
    ];
  }
}

final homeLayoutPreferencesRepositoryProvider =
    Provider<HomeLayoutPreferencesRepository>(
      (ref) => HomeLayoutPreferencesRepository(ref.watch(sharedPrefsProvider)),
    );

class HomeLayoutPreferencesNotifier extends Notifier<HomeLayoutPreferences> {
  HomeLayoutPreferencesNotifier(this.serverId);

  final String serverId;
  late HomeLayoutPreferencesRepository _repository;

  @override
  HomeLayoutPreferences build() {
    _repository = ref.read(homeLayoutPreferencesRepositoryProvider);
    return _repository.load(serverId);
  }

  Future<void> update(HomeLayoutPreferences next) {
    state = next;
    return _repository.save(serverId, next);
  }
}

final homeLayoutPreferencesProvider =
    NotifierProvider.family<
      HomeLayoutPreferencesNotifier,
      HomeLayoutPreferences,
      String
    >(HomeLayoutPreferencesNotifier.new);

/// 将已保存的顺序与当前运行时模块合并，新模块追加到末尾。
HomeLayoutPreferences reconcileHomeLayoutPreferences(
  List<HomeLayoutModule> modules,
  HomeLayoutPreferences preferences,
) {
  final ids = modules.map((module) => module.id).toSet();
  final order = <String>[];
  for (final id in preferences.order) {
    if (ids.contains(id) && !order.contains(id)) order.add(id);
  }
  for (final module in modules) {
    if (!order.contains(module.id)) order.add(module.id);
  }
  return HomeLayoutPreferences(
    order: order,
    hidden: preferences.hidden.where(ids.contains).toSet(),
  );
}

List<HomeLayoutModule> orderedHomeLayoutModules(
  List<HomeLayoutModule> modules,
  HomeLayoutPreferences preferences,
) {
  final normalized = reconcileHomeLayoutPreferences(modules, preferences);
  final byId = {for (final module in modules) module.id: module};
  return [for (final id in normalized.order) byId[id]!];
}

class HomeLayoutEditorConfig {
  const HomeLayoutEditorConfig({
    required this.modules,
    required this.preferences,
    required this.onSave,
  });

  final List<HomeLayoutModule> modules;
  final HomeLayoutPreferences preferences;
  final Future<void> Function(HomeLayoutPreferences preferences) onSave;
}

class HomeLayoutEditButton extends StatelessWidget {
  const HomeLayoutEditButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
      child: Center(
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.tune_rounded, size: 18),
          label: Text(AppL10n.of(context).homeEditLayout),
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.accent,
            side: BorderSide(color: colors.divider),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showHomeLayoutEditor({
  required BuildContext context,
  required HomeLayoutEditorConfig config,
}) async {
  await showGlassSheet<void>(
    context: context,
    minHeight: 360,
    builder: (context) => _HomeLayoutEditorSheet(config: config),
  );
}

class _HomeLayoutEditorSheet extends StatefulWidget {
  const _HomeLayoutEditorSheet({required this.config});

  final HomeLayoutEditorConfig config;

  @override
  State<_HomeLayoutEditorSheet> createState() => _HomeLayoutEditorSheetState();
}

class _HomeLayoutEditorSheetState extends State<_HomeLayoutEditorSheet> {
  late final List<HomeLayoutModule> _modules = [
    ...orderedHomeLayoutModules(
      widget.config.modules,
      widget.config.preferences,
    ),
  ];
  late final Set<String> _hidden = {...widget.config.preferences.hidden};
  var _saving = false;

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.config.onSave(
        HomeLayoutPreferences(
          order: [for (final module in _modules) module.id],
          hidden: _hidden,
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 暗色主题的 surface 是半透明白色 token，直接覆盖 alpha 会变成亮白底。
    final moduleColor = isDark
        ? Color.alphaBlend(colors.surfaceAlt, colors.bg)
        : colors.surface.withValues(alpha: 0.72);
    final l = AppL10n.of(context);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.72,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 8, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l.homeEditLayout,
                    style: AppText.sectionTitle(context),
                  ),
                ),
                IconButton(
                  tooltip: l.cancel,
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l.homeEditLayoutHint,
                style: TextStyle(color: colors.muted, fontSize: 13),
              ),
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              itemCount: _modules.length,
              buildDefaultDragHandles: false,
              onReorderItem: (oldIndex, newIndex) {
                if (_saving) return;
                AppHaptics.light();
                setState(() {
                  final module = _modules.removeAt(oldIndex);
                  _modules.insert(newIndex, module);
                });
              },
              itemBuilder: (context, index) {
                final module = _modules[index];
                final visible = !_hidden.contains(module.id);
                return Container(
                  key: ValueKey(module.id),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: moduleColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colors.divider),
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: ListTile(
                      dense: true,
                      leading: ReorderableDragStartListener(
                        index: index,
                        enabled: !_saving,
                        child: Icon(
                          Icons.drag_indicator_rounded,
                          color: colors.muted,
                        ),
                      ),
                      title: Text(
                        module.title,
                        style: TextStyle(
                          color: visible ? colors.text : colors.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      trailing: Switch.adaptive(
                        value: visible,
                        onChanged: _saving
                            ? null
                            : (value) {
                                setState(() {
                                  if (value) {
                                    _hidden.remove(module.id);
                                  } else {
                                    _hidden.add(module.id);
                                  }
                                });
                              },
                      ),
                      onTap: _saving
                          ? null
                          : () {
                              setState(() {
                                if (visible) {
                                  _hidden.add(module.id);
                                } else {
                                  _hidden.remove(module.id);
                                }
                              });
                            },
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 18),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? l.commonSaving : l.done),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
