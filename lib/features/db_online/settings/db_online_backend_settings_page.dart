import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/api/api_client.dart';
import 'package:omm/core/api/envelope.dart';
import 'package:omm/core/api/providers.dart';
import 'package:omm/core/platform/app_haptics.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/localized_error_message.dart';
import 'package:omm/shared/glow_background.dart';
import 'package:omm/shared/sheet_controls.dart';
import 'package:omm/shared/filter_chip.dart';
import 'package:omm/features/settings/settings_common.dart';
import 'package:omm/features/db_online/settings/db_online_backend_config.dart';
import 'db_online_downloader_config_widgets.dart';
import 'db_online_media_library_config_widgets.dart';

/// DBO 后台配置内容，可直接嵌入服务器设置页。
class DboBackendSettingsContent extends ConsumerWidget {
  const DboBackendSettingsContent({super.key, this.scrollable = false});

  final bool scrollable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(dbOnlineBackendConfigProvider);
    final content = config.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => _ConfigLoadError(
        error: error,
        onRetry: () => ref.invalidate(dbOnlineBackendConfigProvider),
      ),
      data: (value) => _buildGroups(context, value),
    );

    if (!scrollable) return content;
    return ListView(
      primary: true,
      padding: const EdgeInsets.only(bottom: 80),
      children: [content],
    );
  }

  static Widget _buildGroups(
    BuildContext context,
    Map<String, dynamic> config,
  ) {
    final l = AppL10n.of(context);
    return Column(
      children: [
        for (final group in dboBackendConfigGroups)
          SettingsGroup(
            title: group.title(l),
            items: [
              for (final section in group.sections)
                SettingsTile(
                  title: section.title(l),
                  subtitle: _sectionSubtitle(l, section),
                  leadingIcon: _sectionIcon(section),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DboBackendConfigDetailPage(
                        section: section,
                        config: config,
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  static String _sectionSubtitle(AppL10n l, DboBackendConfigSection section) {
    final test = section.testName == null ? '' : l.dbOnlineSectionSupportsTest;
    return '${l.dbOnlineSectionFieldCount(section.fields.length)}$test';
  }

  static IconData _sectionIcon(DboBackendConfigSection section) {
    return switch (section.basePath) {
      'javdb_api' => Icons.api_outlined,
      'subscription' => Icons.notifications_active_outlined,
      'proxy.main' => Icons.public_outlined,
      'downloader.aria2' => Icons.cloud_download_outlined,
      'downloader.qbittorrent' => Icons.download_outlined,
      'downloader.pan115' => Icons.cloud_queue_outlined,
      'downloader.thunder' => Icons.bolt_outlined,
      'downloader.openlist' ||
      'downloader.clouddrive2' => Icons.storage_outlined,
      'mediaserver.player' => Icons.play_circle_outline,
      'mediaserver.emby' => Icons.tv_outlined,
      'mediaserver.fnmedia' => Icons.movie_outlined,
      'mediaserver.jellyfin' => Icons.video_library_outlined,
      'mediaserver' => Icons.schedule_outlined,
      'subtitle' => Icons.subtitles_outlined,
      'experimental' => Icons.science_outlined,
      _ => Icons.settings_outlined,
    };
  }
}

/// 当前 DBO 服务器的后台配置入口，保留给需要独立打开配置页的场景。
class DboBackendSettingsPage extends StatelessWidget {
  const DboBackendSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appColors(context).bg,
      body: GlowBackground(
        child: SafeArea(
          child: SettingsFixedHeaderLayout(
            header: SettingsSubPageHeader(
              eyebrow: 'DB ONLINE',
              title: AppL10n.of(context).dbOnlineBackendConfigTitle,
            ),
            body: const DboBackendSettingsContent(scrollable: true),
          ),
        ),
      ),
    );
  }
}

class _ConfigLoadError extends StatelessWidget {
  const _ConfigLoadError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final l = AppL10n.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 80),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.danger.withValues(alpha: 0.09),
          border: Border.all(color: c.danger.withValues(alpha: 0.24)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: c.danger),
                const SizedBox(width: 8),
                Text(
                  l.dbOnlineConfigLoadError,
                  style: TextStyle(
                    color: c.danger,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              localizedErrorMessage(l, error),
              style: AppText.meta(context).copyWith(color: c.danger),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(l.dbOnlineRetry),
            ),
          ],
        ),
      ),
    );
  }
}

class DboBackendConfigDetailPage extends ConsumerStatefulWidget {
  const DboBackendConfigDetailPage({
    super.key,
    required this.section,
    required this.config,
  });

