part of 'db_online_subscriptions_page.dart';

/// 综合订阅全部子类型，顺序与网页端分享弹窗一致。
const List<String> _shareSeriesTypes = [
  'series',
  'maker',
  'publisher',
  'director',
  'list',
  'prefix',
  'follow',
];

/// 导出配置的持久化键（记忆上次选择的订阅类型）。
const String _shareExportFormKey = 'db_online.subscriptions.share_export.v1';

/// 综合订阅子类型的标签与图标（导出配置与编辑器实体预览共用）。
(String, IconData) _seriesTypeMeta(AppL10n l, String subType) => switch (
  subType
) {
  'maker' => (l.dbOnlineSeriesTypeMaker, Icons.domain_outlined),
  'publisher' => (l.dbOnlineSeriesTypePublisher, Icons.business_center_outlined),
  'director' => (l.dbOnlineSeriesTypeDirector, Icons.videocam_outlined),
  'list' => (l.dbOnlineSeriesTypeList, Icons.featured_play_list_outlined),
  'prefix' => (l.dbOnlineSeriesTypePrefix, Icons.tag_outlined),
  'follow' => (l.dbOnlineSeriesTypeFollow, Icons.person_search_outlined),
  _ => (l.dbOnlineSeriesTypeSeries, Icons.workspaces_outlined),
};

/// 订阅分享码导出配置：选择影片/演员/综合订阅（七种子类型）后生成
/// 分享码，选择会持久化，与网页端 SubscriptionShareModal 行为一致。
class DbOnlineSubscriptionShareExportSheet extends ConsumerStatefulWidget {
  const DbOnlineSubscriptionShareExportSheet({super.key, required this.l});

  final AppL10n l;

  @override
  ConsumerState<DbOnlineSubscriptionShareExportSheet> createState() =>
      _ShareExportSheetState();
}

