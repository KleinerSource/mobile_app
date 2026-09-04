import 'package:flutter/material.dart';

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