  final DboBackendConfigSection section;
  final Map<String, dynamic> config;

  @override
  ConsumerState<DboBackendConfigDetailPage> createState() =>
      _DboBackendConfigDetailPageState();
}

class _DboBackendConfigDetailPageState
    extends ConsumerState<DboBackendConfigDetailPage> {
  late Map<String, dynamic> _working;
  final _controllers = <String, TextEditingController>{};
  final _visiblePasswords = <String>{};
  bool _saving = false;
  bool _testing = false;
  bool _leaving = false;
  late final ApiClient _client;

  @override
  void initState() {
    super.initState();
    _client = ref.read(requiredApiClientProvider);
    final subtree = _readPath(widget.config, widget.section.basePath);
    _working = {
      ...widget.section.defaults,
      if (subtree is Map && widget.section.basePath != 'mediaserver')
        ...Map<String, dynamic>.from(jsonDecode(jsonEncode(subtree)) as Map),
      if (subtree is Map &&
          widget.section.basePath == 'mediaserver' &&
          subtree.containsKey('library_cache_schedule'))
        'library_cache_schedule': subtree['library_cache_schedule'],
    };
    if (widget.section.basePath == 'mediaserver.player') {
      for (final key in ['controls', 'speed_options']) {
        if (_working[key] is! List || (_working[key] as List).isEmpty) {
          _working[key] = widget.section.defaults[key];
        }
      }
      final speeds = _working['speed_options'] as List;
      if (!speeds.contains(_working['default_speed'])) {
        _working['default_speed'] = speeds.first;
      }
    }
    for (final field in widget.section.fields) {
      if (_isTextField(field.type)) {
        _controllers[field.path] = TextEditingController(
          text: switch (field.type) {
            DboBackendConfigFieldType.lines =>
              (_working[field.path] as List? ?? []).join('\n'),
            DboBackendConfigFieldType.commaList =>
              (_working[field.path] as List? ?? []).join(', '),
            _ => _readPath(_working, field.path)?.toString() ?? '',
          },
        );
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_current) return;
    final l = AppL10n.of(context);
    final validation =
        validateDboCloudDownloader(widget.section.testName, _working, l) ??
        validateDboMediaServer(widget.section.testName, _working, l);
    if (validation != null) {
      _showMessage(validation);
      return;
    }
    if (widget.section.basePath == 'subtitle') {
      final interval = int.tryParse(
        _working['scan_interval']?.toString() ?? '',
      );
      if (interval == null ||
          interval < 0 ||
          (_working['enabled'] == true &&
              (_working['directories'] as List).isNotEmpty &&
              (_working['extensions'] as List).isEmpty)) {
        _showMessage(l.dbOnlineSubtitleInvalidSettings);
        return;
      }
    }
    if (widget.section.basePath == 'experimental') {
      for (final field in widget.section.fields) {
        if (_experimentalReason(field) != null) _working[field.path] = false;
      }
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(dbOnlineBackendConfigProvider.notifier)
          .save(_buildNested(widget.section.basePath, _working));
      if (!mounted || !_current) return;
      AppHaptics.medium();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppL10n.of(context).dbOnlineSaved)),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted && _current) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizedErrorMessage(AppL10n.of(context), error)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _testConnection() async {
    final name = widget.section.testName;
    if (_testing || name == null || !_current) return;
    final l = AppL10n.of(context);
    if ((isDboCloudDownloader(name) || isDboMediaServer(name)) &&
        _working['enabled'] != true) {
      return;
    }
    final validation =
        validateDboCloudDownloader(name, _working, l, connectionOnly: true) ??
        validateDboMediaServer(name, _working, l);
    if (validation != null) {
      _showMessage(validation);
      return;
    }
    final snapshot = jsonEncode(_working);
    setState(() => _testing = true);
    try {
      final result = await ref
          .read(dbOnlineBackendConfigProvider.notifier)
          .testConnection(
            name,
            Map<String, dynamic>.from(jsonDecode(snapshot) as Map),
          );
      final success = result['success'] == true;
      final fallback = success
          ? l.dbOnlineConnectionOk
          : l.dbOnlineConnectionFailed;
      final detail = result['data'] is Map
          ? (result['data'] as Map)['version']
          : null;
      final message = envelopeMessageOrNull(result) ?? fallback;
      if (mounted && _current && snapshot == jsonEncode(_working)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(detail == null ? message : '$message · $detail'),
          ),
        );
      }
    } catch (error) {
      if (mounted && _current && snapshot == jsonEncode(_working)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizedErrorMessage(l, error))),
        );
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  bool get _current {
    if (!mounted || _leaving) return false;
    try {
      return identical(ref.read(requiredApiClientProvider), _client);
    } catch (_) {
      return false;
    }
  }

  String? _experimentalReason(DboBackendConfigField field) =>
      widget.section.basePath == 'experimental'
      ? dboExperimentalDisabledReason(
          field.path,
          ref.read(dbOnlineBackendConfigProvider).asData?.value ??
              widget.config,
          AppL10n.of(context),
        )
      : null;

  bool _fieldEnabled(DboBackendConfigField field) =>
      _experimentalReason(field) == null &&
      (widget.section.basePath != 'mediaserver.player' ||
          field.path == 'enabled' ||
          _working['enabled'] == true);

  void _showMessage(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  void _leaveForServerChange() {
    if (_leaving) return;
    _leaving = true;
    final route = ModalRoute.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || route == null || !route.isActive) return;
      Navigator.of(context).popUntil((candidate) => candidate == route);
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(dbOnlineBackendConfigProvider);
    ref.listen(requiredApiClientProvider, (_, next) {
      if (!identical(next, _client)) _leaveForServerChange();
    }, onError: (_, _) => _leaveForServerChange());
    final visibleFields = widget.section.fields
        .where((field) => field.visibleWhen?.call(_working) ?? true)
        .toList();
    final l = AppL10n.of(context);
    return Scaffold(
      backgroundColor: appColors(context).bg,
      body: GlowBackground(
        child: SafeArea(
          child: SettingsFixedHeaderLayout(
            header: SettingsSubPageHeader(
              eyebrow: 'DB ONLINE',
              title: widget.section.title(l),
            ),
            body: ListView(
              primary: true,
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 30),
              children: [
                if (widget.section.testName == 'pan115' &&
                    _readPath(widget.config, 'downloader.pan115.enabled') ==
                        true)
                  DbOnlinePan115AccountInfo(api: _client.dbOnline),
                for (var i = 0; i < visibleFields.length; i++) ...[
                  _buildField(visibleFields[i]),
                  if (i < visibleFields.length - 1) const SizedBox(height: 12),
                ],
                if (widget.section.basePath == 'mediaserver' ||
                    widget.section.basePath == 'subtitle') ...[
                  const SizedBox(height: 16),
                  DbOnlineLibraryTaskPanel(
                    api: _client.dbOnline,
                    subtitles: widget.section.basePath == 'subtitle',
                    hasDirectories:
                        widget.section.basePath != 'subtitle' ||
                        (_working['directories'] as List).isNotEmpty,
                    isCurrent: () => _current,
                  ),
                ],
                const SizedBox(height: 16),
                if (widget.section.testName != null) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed:
                          _testing ||
                              _saving ||
                              ((isDboCloudDownloader(widget.section.testName) ||
                                      isDboMediaServer(
                                        widget.section.testName,
                                      )) &&
                                  _working['enabled'] != true)
                          ? null
                          : _testConnection,
                      style: sheetSecondaryButtonStyle(context),
                      icon: _testing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.wifi_tethering_outlined, size: 18),
                      label: Text(l.dbOnlineTestConnection),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                SettingsSaveButton(onPressed: _save, saving: _saving),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(DboBackendConfigField field) {
    final l = AppL10n.of(context);
    switch (field.type) {
      case DboBackendConfigFieldType.libraries:
        return DbOnlineMediaLibrariesField(
          api: _client.dbOnline,
          name: widget.section.testName!,
          values: _working,
          isCurrent: () => _current,
          onChanged: (ids) => setState(() => _working[field.path] = ids),
        );
      case DboBackendConfigFieldType.multiSelect:
        final speed = field.path == 'speed_options';
        final selected = List<dynamic>.from(
          _working[field.path] as List? ?? [],
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _fieldLabel(field),
            IgnorePointer(
              ignoring: !_fieldEnabled(field),
              child: Opacity(
                opacity: _fieldEnabled(field) ? 1 : 0.45,
                child: Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    for (final option in field.options!)
                      CompactFilterButton(
                        key: ValueKey('${field.path}.${option.value}'),
                        label: option.label(l),
                        active: selected.contains(
                          speed ? num.parse(option.value) : option.value,
                        ),
                        onTap: () {
                          final value = speed
                              ? num.parse(option.value)
                              : option.value;
                          if (selected.contains(value)) {
                            if (selected.length == 1) return;
                            selected.remove(value);
                          } else {
                            selected.add(value);
                          }
                          setState(() {
                            _working[field.path] = selected;
                            if (speed &&
                                !selected.contains(_working['default_speed'])) {
                              _working['default_speed'] = selected.first;
                            }
                          });
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      case DboBackendConfigFieldType.directory:
        return DbOnlineDownloaderDirectoryField(
          name: widget.section.testName!,
          api: _client.dbOnline,
          values: _working,
          isCurrent: () => _current,
          onChanged: (values) => setState(() => _working.addAll(values)),
        );
      case DboBackendConfigFieldType.toolPaths:
        return DbOnlineOpenListToolPathsField(
          api: _client.dbOnline,
          values: _working,
          isCurrent: () => _current,
          onChanged: (values) =>
              setState(() => _working['tool_path_suffixes'] = values),
        );
      case DboBackendConfigFieldType.toggle:
        return Container(
          decoration: settingsCardDecoration(context),
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(field.label(l), style: AppText.cardTitle(context)),
                    if (field.hint != null) ...[
                      const SizedBox(height: 2),
                      Text(field.hint!(l), style: AppText.meta(context)),
                    ],
                    if (_experimentalReason(field)
                        case final String reason) ...[
                      const SizedBox(height: 2),
                      Text(
                        reason,
                        style: AppText.meta(
                          context,
                        ).copyWith(color: appColors(context).muted),
                      ),
                    ],
                  ],
                ),
              ),
              SettingsSwitch(
                key: ValueKey(field.path),
                value:
                    _readPath(_working, field.path) == true &&
                    _experimentalReason(field) == null,
                onChanged: _fieldEnabled(field)
                    ? (value) => setState(
                        () => _writePath(_working, field.path, value),
                      )
                    : null,
              ),
            ],
          ),
        );
      case DboBackendConfigFieldType.select:
        final speed = field.path == 'default_speed';
        final options = speed
            ? [
                for (final value in _working['speed_options'] as List)
                  DboBackendConfigOption(
                    value: '$value',
                    label: (l) => '${value}x',
                  ),
              ]
            : field.options ?? const <DboBackendConfigOption>[];
        if (options.isEmpty) return const SizedBox.shrink();
        final raw = _readPath(_working, field.path)?.toString();
        final current = options.firstWhere(
          (option) => speed
              ? num.tryParse(option.value) == num.tryParse(raw ?? '')
              : option.value == raw,
          orElse: () => options.first,
        );
        final icon = _fieldIcon(field);
        final colors = appColors(context);
        return InputDecorator(
          decoration: settingsInputDecoration(
            context,
            labelText: field.label(l),
            prefixIcon: icon == null ? null : Icon(icon),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: current.value,
              isExpanded: true,
              isDense: true,
              style: TextStyle(
                color: colors.text,
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              items: [
                for (final option in options)
                  DropdownMenuItem(
                    value: option.value,
                    child: Text(option.label(l)),
                  ),
              ],
              onChanged: !_fieldEnabled(field)
                  ? null
                  : (value) {
                      if (value == null) return;
                      AppHaptics.selection();
                      setState(
                        () => _writePath(
                          _working,
                          field.path,
                          speed ? num.parse(value) : value,
                        ),
                      );
                    },
            ),
          ),
        );
      case DboBackendConfigFieldType.text:
      case DboBackendConfigFieldType.password:
      case DboBackendConfigFieldType.number:
      case DboBackendConfigFieldType.lines:
      case DboBackendConfigFieldType.commaList:
      case DboBackendConfigFieldType.schedule:
        final controller = _controllers[field.path]!;
        final isPassword = field.type == DboBackendConfigFieldType.password;
        final icon = _fieldIcon(field);
        final colors = appColors(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _fieldLabel(field),
            TextField(
              key: ValueKey(field.path),
              controller: controller,
              minLines: field.type == DboBackendConfigFieldType.lines ? 3 : 1,
              maxLines: field.type == DboBackendConfigFieldType.lines ? 5 : 1,
              obscureText:
                  isPassword && !_visiblePasswords.contains(field.path),
              keyboardType: field.type == DboBackendConfigFieldType.number
                  ? TextInputType.number
                  : field.type == DboBackendConfigFieldType.lines
                  ? TextInputType.multiline
                  : TextInputType.text,
              autocorrect: false,
              enableSuggestions: !isPassword,
              decoration: settingsInputDecoration(
                context,
                hintText: isPassword ? l.dbOnlineFieldMaskHint : null,
                prefixIcon: icon == null ? null : Icon(icon),
                suffixIcon: isPassword
                    ? IconButton(
                        tooltip: _visiblePasswords.contains(field.path)
                            ? l.dbOnlineHidePassword
                            : l.dbOnlineShowPassword,
                        icon: Icon(
                          _visiblePasswords.contains(field.path)
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () => setState(() {
                          if (_visiblePasswords.contains(field.path)) {
                            _visiblePasswords.remove(field.path);
                          } else {
                            _visiblePasswords.add(field.path);
                          }
                        }),
                      )
                    : null,
              ),
              style: TextStyle(
                color: colors.text,
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              onChanged: (value) {
                final next = switch (field.type) {
                  DboBackendConfigFieldType.number =>
                    num.tryParse(value) ?? value,
                  DboBackendConfigFieldType.lines =>
                    value
                        .split(RegExp(r'[\r\n]+'))
                        .map((entry) => entry.trim())
                        .where((entry) => entry.isNotEmpty)
                        .toList(),
                  DboBackendConfigFieldType.commaList =>
                    value
                        .split(',')
                        .map((entry) => entry.trim())
                        .where((entry) => entry.isNotEmpty)
                        .toList(),
                  _ => value,
                };
                if (isDboCloudDownloader(widget.section.testName) ||
                    isDboMediaServer(widget.section.testName) ||
                    widget.section.basePath == 'subtitle' ||
                    field.type == DboBackendConfigFieldType.schedule) {
                  setState(() => _writePath(_working, field.path, next));
                } else {
                  _writePath(_working, field.path, next);
                }
              },
            ),
            if (field.type == DboBackendConfigFieldType.schedule) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final option in field.options!)
                    CompactFilterButton(
                      label: option.label(l),
                      active: _working[field.path] == option.value,
                      onTap: () => setState(() {
                        controller.text = option.value;
                        _working[field.path] = option.value;
                      }),
                    ),
                ],
              ),
            ],
          ],
        );
    }
  }

  Widget _fieldLabel(DboBackendConfigField field) {
    final l = AppL10n.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(field.label(l).toUpperCase(), style: AppText.eyebrow(context)),
          if (field.hint != null) ...[
            const SizedBox(height: 2),
            Text(
              field.hint!(l),
              style: AppText.meta(context).copyWith(fontSize: 10.5),
            ),
          ],
        ],
      ),
    );
  }

  IconData? _fieldIcon(DboBackendConfigField field) {
    return switch (field.path) {
      'host' => Icons.link,
      'authorization' ||
      'secret' ||
      'password' ||
      'cookie' => Icons.key_outlined,
      'token' || 'api_key' => Icons.key_outlined,
      'port' || 'cid' || 'parent_folder_id' => Icons.numbers_outlined,
      'save_path' => Icons.folder_open_outlined,
      'protocol' => Icons.public_outlined,
      'image_mode' => Icons.image_outlined,
      'timeout' ||
      'request_timeout' ||
      'check_interval' ||
      'retry_interval' => Icons.timer_outlined,
      _ => null,
    };
  }

  static bool _isTextField(DboBackendConfigFieldType type) {
    return type == DboBackendConfigFieldType.text ||
        type == DboBackendConfigFieldType.password ||
        type == DboBackendConfigFieldType.number ||
        type == DboBackendConfigFieldType.lines ||
        type == DboBackendConfigFieldType.commaList ||
        type == DboBackendConfigFieldType.schedule;
  }
}

dynamic _readPath(Map<String, dynamic> root, String path) {
  dynamic current = root;
  for (final key in path.split('.')) {
    if (current is Map && current.containsKey(key)) {
      current = current[key];
    } else {
      return null;
    }
  }
  return current;
}

void _writePath(Map<String, dynamic> root, String path, dynamic value) {
  final keys = path.split('.');
  var current = root;
  for (var i = 0; i < keys.length - 1; i++) {
    final key = keys[i];
    if (current[key] is! Map<String, dynamic>) {
      current[key] = <String, dynamic>{};
    }
    current = current[key] as Map<String, dynamic>;
  }
  current[keys.last] = value;
}

Map<String, dynamic> _buildNested(String basePath, Map<String, dynamic> value) {
  var result = value;
  final keys = basePath.split('.');
  for (var i = keys.length - 1; i >= 0; i--) {
    result = <String, dynamic>{keys[i]: result};
  }
  return result;
}
