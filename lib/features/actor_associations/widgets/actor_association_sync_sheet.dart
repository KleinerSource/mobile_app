import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/dio_factory.dart';
import '../../../core/config/server_config_provider.dart';
import '../../../core/models/avdb_config.dart';
import '../../../core/models/dbo_config.dart';
import '../../../core/models/mapping_rule.dart';
import '../../../core/platform/app_theme.dart';
import '../../configs/configs_providers.dart';
import '../actor_associations_providers.dart';
import '../actor_associations_repository.dart';

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
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: appColors(context).bg,
      isScrollControlled: true,
      showDragHandle: true,
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
  final Map<String, Uint8List> _avatarChoiceBytes = <String, Uint8List>{};
  final Set<String> _avatarChoiceLoading = <String>{};
  final Set<String> _avatarChoiceFailed = <String>{};
  int _avatarChoiceIndex = 0;
  bool _avatarManuallySelected = false;
  int _loadRequestId = 0;

  String get _actorName =>
      widget.actor.mappedValue?.trim().isNotEmpty == true
          ? widget.actor.mappedValue!
          : (widget.actor.originalValues.isNotEmpty
              ? widget.actor.originalValues.first
              : '');

  List<ActorAssociationAvatarChoice> _avatarChoicesFor(
    ActorAssocPreview preview,
  ) {
    final seen = <String>{};
    return preview.avatarChoices
        .where((choice) =>
            choice.proxyUrl.isNotEmpty && seen.add(choice.proxyUrl))
        .toList(growable: false);
  }

  String _activeAvatarUrlFor(ActorAssocPreview preview) {
    final choices = _avatarChoicesFor(preview);
    if (choices.isNotEmpty) {
      final index = _avatarChoiceIndex < choices.length ? _avatarChoiceIndex : 0;
      return choices[index].proxyUrl;
    }
    return preview.avatarUrl;
  }

  Uint8List? get _activeAvatarBytes {
    final preview = _preview;
    if (preview == null) return null;
    return _avatarChoiceBytes[_activeAvatarUrlFor(preview)];
  }

  bool get _activeAvatarLoading {
    final preview = _preview;
    return preview != null &&
        _avatarChoiceLoading.contains(_activeAvatarUrlFor(preview));
  }

  bool get _activeAvatarLoadFailed {
    final preview = _preview;
    return preview != null &&
        _avatarChoiceFailed.contains(_activeAvatarUrlFor(preview));
  }

  @override
  void initState() {
    super.initState();
    _source = ActorAssociationsRepository.loadRememberedSource(
          ref.read(sharedPrefsProvider),
        ) ??
        ActorDataSource.dbonline;
    unawaited(_load());
  }

  bool _hasSyncChanges(ActorAssocPreview preview) {
    return _selectedAliases.isNotEmpty ||
        _biographyNeedsSync(preview) ||
        _canSyncAvatar(preview);
  }

  bool _canSyncAvatar(ActorAssocPreview preview) {
    final canReplace = !preview.avatarExists || _avatarManuallySelected;
    return canReplace &&
        _activeAvatarUrlFor(preview).isNotEmpty &&
        _activeAvatarBytes != null &&
        !_activeAvatarLoadFailed;
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
      _avatarChoiceBytes.clear();
      _avatarChoiceLoading.clear();
      _avatarChoiceFailed.clear();
      _avatarChoiceIndex = 0;
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
      final repo = ref.read(actorAssociationsRepositoryProvider);
      final p = await repo.previewSource(_actorName, source: actualSource);
      if (!mounted ||
          requestId != _loadRequestId ||
          actualSource != _source) {
        return;
      }
      setState(() {
        _preview = p;
        _selectedAliases = p.newAliases.toSet();
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

  Future<void> _loadAvatarPreviews(
    ActorAssocPreview preview,
    ActorDataSource source,
  ) async {
    final choices = _avatarChoicesFor(preview);
    final urls = choices.isNotEmpty
        ? choices.map((choice) => choice.proxyUrl)
        : <String>[preview.avatarUrl];
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
    if (url.isEmpty || !mounted || _preview != preview || _source != source) {
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
    try {
      final bytes = await ref
          .read(actorAssociationsRepositoryProvider)
          .previewAvatar(url, source: source);
      if (!mounted || _preview != preview || _source != source) return;
      if (bytes.isEmpty) throw StateError('头像内容为空');
      setState(() {
        _avatarChoiceBytes[url] = Uint8List.fromList(bytes);
        _avatarChoiceLoading.remove(url);
        _avatarChoiceFailed.remove(url);
      });
    } catch (_) {
      if (!mounted || _preview != preview || _source != source) return;
      setState(() {
        _avatarChoiceLoading.remove(url);
        _avatarChoiceFailed.add(url);
      });
    }
  }

  void _selectAvatarChoice(int index) {
    final preview = _preview;
    if (_applying || preview == null) return;
    final choices = _avatarChoicesFor(preview);
    if (index < 0 || index >= choices.length || index == _avatarChoiceIndex) {
      return;
    }
    setState(() {
      _avatarChoiceIndex = index;
      _avatarManuallySelected = true;
    });
    unawaited(
      _loadAvatarPreview(preview, _source, choices[index].proxyUrl),
    );
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
      _avatarChoiceBytes.clear();
      _avatarChoiceLoading.clear();
      _avatarChoiceFailed.clear();
      _avatarChoiceIndex = 0;
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
    final avatarChanged = _canSyncAvatar(preview);
    final activeAvatarUrl = _activeAvatarUrlFor(preview);
    final selectedAliases = preview.newAliases
        .where(_selectedAliases.contains)
        .toList(growable: false);
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
      await ref.read(actorAssociationsRepositoryProvider).applySource(
            mappedValue: preview.mappedValue.isNotEmpty
                ? preview.mappedValue
                : widget.actor.mappedValue ?? '',
            originalValues: merged,
            source: _source,
            biography: biographyChanged ? preview.biography : null,
            avatarUrl: avatarChanged ? activeAvatarUrl : null,
            avatarOverwrite: avatarChanged && preview.avatarExists,
          );
      if (!mounted) return;
      final changes = <String>[];
      if (selectedAliases.isNotEmpty) {
        changes.add('添加 ${selectedAliases.length} 个关联名称');
      }
      if (biographyChanged) {
        changes.add('更新演员简介');
        widget.onBiographyApplied?.call(preview.biography.trim());
      }
      if (avatarChanged) {
        changes.add(preview.avatarExists ? '替换演员头像' : '同步演员头像');
        widget.onAvatarApplied?.call();
      }
      messenger.showSnackBar(
        SnackBar(content: Text('同步完成：${changes.join('，')}')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('应用失败: ${toApiException(e).message}'),
      ));
      setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final mq = MediaQuery.of(context);
    final preview = _preview;
    final canApply = preview != null &&
        preview.found &&
        _hasSyncChanges(preview) &&
        !_applying;
    return SizedBox(
      height: mq.size.height * 0.78,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 6, 22, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('同步演员关联: $_actorName',
                      style: AppText.sectionTitle(context)),
                  const SizedBox(height: 2),
                  Text('从选定数据源拉取演员别名预览',
                      style: AppText.meta(context)),
                  const SizedBox(height: 12),
                  _ActorDataSourceSelector(
                    sources: _availableSources,
                    selectedSource: _source,
                    enabled: !_applying,
                    onChanged: _selectSource,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _ErrorView(message: _error!, onRetry: _load)
                      : preview == null
                          ? const Center(child: Text('无数据'))
                          : !preview.found
                              ? _EmptyView(actorName: _actorName)
                              : ListView(
                                  padding: const EdgeInsets.fromLTRB(
                                      22, 14, 22, 14),
                                  children: [
                                    _ActorIdentitySection(
                                      mappedValue: preview.mappedValue,
                                      avatarExists: preview.avatarExists,
                                      avatarChoices: _avatarChoicesFor(preview),
                                      selectedChoiceIndex: _avatarChoiceIndex,
                                      avatarBytes: _avatarChoiceBytes,
                                      avatarLoading: _avatarChoiceLoading,
                                      avatarLoadFailed: _avatarChoiceFailed,
                                      activeBytes: _activeAvatarBytes,
                                      activeLoading: _activeAvatarLoading,
                                      activeLoadFailed: _activeAvatarLoadFailed,
                                      avatarManuallySelected:
                                          _avatarManuallySelected,
                                      onChoiceSelected: _applying
                                          ? null
                                          : _selectAvatarChoice,
                                    ),
                                    if (_biographyNeedsSync(preview)) ...[
                                      const SizedBox(height: 16),
                                      _BiographySection(
                                        biography: preview.biography,
                                      ),
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
                                      onToggleAll: _applying ||
                                              preview.newAliases.isEmpty
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
            Container(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 10),
              decoration: BoxDecoration(
                color: c.bg,
                border: Border(top: BorderSide(color: c.divider)),
              ),
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
        ),
      ),
    );
  }
}

class _ActorDataSourceSelector extends StatelessWidget {
  const _ActorDataSourceSelector({
    required this.sources,
    required this.selectedSource,
    required this.onChanged,
    this.enabled = true,
  });

  final List<ActorDataSource> sources;
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
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final ActorDataSource source;
  final bool selected;
  final bool enabled;
  final ValueChanged<ActorDataSource> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    void select() {
      if (enabled && !selected) onChanged(source);
    }

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: source.label,
      child: Material(
        color: selected ? c.accent.withValues(alpha: 0.10) : c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: selected ? c.accent : c.cardBorder,
            width: selected ? 1.5 : 1,
          ),
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
                child: Text(
                  source.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: enabled
                        ? (selected ? c.accent : c.text)
                        : c.muted,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                    fontSize: 13,
                  ),
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
    required this.selectedChoiceIndex,
    required this.avatarBytes,
    required this.avatarLoading,
    required this.avatarLoadFailed,
    required this.activeBytes,
    required this.activeLoading,
    required this.activeLoadFailed,
    required this.avatarManuallySelected,
    this.onChoiceSelected,
  });

  final String mappedValue;
  final bool avatarExists;
  final List<ActorAssociationAvatarChoice> avatarChoices;
  final int selectedChoiceIndex;
  final Map<String, Uint8List> avatarBytes;
  final Set<String> avatarLoading;
  final Set<String> avatarLoadFailed;
  final Uint8List? activeBytes;
  final bool activeLoading;
  final bool activeLoadFailed;
  final bool avatarManuallySelected;
  final ValueChanged<int>? onChoiceSelected;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final hasPreview = activeBytes != null && activeBytes!.isNotEmpty;
    final status = activeLoading
        ? avatarExists
            ? '正在获取数据源头像，可选择后替换本地'
            : '正在获取头像...'
        : avatarExists
            ? avatarManuallySelected && hasPreview
                ? '已选择数据源头像，将替换本地头像'
                : hasPreview
                    ? '数据源头像预览（本地已有头像，不覆盖）'
                    : '本地已有头像，可选择候选替换'
            : activeLoadFailed
                ? '头像获取失败，不会同步头像'
                : hasPreview
                    ? '将同步头像'
                    : '数据源未提供头像';
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
                              child: CircularProgressIndicator(strokeWidth: 2),
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
              else if (hasPreview)
                Icon(
                  avatarExists && !avatarManuallySelected
                      ? Icons.visibility_outlined
                      : Icons.check_circle,
                  color: avatarExists && !avatarManuallySelected
                      ? c.muted
                      : c.accent,
                  size: 20,
                )
              else if (activeLoadFailed)
                Icon(Icons.error_outline, color: c.danger, size: 20),
            ],
          ),
          if (avatarChoices.length > 1) ...[
            const SizedBox(height: 12),
            Text('候选头像 · 点击选择', style: AppText.meta(context)),
            const SizedBox(height: 8),
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: avatarChoices.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final choice = avatarChoices[index];
                  final url = choice.proxyUrl;
                  final bytes = avatarBytes[url];
                  final selected = index == selectedChoiceIndex;
                  final loading = avatarLoading.contains(url);
                  final failed = avatarLoadFailed.contains(url);
                  return Semantics(
                    button: true,
                    selected: selected,
                    label: '候选头像 ${index + 1}',
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onChoiceSelected == null
                            ? null
                            : () => onChoiceSelected!(index),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 70,
                          height: 92,
                          decoration: BoxDecoration(
                            color: c.chipBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selected ? c.accent : c.cardBorder,
                              width: selected ? 2 : 1,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (bytes != null && bytes.isNotEmpty)
                                Image.memory(bytes, fit: BoxFit.cover)
                              else if (loading)
                                const Center(
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              else
                                Center(
                                  child: Icon(
                                    failed
                                        ? Icons.broken_image_outlined
                                        : Icons.person_outline,
                                    color: failed ? c.danger : c.muted,
                                    size: 24,
                                  ),
                                ),
                              if (selected)
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: c.accent,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.check,
                                      color: c.chipTextActive,
                                      size: 14,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
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
          Text('演员简介（AVDB）', style: AppText.cardTitle(context)),
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
              child: Text(title,
                  style: TextStyle(
                    color: c.text,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  )),
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
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.15) : c.chipBg,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: active ? color.withValues(alpha: 0.45) : c.cardBorder,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? color : c.text,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );

    if (onTap == null) return pill;
    return Semantics(
      button: true,
      toggled: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(100),
          child: pill,
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
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: c.danger)),
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
            Text('数据源没有找到匹配演员: $actorName',
                textAlign: TextAlign.center,
                style: TextStyle(color: c.muted)),
          ],
        ),
      ),
    );
  }
}
