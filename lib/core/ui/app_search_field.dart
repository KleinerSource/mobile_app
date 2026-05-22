import 'package:flutter/material.dart';
import 'tokens.dart';

class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    this.controller,
    required this.placeholder,
    required this.onSubmitted,
  });

  final TextEditingController? controller;
  final String placeholder;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(Icons.search, size: 18, color: c.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.search,
              onSubmitted: onSubmitted,
              style: TextStyle(fontSize: 14, color: c.text),
              cursorColor: c.brand,
              decoration: InputDecoration(
                isCollapsed: true,
                hintText: placeholder,
                hintStyle: TextStyle(fontSize: 14, color: c.textMuted),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
