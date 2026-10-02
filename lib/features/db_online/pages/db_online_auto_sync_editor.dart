part of 'db_online_subscriptions_page.dart';

class _AutoSyncEditor extends StatefulWidget {
  const _AutoSyncEditor({required this.initial, required this.l});

  final Map<String, dynamic> initial;
  final AppL10n l;

  @override
  State<_AutoSyncEditor> createState() => _AutoSyncEditorState();
}

class _AutoSyncEditorState extends State<_AutoSyncEditor> {
  late bool _enabled = widget.initial['enabled'] == true;
  late final TextEditingController _schedules = TextEditingController(
    text: _scheduleText(widget.initial['schedules']),
  );

  @override
  void dispose() {
    _schedules.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        8,
        22,
        18 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SheetHeader(
            icon: Icons.sync_rounded,
            title: widget.l.dbOnlineSubscriptionAutoSync,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(widget.l.dbOnlineSubscriptionActive),
            value: _enabled,
            onChanged: (value) => setState(() => _enabled = value),
          ),
          TextField(
            controller: _schedules,
            decoration: InputDecoration(
              labelText: widget.l.dbOnlineSubscriptionSchedules,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => Navigator.pop(context, {
              ...widget.initial,
              'enabled': _enabled,
              'schedules': _schedules.text
                  .split(RegExp(r'[,\s]+'))
                  .map((value) => value.trim())
                  .where((value) => value.isNotEmpty)
                  .toList(growable: false),
            }),
            child: Text(widget.l.dbOnlineSubscriptionSave),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(widget.l.dbOnlineSubscriptionCancel),
          ),
        ],
      ),
    ),
  );
}
