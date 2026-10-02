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
  late final TextEditingController _startDate = TextEditingController(
    text: _value(const ['after_date', 'start_date']),
  );
  late final TextEditingController _minimum = TextEditingController(
    text: _value(const ['min_size_mb'], fallback: '0'),
  );
  late final TextEditingController _maximum = TextEditingController(
    text: _value(const ['max_size_mb'], fallback: '0'),
  );
  late final TextEditingController _fileCount = TextEditingController(
    text: _value(const ['max_file_count'], fallback: '0'),
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
  late String _quality = _value(const ['quality']);
  late bool _active =
      (widget.initial['enabled'] ?? widget.initial['active']) != false;
  late bool _requireSub = widget.initial['require_sub'] == true;
  late bool _requireUncensored = widget.initial['require_uncensored'] == true;
  late bool _preDownload = widget.initial['pre_download_mode'] == true;
  late bool _washMode = widget.initial['wash_mode'] == true;

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
      _startDate,
      _minimum,
      _maximum,
      _fileCount,
      _overdueDays,
      _includeCategories,
      _excludeCategories,
    ]) {
      controller.dispose();
    }
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
              _sectionTitle(l.dbOnlineSubscriptionDownloadMode),
              Row(
                children: [
                  Expanded(
                    child: _choiceButton(
                      l.dbOnlineSubscriptionStrictMode,
                      !_preDownload,
                      _qualityColor('primary'),
                      () => setState(() => _preDownload = false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _choiceButton(
                      l.dbOnlineSubscriptionPreDownload,
                      _preDownload,
                      _qualityColor('info'),
                      () => setState(() => _preDownload = true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _sectionTitle(l.dbOnlineSubscriptionQuality),
              Row(
                children: [
                  Expanded(
                    child: _choiceButton(
                      l.dbOnlineSubscriptionQualityNormal,
                      _quality.isEmpty,
                      _qualityColor('neutral'),
                      () => setState(() => _quality = ''),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _choiceButton(
                      l.dbOnlineSubscriptionQualityHd,
                      _quality == 'hd',
                      _qualityColor('primary'),
                      () => setState(() => _quality = 'hd'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _choiceButton(
                      l.dbOnlineSubscriptionQualityUhd,
                      _quality == 'uhd',
                      _qualityColor('info'),
                      () => setState(() => _quality = 'uhd'),
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.dbOnlineSubscriptionActive),
                value: _active,
                onChanged: (value) => setState(() => _active = value),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _toggleButton(
                    l.dbOnlineSubscriptionSubtitle,
                    _requireSub,
                    _qualityColor('warning'),
                    () => setState(() => _requireSub = !_requireSub),
                  ),
                  _toggleButton(
                    l.dbOnlineSubscriptionUncensored,
                    _requireUncensored,
                    _qualityColor('danger'),
                    () => setState(
                      () => _requireUncensored = !_requireUncensored,
                    ),
                  ),
                  _toggleButton(
                    l.dbOnlineSubscriptionWashMode,
                    _washMode,
                    _qualityColor('secondary'),
                    () => setState(() => _washMode = !_washMode),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _sectionTitle(l.dbOnlineSubscriptionFileSize),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      _minimum,
                      l.dbOnlineSubscriptionMinimumSize,
                      numeric: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _field(
                      _maximum,
                      l.dbOnlineSubscriptionMaximumSize,
                      numeric: true,
                    ),
                  ),
                ],
              ),
              _sectionTitle(l.dbOnlineSubscriptionOtherLimits),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      _fileCount,
                      l.dbOnlineSubscriptionMaxFiles,
                      numeric: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _field(_startDate, l.dbOnlineSubscriptionStartDate),
                  ),
                ],
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

  Widget _toggleButton(
    String label,
    bool selected,
    Color color,
    VoidCallback onPressed,
  ) => _choiceButton(label, selected, color, onPressed);

  Widget _choiceButton(
    String label,
    bool selected,
    Color color,
    VoidCallback onPressed,
  ) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: selected ? color : color.withValues(alpha: 0.55),
        backgroundColor: selected
            ? color.withValues(alpha: 0.12)
            : Colors.transparent,
        side: BorderSide(
          color: selected
              ? color.withValues(alpha: 0.75)
              : color.withValues(alpha: 0.3),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 8),
    child: Text(
      title,
      style: AppText.meta(context).copyWith(fontWeight: FontWeight.w700),
    ),
  );

  Color _qualityColor(String tone) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return switch (tone) {
      'primary' => isDark ? const Color(0xFF00F3FF) : const Color(0xFF0099AA),
      'info' => isDark ? const Color(0xFF4A9EFF) : const Color(0xFF3B82F6),
      'neutral' => const Color(0xFF8B95A8),
      'warning' => isDark ? const Color(0xFFFFC107) : const Color(0xFFF59E0B),
      'danger' => const Color(0xFFFF0050),
      'secondary' => isDark ? const Color(0xFFA855F7) : const Color(0xFF9333EA),
      _ => appColors(context).accent,
    };
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
    final values = <String, dynamic>{
      ...widget.initial,
      if (widget.presetOnly) 'enabled': _active,
      if (!widget.presetOnly) 'active': _active,
      'pre_download_mode': _preDownload,
      'wash_mode': _washMode,
      'quality': _quality,
      'require_sub': _requireSub,
      'require_uncensored': _requireUncensored,
      'min_size_mb': double.tryParse(_minimum.text) ?? 0,
      'max_size_mb': double.tryParse(_maximum.text) ?? 0,
      'max_file_count': int.tryParse(_fileCount.text) ?? 0,
      'overdue_days': int.tryParse(_overdueDays.text) ?? 0,
      if (widget.kind == 'video') 'after_date': _startDate.text.trim(),
      if (widget.kind != 'video') 'start_date': _startDate.text.trim(),
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
