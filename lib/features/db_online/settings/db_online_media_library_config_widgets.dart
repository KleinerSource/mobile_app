import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'package:omm/core/api/envelope.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/core/sources/media/dbo/db_online_api.dart';
import 'package:omm/features/settings/settings_common.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/empty_view.dart';
import 'package:omm/shared/error_view.dart';
import 'package:omm/shared/glass.dart';
import 'package:omm/shared/localized_error_message.dart';
import 'package:omm/shared/sheet_controls.dart';

import 'db_online_backend_config.dart';

String _connectionSignature(Map<String, dynamic> values) => jsonEncode([
  for (final key in [
    'host',
    'port',
    'timeout',
    'use_https',
    'api_key',
    'username',
    'password',
  ])
    values[key],
]);

class DbOnlineMediaLibrariesField extends StatefulWidget {
  const DbOnlineMediaLibrariesField({
    super.key,
    required this.api,
    required this.name,
    required this.values,
    required this.isCurrent,
    required this.onChanged,
  });
  final DbOnlineApi api;
  final String name;
  final Map<String, dynamic> values;
  final bool Function() isCurrent;
  final ValueChanged<List<String>> onChanged;

  @override
  State<DbOnlineMediaLibrariesField> createState() =>
      _MediaLibrariesFieldState();
}

class _MediaLibrariesFieldState extends State<DbOnlineMediaLibrariesField> {
  Future<void> _open() async {
    if (!widget.isCurrent()) return;
    final signature = _connectionSignature(widget.values);
    bool current() =>
        mounted &&
        widget.isCurrent() &&
        signature == _connectionSignature(widget.values);
    final result = await showGlassSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      minHeight: sheetMinHeight(context),
      builder: (_) => _MediaLibrariesSheet(
        api: widget.api,
        name: widget.name,
        values: Map<String, dynamic>.from(
          jsonDecode(jsonEncode(widget.values)) as Map,
        ),
        isCurrent: current,
      ),
    );
    if (current() && result != null) widget.onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final selected = widget.values['library_ids'] as List? ?? [];
    final enabled = widget.values['enabled'] == true;
    final validation = enabled
        ? validateDboMediaServer(widget.name, widget.values, l)
        : l.dbOnlineMediaServerRequired;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.dbOnlineMediaLibraries, style: AppText.eyebrow(context)),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: enabled && validation == null ? _open : null,
            style: sheetSecondaryButtonStyle(context),
            icon: const Icon(Icons.video_library_outlined, size: 18),
            label: Text(
              selected.isEmpty
                  ? l.dbOnlineMediaLibrariesAll
                  : l.dbOnlineMediaLibrariesSelected(selected.length),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          validation ?? l.dbOnlineMediaLibrariesHint,
          style: AppText.meta(context),
        ),
      ],
    );
  }
}

class _MediaLibrariesSheet extends StatefulWidget {
  const _MediaLibrariesSheet({
    required this.api,
    required this.name,
    required this.values,
    required this.isCurrent,
  });
  final DbOnlineApi api;
  final String name;
  final Map<String, dynamic> values;
  final bool Function() isCurrent;

  @override
  State<_MediaLibrariesSheet> createState() => _MediaLibrariesSheetState();
}

