import 'package:flutter/material.dart';

import '../core/platform/app_theme.dart';
import '../l10n/generated/app_localizations.dart';

/// 管理类列表通用的批量操作按钮。
class EntityBatchAction {
  const EntityBatchAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.tooltip,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  final String? tooltip;
}

/// 管理类列表通用的底部批量工具栏。
class EntityBatchToolbar extends StatelessWidget {
  const EntityBatchToolbar({
    super.key,
    required this.selectedCount,
    required this.onSelectAll,
    required this.onClear,
    required this.onClose,
    required this.actions,
  });

  final int selectedCount;
  final VoidCallback onSelectAll;
  final VoidCallback onClear;
  final VoidCallback onClose;
  final List<EntityBatchAction> actions;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final c = appColors(context);
    final background = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1B1A24)
        : Colors.white;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    l.selectedN(selectedCount),
                    style: TextStyle(
                      color: c.text,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: onSelectAll,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(l.commonSelectAll),
                  ),
                  TextButton(
                    onPressed: onClear,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: c.danger,
                    ),
                    child: Text(l.commonClearSelection),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: l.commonExitSelection,
                    onPressed: onClose,
                    icon: Icon(Icons.close, size: 18, color: c.muted),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 4),
                SizedBox(
                  height: 38,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: constraints.maxWidth,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              for (var i = 0; i < actions.length; i++) ...[
                                if (i > 0) const SizedBox(width: 6),
                                _EntityBatchActionButton(action: actions[i]),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EntityBatchActionButton extends StatelessWidget {
  const _EntityBatchActionButton({required this.action});

  final EntityBatchAction action;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final enabled = action.onTap != null;
    final foreground = enabled ? (action.color ?? c.accent) : c.muted;

    final button = GestureDetector(
      onTap: action.onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: enabled ? foreground.withValues(alpha: 0.12) : c.chipBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled ? foreground.withValues(alpha: 0.4) : c.cardBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(action.icon, size: 15, color: foreground),
            const SizedBox(width: 5),
            Text(
              action.label,
              style: TextStyle(
                color: foreground,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
    final tooltip = action.tooltip;
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }
}
