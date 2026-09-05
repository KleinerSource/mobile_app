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

  static MovieListItem previewMovie(AppL10n l) => MovieListItem(
    id: 0,
    title: l.badgePreviewMovieTitle,
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
    final previewMovie = BadgePositionPage.previewMovie(l);
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
                              movie: previewMovie,
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
                      // 3 项 badge 配置：评分、字幕/破解/清晰度、新资源
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
                            label: l.badgeContentGroup,
                            icon: Icons.subtitles_rounded,
                            value: pos.contentBadge,
                            enabled: pos.contentBadgeEnabled,
                            onChanged: (v) => ref
                                .read(badgePositionsProvider.notifier)
                                .setContentBadgePosition(v),
                            onToggle: (v) => ref
                                .read(badgePositionsProvider.notifier)
                                .setContentBadgeEnabled(v),
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
                      _CornerOffsetController(
                        contentCorner: pos.contentBadge,
                        offsetOf: pos.offsetOf,
                        onHorizontalChanged: (corner, value) => ref
                            .read(badgePositionsProvider.notifier)
                            .setHorizontalOffset(corner, value),
                        onVerticalChanged: (corner, value) => ref
                            .read(badgePositionsProvider.notifier)
                            .setVerticalOffset(corner, value),
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

class _CornerOffsetController extends StatefulWidget {
  const _CornerOffsetController({
    required this.contentCorner,
    required this.offsetOf,
    required this.onHorizontalChanged,
    required this.onVerticalChanged,
  });

  final BadgeCorner contentCorner;
  final BadgeCornerOffset Function(BadgeCorner) offsetOf;
  final Future<void> Function(BadgeCorner, int) onHorizontalChanged;
  final Future<void> Function(BadgeCorner, int) onVerticalChanged;

  @override
  State<_CornerOffsetController> createState() =>
      _CornerOffsetControllerState();
}

class _CornerOffsetControllerState extends State<_CornerOffsetController> {
  late BadgeCorner _selectedCorner;

  @override
  void initState() {
    super.initState();
    _selectedCorner = widget.contentCorner;
  }

  @override
  void didUpdateWidget(covariant _CornerOffsetController oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contentCorner != widget.contentCorner &&
        _selectedCorner == oldWidget.contentCorner) {
      _selectedCorner = widget.contentCorner;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final l = AppL10n.of(context);
    final offset = widget.offsetOf(_selectedCorner);

    return SettingsGroup(
      title: l.badgePositionController,
      items: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${l.badgeContentGroup} · ${_cornerLabel(widget.contentCorner, l)}',
                style: AppText.body(
                  context,
                ).copyWith(color: c.text, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(l.badgeOffsetTitle, style: AppText.meta(context)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _CornerChoice(
                      corner: BadgeCorner.topLeft,
                      selected: _selectedCorner == BadgeCorner.topLeft,
                      onTap: () => _selectCorner(BadgeCorner.topLeft),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _CornerChoice(
                      corner: BadgeCorner.topRight,
                      selected: _selectedCorner == BadgeCorner.topRight,
                      onTap: () => _selectCorner(BadgeCorner.topRight),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _CornerChoice(
                      corner: BadgeCorner.bottomLeft,
                      selected: _selectedCorner == BadgeCorner.bottomLeft,
                      onTap: () => _selectCorner(BadgeCorner.bottomLeft),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _CornerChoice(
                      corner: BadgeCorner.bottomRight,
                      selected: _selectedCorner == BadgeCorner.bottomRight,
                      onTap: () => _selectCorner(BadgeCorner.bottomRight),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _OffsetSlider(
          label: l.badgeOffsetHorizontal,
          icon: Icons.swap_horiz_rounded,
          value: offset.horizontal,
          onChanged: (value) =>
              widget.onHorizontalChanged(_selectedCorner, value),
        ),
        _OffsetSlider(
          label: l.badgeOffsetVertical,
          icon: Icons.swap_vert_rounded,
          value: offset.vertical,
          onChanged: (value) =>
              widget.onVerticalChanged(_selectedCorner, value),
        ),
      ],
    );
  }

  void _selectCorner(BadgeCorner corner) {
    if (_selectedCorner == corner) return;
    setState(() => _selectedCorner = corner);
  }
}

class _CornerChoice extends StatelessWidget {
  const _CornerChoice({
    required this.corner,
    required this.selected,
    required this.onTap,
  });

  final BadgeCorner corner;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final l = AppL10n.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: selected
                ? c.accent.withValues(alpha: 0.14)
                : c.bg.withValues(alpha: 0.45),
            border: Border.all(
              color: selected ? c.accent : c.cardBorder,
              width: selected ? 1.4 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                _cornerIcon(corner),
                color: selected ? c.accent : c.muted,
                size: 17,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  _cornerLabel(corner, l),
                  style: TextStyle(
                    color: selected ? c.text : c.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (selected)
                Icon(Icons.check_rounded, color: c.accent, size: 17),
            ],
          ),
        ),
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

IconData _cornerIcon(BadgeCorner corner) {
  switch (corner) {
    case BadgeCorner.topLeft:
      return Icons.north_west_rounded;
    case BadgeCorner.topRight:
      return Icons.north_east_rounded;
    case BadgeCorner.bottomLeft:
      return Icons.south_west_rounded;
    case BadgeCorner.bottomRight:
      return Icons.south_east_rounded;
  }
}
