import 'package:flutter/material.dart';

import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

Future<({String name, int hue})?> showCreateListDialog(
  BuildContext context, {
  InputDecoration? inputDecoration,
}) => showDialog<({String name, int hue})>(
  context: context,
  builder: (_) => _CreateListDialog(inputDecoration: inputDecoration),
);

class _CreateListDialog extends StatefulWidget {
  const _CreateListDialog({this.inputDecoration});

  final InputDecoration? inputDecoration;

  @override
  State<_CreateListDialog> createState() => _CreateListDialogState();
}

class _CreateListDialogState extends State<_CreateListDialog> {
  final _name = TextEditingController();
  int _hue = AppHues.lavender;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return AlertDialog(
      title: Text(l.newList),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            textAlignVertical: TextAlignVertical.center,
            decoration:
                widget.inputDecoration ??
                InputDecoration(
                  hintText: l.listNameHint,
                  prefixIcon: const Icon(Icons.label_outline),
                ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            children: AppHues.all.map((hue) {
              final selected = hue == _hue;
              return GestureDetector(
                key: ValueKey(hue),
                onTap: () => setState(() => _hue = hue),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppHues.top(hue), AppHues.bottom(hue)],
                    ),
                    border: Border.all(
                      color: selected ? Colors.white : Colors.transparent,
                      width: 2,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: AppHues.top(hue).withValues(alpha: 0.4),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, (name: _name.text.trim(), hue: _hue)),
          child: Text(l.listCreate),
        ),
      ],
    );
  }
}