class _MediaLibrariesSheetState extends State<_MediaLibrariesSheet> {
  late final _selected = {
    for (final id in widget.values['library_ids'] as List? ?? []) id.toString(),
  };
  List<Map<String, dynamic>> _libraries = [];
  bool _loading = true;
  String? _error;
  int _generation = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_generation == 0) unawaited(_load());
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final l = AppL10n.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final libraries = await widget.api.mediaServerLibraries(
        widget.name,
        widget.values,
      );
      if (!mounted || !widget.isCurrent() || generation != _generation) return;
      setState(() {
        _libraries = libraries
            .where((item) => item['id']?.toString().isNotEmpty == true)
            .toList();
        _loading = false;
      });
    } catch (error) {
      if (mounted && widget.isCurrent() && generation == _generation) {
        setState(() {
          _error = localizedErrorMessage(l, error);
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final items = [
      ..._libraries,
      for (final id in _selected)
        if (!_libraries.any((item) => item['id'].toString() == id))
          {'id': id, 'name': id},
    ];
    return SizedBox(
      height: sheetMaxHeight(context).clamp(0.0, 560.0),
      child: Column(
        children: [
          SheetHeader(
            icon: Icons.video_library_outlined,
            title: l.dbOnlineMediaLibraries,
            trailing: IconButton(
              tooltip: l.mediaBrowserRefresh,
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l.dbOnlineMediaLibrariesHint,
                    style: AppText.meta(context),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(_selected.clear),
                  child: Text(l.dbOnlineMediaLibrariesAll),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? ErrorView.list(message: _error!, onRetry: _load)
                : items.isEmpty
                ? EmptyView(message: l.dbOnlineMediaLibrariesEmpty)
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: items.length,
                    itemBuilder: (_, index) {
                      final item = items[index];
                      final id = item['id'].toString();
                      final selected = _selected.contains(id);
                      return ListTile(
                        titleTextStyle: AppText.cardTitle(context),
                        subtitleTextStyle: AppText.meta(context),
                        title: Text(item['name']?.toString() ?? id),
                        subtitle: item['collection_type'] == null
                            ? null
                            : Text(item['collection_type'].toString()),
                        leading: Icon(
                          Icons.video_library_outlined,
                          color: appColors(context).accent,
                          size: 20,
                        ),
                        trailing: Icon(
                          selected
                              ? Icons.check_box_rounded
                              : Icons.check_box_outline_blank_rounded,
                          color: selected
                              ? appColors(context).accent
                              : appColors(context).muted,
                          size: 22,
                        ),
                        onTap: () => setState(() {
                          selected ? _selected.remove(id) : _selected.add(id);
                        }),
                      );
                    },
                  ),
          ),
          SheetActionBar(
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: sheetSecondaryButtonStyle(context),
                    child: Text(l.cancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _loading || _error != null
                        ? null
                        : () {
                            if (widget.isCurrent()) {
                              Navigator.of(context).pop(_selected.toList());
                            }
                          },
                    style: sheetPrimaryButtonStyle(context),
                    child: Text(l.save),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 入库缓存和字幕扫描沿用相同的进度、错误及页面生命周期处理。
class DbOnlineLibraryTaskPanel extends StatefulWidget {
  const DbOnlineLibraryTaskPanel({
    super.key,
    required this.api,
    required this.isCurrent,
    this.subtitles = false,
    this.hasDirectories = true,
  });
  final DbOnlineApi api;
  final bool Function() isCurrent;
  final bool subtitles;
  final bool hasDirectories;

  @override
  State<DbOnlineLibraryTaskPanel> createState() => _LibraryTaskPanelState();
}

class _LibraryTaskPanelState extends State<DbOnlineLibraryTaskPanel>
    with WidgetsBindingObserver {
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _progress;
  bool _available = false;
  bool _loading = true;
  bool _busy = false;
  bool _foreground = true;
  String? _error;
  Timer? _timer;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_generation == 0) unawaited(_load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _timer?.cancel();
      _generation++;
    } else if (mounted && widget.isCurrent()) {
      unawaited(_load());
    }
  }

  bool _current(int generation) =>
      mounted && _foreground && widget.isCurrent() && generation == _generation;

  Future<void> _load() async {
    final generation = ++_generation;
    final l = AppL10n.of(context);
    _timer?.cancel();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final health = await widget.api.subscriptions.health();
      if (!_current(generation)) return;
      if (health is Map && health['success'] == false) {
        unwrapStd<Object?>(health, (value) => value);
      }
      final body = health is Map && health['data'] is Map
          ? health['data']
          : health;
      final capabilities = body is Map ? body['capabilities'] : null;
      final available =
          capabilities is Map &&
          capabilities[widget.subtitles
                  ? 'subtitle_library'
                  : 'media_library'] ==
              true;
      setState(() {
        _available = available;
      });
      if (!available) {
        setState(() {
          _loading = false;
          _busy = false;
          _stats = null;
        });
        return;
      }
      final stats = await widget.api.libraryTaskStats(
        subtitles: widget.subtitles,
      );
      if (!_current(generation)) return;
      setState(() {
        _stats = stats;
        _loading = false;
      });
      await _poll(generation, notify: false);
    } catch (error) {
      if (_current(generation)) {
        setState(() {
          _error = localizedErrorMessage(l, error);
          _loading = false;
          _busy = false;
        });
      }
    }
  }

  Future<void> _start(String mode) async {
    if (!_available ||
        _busy ||
        !widget.isCurrent() ||
        (widget.subtitles && !widget.hasDirectories)) {
      return;
    }
    final generation = ++_generation;
    final l = AppL10n.of(context);
    _timer?.cancel();
    setState(() {
      _busy = true;
      _error = null;
      _progress = null;
    });
    try {
      final result = await widget.api.startLibraryTask(
        subtitles: widget.subtitles,
        mode: mode,
      );
      if (!_current(generation)) return;
      _message(
        envelopeMessageOrNull(result) ??
            (widget.subtitles
                ? l.dbOnlineSubtitleScanStarted
                : l.dbOnlineCacheRefreshStarted),
      );
      _schedule(generation);
    } catch (error) {
      if (!_current(generation)) return;
      if (widget.subtitles &&
          error is DioException &&
          error.response?.statusCode == 409) {
        _message(l.dbOnlineSubtitleScanBusy);
        _schedule(generation);
      } else {
        setState(() {
          _busy = false;
          _error = localizedErrorMessage(l, error);
        });
      }
    }
  }

  Future<void> _poll(int generation, {required bool notify}) async {
    final l = AppL10n.of(context);
    try {
      final progress = await widget.api.libraryTaskProgress(
        subtitles: widget.subtitles,
      );
      if (!_current(generation)) return;
      final busy =
          progress[widget.subtitles ? 'scanning' : 'refreshing'] == true;
      final wasBusy = _busy;
      setState(() {
        _progress = progress;
        _busy = busy;
      });
      if (busy) {
        _schedule(generation);
      } else if (notify || wasBusy) {
        final stats = await widget.api.libraryTaskStats(
          subtitles: widget.subtitles,
        );
        if (!_current(generation)) return;
        setState(() {
          _stats = stats;
        });
        _message(
          widget.subtitles
              ? l.dbOnlineSubtitleScanCompleted
              : l.dbOnlineCacheRefreshCompleted,
        );
      }
    } catch (error) {
      if (_current(generation)) {
        setState(() {
          _error = localizedErrorMessage(l, error);
          _busy = false;
        });
      }
    }
  }

  void _schedule(int generation) {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 500), () {
      if (_current(generation)) unawaited(_poll(generation, notify: true));
    });
  }

  void _message(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
  int _count(Map<String, dynamic>? data, String key) =>
      (data?[key] as num?)?.toInt() ?? 0;

  double get _percent {
    final progress = _progress;
    if (!widget.subtitles) {
      return ((progress?['percent'] as num?)?.toDouble() ?? 0).clamp(
        0.0,
        100.0,
      );
    }
    final counting = progress?['phase'] == 'counting';
    final total = _count(progress, counting ? 'total_dirs' : 'estimated_total');
    final completed = _count(
      progress,
      counting ? 'completed_dirs' : 'total_files',
    );
    if (total > 0) return (completed / total * 100).clamp(0.0, 99.0);
    final dirs = _count(progress, 'total_dirs');
    return counting
        ? 5
        : dirs > 0
        ? (_count(progress, 'completed_dirs') / dirs * 100).clamp(0.0, 99.0)
        : 0;
  }

  String _sourceName(String source, AppL10n l) => switch (source) {
    'emby' => 'Emby',
    'jellyfin' => 'Jellyfin',
    'fnmedia' => l.dbOnlineSectionFnMedia,
    _ => source,
  };

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final canStart =
        _available &&
        !_loading &&
        !_busy &&
        (!widget.subtitles || widget.hasDirectories);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: settingsCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.subtitles
                ? l.dbOnlineSubtitleScanning
                : l.dbOnlineCacheRefresh,
            style: AppText.eyebrow(context),
          ),
          const SizedBox(height: 8),
          if (_loading)
            const LinearProgressIndicator()
          else if (!_available && _error == null)
            Text(
              widget.subtitles
                  ? l.dbOnlineSubtitleLibraryUnavailable
                  : l.dbOnlineMediaLibraryUnavailable,
              style: AppText.meta(context),
            ),
          if (_error != null) ...[
            Text(
              _error!,
              style: AppText.meta(
                context,
              ).copyWith(color: appColors(context).danger),
            ),
            TextButton(onPressed: _load, child: Text(l.dbOnlineRetry)),
          ],
          if (_stats != null) ...[
            if (widget.subtitles) ...[
              Text(
                l.dbOnlineSubtitleIndexCounts(
                  _count(_stats, 'total_count'),
                  _count(_stats, 'unique_codes'),
                ),
                style: AppText.meta(context),
              ),
              if (_stats!['last_scan'] case final String timestamp)
                Builder(
                  builder: (context) {
                    final date = DateTime.tryParse(timestamp)?.toLocal();
                    final local = MaterialLocalizations.of(context);
                    return date == null
                        ? const SizedBox.shrink()
                        : Text(
                            l.dbOnlineSubtitleLastScan(
                              '${local.formatMediumDate(date)} ${local.formatTimeOfDay(TimeOfDay.fromDateTime(date))}',
                            ),
                            style: AppText.meta(context),
                          );
                  },
                ),
            ] else ...[
              for (final item
                  in (_stats!['libraries'] as List? ?? []).whereType<Map>())
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _sourceName(item['source']?.toString() ?? '', l),
                          style: AppText.cardTitle(context),
                        ),
                      ),
                      Text(
                        '${item['ready'] == true ? item['cache_count'] ?? 0 : l.dbOnlineCacheNotReady} / ${item['actual_count'] ?? 0}',
                        style: AppText.meta(context),
                      ),
                    ],
                  ),
                ),
              Text(
                l.dbOnlineCacheTotal(
                  _count(_stats, 'cache_total'),
                  _count(_stats, 'actual_total'),
                ),
                style: AppText.meta(context),
              ),
            ],
            const SizedBox(height: 10),
          ],
          if (_busy) ...[
            LinearProgressIndicator(
              value: _progress == null ? null : _percent / 100,
            ),
            const SizedBox(height: 6),
            Text(
              widget.subtitles
                  ? l.dbOnlineSubtitleScanProgress(
                      _count(_progress, 'total_files'),
                      _count(_progress, 'estimated_total'),
                      _count(_progress, 'completed_dirs'),
                      _count(_progress, 'total_dirs'),
                    )
                  : l.dbOnlineLibraryTaskProgress(
                      _count(_progress, 'completed'),
                      _count(_progress, 'total'),
                    ),
              style: AppText.meta(context),
            ),
            if (widget.subtitles) ...[
              if (_progress?['current_dir'] case final String directory)
                Text(
                  directory,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.meta(context),
                ),
            ],
            const SizedBox(height: 10),
          ],
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: canStart ? () => _start('incremental') : null,
                style: sheetSecondaryButtonStyle(context),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(
                  widget.subtitles
                      ? l.dbOnlineSubtitleIncrementalScan
                      : l.dbOnlineCacheRefresh,
                ),
              ),
              if (widget.subtitles)
                OutlinedButton.icon(
                  onPressed: canStart ? () => _start('full') : null,
                  style: sheetSecondaryButtonStyle(context),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(l.dbOnlineSubtitleFullScan),
                ),
            ],
          ),
          if (widget.subtitles) ...[
            const SizedBox(height: 6),
            Text(
              l.dbOnlineSubtitleScanSavedConfig,
              style: AppText.meta(context),
            ),
          ],
        ],
      ),
    );
  }
}
