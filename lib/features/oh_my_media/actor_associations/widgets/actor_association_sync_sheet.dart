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

  Future<void> _load({ActorDataSource? source}) async {
    final requestId = ++_loadRequestId;
    final selectedSource = source ?? _source;
    setState(() {
      _loading = true;
      _error = null;
      _pendingSources = const [];
      _avatarChoiceBytes.clear();
      _avatarChoiceLoading.clear();
      _avatarChoiceFailed.clear();
      _selectedAvatarChoices = <int>{};
      _avatarManuallySelected = false;
    });
    try {
      if (!_sourcesLoaded) {
        final available = await _loadAvailableSources();
        if (!mounted || requestId != _loadRequestId) return;
        if (available.isEmpty) {
          throw StateError('请先在服务器设置中配置并启用 DB Online 或 AVDB 数据源');
        }
        setState(() {
          _availableSources = available;
          _sourcesLoaded = true;
          if (!_availableSources.contains(_source)) {
            _source = _availableSources.first;
          }
        });
        // 先让数据源选择器完成一帧渲染，再开始预览请求，避免加载状态与选择器状态竞态。
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted || requestId != _loadRequestId) return;
      }
      final actualSource = _availableSources.contains(selectedSource)
          ? selectedSource
          : _source;
      if (actualSource == ActorDataSource.mixed) {
        await _loadMixedPreview(requestId, actualSource);
        return;
      }
      final repo = ref.read(actorAssociationsRepositoryProvider);
      final p = await repo.previewSource(_actorName, source: actualSource);
      if (!mounted || requestId != _loadRequestId || actualSource != _source) {
        return;
      }
      setState(() {
        _preview = p;
        _selectedAliases = p.newAliases.toSet();
        _syncDefaultAvatarSelection(p);
        _loading = false;
      });
      unawaited(_loadAvatarPreviews(p, actualSource));
    } catch (e) {
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        _error = toApiException(e).message;
        _loading = false;
      });
    }
  }

  /// 混合渠道渐进预览：先完成的渠道立即上屏（提前结束 loading），后到的渠道补齐。
  /// 轮询循环由 _loadRequestId / _source / mounted 变化自然终止。
  Future<void> _loadMixedPreview(int requestId, ActorDataSource source) async {
    final repo = ref.read(actorAssociationsRepositoryProvider);
    final taskId = await repo.startMixedPreviewSession(_actorName);
    if (!mounted || requestId != _loadRequestId || source != _source) return;

    var rendered = false;
    var lastChoiceCount = -1;
    final startedAt = DateTime.now();
    while (mounted && requestId == _loadRequestId && source == _source) {
      final session = await repo.getMixedPreviewSession(taskId);
      if (!mounted || requestId != _loadRequestId || source != _source) return;

      final p = session.preview;
      if (p != null && p.found) {
        final choiceCount = _avatarChoicesFor(p).length;
        setState(() {
          _preview = p;
          _selectedAliases = p.newAliases.toSet();
          _syncDefaultAvatarSelection(p);
          _pendingSources = session.pendingSources;
          if (!rendered) {
            rendered = true;
            _loading = false;
          }
        });
        // 仅在新候选出现时补拉头像，避免每次轮询重复入队
        if (choiceCount != lastChoiceCount) {
          lastChoiceCount = choiceCount;
          unawaited(_loadAvatarPreviews(p, source));
        }
      }
      if (session.complete) {
        setState(() {
          _preview = session.preview;
          _selectedAliases = session.preview?.newAliases.toSet() ?? <String>{};
          final finalPreview = session.preview;
          if (finalPreview != null && finalPreview.found) {
            _syncDefaultAvatarSelection(finalPreview);
          }
          _pendingSources = const [];
          _loading = false;
        });
        final finalPreview = session.preview;
        if (finalPreview != null && finalPreview.found) {
          final choiceCount = _avatarChoicesFor(finalPreview).length;
          if (choiceCount != lastChoiceCount) {
            unawaited(_loadAvatarPreviews(finalPreview, source));
          }
        }
        return;
      }
      if (session.failed) {
        throw StateError(session.error.isEmpty ? '混合渠道查询失败' : session.error);
      }
      if (DateTime.now().difference(startedAt) > const Duration(seconds: 90)) {
        throw StateError('混合渠道预览超时');
      }
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
  }

  Future<void> _loadAvatarPreviews(
    ActorAssocPreview preview,
    ActorDataSource source,
  ) async {
    final urls = [
      for (final choice in _avatarChoicesFor(preview)) choice.downloadUrl,
    ];
    if (urls.isEmpty) return;
    var cursor = 0;
    Future<void> worker() async {
      while (cursor < urls.length) {
        final url = urls.elementAt(cursor++);
        await _loadAvatarPreview(preview, source, url);
      }
    }

    final workerCount = urls.length < 4 ? urls.length : 4;
    await Future.wait(List.generate(workerCount, (_) => worker()));
  }

  Future<void> _loadAvatarPreview(
    ActorAssocPreview preview,
    ActorDataSource source,
    String avatarUrl,
  ) async {
    final url = avatarUrl.trim();
    // 不比较 _preview 对象身份：渐进补齐会替换 preview 对象，但按 URL 缓存的
    // 头像字节仍然有效；仅以数据源切换/组件销毁判定过期。
    if (url.isEmpty || !mounted || _source != source) {
      return;
    }
    if (_avatarChoiceBytes.containsKey(url) ||
        _avatarChoiceLoading.contains(url)) {
      return;
    }
    setState(() {
      _avatarChoiceLoading.add(url);
      _avatarChoiceFailed.remove(url);
    });
    _avatarPickerRevision.value++;
    try {
      final bytes = await ref
          .read(actorAssociationsRepositoryProvider)
          .previewAvatar(url, source: _avatarDownloadSource(url));
      if (!mounted || _source != source) return;
      if (bytes.isEmpty) throw StateError('头像内容为空');
      setState(() {
        _avatarChoiceBytes[url] = Uint8List.fromList(bytes);
        _avatarChoiceLoading.remove(url);
        _avatarChoiceFailed.remove(url);
      });
      _avatarPickerRevision.value++;
    } catch (_) {
      if (!mounted || _source != source) return;
      setState(() {
        _avatarChoiceLoading.remove(url);
        _avatarChoiceFailed.add(url);
      });
      _avatarPickerRevision.value++;
    }
  }

  Future<void> _openAvatarPicker() async {
    final preview = _preview;
    if (_applying || preview == null) return;
    final choices = _avatarChoicesFor(preview);
    if (choices.length <= 1) return;

    final result = await showGlassSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AvatarChoicePicker(
        mappedValue: preview.mappedValue,
        choices: choices,
        selectedIndices: _selectedAvatarChoices,
        avatarBytes: _avatarChoiceBytes,
        avatarLoading: _avatarChoiceLoading,
        avatarLoadFailed: _avatarChoiceFailed,
        revision: _avatarPickerRevision,
        onRetry: (url) => unawaited(_loadAvatarPreview(preview, _source, url)),
      ),
    );
    if (!mounted || result == null) return;
    if (_applying) return;
    setState(() {
      _selectedAvatarChoices = result;
      _avatarManuallySelected = true;
    });
  }

  Future<List<ActorDataSource>> _loadAvailableSources() async {
    Future<DboConfig?> loadDbo() async {
      try {
        return await ref.read(dboConfigProvider.future);
      } catch (_) {
        return null;
      }
    }

    Future<AvdbConfig?> loadAvdb() async {
      try {
        return await ref.read(avdbConfigProvider.future);
      } catch (_) {
        return null;
      }
    }

    final configs = await Future.wait<Object?>([loadDbo(), loadAvdb()]);
    return configuredActorDataSources(
      dbonline: configs[0] as DboConfig?,
      avdb: configs[1] as AvdbConfig?,
    );
  }

  void _selectSource(ActorDataSource source) {
    if (_applying || source == _source) return;
    setState(() {
      _source = source;
      _preview = null;
      _selectedAliases = <String>{};
      _pendingSources = const [];
      _avatarChoiceBytes.clear();
      _avatarChoiceLoading.clear();
      _avatarChoiceFailed.clear();
      _selectedAvatarChoices = <int>{};
      _avatarManuallySelected = false;
    });
    unawaited(
      ActorAssociationsRepository.rememberSource(
        ref.read(sharedPrefsProvider),
        source,
      ),
    );
    unawaited(_load(source: source));
  }

  Future<void> _apply() async {
    final preview = _preview;
    if (preview == null || _applying) return;
    if (!_hasSyncChanges(preview)) return;

    final biographyChanged = _biographyNeedsSync(preview);
    final avatarChanged = _canSyncAvatars(preview);
    final selectedAliases = preview.newAliases
        .where(_selectedAliases.contains)
        .toList(growable: false);
    // 按候选顺序提交所选头像,后端依次下载保存为多张可轮播封面
    final avatarUrls = avatarChanged
        ? [
            for (final (_, choice) in _selectedChoicesFor(preview))
              choice.downloadUrl,
          ]
        : const <String>[];
    setState(() => _applying = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final merged = ActorAssociationsRepository.mergeAliases(
        widget.actor.originalValues,
        selectedAliases,
        preview.mappedValue.isNotEmpty
            ? preview.mappedValue
            : widget.actor.mappedValue ?? '',
      );
      await ref
          .read(actorAssociationsRepositoryProvider)
          .applySource(
            mappedValue: preview.mappedValue.isNotEmpty
                ? preview.mappedValue
                : widget.actor.mappedValue ?? '',
            originalValues: merged,
            source: _source,
            biography: biographyChanged ? preview.biography : null,
            avatarUrls: avatarUrls,
            avatarOverwrite: avatarChanged && preview.avatarExists,
            avatarSources: avatarChanged ? _avatarSourcesFor(preview) : null,
            externalIds:
                _source == ActorDataSource.mixed &&
                    preview.externalIds.isNotEmpty
                ? preview.externalIds
                : null,
          );
      if (!mounted) return;
      // 成功只提示结果，详细情况仅在失败时展示；回调仍需驱动外部状态刷新
      if (biographyChanged) {
        widget.onBiographyApplied?.call(preview.biography.trim());
      }
      if (avatarChanged) {
        widget.onAvatarApplied?.call();
      }
      messenger.showSnackBar(const SnackBar(content: Text('同步完成')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('应用失败: ${toApiException(e).message}')),
      );
      setState(() => _applying = false);
    }
  }

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
          title: '同步演员关联: $_actorName',
          subtitle: '从选定数据源拉取演员别名预览',
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
                      title:
                          '待新增名称（已选 ${_selectedAliases.length}/${preview.newAliases.length}）',
                      empty: '没有需要新增的关联名称',
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
                        title: '已有关联',
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
                  child: const Text('取消'),
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
                  label: Text(_applying ? '应用中...' : '确认添加'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

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
    if (sources.isEmpty) {
      return Text('正在加载数据源...', style: AppText.meta(context));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.cloud_outlined, size: 18, color: c.muted),
            const SizedBox(width: 6),
            Text('数据源', style: AppText.meta(context)),
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
    final hasStatus = notFound || failed;
    final statusLabel = failed ? '请求失败' : '无匹配';
    void select() {
      if (enabled && !selected) onChanged(source);
    }

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: hasStatus ? '${source.label}，$statusLabel' : source.label,
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
                        source.label,
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
    final hasPreview = activeBytes != null && activeBytes!.isNotEmpty;
    final total = avatarChoices.length;
    final status = activeLoading
        ? avatarExists
              ? '正在获取数据源头像，可多选后替换本地'
              : '正在获取头像...'
        : selectedAvatarCount == 0
        ? '未选择头像（点头像候选调整）'
        : avatarExists
        ? avatarManuallySelected
              ? '将替换本地头像（已选 $selectedAvatarCount 张）'
              : '本地已有头像（不覆盖）'
        : activeLoadFailed
        ? '头像获取失败'
        : '将同步头像（已选 $selectedAvatarCount 张）';
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
                label: total > 1 ? '选择候选头像' : '演员头像',
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
                    Text('标准演员', style: AppText.meta(context)),
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
    // 加载失败的候选滞后到末尾展示，不占靠前的位置；保留原始索引供选中回传
    final ordered = <(int, ActorAssociationAvatarChoice)>[
      for (var i = 0; i < widget.choices.length; i++)
        if (!widget.avatarLoadFailed.contains(widget.choices[i].downloadUrl))
          (i, widget.choices[i]),
      for (var i = 0; i < widget.choices.length; i++)
        if (widget.avatarLoadFailed.contains(widget.choices[i].downloadUrl))
          (i, widget.choices[i]),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SheetHeader(
          icon: Icons.account_box_outlined,
          title: '选择演员头像',
          subtitle:
              '${widget.mappedValue.isEmpty ? '演员' : widget.mappedValue} · '
              '已选 ${_selected.length}/${widget.choices.length} 张'
              '${widget.avatarLoadFailed.isEmpty ? '' : '（${widget.avatarLoadFailed.length} 张加载失败已后置，点击可重试）'}',
          trailing: TextButton.icon(
            onPressed: _toggleAll,
            icon: Icon(
              _selected.length == ordered.length
                  ? Icons.deselect
                  : Icons.select_all,
              size: 16,
            ),
            label: Text(_selected.length == ordered.length ? '清空' : '全选'),
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
                    ? '重试第 ${index + 1} 张演员头像'
                    : '选择第 ${index + 1} 张演员头像',
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
                                  ? '点击重试'
                                  : selected
                                  ? '已选'
                                  : '候选 ${index + 1}',
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
              label: Text('确定（${_selected.length} 张）'),
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
        final label = actorDataSourceFromValue(source)?.label ?? source;
        statuses.add(
          _ActorChannelStatusPill(
            icon: icon,
            color: color,
            label: '$label $suffix',
            spinning: spinning,
          ),
        );
      }
    }

    addStatus(
      failedSources,
      icon: Icons.error_outline,
      color: c.danger,
      suffix: '请求失败',
    );
    addStatus(
      notFoundSources,
      icon: Icons.search_off_rounded,
      color: c.muted,
      suffix: '无匹配',
    );
    addStatus(
      pendingSources,
      icon: Icons.sync,
      color: c.warning,
      suffix: '查询中',
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
          Text('演员简介', style: AppText.cardTitle(context)),
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
                label: Text(allSelected ? '取消全选' : '全选'),
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
              '暂无预览数据',
              style: TextStyle(color: c.text, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '完成数据源请求后，外部接口返回的演员信息会显示在这里。',
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
              '请求失败',
              style: TextStyle(color: c.danger, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.muted, fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('重试')),
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
              '未找到匹配演员',
              style: TextStyle(color: c.text, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '外部数据源没有找到“$actorName”的匹配结果。',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.muted, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}
