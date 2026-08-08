import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/movie.dart';
import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/glow_background.dart';
import '../../shared/movie_card.dart';
import '../i18n/badge_position_provider.dart';
import 'settings_common.dart';

class BadgePositionPage extends ConsumerWidget {
  const BadgePositionPage({super.key});

  static const _previewMovie = MovieListItem(
    id: 0,
    title: '示例影片 / Preview',
    num: 'ABC-123',
    year: 2024,
    rating: 8.7,
    runtime: 120,
    hasExternalSubtitle: true,
    hasInternalSubtitle: true,
    videoHeight: 1080,
    fileName: 'abc-123-uc.mp4',
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = appColors(context);
    final l = AppL10n.of(context);
    final pos = ref.watch(badgePositionsProvider);

    return Scaffold(
      backgroundColor: c.bg,
      body: GlowBackground(
        child: SafeArea(
          child: ListView(
            children: [
              SettingsSubPageHeader(
                eyebrow: l.settingsAppSettings,
                title: l.settingsBadgePositions,
              ),
              // 预览区
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: c.surface,
                    border: Border.all(color: c.cardBorder),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.previewTitle, style: AppText.eyebrow(context)),
                      const SizedBox(height: 12),
                      Center(
                        child: SizedBox(
                          width: 160,
                          child: MovieCard(
                            movie: _previewMovie,
                            posterUrlBuilder: (_) => '',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // 4 项 badge 配置
              SettingsGroup(
                title: l.settingsBadgePositions,
                items: [
                  _CornerTile(
                    label: l.badgeRating,
                    icon: Icons.star_rounded,
                    value: pos.rating,
                    enabled: pos.ratingEnabled,
                    onChanged: (v) => ref
                        .read(badgePositionsProvider.notifier)
                        .setKind(BadgeKind.rating, v),
                    onToggle: (v) => ref
                        .read(badgePositionsProvider.notifier)
                        .setEnabled(BadgeKind.rating, v),
                  ),
                  _CornerTile(
                    label: l.badgeSubtitle,
                    icon: Icons.closed_caption_rounded,
                    value: pos.subtitle,
                    enabled: pos.subtitleEnabled,
                    onChanged: (v) => ref
                        .read(badgePositionsProvider.notifier)
                        .setKind(BadgeKind.subtitle, v),
                    onToggle: (v) => ref
                        .read(badgePositionsProvider.notifier)
                        .setEnabled(BadgeKind.subtitle, v),
                  ),
                  _CornerTile(
                    label: l.badgeCrack,
                    icon: Icons.lock_open_rounded,
                    value: pos.crack,
                    enabled: pos.crackEnabled,
                    onChanged: (v) => ref
                        .read(badgePositionsProvider.notifier)
                        .setKind(BadgeKind.crack, v),
                    onToggle: (v) => ref
                        .read(badgePositionsProvider.notifier)
                        .setEnabled(BadgeKind.crack, v),
                  ),
                  _CornerTile(
                    label: l.badgeResolution,
                    icon: Icons.high_quality_outlined,
                    value: pos.resolution,
                    enabled: pos.resolutionEnabled,
                    onChanged: (v) => ref
                        .read(badgePositionsProvider.notifier)
                        .setKind(BadgeKind.resolution, v),
                    onToggle: (v) => ref
                        .read(badgePositionsProvider.notifier)
                        .setEnabled(BadgeKind.resolution, v),
                  ),
                ],
              ),
              // 微调滑块
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  decoration: BoxDecoration(
                    color: c.surface,
                    border: Border.all(color: c.cardBorder),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.badgeOffsetTitle, style: AppText.eyebrow(context)),
                      const SizedBox(height: 4),
                      _OffsetSlider(
                        label: l.badgeOffsetHorizontal,
                        icon: Icons.swap_horiz_rounded,
                        value: pos.horizontalOffset,
                        onChanged: (v) => ref
                            .read(badgePositionsProvider.notifier)
                            .setHorizontalOffset(v),
                      ),
                      _OffsetSlider(
                        label: l.badgeOffsetVertical,
                        icon: Icons.swap_vert_rounded,
                        value: pos.verticalOffset,
                        onChanged: (v) => ref
                            .read(badgePositionsProvider.notifier)
                            .setVerticalOffset(v),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}

class _OffsetSlider extends StatelessWidget {
  const _OffsetSlider({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final IconData icon;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: c.muted, size: 18),
          const SizedBox(width: 8),
          SizedBox(
            width: 56,
            child: Text(label, style: AppText.meta(context)),
          ),
          Expanded(
            child: Slider(
              min: -16,
              max: 16,
              divisions: 32,
              value: value.toDouble(),
              label: '$value',
              onChanged: (v) => onChanged(v.round()),
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              '$value',
              textAlign: TextAlign.end,
              style: TextStyle(
                color: c.text,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CornerTile extends StatelessWidget {
  const _CornerTile({
    required this.label,
    required this.icon,
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.onToggle,
  });
  final String label;
  final IconData icon;
  final BadgeCorner value;
  final bool enabled;
  final ValueChanged<BadgeCorner> onChanged;
  final ValueChanged<bool> onToggle;

  String _labelOf(BadgeCorner c, AppL10n l) {
    switch (c) {
      case BadgeCorner.topLeft:
        return l.cornerTopLeft;
      case BadgeCorner.topRight:
        return l.cornerTopRight;
      case BadgeCorner.bottomLeft:
        return l.cornerBottomLeft;
      case BadgeCorner.bottomRight:
        return l.cornerBottomRight;
    }
  }

  Future<void> _pick(BuildContext context) async {
    final c = appColors(context);
    final l = AppL10n.of(context);
    final picked = await showModalBottomSheet<BadgeCorner>(
      context: context,
      backgroundColor: c.bg,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 14),
                child: Row(children: [
                  Text(label, style: AppText.sectionTitle(ctx)),
                ]),
              ),
              for (final corner in BadgeCorner.values)
                ListTile(
                  title: Text(_labelOf(corner, l),
                      style: TextStyle(
                        color: c.text,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      )),
                  trailing: corner == value
                      ? Icon(Icons.check, color: c.accent)
                      : null,
                  onTap: () => Navigator.pop(ctx, corner),
                ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
    if (picked != null && picked != value) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final c = appColors(context);
    return SettingsTile(
      title: label,
      subtitle: enabled ? _labelOf(value, l) : l.badgeHidden,
      leadingIcon: icon,
      onTap: enabled ? () => _pick(context) : null,
      trailing: Switch(
        value: enabled,
        onChanged: AppHaptics.wrapToggle(onToggle),
        activeThumbColor: c.accent,
      ),
    );
  }
}
