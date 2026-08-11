import 'dart:async';

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

/// 演员关联数据源同步 sheet · 选择数据源预览, 用户确认后应用
class ActorAssociationSyncSheet extends ConsumerStatefulWidget {
  const ActorAssociationSyncSheet({
    super.key,
    required this.actor,
    this.currentBiography,
    this.onBiographyApplied,
  });
  final MappingRule actor;
  final String? currentBiography;
  final ValueChanged<String>? onBiographyApplied;

  static Future<bool?> show(
    BuildContext context,
    MappingRule actor, {
    String? currentBiography,
    ValueChanged<String>? onBiographyApplied,
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
  bool _sourcesLoaded = false;
  bool _applying = false;

  String get _actorName =>
      widget.actor.mappedValue?.trim().isNotEmpty == true
          ? widget.actor.mappedValue!
          : (widget.actor.originalValues.isNotEmpty
              ? widget.actor.originalValues.first
              : '');

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
    return preview.newAliases.isNotEmpty ||
        ActorAssociationsRepository.biographyNeedsSync(
          widget.currentBiography,
          preview.biography,
        );
  }

  Future<void> _load({ActorDataSource? source}) async {
    final selectedSource = source ?? _source;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!_sourcesLoaded) {
        final available = await _loadAvailableSources();
        if (!mounted) return;
        _availableSources = available;
        _sourcesLoaded = true;
        if (_availableSources.isEmpty) {
          throw StateError('请先在服务器设置中配置并启用 DB Online 或 AVDB 数据源');
        }
        if (!_availableSources.contains(_source)) {
          _source = _availableSources.first;
        }
      }
      final actualSource = _availableSources.contains(selectedSource)
          ? selectedSource
          : _source;
      final repo = ref.read(actorAssociationsRepositoryProvider);
      final p = await repo.previewSource(_actorName, source: actualSource);
      if (!mounted || actualSource != _source) return;
      setState(() {
        _preview = p;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || (source != null && selectedSource != _source)) return;
      setState(() {
        _error = toApiException(e).message;
        _loading = false;
      });
    }
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

  Future<void> _apply() async {
    final preview = _preview;
    if (preview == null || _applying) return;
    if (!_hasSyncChanges(preview)) return;

    final biographyChanged = ActorAssociationsRepository.biographyNeedsSync(
      widget.currentBiography,
      preview.biography,
    );
    setState(() => _applying = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final merged = ActorAssociationsRepository.mergeAliases(
        widget.actor.originalValues,
        preview.newAliases,
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
          );
      if (!mounted) return;
      final changes = <String>[];
      if (preview.newAliases.isNotEmpty) {
        changes.add('添加 ${preview.newAliases.length} 个关联名称');
      }
      if (biographyChanged) {
        changes.add('更新演员简介');
        widget.onBiographyApplied?.call(preview.biography.trim());
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
                  Text('数据源同步: $_actorName',
                      style: AppText.sectionTitle(context)),
                  const SizedBox(height: 2),
                  Text('从选定数据源拉取演员别名预览',
                      style: AppText.meta(context)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ActorDataSource>(
                    initialValue: _source,
                    decoration: const InputDecoration(
                      labelText: '数据源',
                      prefixIcon: Icon(Icons.cloud_outlined),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      for (final source in _availableSources)
                        DropdownMenuItem(
                          value: source,
                          child: Text(source.label),
                        ),
                    ],
                    onChanged: _loading || _applying
                        ? null
                        : (source) {
                            if (source == null || source == _source) return;
                            setState(() {
                              _source = source;
                              _preview = null;
                            });
                            unawaited(
                              ActorAssociationsRepository.rememberSource(
                                ref.read(sharedPrefsProvider),
                                source,
                              ),
                            );
                            unawaited(_load(source: source));
                          },
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
                                    _SummaryRow(
                                      mappedValue: preview.mappedValue,
                                      newCount: preview.newAliases.length,
                                    ),
                                    if (ActorAssociationsRepository
                                        .biographyNeedsSync(
                                      widget.currentBiography,
                                      preview.biography,
                                    )) ...[
                                      const SizedBox(height: 16),
                                      _BiographySection(
                                        biography: preview.biography,
                                      ),
                                    ],
                                    const SizedBox(height: 16),
                                    _AliasSection(
                                      title: '待新增名称',
                                      empty: '没有需要新增的关联名称',
                                      aliases: preview.newAliases,
                                      color: c.accent,
                                      highlight: true,
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

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.mappedValue, required this.newCount});
  final String mappedValue;
  final int newCount;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.cardBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('标准演员', style: AppText.meta(context)),
                const SizedBox(height: 3),
                Text(
                  mappedValue.isEmpty ? '-' : mappedValue,
                  style: TextStyle(
                    color: c.text,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('新增别名', style: AppText.meta(context)),
              const SizedBox(height: 3),
              Text(
                '$newCount',
                style: TextStyle(
                  color: c.accent,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ],
          ),
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
  });
  final String title;
  final String empty;
  final List<String> aliases;
  final Color color;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
              color: c.text,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 13,
            )),
        const SizedBox(height: 8),
        if (aliases.isEmpty)
          Text(empty, style: AppText.meta(context))
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final a in aliases)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: highlight
                        ? color.withValues(alpha: 0.15)
                        : c.chipBg,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: highlight
                          ? color.withValues(alpha: 0.45)
                          : c.cardBorder,
                    ),
                  ),
                  child: Text(
                    a,
                    style: TextStyle(
                      color: highlight ? color : c.text,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
      ],
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
