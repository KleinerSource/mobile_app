import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/app_theme.dart';
import '../../shared/glow_background.dart';
import '../i18n/poster_badge_visibility_provider.dart';
import 'settings_common.dart';

/// 影片详情页海报技术角标显示设置。
class PosterBadgeDisplayPage extends ConsumerWidget {
  const PosterBadgeDisplayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visibility = ref.watch(posterBadgeVisibilityProvider);

    return Scaffold(
      backgroundColor: appColors(context).bg,
      body: GlowBackground(
        child: SafeArea(
          child: SettingsFixedHeaderLayout(
            header: const SettingsSubPageHeader(
              eyebrow: '应用设置',
              title: '海报角标显示',
              subtitle: '控制影片详情海报上显示的技术信息',
            ),
            body: ListView(
              primary: true,
              padding: EdgeInsets.zero,
              children: [
                SettingsGroup(
                  title: '影片详情海报',
                  items: [
                    for (final kind in PosterBadgeKind.values)
                      _PosterBadgeVisibilityTile(
                        kind: kind,
                        enabled: visibility.isEnabled(kind),
                        onChanged: (value) => ref
                            .read(posterBadgeVisibilityProvider.notifier)
                            .setEnabled(kind, value),
                      ),
                  ],
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PosterBadgeVisibilityTile extends StatelessWidget {
  const _PosterBadgeVisibilityTile({
    required this.kind,
    required this.enabled,
    required this.onChanged,
  });

  final PosterBadgeKind kind;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  IconData get _icon {
    return switch (kind) {
      PosterBadgeKind.codec => Icons.memory_outlined,
      PosterBadgeKind.hdr => Icons.hdr_on,
      PosterBadgeKind.strm => Icons.link_outlined,
      PosterBadgeKind.subtitle => Icons.closed_caption_outlined,
      PosterBadgeKind.crack => Icons.lock_open_outlined,
      PosterBadgeKind.resolution => Icons.high_quality_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      title: kind.label,
      subtitle: enabled ? '显示' : '已隐藏',
      leadingIcon: _icon,
      trailing: SettingsSwitch(value: enabled, onChanged: onChanged),
    );
  }
}
