import 'package:flutter/material.dart';

import '../core/platform/app_theme.dart';
import '../l10n/generated/app_localizations.dart';
import 'sheet_controls.dart';

/// 横向滑动切换资源类型，保留内容的自适应高度和纵向滚动。
class ResourcePanelSwipeArea extends StatefulWidget {
  const ResourcePanelSwipeArea({
    super.key,
    required this.child,
    this.onSwipeLeft,
    this.onSwipeRight,
  });

  final Widget child;
  final VoidCallback? onSwipeLeft;
  final VoidCallback? onSwipeRight;

  @override
  State<ResourcePanelSwipeArea> createState() => _ResourcePanelSwipeAreaState();
}

class _ResourcePanelSwipeAreaState extends State<ResourcePanelSwipeArea> {
  double _dragDistance = 0;

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final direction = velocity.abs() >= 300 ? velocity : _dragDistance;
    if (velocity.abs() >= 300 || _dragDistance.abs() >= 48) {
      if (direction < 0) {
        widget.onSwipeLeft?.call();
      } else if (direction > 0) {
        widget.onSwipeRight?.call();
      }
    }
    _dragDistance = 0;
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onSwipeLeft != null || widget.onSwipeRight != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: enabled ? (_) => _dragDistance = 0 : null,
      onHorizontalDragUpdate: enabled
          ? (details) => _dragDistance += details.primaryDelta ?? 0
          : null,
      onHorizontalDragEnd: enabled ? _onDragEnd : null,
      onHorizontalDragCancel: enabled ? () => _dragDistance = 0 : null,
      child: widget.child,
    );
  }
}

@immutable
class ResourcePanelTab {
  const ResourcePanelTab({required this.label});

  final String label;
}

