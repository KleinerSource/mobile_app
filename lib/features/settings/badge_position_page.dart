import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/movie.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/glass.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/glow_background.dart';
import '../../shared/movie_card.dart';
import '../../shared/sheet_controls.dart';
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
    hasNewResources: true,
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
          child: SettingsFixedHeaderLayout(
            header: SettingsSubPageHeader(
              eyebrow: l.settingsAppSettings,
              title: l.settingsBadgePositions,
            ),
            body: Column(
              children: [
                // 预览固定在设置列表上方，调整位置时始终可见。
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
                Expanded(
                  child: ListView(
                    primary: true,
                    children: [
                      // 5 项 badge 配置
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
                          _CornerTile(
                            label: l.badgeNewResources,
                            icon: Icons.auto_awesome_rounded,
                            value: pos.newResources,
                            enabled: pos.newResourcesEnabled,
                            onChanged: (v) => ref
                                .read(badgePositionsProvider.notifier)
                                .setKind(BadgeKind.newResources, v),
                            onToggle: (v) => ref
                                .read(badgePositionsProvider.notifier)
                                .setEnabled(BadgeKind.newResources, v),
                          ),
                        ],
                      ),
                      // 每个角落单独微调，避免不同角落的 badge 相互牵连
                      for (final corner in BadgeCorner.values)
                        _CornerOffsetGroup(
                          corner: corner,
                          offset: pos.offsetOf(corner),
                          onHorizontalChanged: (v) => ref
                              .read(badgePositionsProvider.notifier)
                              .setHorizontalOffset(corner, v),
                          onVerticalChanged: (v) => ref
                              .read(badgePositionsProvider.notifier)
                              .setVerticalOffset(corner, v),
                        ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OffsetSlider extends StatelessWidget {
  static const _rowHeight = 56.0;
  static const _sliderHeight = 48.0;

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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: _rowHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 18,
              height: _rowHeight,
              child: Center(child: Icon(icon, color: c.muted, size: 18)),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 56,
              height: _rowHeight,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.meta(context),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: SizedBox(
                  height: _sliderHeight,
                  child: HapticSlider(
                    min: -16,
                    max: 16,
                    divisions: 32,
                    value: value.toDouble(),
                    label: '$value',
                    onChanged: (v) => onChanged(v.round()),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 36,
              height: _rowHeight,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '$value',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: c.text,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    height: 1.2,
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

class _CornerOffsetGroup extends StatelessWidget {
  const _CornerOffsetGroup({
    required this.corner,
    required this.offset,
    required this.onHorizontalChanged,
    required this.onVerticalChanged,
  });

  final BadgeCorner corner;
  final BadgeCornerOffset offset;
  final ValueChanged<int> onHorizontalChanged;
  final ValueChanged<int> onVerticalChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return SettingsGroup(
      title: '${_cornerLabel(corner, l)} · ${l.badgeOffsetTitle}',
      items: [
        _OffsetSlider(
          label: l.badgeOffsetHorizontal,
          icon: Icons.swap_horiz_rounded,
          value: offset.horizontal,
          onChanged: onHorizontalChanged,
        ),
        _OffsetSlider(
          label: l.badgeOffsetVertical,
          icon: Icons.swap_vert_rounded,
          value: offset.vertical,
          onChanged: onVerticalChanged,
        ),
      ],
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

  Future<void> _pick(BuildContext context) async {
    final c = appColors(context);
    final l = AppL10n.of(context);
    final picked = await showGlassSheet<BadgeCorner>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SheetHeader(
                icon: icon,
                title: label,
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 14),
              ),
              for (final corner in BadgeCorner.values)
                ListTile(
                  title: Text(
                    _cornerLabel(corner, l),
                    style: AppText.body(
                      ctx,
                    ).copyWith(color: c.text, fontWeight: FontWeight.w700),
                  ),
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
    return SettingsTile(
      title: label,
      subtitle: enabled ? _cornerLabel(value, l) : l.badgeHidden,
      leadingIcon: icon,
      onTap: enabled ? () => _pick(context) : null,
      trailing: SettingsSwitch(value: enabled, onChanged: onToggle),
    );
  }
}

String _cornerLabel(BadgeCorner corner, AppL10n l) {
  switch (corner) {
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
