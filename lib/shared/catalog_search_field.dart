import 'package:flutter/material.dart';

import '../core/platform/app_theme.dart';
import '../l10n/generated/app_localizations.dart';

/// 搜索与目录列表共用的输入框，提交和清空行为由页面负责。
class CatalogSearchField extends StatelessWidget {
  const CatalogSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onSubmitted,
    required this.onCleared,
    this.onChanged,
    this.leading,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onCleared;
  final ValueChanged<String>? onChanged;
  final Widget? leading;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final l = AppL10n.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.cardBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) => Row(
          children: [
            const SizedBox(width: 14),
            leading ??
                Icon(Icons.search_rounded, color: colors.muted, size: 20),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: controller,
                autofocus: autofocus,
                textInputAction: TextInputAction.search,
                textAlignVertical: TextAlignVertical.center,
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: TextStyle(
                    color: colors.muted,
                    fontWeight: FontWeight.w500,
                  ),
                  isCollapsed: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: InputBorder.none,
                ),
                style: TextStyle(
                  color: colors.text,
                  fontWeight: FontWeight.w500,
                ),
                onChanged: onChanged,
                onSubmitted: onSubmitted,
              ),
            ),
            if (value.text.isNotEmpty)
              IconButton(
                tooltip: l.commonClearInput,
                icon: Icon(Icons.close, size: 16, color: colors.muted),
                onPressed: () {
                  controller.clear();
                  onCleared();
                },
              ),
            IconButton(
              tooltip: l.searchTitle,
              icon: Icon(Icons.search, size: 18, color: colors.muted),
              onPressed: () => onSubmitted(controller.text),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}
