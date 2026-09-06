import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/api/dio_factory.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/models/avdb_config.dart';
import 'package:omm/core/models/dbo_config.dart';
import 'package:omm/core/models/mapping_rule.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/shared/glass.dart';
import 'package:omm/shared/sheet_controls.dart';
import 'package:omm/features/oh_my_media/configs/configs_providers.dart';
import 'package:omm/features/oh_my_media/actor_associations/actor_associations_providers.dart';
import 'package:omm/features/oh_my_media/actor_associations/actor_associations_repository.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

part 'actor_association_sync_widgets.dart';

part 'actor_association_sync_session.dart';

part 'actor_association_sync_actions.dart';

/// 数据源显示名：混合渠道走本地化，其余沿用模型自带品牌名（DB Online / AVDB）。
String _actorSourceLabel(AppL10n l, ActorDataSource? source) {
  if (source == null) return '';
  return switch (source) {
    ActorDataSource.dbonline => 'DB Online',
    ActorDataSource.avdb => 'AVDB',
    ActorDataSource.mixed => l.actorAssocSourceMixed,
  };
}

/// 同步演员关联 sheet · 选择数据源预览, 用户确认后应用
class ActorAssociationSyncSheet extends ConsumerStatefulWidget {
  const ActorAssociationSyncSheet({
    super.key,
    required this.actor,
    this.currentBiography,
    this.onBiographyApplied,
    this.onAvatarApplied,
  });
  final MappingRule actor;
  final String? currentBiography;
  final ValueChanged<String>? onBiographyApplied;
  final VoidCallback? onAvatarApplied;

  static Future<bool?> show(
    BuildContext context,
    MappingRule actor, {
    String? currentBiography,
    ValueChanged<String>? onBiographyApplied,
    VoidCallback? onAvatarApplied,
  }) {
    return showGlassSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ActorAssociationSyncSheet(
        actor: actor,
        currentBiography: currentBiography,
        onBiographyApplied: onBiographyApplied,
        onAvatarApplied: onAvatarApplied,
      ),
    );
  }

  @override
  ConsumerState<ActorAssociationSyncSheet> createState() =>
      _ActorAssociationSyncSheetState();
}

