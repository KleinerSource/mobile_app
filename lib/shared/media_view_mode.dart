import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/server_config_provider.dart';
import '../core/config/server_runtime.dart';
import '../core/platform/app_theme.dart';
import '../l10n/generated/app_localizations.dart';

/// 目录影片卡片的三种展示方式。
enum MediaViewMode { portrait, landscape, list }

MediaViewMode mediaViewModeFromPreference(String? value) => switch (value) {
  'landscape' => MediaViewMode.landscape,
  'list' => MediaViewMode.list,
  // 兼容已有双模式页面保存的 grid 值。
  _ => MediaViewMode.portrait,
};

/// 媒体视图模式的全局偏好：按服务器隔离保存（模式同 home.layout），
/// 任意媒体库页面（OMM/DBO/Emby/Jellyfin/Feiniu/Stash）切换后所有页面同步生效。
class MediaServerViewModePreference extends Notifier<MediaViewMode> {
  /// 旧版本按页面独立保存的全局键；首次读取时迁移到当前服务器的全局键。
  static const _legacyKeys = <String>[
    'movies.view_mode.v1',
    'media_browser.library.view_mode.v1',
    'db_online.library.view_mode.v1',
    'favorites.view_mode.v1',
    'media_browser.favorites.view_mode.v1',
    'db_online.subscriptions.view_mode.v1',
    'db_online.rankings.view_mode.v1',
    'db_online.following.view_mode.v1',
    'db_online.watched.view_mode.v1',
    'db_online.latest.view_mode.v1',
    'db_online.entity_movies.view_mode.v1',
    'omm.search.view_mode.v1',
    'db_online.search.view_mode.v1',
    'media_browser.search.view_mode.v1',
  ];

  @override
  MediaViewMode build() {
    final serverId = ref.watch(
      serverRuntimeProvider.select((runtime) => runtime.media.serverId),
    );
    final prefs = ref.watch(sharedPrefsProvider);
    final key = mediaServerViewModeStorageKey(serverId);

    final stored = prefs.getString(key);
    if (stored != null) return mediaViewModeFromPreference(stored);

    // 迁移旧版页面级键：采用第一个已保存的值并立即固化到当前服务器。
    for (final legacyKey in _legacyKeys) {
      final legacy = prefs.getString(legacyKey);
      if (legacy == null) continue;
      final mode = mediaViewModeFromPreference(legacy);
      unawaited(prefs.setString(key, mode.name));
      return mode;
    }
    return MediaViewMode.portrait;
  }

  void set(MediaViewMode mode) {
    if (state == mode) return;
    state = mode;
    final prefs = ref.read(sharedPrefsProvider);
    unawaited(
      prefs.setString(
        mediaServerViewModeStorageKey(_currentServerId()),
        mode.name,
      ),
    );
  }

  String? _currentServerId() => ref.read(
    serverRuntimeProvider.select((runtime) => runtime.media.serverId),
  );
}

/// 按服务器编码的视图模式存储键；无激活服务器时落到共享的 default
/// 槽位，保证偏好始终持久化。
String mediaServerViewModeStorageKey(String? serverId) {
  final normalized = (serverId ?? '').trim();
  final encoded = base64Url
      .encode(utf8.encode(normalized.isEmpty ? 'default' : normalized))
      .replaceAll('=', '');
  return 'media.view_mode.v1.$encoded';
}

final mediaServerViewModeProvider =
    NotifierProvider<MediaServerViewModePreference, MediaViewMode>(
      MediaServerViewModePreference.new,
    );

/// 与 OMM 现有风格一致的紧凑分段视图切换。
class MediaViewModeToggle extends StatelessWidget {
  const MediaViewModeToggle({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  final MediaViewMode mode;
  final ValueChanged<MediaViewMode> onChanged;

  String _label(AppL10n l, MediaViewMode value) => switch (value) {
    MediaViewMode.portrait => l.viewGrid,
    MediaViewMode.landscape => l.playerSwitchToLandscape,
    MediaViewMode.list => l.viewList,
  };

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);

    Widget button(IconData icon, MediaViewMode value) {
      final active = mode == value;
      return Semantics(
        button: true,
        selected: active,
        label: _label(AppL10n.of(context), value),
        child: Tooltip(
          message: _label(AppL10n.of(context), value),
          child: GestureDetector(
            onTap: () => onChanged(value),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: active ? colors.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                boxShadow: active
                    ? const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 3,
                          offset: Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                icon,
                size: 15,
                color: active ? colors.text : colors.muted,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.chipBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(Icons.grid_view_rounded, MediaViewMode.portrait),
          button(Icons.crop_landscape_rounded, MediaViewMode.landscape),
          button(Icons.view_list_rounded, MediaViewMode.list),
        ],
      ),
    );
  }
}

/// 绑定 [mediaServerViewModeProvider] 的全局视图切换；所有媒体库页面共用。
class MediaServerViewModeToggle extends ConsumerWidget {
  const MediaServerViewModeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MediaViewModeToggle(
    mode: ref.watch(mediaServerViewModeProvider),
    onChanged: ref.read(mediaServerViewModeProvider.notifier).set,
  );
}