/// Shared sheet structure for OMM and DBO online resource and subtitle panels.
class ResourcePanelShell extends StatelessWidget {
  const ResourcePanelShell({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.tabs = const <ResourcePanelTab>[],
    this.selectedTabIndex = 0,
    this.onTabSelected,
    this.contentTopSpacing = 0,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final List<ResourcePanelTab> tabs;
  final int selectedTabIndex;
  final ValueChanged<int>? onTabSelected;
  final double contentTopSpacing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final hasTabs = tabs.length > 1;
    final canChangeTab = hasTabs && onTabSelected != null;
    return SafeArea(
      top: false,
      bottom: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: ResourcePanelSwipeArea(
          onSwipeLeft: canChangeTab && selectedTabIndex < tabs.length - 1
              ? () => onTabSelected!(selectedTabIndex + 1)
              : null,
          onSwipeRight: canChangeTab && selectedTabIndex > 0
              ? () => onTabSelected!(selectedTabIndex - 1)
              : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SheetHeader(
                icon: icon,
                title: title,
                subtitle: subtitle,
                trailing: trailing,
              ),
              if (hasTabs)
                _ResourcePanelTabs(
                  tabs: tabs,
                  selectedTabIndex: selectedTabIndex,
                  onTabSelected: onTabSelected,
                ),
              if (contentTopSpacing > 0) SizedBox(height: contentTopSpacing),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _ResourcePanelTabs extends StatelessWidget {
  const _ResourcePanelTabs({
    required this.tabs,
    required this.selectedTabIndex,
    required this.onTabSelected,
  });

  final List<ResourcePanelTab> tabs;
  final int selectedTabIndex;
  final ValueChanged<int>? onTabSelected;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: colors.chipBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            for (var index = 0; index < tabs.length; index++)
              Expanded(
                child: ResourcePanelTabButton(
                  label: tabs[index].label,
                  active: index == selectedTabIndex,
                  onTap: () => onTabSelected?.call(index),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Self-sizing, vertically scrollable list used by resource and subtitle sheets.
class ResourcePanelList extends StatelessWidget {
  const ResourcePanelList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.dividerColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 22),
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final Color dividerColor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Flexible(
    fit: FlexFit.loose,
    child: ListView.separated(
      shrinkWrap: true,
      padding: padding,
      itemCount: itemCount,
      separatorBuilder: (_, __) => Divider(height: 1, color: dividerColor),
      itemBuilder: itemBuilder,
    ),
  );
}

/// OMM and DBO resource-list row presentation.
class ResourcePanelRow extends StatelessWidget {
  const ResourcePanelRow({
    super.key,
    required this.title,
    required this.trailing,
    this.titleMaxLines = 2,
    this.metadata,
    this.tags = const <String>[],
    this.downloadedTooltip,
  });

  final String title;
  final int titleMaxLines;
  final Widget? metadata;
  final List<String> tags;
  final Widget trailing;
  final String? downloadedTooltip;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final tile = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: titleMaxLines,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.text,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
                if (metadata != null) ...[const SizedBox(height: 4), metadata!],
                ResourceTagBadges(tags: tags),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );

    Widget row = Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: downloadedTooltip == null
            ? null
            : Border.all(color: const Color(0xFF2E9C7A), width: 1),
      ),
      child: tile,
    );
    final tooltip = downloadedTooltip;
    if (tooltip != null) {
      row = Tooltip(message: tooltip, child: row);
    }
    return row;
  }
}

String formatResourceDownloadedTooltip(AppL10n l, String value) {
  if (value.isEmpty) return '';
  final dt = DateTime.tryParse(value);
  if (dt == null) return l.resourceRecentlyDownloaded(value);
  final local = dt.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final mo = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  final h = local.hour.toString().padLeft(2, '0');
  final mi = local.minute.toString().padLeft(2, '0');
  return l.resourceRecentlyDownloadedAt('$y-$mo-$d $h:$mi');
}

/// Segmented resource/subtitle tab button shared by the OMM and DBO panels.
class ResourcePanelTabButton extends StatelessWidget {
  const ResourcePanelTabButton({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? colors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
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
        child: Text(
          label,
          style: TextStyle(
            color: active ? colors.text : colors.muted,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

/// Resource-quality badges shared by the OMM and DBO resource panels.
class ResourceTagBadges extends StatelessWidget {
  const ResourceTagBadges({
    super.key,
    required this.tags,
    this.showNormal = false,
  });

  final List<String> tags;
  final bool showNormal;

  @override
  Widget build(BuildContext context) {
    final normalized = tags
        .map((tag) => tag.trim().toLowerCase())
        .where((tag) => tag.isNotEmpty)
        .toList(growable: false);
    final hasUhd = normalized.any(
      (tag) => tag.contains('uhd') || tag.contains('4k'),
    );
    final hasHd =
        !hasUhd &&
        normalized.any((tag) => tag.contains('hd') || tag.contains('高清'));
    final hasSubtitle = normalized.any(
      (tag) => tag.contains('字幕') || tag.contains('sub'),
    );
    final hasCrack = normalized.any(
      (tag) => tag.contains('破解') || tag.contains('无码') || tag == 'uncensored',
    );
    final hasLada = normalized.any((tag) => tag == 'lada');

    if (!showNormal &&
        !hasUhd &&
        !hasHd &&
        !hasSubtitle &&
        !hasCrack &&
        !hasLada) {
      return const SizedBox.shrink();
    }

    final l = AppL10n.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          if (showNormal && !hasUhd && !hasHd)
            _ResourceTagBadge(
              label: l.dbOnlineDownloadRecordsNormal,
              icon: Icons.video_file_outlined,
              color: appColors(context).muted,
            ),
          if (hasUhd)
            const _ResourceTagBadge(
              label: 'UHD',
              icon: Icons.tv_rounded,
              color: Color(0xFF2D6CDF),
            )
          else if (hasHd)
            const _ResourceTagBadge(
              label: 'HD',
              icon: Icons.tv_rounded,
              color: Color(0xFF10B981),
            ),
          if (hasSubtitle)
            _ResourceTagBadge(
              label: l.movieFlagSubtitle,
              icon: Icons.closed_caption_rounded,
              color: const Color(0xFFFF9F1C),
            ),
          if (hasLada)
            const _ResourceTagBadge(
              label: 'LADA',
              icon: Icons.auto_awesome_rounded,
              color: Color(0xFFA855F7),
            )
          else if (hasCrack)
            _ResourceTagBadge(
              label: l.movieFlagCrack,
              icon: Icons.lock_open_rounded,
              color: const Color(0xFFE91E63),
            ),
        ],
      ),
    );
  }
}

class _ResourceTagBadge extends StatelessWidget {
  const _ResourceTagBadge({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 10),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w800,
            fontSize: 9.5,
            height: 1,
            letterSpacing: 0.3,
          ),
        ),
      ],
    ),
  );
}

/// Subtitle-list row shared by OMM's Thunder panel and DBO's subtitle panel.
class SubtitlePanelRow extends StatelessWidget {
  const SubtitlePanelRow({
    super.key,
    required this.title,
    required this.previewing,
    required this.downloading,
    required this.onPreview,
    required this.onDownload,
    this.details,
    this.index,
    this.disableOtherActionWhileBusy = false,
  });

  final String title;
  final Widget? details;
  final int? index;
  final bool previewing;
  final bool downloading;
  final VoidCallback onPreview;
  final VoidCallback onDownload;
  final bool disableOtherActionWhileBusy;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final l = AppL10n.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (index != null) ...[
            SizedBox(
              width: 24,
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '$index',
                  style: TextStyle(
                    color: colors.muted,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.text,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    height: 1.3,
                  ),
                ),
                if (details != null) ...[const SizedBox(height: 5), details!],
              ],
            ),
          ),
          const SizedBox(width: 6),
          _SubtitlePanelAction(
            tooltip: l.subtitlePreview,
            loading: previewing,
            icon: Icons.visibility_outlined,
            onPressed:
                previewing || (disableOtherActionWhileBusy && downloading)
                ? null
                : onPreview,
          ),
          const SizedBox(width: 4),
          _SubtitlePanelAction(
            tooltip: l.subtitleDownload,
            loading: downloading,
            icon: Icons.download_rounded,
            color: colors.accent,
            onPressed:
                downloading || (disableOtherActionWhileBusy && previewing)
                ? null
                : onDownload,
          ),
        ],
      ),
    );
  }
}

class _SubtitlePanelAction extends StatelessWidget {
  const _SubtitlePanelAction({
    required this.tooltip,
    required this.loading,
    required this.icon,
    required this.onPressed,
    this.color,
  });

  final String tooltip;
  final bool loading;
  final IconData icon;
  final Color? color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return IconButton(
      tooltip: tooltip,
      iconSize: 18,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      icon: loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, color: color ?? colors.text2),
      onPressed: onPressed,
    );
  }
}