class _ShareExportSheetState
    extends ConsumerState<DbOnlineSubscriptionShareExportSheet> {
  late bool _video = _stored['video'] != false;
  late bool _actor = _stored['actor'] != false;
  late List<String> _types = _storedTypes;

  /// 上次保存的选择；无记录或子类型全被剔除时回退全选。
  Map<String, dynamic> get _stored {
    final raw = ref.read(sharedPrefsProvider).getString(_shareExportFormKey);
    if (raw == null || raw.isEmpty) return const <String, dynamic>{};
    try {
      final parsed = jsonDecode(raw);
      return parsed is Map ? Map<String, dynamic>.from(parsed) : const {};
    } catch (_) {
      return const <String, dynamic>{};
    }
  }

  List<String> get _storedTypes {
    final value = _stored['types'];
    if (value is! List) return List<String>.of(_shareSeriesTypes);
    final filtered = _shareSeriesTypes
        .where((type) => value.contains(type))
        .toList(growable: false);
    return filtered.isEmpty ? List<String>.of(_shareSeriesTypes) : filtered;
  }

  void _persist() {
    unawaited(
      ref
          .read(sharedPrefsProvider)
          .setString(
            _shareExportFormKey,
            jsonEncode({
              'video': _video,
              'actor': _actor,
              'types': List<String>.of(_types),
            }),
          ),
    );
  }

  void _toggleType(String type) => setState(() {
    _types = _types.contains(type)
        ? _types.where((item) => item != type).toList(growable: false)
        : [..._types, type];
    _persist();
  });

  bool get _canExport => _video || _actor || _types.isNotEmpty;

  Map<String, dynamic> get _result => {
    'video': _video,
    'actor': _actor,
    'types': List<String>.of(_types),
  };

  @override
  Widget build(BuildContext context) {
    final l = widget.l;
    final colors = appColors(context);
    Widget sectionLabel(String text) => Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Text(
        text,
        style: AppText.meta(context).copyWith(fontWeight: FontWeight.w700),
      ),
    );
    Widget chip(String label, IconData icon, bool active, VoidCallback onTap) =>
        CompactFilterButton(label: label, icon: icon, active: active, onTap: onTap);
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
                icon: Icons.ios_share_rounded,
                title: l.dbOnlineSubscriptionExport,
                trailing: TextButton(
                  onPressed: _canExport
                      ? () => Navigator.pop(context, _result)
                      : null,
                  child: Text(l.dbOnlineSubscriptionShareGenerate),
                ),
              ),
              sectionLabel(l.dbOnlineSubscriptionShareSelectTypes),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  chip(
                    l.dbOnlineSubscriptionShareVideoSubs,
                    Icons.movie_outlined,
                    _video,
                    () => setState(() {
                      _video = !_video;
                      _persist();
                    }),
                  ),
                  chip(
                    l.dbOnlineSubscriptionShareActorSubs,
                    Icons.person_outline_rounded,
                    _actor,
                    () => setState(() {
                      _actor = !_actor;
                      _persist();
                    }),
                  ),
                ],
              ),
              sectionLabel(l.dbOnlineSubscriptionComprehensive),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final type in _shareSeriesTypes)
                    chip(
                      _seriesTypeMeta(l, type).$1,
                      _seriesTypeMeta(l, type).$2,
                      _types.contains(type),
                      () => _toggleType(type),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                l.dbOnlineSubscriptionShareExportHint,
                style: AppText.meta(context).copyWith(color: colors.muted),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: _canExport
                    ? () => Navigator.pop(context, _result)
                    : null,
                style: sheetPrimaryButtonStyle(context),
                child: Text(l.dbOnlineSubscriptionShareGenerate),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 导出结果：统计摘要（按所选类型过滤）+ 分享码展示与复制。
class DbOnlineSubscriptionShareResultSheet extends StatefulWidget {
  const DbOnlineSubscriptionShareResultSheet({
    super.key,
    required this.shareText,
    required this.summary,
    required this.video,
    required this.actor,
    required this.seriesTypes,
  });

  final String shareText;
  final Map<String, dynamic> summary;
  final bool video;
  final bool actor;
  final Set<String> seriesTypes;

  @override
  State<DbOnlineSubscriptionShareResultSheet> createState() =>
      _ShareResultSheetState();
}

class _ShareResultSheetState extends State<DbOnlineSubscriptionShareResultSheet> {
  bool _copied = false;

  int _count(String key) =>
      int.tryParse(widget.summary[key]?.toString() ?? '') ?? 0;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.shareText));
    if (!mounted) return;
    setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final colors = appColors(context);
    final stats = <(String, int)>[
      if (widget.video) (l.dbOnlineSubscriptionShareVideoSubs, _count('video_count')),
      if (widget.actor) (l.dbOnlineSubscriptionShareActorSubs, _count('actor_count')),
      if (widget.seriesTypes.isNotEmpty) ...[
        (l.dbOnlineSubscriptionComprehensive, _count('series_count')),
        (l.dbOnlineSubscriptionShareSeriesVideos, _count('series_video_count')),
      ],
    ].where((row) => row.$2 > 0).toList(growable: false);
    final seriesByType = widget.summary['series_by_type'];
    final breakdown = <String, Map<String, dynamic>>{};
    if (seriesByType is Map) {
      for (final entry in seriesByType.entries) {
        final type = entry.key.toString();
        if (!widget.seriesTypes.contains(type) || entry.value is! Map) continue;
        final value = Map<String, dynamic>.from(entry.value as Map);
        if ((int.tryParse(value['count']?.toString() ?? '') ?? 0) > 0) {
          breakdown[type] = value;
        }
      }
    }
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetHeader(
              icon: Icons.ios_share_rounded,
              title: l.dbOnlineSubscriptionShare,
            ),
            if (stats.isNotEmpty) ...[
              for (final (label, value) in stats)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(label, style: AppText.meta(context)),
                      ),
                      Text(
                        '$value',
                        style: AppText.meta(
                          context,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
            ],
            if (breakdown.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final entry in breakdown.entries)
                      _ShareStatPill(
                        icon: _seriesTypeMeta(l, entry.key).$2,
                        label:
                            '${_seriesTypeMeta(l, entry.key).$1} '
                            '${entry.value['count']}',
                      ),
                  ],
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  l.dbOnlineSubscriptionShareCode,
                  style: AppText.meta(
                    context,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.chipBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.cardBorder),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  widget.shareText,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: widget.shareText.isEmpty ? null : _copy,
              style: sheetPrimaryButtonStyle(context),
              icon: Icon(_copied ? Icons.check_rounded : Icons.copy_rounded, size: 18),
              label: Text(
                _copied
                    ? l.dbOnlineSubscriptionShareCopied
                    : l.dbOnlineSubscriptionShareCopy,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 导出结果统计里的静态展示标签（不可点击）。
class _ShareStatPill extends StatelessWidget {
  const _ShareStatPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.chipBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colors.accent),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: colors.text,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}