class _ActorAssociationSyncSheetState
    extends ConsumerState<ActorAssociationSyncSheet> {
  void _updateViewState(VoidCallback update) => setState(update);

  bool _loading = true;
  String? _error;
  ActorAssocPreview? _preview;
  ActorDataSource _source = ActorDataSource.dbonline;
  List<ActorDataSource> _availableSources = const [];
  Set<String> _selectedAliases = <String>{};
  bool _sourcesLoaded = false;
  bool _applying = false;
  // 混合渠道渐进预览仍在采集的渠道；非空时禁用应用，避免写入半合并的身份数据
  List<String> _pendingSources = const [];
  final Map<String, Uint8List> _avatarChoiceBytes = <String, Uint8List>{};
  final Set<String> _avatarChoiceLoading = <String>{};
  final Set<String> _avatarChoiceFailed = <String>{};
  final ValueNotifier<int> _avatarPickerRevision = ValueNotifier<int>(0);
  // 多选候选索引 · 默认全选,用户调整后不再自动跟随新增候选
  Set<int> _selectedAvatarChoices = <int>{};
  bool _avatarManuallySelected = false;
  int _loadRequestId = 0;

  String get _actorName => widget.actor.mappedValue?.trim().isNotEmpty == true
      ? widget.actor.mappedValue!
      : (widget.actor.originalValues.isNotEmpty
            ? widget.actor.originalValues.first
            : '');

  List<ActorAssociationAvatarChoice> _avatarChoicesFor(
    ActorAssocPreview preview,
  ) {
    final seen = <String>{};
    return preview.avatarChoices
        .where(
          (choice) =>
              choice.downloadUrl.isNotEmpty && seen.add(choice.downloadUrl),
        )
        .toList(growable: false);
  }

  /// 未手动调整过选择时,默认全选所有候选(含渐进补齐的新候选)
  void _syncDefaultAvatarSelection(ActorAssocPreview preview) {
    if (_avatarManuallySelected) return;
    _selectedAvatarChoices = {
      for (var i = 0; i < _avatarChoicesFor(preview).length; i++) i,
    };
  }

  /// 已选且预览加载未失败的候选,按候选顺序排列(提交顺序与此一致)
  List<(int, ActorAssociationAvatarChoice)> _selectedChoicesFor(
    ActorAssocPreview preview,
  ) {
    final choices = _avatarChoicesFor(preview);
    return [
      for (var i = 0; i < choices.length; i++)
        if (_selectedAvatarChoices.contains(i) &&
            !_avatarChoiceFailed.contains(choices[i].downloadUrl))
          (i, choices[i]),
    ];
  }

  /// 预览圆形大头像 · 取第一张已选候选;无可用时返回空串走占位兜底
  String _previewAvatarUrlFor(ActorAssocPreview preview) {
    final selected = _selectedChoicesFor(preview);
    return selected.isEmpty ? '' : selected.first.$2.downloadUrl;
  }

  /// 混合渠道的候选携带具体来源（dbonline/avdb），代理下载按候选来源选择下载方式；
  /// 单渠道或无来源标记时回退当前数据源。
  ActorDataSource _avatarDownloadSource(String url) {
    final preview = _preview;
    if (preview == null || _source != ActorDataSource.mixed) return _source;
    for (final choice in _avatarChoicesFor(preview)) {
      if (choice.downloadUrl == url && choice.source.isNotEmpty) {
        return actorDataSourceFromValue(choice.source) ?? _source;
      }
    }
    return _source;
  }

  /// 混合渠道 apply 时按所选候选构建 地址 → 来源 映射；单渠道返回 null。
  Map<String, String>? _avatarSourcesFor(ActorAssocPreview preview) {
    if (_source != ActorDataSource.mixed) return null;
    final sources = <String, String>{};
    for (final (_, choice) in _selectedChoicesFor(preview)) {
      if (choice.source.isNotEmpty) {
        sources[choice.downloadUrl] = choice.source;
      }
    }
    return sources;
  }

  Uint8List? get _previewAvatarBytes {
    final preview = _preview;
    if (preview == null) return null;
    return _avatarChoiceBytes[_previewAvatarUrlFor(preview)];
  }

  bool get _previewAvatarLoading {
    final preview = _preview;
    if (preview == null) return false;
    return _avatarChoiceLoading.contains(_previewAvatarUrlFor(preview));
  }

  bool get _previewAvatarLoadFailed {
    final preview = _preview;
    if (preview == null) return false;
    return _avatarChoiceFailed.contains(_previewAvatarUrlFor(preview));
  }

  @override
  void initState() {
    super.initState();
    _source =
        ActorAssociationsRepository.loadRememberedSource(
          ref.read(sharedPrefsProvider),
        ) ??
        ActorDataSource.dbonline;
    unawaited(_load());
  }

  @override
  void dispose() {
    _avatarPickerRevision.dispose();
    super.dispose();
  }

  bool _hasSyncChanges(ActorAssocPreview preview) {
    return _selectedAliases.isNotEmpty ||
        _biographyNeedsSync(preview) ||
        _canSyncAvatars(preview);
  }

  bool _canSyncAvatars(ActorAssocPreview preview) {
    final canReplace = !preview.avatarExists || _avatarManuallySelected;
    return canReplace && _selectedChoicesFor(preview).isNotEmpty;
  }

  bool _allAliasesSelected(ActorAssocPreview preview) {
    return preview.newAliases.isNotEmpty &&
        preview.newAliases.every(_selectedAliases.contains);
  }

  void _toggleAllAliases(ActorAssocPreview preview) {
    setState(() {
      if (_allAliasesSelected(preview)) {
        _selectedAliases.clear();
      } else {
        _selectedAliases.addAll(preview.newAliases);
      }
    });
  }

  bool _biographyNeedsSync(ActorAssocPreview preview) {
    if (preview.biographyChanged != null) {
      return preview.biographyChanged!;
    }
    if (widget.currentBiography == null) return false;
    return ActorAssociationsRepository.biographyNeedsSync(
      widget.currentBiography,
      preview.biography,
    );
  }

  /// 混合渠道渐进预览：先完成的渠道立即上屏（提前结束 loading），后到的渠道补齐。
  /// 轮询循环由 _loadRequestId / _source / mounted 变化自然终止。

  /// 混合渠道未命中的渠道显示名（请求成功但没有匹配演员）
  List<String> get _notFoundSources =>
      _preview?.notFoundSources ?? const <String>[];

  /// 后端当前以“渠道名称 + 渠道查询失败”前缀返回混合渠道错误警告。
  Set<String> get _failedSources {
    final result = <String>{};
    for (final warning in _preview?.warnings ?? const <String>[]) {
      if (warning.startsWith('DB Online 渠道查询失败')) {
        result.add('dbonline');
      } else if (warning.startsWith('AVDB 渠道查询失败')) {
        result.add('avdb');
      }
    }
    return result;
  }

  bool get _hasChannelStatuses =>
      _pendingSources.isNotEmpty ||
      _notFoundSources.isNotEmpty ||
      _failedSources.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final l = AppL10n.of(context);
    final preview = _preview;
    final canApply =
        preview != null &&
        preview.found &&
        _hasSyncChanges(preview) &&
        !_applying;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetHeader(
          icon: Icons.sync_alt_outlined,
          title: l.actorAssocSyncTitle(_actorName),
          subtitle: l.actorAssocSyncSubtitle,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
          child: _ActorDataSourceSelector(
            sources: _availableSources,
            notFoundSources: _notFoundSources,
            failedSources: _failedSources,
            selectedSource: _source,
            enabled: !_applying,
            onChanged: _selectSource,
          ),
        ),
        Flexible(
          fit: FlexFit.loose,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? _ErrorView(message: _error!, onRetry: _load)
              : preview == null
              ? const _NoPreviewView()
              : !preview.found
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      fit: FlexFit.loose,
                      child: _EmptyView(actorName: _actorName),
                    ),
                    if (_hasChannelStatuses)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
                        child: _ActorChannelStatusSummary(
                          pendingSources: _pendingSources,
                          notFoundSources: _notFoundSources,
                          failedSources: _failedSources,
                        ),
                      ),
                    if (preview.warnings.isNotEmpty)
                      _WarningsSection(warnings: preview.warnings),
                  ],
                )
              : ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
                  children: [
                    if (preview.warnings.isNotEmpty) ...[
                      _WarningsSection(warnings: preview.warnings),
                      const SizedBox(height: 16),
                    ],
                    _ActorIdentitySection(
                      mappedValue: preview.mappedValue,
                      avatarExists: preview.avatarExists,
                      avatarChoices: _avatarChoicesFor(preview),
                      selectedAvatarCount: _selectedChoicesFor(preview).length,
                      activeBytes: _previewAvatarBytes,
                      activeLoading: _previewAvatarLoading,
                      activeLoadFailed: _previewAvatarLoadFailed,
                      avatarManuallySelected: _avatarManuallySelected,
                      pendingSources: _pendingSources,
                      notFoundSources: _notFoundSources,
                      failedSources: _failedSources,
                      onAvatarTap: _applying
                          ? null
                          : () => unawaited(_openAvatarPicker()),
                    ),
                    if (_biographyNeedsSync(preview)) ...[
                      const SizedBox(height: 16),
                      _BiographySection(biography: preview.biography),
                    ],
                    const SizedBox(height: 16),
                    _AliasSection(
                      title: l.actorAssocSyncNewAliasesTitle(
                        _selectedAliases.length,
                        preview.newAliases.length,
                      ),
                      empty: l.actorAssocSyncNoNewAliases,
                      aliases: preview.newAliases,
                      color: c.accent,
                      highlight: true,
                      selectedAliases: _selectedAliases,
                      allSelected: _allAliasesSelected(preview),
                      onToggleAll: _applying || preview.newAliases.isEmpty
                          ? null
                          : () => _toggleAllAliases(preview),
                      onToggle: (alias) {
                        if (_applying) return;
                        setState(() {
                          if (_selectedAliases.contains(alias)) {
                            _selectedAliases.remove(alias);
                          } else {
                            _selectedAliases.add(alias);
                          }
                        });
                      },
                    ),
                    if (preview.existingAliases.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _AliasSection(
                        title: l.actorAssocSyncExistingTitle,
                        empty: '',
                        aliases: preview.existingAliases,
                        color: c.muted,
                        highlight: false,
                      ),
                    ],
                  ],
                ),
        ),
        SheetActionBar(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _applying
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: Text(l.cancel),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: canApply ? _apply : null,
                  icon: _applying
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_download_outlined, size: 18),
                  label: Text(
                    _applying
                        ? l.actorAssocSyncApplying
                        : l.actorAssocSyncApply,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
