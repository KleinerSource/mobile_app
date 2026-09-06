part of 'actor_association_sync_sheet.dart';

class _ActorDataSourceSelector extends StatelessWidget {
  const _ActorDataSourceSelector({
    required this.sources,
    required this.notFoundSources,
    required this.failedSources,
    required this.selectedSource,
    required this.onChanged,
    this.enabled = true,
  });

  final List<ActorDataSource> sources;
  final List<String> notFoundSources;
  final Set<String> failedSources;
  final ActorDataSource selectedSource;
  final ValueChanged<ActorDataSource> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final l = AppL10n.of(context);
    if (sources.isEmpty) {
      return Text(l.actorAssocSyncSourcesLoading, style: AppText.meta(context));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.cloud_outlined, size: 18, color: c.muted),
            const SizedBox(width: 6),
            Text(l.actorAssocSyncSourcesLabel, style: AppText.meta(context)),
          ],
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            for (var i = 0; i < sources.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _ActorDataSourceOption(
                  source: sources[i],
                  notFound: notFoundSources.contains(sources[i].value),
                  failed: failedSources.contains(sources[i].value),
                  selected: sources[i] == selectedSource,
                  enabled: enabled,
                  onChanged: onChanged,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _ActorDataSourceOption extends StatelessWidget {
  const _ActorDataSourceOption({
    required this.source,
    required this.notFound,
    required this.failed,
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final ActorDataSource source;
  final bool notFound;
  final bool failed;
  final bool selected;
  final bool enabled;
  final ValueChanged<ActorDataSource> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final l = AppL10n.of(context);
    final hasStatus = notFound || failed;
    final sourceLabel = _actorSourceLabel(l, source);
    final statusLabel = failed
        ? l.actorAssocSyncSourceFailed
        : l.actorAssocSyncSourceNoMatch;
    void select() {
      if (enabled && !selected) onChanged(source);
    }

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: hasStatus ? '$sourceLabel，$statusLabel' : sourceLabel,
      child: Material(
        color: selected ? c.accent.withValues(alpha: 0.10) : c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: selected ? c.accent : c.cardBorder, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? select : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        sourceLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: enabled
                              ? (selected ? c.accent : c.text)
                              : c.muted,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActorIdentitySection extends StatelessWidget {
  const _ActorIdentitySection({
    required this.mappedValue,
    required this.avatarExists,
    required this.avatarChoices,
    required this.selectedAvatarCount,
    required this.activeBytes,
    required this.activeLoading,
    required this.activeLoadFailed,
    required this.avatarManuallySelected,
    required this.pendingSources,
    required this.notFoundSources,
    required this.failedSources,
    this.onAvatarTap,
  });

  final String mappedValue;
  final bool avatarExists;
  final List<ActorAssociationAvatarChoice> avatarChoices;
  final int selectedAvatarCount;
  final Uint8List? activeBytes;
  final bool activeLoading;
  final bool activeLoadFailed;
  final bool avatarManuallySelected;
  final List<String> pendingSources;
  final List<String> notFoundSources;
  final Set<String> failedSources;
  final VoidCallback? onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final l = AppL10n.of(context);
    final hasPreview = activeBytes != null && activeBytes!.isNotEmpty;
    final total = avatarChoices.length;
    final status = activeLoading
        ? avatarExists
              ? l.actorAssocSyncAvatarLoadingReplace
              : l.actorAssocSyncAvatarLoading
        : selectedAvatarCount == 0
        ? l.actorAssocSyncAvatarNoneSelected
        : avatarExists
        ? avatarManuallySelected
              ? l.actorAssocSyncAvatarWillReplace(selectedAvatarCount)
              : l.actorAssocSyncAvatarExists
        : activeLoadFailed
        ? l.actorAssocSyncAvatarFailed
        : l.actorAssocSyncAvatarWillSync(selectedAvatarCount);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.cardBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Semantics(
                button: onAvatarTap != null,
                label: total > 1
                    ? l.actorAssocSyncPickAvatar
                    : l.actorAssocSyncAvatarLabel,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onAvatarTap,
                    customBorder: const CircleBorder(),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipOval(
                          child: SizedBox(
                            width: 62,
                            height: 62,
                            child: activeLoading
                                ? DecoratedBox(
                                    decoration: BoxDecoration(color: c.chipBg),
                                    child: const Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                  )
                                : hasPreview
                                ? Image.memory(activeBytes!, fit: BoxFit.cover)
                                : DecoratedBox(
                                    decoration: BoxDecoration(color: c.chipBg),
                                    child: Icon(
                                      avatarExists
                                          ? Icons.account_circle_outlined
                                          : Icons.person_outline,
                                      color: c.muted,
                                      size: 32,
                                    ),
                                  ),
                          ),
                        ),
                        if (total > 1)
                          Positioned(
                            right: -5,
                            bottom: -5,
                            child: Container(
                              constraints: const BoxConstraints(minWidth: 27),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: c.accent,
                                border: Border.all(color: c.surface, width: 2),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.collections_outlined,
                                    color: c.chipTextActive,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '$selectedAvatarCount/$total',
                                    style: TextStyle(
                                      color: c.chipTextActive,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.actorAssocSyncCanonicalLabel,
                      style: AppText.meta(context),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      mappedValue.isEmpty ? '-' : mappedValue,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.text,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      status,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: activeLoadFailed ? c.danger : c.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (activeLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (avatarExists && !avatarManuallySelected)
                Icon(Icons.visibility_outlined, color: c.muted, size: 20)
              else if (selectedAvatarCount > 0)
                Icon(Icons.check_circle, color: c.accent, size: 20)
              else if (activeLoadFailed)
                Icon(Icons.error_outline, color: c.danger, size: 20),
            ],
          ),
          if (pendingSources.isNotEmpty ||
              notFoundSources.isNotEmpty ||
              failedSources.isNotEmpty) ...[
            const SizedBox(height: 10),
            _ActorChannelStatusSummary(
              pendingSources: pendingSources,
              notFoundSources: notFoundSources,
              failedSources: failedSources,
            ),
          ],
        ],
      ),
    );
  }
}

/// 头像候选多选 · 点选切换,失败候选点击重试,确定后回传所选索引集合
class _AvatarChoicePicker extends StatefulWidget {
  const _AvatarChoicePicker({
    required this.mappedValue,
    required this.choices,
    required this.selectedIndices,
    required this.avatarBytes,
    required this.avatarLoading,
    required this.avatarLoadFailed,
    required this.revision,
    this.onRetry,
  });

  final String mappedValue;
  final List<ActorAssociationAvatarChoice> choices;
  final Set<int> selectedIndices;
  final Map<String, Uint8List> avatarBytes;
  final Set<String> avatarLoading;
  final Set<String> avatarLoadFailed;
  final ValueListenable<int> revision;
  final ValueChanged<String>? onRetry;

  @override
  State<_AvatarChoicePicker> createState() => _AvatarChoicePickerState();
}

class _AvatarChoicePickerState extends State<_AvatarChoicePicker> {
  late Set<int> _selected = {...widget.selectedIndices};

  @override
  void initState() {
    super.initState();
    // 剔除已丢失/加载失败且不在候选范围内的索引
    _selected.removeWhere(
      (index) => index < 0 || index >= widget.choices.length,
    );
  }

  void _toggle(int index) {
    setState(() {
      if (!_selected.add(index)) {
        _selected.remove(index);
      }
    });
  }

  /// 全选对象为加载未失败的候选;已全选时清空
  void _toggleAll() {
    final all = {
      for (var i = 0; i < widget.choices.length; i++)
        if (!widget.avatarLoadFailed.contains(widget.choices[i].downloadUrl)) i,
    };
    setState(() {
      _selected = _selected.containsAll(all) ? <int>{} : all;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: widget.revision,
      builder: (context, _, __) => _buildPicker(context),
    );
  }

  Widget _buildPicker(BuildContext context) {
    final c = appColors(context);
    final l = AppL10n.of(context);
    // 加载失败的候选滞后到末尾展示，不占靠前的位置；保留原始索引供选中回传
    final ordered = <(int, ActorAssociationAvatarChoice)>[
      for (var i = 0; i < widget.choices.length; i++)
        if (!widget.avatarLoadFailed.contains(widget.choices[i].downloadUrl))
          (i, widget.choices[i]),
      for (var i = 0; i < widget.choices.length; i++)
        if (widget.avatarLoadFailed.contains(widget.choices[i].downloadUrl))
          (i, widget.choices[i]),
    ];
    final pickerSubtitle = widget.avatarLoadFailed.isEmpty
        ? l.actorAssocAvatarPickerCount(
            widget.mappedValue.isEmpty
                ? l.actorAssocAvatarPickerNameFallback
                : widget.mappedValue,
            _selected.length,
            widget.choices.length,
          )
        : l.actorAssocAvatarPickerCountWithFailed(
            widget.mappedValue.isEmpty
                ? l.actorAssocAvatarPickerNameFallback
                : widget.mappedValue,
            _selected.length,
            widget.choices.length,
            widget.avatarLoadFailed.length,
          );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SheetHeader(
          icon: Icons.account_box_outlined,
          title: l.actorAssocAvatarPickerTitle,
          subtitle: pickerSubtitle,
          trailing: TextButton.icon(
            onPressed: _toggleAll,
            icon: Icon(
              _selected.length == ordered.length
                  ? Icons.deselect
                  : Icons.select_all,
              size: 16,
            ),
            label: Text(
              _selected.length == ordered.length
                  ? l.fileClearSelection
                  : l.fileSelectAll,
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: const Size(0, 30),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
        Flexible(
          fit: FlexFit.loose,
          child: GridView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 120,
              childAspectRatio: 0.78,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: ordered.length,
            itemBuilder: (context, slot) {
              final (index, choice) = ordered[slot];
              final url = choice.downloadUrl;
              final bytes = widget.avatarBytes[url];
              final loading = widget.avatarLoading.contains(url);
              final failed = widget.avatarLoadFailed.contains(url);
              final selected = _selected.contains(index);
              return Semantics(
                button: true,
                toggled: selected,
                label: failed
                    ? l.actorAssocAvatarRetrySemantics(index + 1)
                    : l.actorAssocAvatarSelectSemantics(index + 1),
                child: Material(
                  color: c.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: selected ? c.accent : c.cardBorder,
                      width: 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: failed
                        ? () => widget.onRetry?.call(url)
                        : () => _toggle(index),
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                      children: [
                        Expanded(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (bytes != null && bytes.isNotEmpty)
                                Image.memory(bytes, fit: BoxFit.cover)
                              else if (loading)
                                const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              else
                                Center(
                                  child: Icon(
                                    failed
                                        ? Icons.refresh
                                        : Icons.person_outline,
                                    color: failed ? c.danger : c.muted,
                                    size: 28,
                                  ),
                                ),
                              if (selected)
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: c.accent,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.check,
                                      color: c.chipTextActive,
                                      size: 16,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 30,
                          child: Center(
                            child: Text(
                              failed
                                  ? l.actorAssocAvatarRetry
                                  : selected
                                  ? l.actorAssocAvatarSelected
                                  : l.actorAssocAvatarCandidate(index + 1),
                              style: TextStyle(
                                color: failed ? c.danger : c.muted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(_selected),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: Text(l.actorAssocAvatarConfirm(_selected.length)),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActorChannelStatusSummary extends StatelessWidget {
  const _ActorChannelStatusSummary({
    required this.pendingSources,
    required this.notFoundSources,
    required this.failedSources,
  });

  final List<String> pendingSources;
  final List<String> notFoundSources;
  final Set<String> failedSources;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final l = AppL10n.of(context);
    final statuses = <Widget>[];
    final added = <String>{};

    void addStatus(
      Iterable<String> sources, {
      required IconData icon,
      required Color color,
      required String suffix,
      bool spinning = false,
    }) {
      for (final source in sources) {
        if (!added.add(source)) continue;
        final label = _actorSourceLabel(l, actorDataSourceFromValue(source));
        statuses.add(
          _ActorChannelStatusPill(
            icon: icon,
            color: color,
            label: '${label.isEmpty ? source : label} $suffix',
            spinning: spinning,
          ),
        );
      }
    }

    addStatus(
      failedSources,
      icon: Icons.error_outline,
      color: c.danger,
      suffix: l.actorAssocSyncSourceFailed,
    );
    addStatus(
      notFoundSources,
      icon: Icons.search_off_rounded,
      color: c.muted,
      suffix: l.actorAssocSyncSourceNoMatch,
    );
    addStatus(
      pendingSources,
      icon: Icons.sync,
      color: c.warning,
      suffix: l.actorAssocSyncSourceQuerying,
      spinning: true,
    );

    if (statuses.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 6, runSpacing: 6, children: statuses);
  }
}

class _ActorChannelStatusPill extends StatefulWidget {
  const _ActorChannelStatusPill({
    required this.icon,
    required this.color,
    required this.label,
    this.spinning = false,
  });

  final IconData icon;
  final Color color;
  final String label;
  final bool spinning;

  @override
  State<_ActorChannelStatusPill> createState() =>
      _ActorChannelStatusPillState();
}

class _ActorChannelStatusPillState extends State<_ActorChannelStatusPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.spinning) _rotationController.repeat();
  }

  @override
  void didUpdateWidget(covariant _ActorChannelStatusPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.spinning == oldWidget.spinning) return;
    if (widget.spinning) {
      _rotationController.repeat();
    } else {
      _rotationController.stop();
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icon = Icon(widget.icon, size: 13, color: widget.color);
    final iconView = widget.spinning
        // Icons.sync 的箭头为逆时针循环，反向使用控制器才能让箭头朝向
        // 与实际旋转方向保持一致。
        ? RotationTransition(
            turns: ReverseAnimation(_rotationController),
            child: icon,
          )
        : icon;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: widget.color.withValues(alpha: 0.10),
        border: Border.all(color: widget.color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconView,
          const SizedBox(width: 5),
          Text(
            widget.label,
            style: TextStyle(
              color: widget.color,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _WarningsSection extends StatelessWidget {
  const _WarningsSection({required this.warnings});

  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.cardBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < warnings.length; i++) ...[
            if (i > 0) const SizedBox(height: 5),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, size: 16, color: c.muted),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    warnings[i],
                    style: TextStyle(color: c.muted, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _BiographySection extends StatelessWidget {
  const _BiographySection({required this.biography});

  final String biography;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.cardBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppL10n.of(context).actorEditorBiographyLabel,
            style: AppText.cardTitle(context),
          ),
          const SizedBox(height: 7),
          Text(biography, style: AppText.body(context)),
        ],
      ),
    );
  }
}

class _AliasSection extends StatelessWidget {
  const _AliasSection({
    required this.title,
    required this.empty,
    required this.aliases,
    required this.color,
    required this.highlight,
    this.selectedAliases,
    this.allSelected = false,
    this.onToggleAll,
    this.onToggle,
  });
  final String title;
  final String empty;
  final List<String> aliases;
  final Color color;
  final bool highlight;
  final Set<String>? selectedAliases;
  final bool allSelected;
  final VoidCallback? onToggleAll;
  final ValueChanged<String>? onToggle;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: c.text,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            if (onToggleAll != null)
              TextButton.icon(
                onPressed: onToggleAll,
                icon: Icon(
                  allSelected ? Icons.deselect : Icons.select_all,
                  size: 16,
                ),
                label: Text(
                  allSelected
                      ? AppL10n.of(context).actorAssocDeselectAll
                      : AppL10n.of(context).fileSelectAll,
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (aliases.isEmpty)
          Text(empty, style: AppText.meta(context))
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final a in aliases)
                _AliasPill(
                  label: a,
                  color: color,
                  highlight: highlight,
                  selected: selectedAliases?.contains(a) ?? false,
                  onTap: selectedAliases != null && onToggle != null
                      ? () => onToggle!(a)
                      : null,
                ),
            ],
          ),
      ],
    );
  }
}

class _AliasPill extends StatelessWidget {
  const _AliasPill({
    required this.label,
    required this.color,
    required this.highlight,
    required this.selected,
    this.onTap,
  });

  final String label;
  final Color color;
  final bool highlight;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final active = selected || (onTap == null && highlight);
    final text = Text(
      label,
      style: TextStyle(
        color: active ? color : c.text,
        fontFamily: 'Inter',
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
    );

    if (onTap == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.15) : c.chipBg,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: active ? color.withValues(alpha: 0.45) : c.cardBorder,
            width: 1,
          ),
        ),
        child: text,
      );
    }

    return Semantics(
      button: true,
      toggled: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        shape: StadiumBorder(
          side: BorderSide(
            color: active ? color.withValues(alpha: 0.45) : c.cardBorder,
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: active ? color.withValues(alpha: 0.15) : c.chipBg,
              borderRadius: BorderRadius.circular(100),
            ),
            child: text,
          ),
        ),
      ),
    );
  }
}

class _NoPreviewView extends StatelessWidget {
  const _NoPreviewView();

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_download_outlined, color: c.muted, size: 36),
            const SizedBox(height: 8),
            Text(
              AppL10n.of(context).actorAssocSyncNoPreviewTitle,
              style: TextStyle(color: c.text, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              AppL10n.of(context).actorAssocSyncNoPreviewHint,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.muted, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: c.danger, size: 32),
            const SizedBox(height: 8),
            Text(
              AppL10n.of(context).actorAssocSyncRequestFailed,
              style: TextStyle(color: c.danger, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.muted, fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRetry,
              child: Text(AppL10n.of(context).fileRetry),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.actorName});
  final String actorName;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, color: c.muted, size: 36),
            const SizedBox(height: 8),
            Text(
              AppL10n.of(context).actorAssocSyncNoMatchTitle,
              style: TextStyle(color: c.text, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              AppL10n.of(context).actorAssocSyncNoMatchHint(actorName),
              textAlign: TextAlign.center,
              style: TextStyle(color: c.muted, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}
