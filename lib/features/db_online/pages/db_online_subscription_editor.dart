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

class DbOnlineSubscriptionEditor extends ConsumerStatefulWidget {
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
  ConsumerState<DbOnlineSubscriptionEditor> createState() =>
      _DbOnlineSubscriptionEditorState();
}

class _DbOnlineSubscriptionEditorState
    extends ConsumerState<DbOnlineSubscriptionEditor> {
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

  /// 类别过滤存储类别 external_id；兼容历史数据里的逗号分隔字符串。
  late List<String> _includeCategories = _initialCategories(
    widget.initial['include_categories'],
  );
  late List<String> _excludeCategories = _initialCategories(
    widget.initial['exclude_categories'],
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

  static List<String> _initialCategories(Object? raw) => raw is List
      ? raw
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false)
      : _parseList(raw?.toString() ?? '');

  static List<String> _parseList(String value) => value
      .split(RegExp(r'[,\n]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);

  @override
  void dispose() {
    for (final controller in [_id, _name, _overdueDays]) {
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
              // 实体展示与网页端一致：影片显示番号+名称只读字段，演员
              // 显示头像+名称，综合订阅显示类型图标+名称，均不显示编号。
              if (!widget.presetOnly) ...[
                if (widget.kind == 'video') ...[
                  _field(_id, l.dbOnlineSubscriptionCode, readOnly: true),
                  _field(_name, l.dbOnlineSubscriptionName, readOnly: true),
                ],
                if (widget.kind == 'actor') _actorPreview(),
                if (widget.kind == 'series') _seriesPreview(l),
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
                _categoriesBlock(
                  label: l.dbOnlineSubscriptionIncludeCategories,
                  hint: l.dbOnlineSubscriptionIncludeCategoriesHint,
                  selected: _includeCategories,
                  max: 5,
                  onChanged: (value) =>
                      setState(() => _includeCategories = value),
                ),
                _categoriesBlock(
                  label: l.dbOnlineSubscriptionExcludeCategories,
                  hint: l.dbOnlineSubscriptionExcludeCategoriesHint,
                  selected: _excludeCategories,
                  max: 1,
                  onChanged: (value) =>
                      setState(() => _excludeCategories = value),
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

  /// 演员订阅的实体预览：圆形头像 + 名称（新建时附别名），与订阅列表
  /// 行共用 `_SubscriptionCardArtwork` 与隐私遮罩。
  Widget _actorPreview() {
    final config = ref.watch(mediaRuntimeConfigProvider);
    final imageUrl = _resolveSubscriptionImage(config, [
      widget.initial['actor_avatar'],
      widget.initial['avatar_url'],
    ]);
    final alias = widget.initial['other_name']?.toString().trim() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          PrivacyMask(
            movieId: _id.text,
            scope: PrivacyScope.actor,
            radius: 28,
            child: _SubscriptionCardArtwork(imageUrl: imageUrl, isActor: true),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PrivacyText(
                  movieId: _id.text,
                  scope: PrivacyScope.actor,
                  text: _name.text.isEmpty ? _id.text : _name.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.cardTitle(context),
                ),
                if (!widget.isEdit && alias.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    alias,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.meta(context),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 综合订阅的实体预览：按订阅类型显示图标 + 名称 + 类型标签。
  Widget _seriesPreview(AppL10n l) {
    final subType = widget.initial['sub_type']?.toString() ?? 'series';
    final (icon, typeLabel) = switch (subType) {
      'maker' => (Icons.domain_outlined, l.dbOnlineSeriesTypeMaker),
      'publisher' => (
        Icons.business_center_outlined,
        l.dbOnlineSeriesTypePublisher,
      ),
      'director' => (Icons.videocam_outlined, l.dbOnlineSeriesTypeDirector),
      'list' => (
        Icons.featured_play_list_outlined,
        l.dbOnlineSeriesTypeList,
      ),
      'prefix' => (Icons.tag_outlined, l.dbOnlineSeriesTypePrefix),
      'follow' => (Icons.person_search_outlined, l.dbOnlineSeriesTypeFollow),
      _ => (Icons.workspaces_outlined, l.dbOnlineSeriesTypeSeries),
    };
    final colors = appColors(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: colors.chipBg,
              shape: BoxShape.circle,
              border: Border.all(color: colors.cardBorder),
            ),
            child: Icon(icon, size: 24, color: colors.muted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PrivacyText(
                  movieId: 'dbo:subscription:series:$_id.text',
                  text: _name.text.isEmpty ? _id.text : _name.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.cardTitle(context),
                ),
                const SizedBox(height: 2),
                Text(typeLabel, style: AppText.meta(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 类别过滤区块：提示 + 已选 chips（显示类别名，点 × 移除）+ 选择入口。
  Widget _categoriesBlock({
    required String label,
    required String hint,
    required List<String> selected,
    required int max,
    required ValueChanged<List<String>> onChanged,
  }) {
    final actorId = _id.text.trim();
    final categories = actorId.isEmpty
        ? null
        : ref.watch(dbOnlineActorCategoriesProvider(actorId));
    final colors = appColors(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppText.meta(
                        context,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hint,
                      style: AppText.meta(
                        context,
                      ).copyWith(color: colors.muted),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => _pickCategories(label, selected, max, onChanged),
                icon: const Icon(Icons.category_outlined, size: 18),
                label: Text(widget.l.dbOnlineSubscriptionSelectCategories),
              ),
            ],
          ),
          if (selected.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final id in selected)
                    CompactFilterButton(
                      label: _categoryName(
                        categories?.asData?.value,
                        id,
                      ),
                      active: true,
                      trailingIcon: Icons.close_rounded,
                      onTap: () => onChanged(
                        selected.where((value) => value != id).toList(),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickCategories(
    String title,
    List<String> selected,
    int max,
    ValueChanged<List<String>> onChanged,
  ) async {
    final actorId = _id.text.trim();
    if (actorId.isEmpty) return;
    final serverId = ref.read(mediaRuntimeConfigProvider)?.activeServerId ?? '';
    final result = await showGlassSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      minHeight: sheetMinHeight(context),
      builder: (_) => DbOnlineActorCategoriesSheet(
        actorId: actorId,
        title: title,
        selected: selected,
        maxSelections: max,
      ),
    );
    if (result == null || !mounted) return;
    // 弹窗打开期间切换服务器则丢弃结果，避免写入其它服务器的类别。
    if (ref.read(mediaRuntimeConfigProvider)?.activeServerId != serverId) {
      return;
    }
    onChanged(result);
  }

  String _categoryName(List<DbOnlineFollowingStyle>? items, String id) {
    for (final item in items ?? const <DbOnlineFollowingStyle>[]) {
      if (item.id == id) return item.name;
    }
    return id;
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
        'include_categories': List<String>.of(_includeCategories),
      if (widget.kind == 'actor')
        'exclude_categories': List<String>.of(_excludeCategories),
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
}
