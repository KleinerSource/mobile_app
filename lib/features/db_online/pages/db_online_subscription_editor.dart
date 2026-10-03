part of 'db_online_subscriptions_page.dart';

Future<Map<String, dynamic>?> showDbOnlineSubscriptionEditor(
  BuildContext context, {
  required String kind,
  required Map<String, dynamic> initial,
  bool isEdit = false,
}) => showGlassSheet<Map<String, dynamic>>(
  context: context,
  builder: (context) => DbOnlineSubscriptionEditor(
    kind: kind,
    initial: initial,
    l: AppL10n.of(context),
    isEdit: isEdit,
  ),
);

class DbOnlineSubscriptionEditor extends StatefulWidget {
  const DbOnlineSubscriptionEditor({
    super.key,
    required this.kind,
    required this.initial,
    required this.l,
    this.presetOnly = false,
    this.isEdit = false,
  });

  final String kind;
  final Map<String, dynamic> initial;
  final AppL10n l;
  final bool presetOnly;
  final bool isEdit;

  @override
  State<DbOnlineSubscriptionEditor> createState() =>
      _DbOnlineSubscriptionEditorState();
}

class _DbOnlineSubscriptionEditorState
    extends State<DbOnlineSubscriptionEditor> {
  late final TextEditingController _id = TextEditingController(
    text: _value(const ['video_code', 'actor_id', 'external_id', 'id']),
  );
  late final TextEditingController _name = TextEditingController(
    text: _value(const ['video_title', 'actor_name', 'series_name', 'name']),
  );
  late final _requirements = DbOnlineDownloadRequirementsController(
    DbOnlineRecheckRequirements.fromJson({
      ...widget.initial,
      'after_date': _value(const ['after_date', 'start_date']),
    }),
  );
  late final TextEditingController _overdueDays = TextEditingController(
    text: _value(const ['overdue_days'], fallback: '0'),
  );
  late final TextEditingController _includeCategories = TextEditingController(
    text: _stringList(widget.initial['include_categories']),
  );
  late final TextEditingController _excludeCategories = TextEditingController(
    text: _stringList(widget.initial['exclude_categories']),
  );
  late bool _active =
      (widget.initial['enabled'] ?? widget.initial['active']) != false;

  String _value(List<String> keys, {String fallback = ''}) {
    for (final key in keys) {
      final value = widget.initial[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return fallback;
  }

  @override
  void dispose() {
    for (final controller in [
      _id,
      _name,
      _overdueDays,
      _includeCategories,
      _excludeCategories,
    ]) {
      controller.dispose();
    }
    _requirements.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.l;
    final title = widget.presetOnly
        ? l.dbOnlineSubscriptionPreset
        : widget.isEdit
        ? l.dbOnlineSubscriptionEdit
        : l.dbOnlineSubscriptionAdd;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          22,
          8,
          22,
          18 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetHeader(
                icon: widget.kind == 'actor'
                    ? Icons.person_add_alt_1_rounded
                    : widget.kind == 'series'
                    ? Icons.layers_outlined
                    : Icons.subscriptions_outlined,
                title: title,
              ),
              if (!widget.presetOnly) ...[
                _field(
                  _id,
                  widget.kind == 'video'
                      ? l.dbOnlineSubscriptionCode
                      : l.dbOnlineSubscriptionId,
                  readOnly: true,
                ),
                _field(_name, l.dbOnlineSubscriptionName, readOnly: true),
              ],
              DbOnlineDownloadRequirementsFields(
                controller: _requirements,
                qualityTrailing: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.dbOnlineSubscriptionActive),
                  value: _active,
                  onChanged: (value) => setState(() => _active = value),
                ),
              ),
              _field(
                _overdueDays,
                l.dbOnlineSubscriptionOverdueDays,
                numeric: true,
              ),
              if (widget.kind == 'actor') ...[
                _field(
                  _includeCategories,
                  l.dbOnlineSubscriptionIncludeCategories,
                ),
                _field(
                  _excludeCategories,
                  l.dbOnlineSubscriptionExcludeCategories,
                ),
              ],
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _save,
                child: Text(l.dbOnlineSubscriptionSave),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l.dbOnlineSubscriptionCancel),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool numeric = false,
    bool readOnly = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: controller,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: readOnly
            ? const Icon(Icons.lock_outline_rounded, size: 18)
            : null,
      ),
    ),
  );

  void _save() {
    if (!widget.presetOnly &&
        !widget.isEdit &&
        (_id.text.trim().isEmpty || _name.text.trim().isEmpty)) {
      return;
    }
    final requirements = _requirements.value;
    final values = <String, dynamic>{
      ...widget.initial,
      if (widget.presetOnly) 'enabled': _active,
      if (!widget.presetOnly) 'active': _active,
      'pre_download_mode': _requirements.preDownloadMode,
      'wash_mode': _requirements.washMode,
      'quality': _requirements.quality,
      'require_sub': _requirements.requireSub,
      'require_uncensored': _requirements.requireUncensored,
      'min_size_mb': requirements.minSizeMb,
      'max_size_mb': requirements.maxSizeMb,
      'max_file_count': requirements.maxFileCount,
      'overdue_days': int.tryParse(_overdueDays.text) ?? 0,
      if (widget.kind == 'video') 'after_date': requirements.afterDate,
      if (widget.kind != 'video') 'start_date': requirements.afterDate,
      if (widget.kind == 'actor')
        'include_categories': _parseList(_includeCategories.text),
      if (widget.kind == 'actor')
        'exclude_categories': _parseList(_excludeCategories.text),
    };
    if (!widget.presetOnly && !widget.isEdit) {
      switch (widget.kind) {
        case 'video':
          values['video_code'] = _id.text.trim();
          values['video_title'] = _name.text.trim();
        case 'actor':
          values['actor_id'] = _id.text.trim();
          values['actor_name'] = _name.text.trim();
        case 'series':
          values['external_id'] = _id.text.trim();
          values['sub_type'] =
              widget.initial['sub_type']?.toString() ?? 'series';
          values['series_name'] = _name.text.trim();
      }
    }
    Navigator.pop(context, values);
  }

  List<String> _parseList(String value) => value
      .split(RegExp(r'[,\n]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}
