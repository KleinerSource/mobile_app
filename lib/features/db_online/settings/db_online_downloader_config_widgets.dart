import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/core/sources/media/dbo/db_online_api.dart';
import 'package:omm/features/settings/settings_common.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/empty_view.dart';
import 'package:omm/shared/error_view.dart';
import 'package:omm/shared/filter_chip.dart';
import 'package:omm/shared/glass.dart';
import 'package:omm/shared/localized_error_message.dart';
import 'package:omm/shared/sheet_controls.dart';

bool _canBrowse(String name, Map<String, dynamic> values) {
  final keys = name == 'pan115' ? ['cookie'] : ['host'];
  final timeout = int.tryParse(values['timeout']?.toString() ?? '');
  final port = int.tryParse(values['port']?.toString() ?? '');
  return keys.every(
        (key) => values[key]?.toString().trim().isNotEmpty == true,
      ) &&
      timeout != null &&
      timeout > 0 &&
      (name == 'pan115' || (port != null && port > 0 && port <= 65535));
}

String _signature(String name, Map<String, dynamic> values) => jsonEncode([
  for (final key
      in name == 'pan115'
          ? ['cookie', 'timeout']
          : [
              'host',
              'port',
              'use_https',
              'timeout',
              if (name == 'openlist') 'token',
            ])
    values[key],
]);

List<Map<String, dynamic>> _records(Object? value) => value is List
    ? value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList()
    : [];

class DbOnlineDownloaderDirectoryField extends StatefulWidget {
  const DbOnlineDownloaderDirectoryField({
    super.key,
    required this.name,
    required this.api,
    required this.values,
    required this.isCurrent,
    required this.onChanged,
  });

  final String name;
  final DbOnlineApi api;
  final Map<String, dynamic> values;
  final bool Function() isCurrent;
  final ValueChanged<Map<String, dynamic>> onChanged;

  @override
  State<DbOnlineDownloaderDirectoryField> createState() =>
      _DirectoryFieldState();
}

class _DirectoryFieldState extends State<DbOnlineDownloaderDirectoryField> {
  String? _label;
  late String _connection = _signature(widget.name, widget.values);

  @override
  void didUpdateWidget(DbOnlineDownloaderDirectoryField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _signature(widget.name, widget.values);
    if (_connection != next) {
      _connection = next;
      _label = null;
    }
  }

  Future<void> _open() async {
    if (!widget.isCurrent()) return;
    final signature = _connection;
    bool current() =>
        mounted &&
        widget.isCurrent() &&
        signature == _signature(widget.name, widget.values);
    final result = await showGlassSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      minHeight: sheetMinHeight(context),
      builder: (_) => _DirectorySheet(
        name: widget.name,
        api: widget.api,
        values: Map<String, dynamic>.from(
          jsonDecode(jsonEncode(widget.values)) as Map,
        ),
        isCurrent: current,
        onDeviceChanged: (target) {
          if (!current()) return;
          widget.onChanged({'device_target': target, 'parent_folder_id': ''});
          setState(() => _label = null);
        },
      ),
    );
    if (!current() || result == null) return;
    final label = result.remove('_label')?.toString();
    widget.onChanged(result);
    setState(() => _label = label);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final pan = widget.name == 'pan115';
    final canBrowse = _canBrowse(widget.name, widget.values);
    final cid = widget.values['cid']?.toString() ?? '';
    final device = widget.values['device_target']?.toString() ?? '';
    final folder = widget.values['parent_folder_id']?.toString() ?? '';
    final fallback = pan
        ? (cid == '0'
              ? l.dbOnlineRootDirectory
              : (cid.isEmpty
                    ? l.dbOnlineDownloaderSelectDirectory
                    : 'CID $cid'))
        : (device.isEmpty
              ? l.dbOnlineThunderSelectDevice
              : l.dbOnlineThunderSavedSelection(device, folder));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          pan
              ? l.dbOnlineDownloaderDirectory
              : l.dbOnlineThunderDeviceDirectory,
          style: AppText.eyebrow(context),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: canBrowse ? _open : null,
            style: sheetSecondaryButtonStyle(context),
            icon: const Icon(Icons.folder_open_outlined, size: 18),
            label: Text(
              _label ?? fallback,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (!canBrowse) ...[
          const SizedBox(height: 4),
          Text(
            pan
                ? l.dbOnlinePan115FillBeforeBrowse
                : l.dbOnlineDownloaderRequiredFields,
            style: AppText.meta(context),
          ),
        ],
      ],
    );
  }
}

class _DirectorySheet extends StatefulWidget {
  const _DirectorySheet({
    required this.name,
    required this.api,
    required this.values,
    required this.isCurrent,
    required this.onDeviceChanged,
  });

  final String name;
  final DbOnlineApi api;
  final Map<String, dynamic> values;
  final bool Function() isCurrent;
  final ValueChanged<String> onDeviceChanged;

  @override
  State<_DirectorySheet> createState() => _DirectorySheetState();
}

class _DirectorySheetState extends State<_DirectorySheet> {
  List<Map<String, dynamic>> _devices = [];
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _path = [];
  late String _cid = widget.values['cid']?.toString() ?? '0';
  late String _device = widget.values['device_target']?.toString() ?? '';
  late String _selectedFolder =
      widget.values['parent_folder_id']?.toString() ?? '';
  String? _error;
  bool _loading = true;
  bool _loaded = false;
  int _generation = 0;
  int _total = 0;
  bool get _pan => widget.name == 'pan115';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_generation == 0) unawaited(_load());
  }

  Future<void> _load({String? cid, String? device}) async {
    final generation = ++_generation;
    final l = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _loading = true;
      _loaded = false;
      _error = null;
      _items = [];
    });
    bool current() =>
        mounted && widget.isCurrent() && generation == _generation;
    try {
      final payload = Map<String, dynamic>.from(widget.values);
      final Map<String, dynamic> result;
      if (_pan) {
        payload['cid'] = cid ?? _cid;
        result = await widget.api.pan115Directories(payload);
      } else {
        payload.remove('device_target');
        payload.remove('parent_folder_id');
        if (device != null) payload['device_target'] = device;
        result = await widget.api.thunderSelectOptions(payload);
      }
      if (!current()) return;
      setState(() {
        _loading = false;
        _loaded = true;
        _items = _records(result['directories']);
        if (_pan) {
          _cid = result['cid']?.toString() ?? cid ?? _cid;
          _path = _records(result['path']);
          _total = int.tryParse(result['total']?.toString() ?? '') ?? 0;
        } else {
          _devices = _records(result['devices']);
        }
      });
      if (!_pan &&
          _device.isNotEmpty &&
          !_devices.any((item) => item['target']?.toString() == _device)) {
        _device = '';
        widget.onDeviceChanged('');
        setState(() => _error = l.dbOnlineThunderInvalidDevice);
      } else if (!_pan && device == null && _device.isNotEmpty) {
        await _load(device: _device);
      } else if (!_pan &&
          device != null &&
          _selectedFolder.isNotEmpty &&
          !_items.any((item) => item['id']?.toString() == _selectedFolder)) {
        _selectedFolder = '';
        widget.onDeviceChanged(_device);
        messenger.showSnackBar(
          SnackBar(content: Text(l.dbOnlineThunderInvalidDirectory)),
        );
      }
    } catch (error) {
      if (current()) {
        setState(() {
          _loading = false;
          _error = localizedErrorMessage(l, error);
        });
      }
    }
  }

  void _selectDevice(String target) {
    if (!widget.isCurrent()) return;
    setState(() {
      _device = target;
      _selectedFolder = '';
    });
    widget.onDeviceChanged(target);
    unawaited(_load(device: target));
  }

  void _selectDirectory(Map<String, dynamic> item) {
    if (!widget.isCurrent()) return;
    final device = _devices
        .where((entry) => entry['target']?.toString() == _device)
        .firstOrNull;
    Navigator.of(context).pop({
      'device_target': _device,
      'parent_folder_id': item['id']?.toString() ?? '',
      '_label': '${device?['name'] ?? _device} / ${item['real_path'] ?? ''}',
    });
  }

  void _selectCurrent() {
    if (!widget.isCurrent()) return;
    final l = AppL10n.of(context);
    Navigator.of(context).pop({
      'cid': _cid,
      '_label': _path.isEmpty
          ? (_cid == '0' ? l.dbOnlineRootDirectory : 'CID $_cid')
          : _path.map((item) => item['name']?.toString() ?? '').join(' / '),
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return SizedBox(
      height: sheetMaxHeight(context).clamp(0.0, 560.0),
      child: Column(
        children: [
          SheetHeader(
            icon: Icons.folder_open_outlined,
            title: _pan
                ? l.dbOnlineDownloaderDirectory
                : l.dbOnlineThunderDeviceDirectory,
            trailing: IconButton(
              tooltip: l.mediaBrowserRefresh,
              onPressed: _loading
                  ? null
                  : () => _load(
                      device: _pan ? null : (_device.isEmpty ? null : _device),
                    ),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (_pan) ...[
                    TextButton(
                      onPressed: _loading ? null : () => _load(cid: '0'),
                      child: Text(l.dbOnlineRootDirectory),
                    ),
                    for (final part in _path.where(
                      (item) => item['cid']?.toString() != '0',
                    ))
                      TextButton(
                        onPressed: _loading
                            ? null
                            : () => _load(cid: part['cid']?.toString()),
                        child: Text(part['name']?.toString() ?? ''),
                      ),
                    IconButton(
                      tooltip: l.dbOnlineParentDirectory,
                      onPressed: _loading || _cid == '0'
                          ? null
                          : () => _load(
                              cid: _path.length > 1
                                  ? _path[_path.length - 2]['cid']
                                            ?.toString() ??
                                        '0'
                                  : '0',
                            ),
                      icon: const Icon(Icons.arrow_upward_rounded),
                    ),
                  ] else ...[
                    for (final item in _devices)
                      Padding(
                        padding: const EdgeInsets.only(right: 7),
                        child: CompactFilterButton(
                          label: item['name']?.toString() ?? '',
                          active: item['target']?.toString() == _device,
                          onTap: () =>
                              _selectDevice(item['target']?.toString() ?? ''),
                        ),
                      ),
                    IconButton(
                      tooltip: l.dbOnlineThunderRefreshDevices,
                      onPressed: () => _load(),
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? ErrorView.list(
                    message: _error!,
                    onRetry: () =>
                        _load(device: _pan || _device.isEmpty ? null : _device),
                  )
                : _items.isEmpty
                ? EmptyView(
                    message: _pan
                        ? l.dbOnlineNoSubdirectories
                        : (_devices.isEmpty
                              ? l.dbOnlineThunderNoDevices
                              : (_device.isEmpty
                                    ? l.dbOnlineThunderSelectDevice
                                    : l.dbOnlineThunderNoDirectories)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: _items.length,
                    itemBuilder: (_, index) {
                      final item = _items[index];
                      return ListTile(
                        leading: Icon(
                          Icons.folder_outlined,
                          size: 20,
                          color: appColors(context).accent,
                        ),
                        titleTextStyle: AppText.cardTitle(context),
                        subtitleTextStyle: AppText.meta(context),
                        title: Text(
                          _pan
                              ? item['name']?.toString() ?? ''
                              : item['real_path']?.toString() ??
                                    item['name']?.toString() ??
                                    '',
                        ),
                        subtitle: !_pan && item['is_default'] == true
                            ? Text(l.mediaStreamDefault)
                            : null,
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: appColors(context).muted,
                        ),
                        onTap: () => _pan
                            ? _load(cid: item['cid']?.toString())
                            : _selectDirectory(item),
                      );
                    },
                  ),
          ),
          if (_pan && _loaded && _total > _items.length)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Text(
                l.dbOnlinePan115PartialDirectories(_items.length),
                style: AppText.meta(context),
              ),
            ),
          SheetActionBar.buttons(
            buttons: [
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: sheetSecondaryButtonStyle(context),
                child: Text(l.cancel),
              ),
              if (_pan)
                FilledButton(
                  onPressed: !_loading && _loaded && _error == null
                      ? _selectCurrent
                      : null,
                  style: sheetPrimaryButtonStyle(context),
                  child: Text(l.dbOnlineSelectCurrentDirectory),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class DbOnlineOpenListToolPathsField extends StatefulWidget {
  const DbOnlineOpenListToolPathsField({
    super.key,
    required this.api,
    required this.values,
    required this.isCurrent,
    required this.onChanged,
  });
  final DbOnlineApi api;
  final Map<String, dynamic> values;
  final bool Function() isCurrent;
  final ValueChanged<Map<String, String>> onChanged;

  @override
  State<DbOnlineOpenListToolPathsField> createState() => _ToolPathsFieldState();
}

class _ToolPathsFieldState extends State<DbOnlineOpenListToolPathsField> {
  Future<void> _open() async {
    if (!widget.isCurrent()) return;
    final signature = _signature('openlist', widget.values);
    final result = await showGlassSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      minHeight: sheetMinHeight(context),
      builder: (_) => _ToolPathsSheet(
        api: widget.api,
        values: Map<String, dynamic>.from(
          jsonDecode(jsonEncode(widget.values)) as Map,
        ),
        isCurrent: () =>
            mounted &&
            widget.isCurrent() &&
            signature == _signature('openlist', widget.values),
      ),
    );
    if (mounted &&
        widget.isCurrent() &&
        result != null &&
        signature == _signature('openlist', widget.values)) {
      widget.onChanged(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: widget.values['enabled'] == true ? _open : null,
        style: sheetSecondaryButtonStyle(context),
        icon: const Icon(Icons.folder_copy_outlined, size: 18),
        label: Text(l.dbOnlineOpenListToolPaths),
      ),
    );
  }
}

String _normalizePath(String value) =>
    value.trim().replaceAll('\\', '/').replaceAll(RegExp(r'/+'), '/');
String _normalizeSuffix(String value) =>
    _normalizePath(value).replaceFirst(RegExp(r'^/+'), '');
String _normalizePrefix(String value) {
  final path = _normalizePath(value);
  return path == '/' ? path : path.replaceFirst(RegExp(r'/+$'), '');
}

class _ToolPathsSheet extends StatefulWidget {
  const _ToolPathsSheet({
    required this.api,
    required this.values,
    required this.isCurrent,
  });
  final DbOnlineApi api;
  final Map<String, dynamic> values;
  final bool Function() isCurrent;

  @override
  State<_ToolPathsSheet> createState() => _ToolPathsSheetState();
}

class _ToolPathsSheetState extends State<_ToolPathsSheet> {
  final _controllers = <String, TextEditingController>{};
  List<Map<String, dynamic>> _tools = [];
  late final Map<String, String> _draft = {
    if (widget.values['tool_path_suffixes'] is Map)
      for (final entry in (widget.values['tool_path_suffixes'] as Map).entries)
        entry.key.toString(): entry.value?.toString() ?? '',
  };
  bool _loading = true;
  String? _error;
  int _generation = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_generation == 0) unawaited(_load());
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final l = AppL10n.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.api.openListToolPaths(widget.values);
      if (!mounted || !widget.isCurrent() || generation != _generation) return;
      final tools = _records(result['tools'])
          .where((item) => item['tool_key']?.toString().isNotEmpty == true)
          .toList();
      for (final tool in tools) {
        final key = tool['tool_key'].toString();
        _draft.putIfAbsent(key, () => tool['suffix']?.toString() ?? '');
        _controllers.putIfAbsent(
          key,
          () => TextEditingController(text: _draft[key]),
        );
      }
      setState(() {
        _tools = tools;
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

  void _save() {
    if (!widget.isCurrent()) return;
    Navigator.of(context).pop({
      for (final entry in _draft.entries)
        entry.key: _normalizeSuffix(entry.value),
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return SizedBox(
      height: sheetMaxHeight(context).clamp(0.0, 560.0),
      child: Column(
        children: [
          SheetHeader(
            icon: Icons.folder_copy_outlined,
            title: l.dbOnlineOpenListToolPaths,
            trailing: IconButton(
              tooltip: l.mediaBrowserRefresh,
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? ErrorView.list(message: _error!, onRetry: _load)
                : _tools.isEmpty
                ? EmptyView(message: l.dbOnlineOpenListNoTools)
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    children: [
                      for (final tool in _tools) ...[
                        Text(
                          tool['tool']?.toString() ?? '',
                          style: AppText.cardTitle(context),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _normalizePrefix(
                                tool['prefix']?.toString() ?? '',
                              ).isEmpty
                              ? l.dbOnlineOpenListMissingPrefix
                              : _normalizePrefix(tool['prefix'].toString()),
                          style: AppText.meta(context),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          key: ValueKey(tool['tool_key'].toString()),
                          controller: _controllers[tool['tool_key'].toString()],
                          decoration: settingsInputDecoration(
                            context,
                            labelText: l.dbOnlineOpenListPathSuffix,
                          ),
                          style: TextStyle(
                            color: appColors(context).text,
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          onChanged: (value) =>
                              _draft[tool['tool_key'].toString()] = value,
                        ),
                        const SizedBox(height: 16),
                      ],
                      Text(
                        l.dbOnlineOpenListPathHint,
                        style: AppText.meta(context),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l.dbOnlineDownloaderPathVariables,
                        style: AppText.meta(context),
                      ),
                      Text(
                        '{release_date} · {publish_date} · {actor_name} · {sub_name}',
                        style: AppText.meta(context),
                      ),
                    ],
                  ),
          ),
          SheetActionBar.buttons(
            buttons: [
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: sheetSecondaryButtonStyle(context),
                child: Text(l.cancel),
              ),
              FilledButton(
                onPressed: _loading || _error != null ? null : _save,
                style: sheetPrimaryButtonStyle(context),
                child: Text(l.save),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DbOnlinePan115AccountInfo extends StatefulWidget {
  const DbOnlinePan115AccountInfo({super.key, required this.api});
  final DbOnlineApi api;

  @override
  State<DbOnlinePan115AccountInfo> createState() => _AccountInfoState();
}

class _AccountInfoState extends State<DbOnlinePan115AccountInfo> {
  late final _account = widget.api.pan115Account();

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return FutureBuilder<Map<String, dynamic>>(
      future: _account,
      builder: (_, snapshot) {
        final account = snapshot.data;
        if (account == null || account.isEmpty) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: settingsCardDecoration(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.dbOnlinePan115AccountInfo,
                style: AppText.eyebrow(context),
              ),
              const SizedBox(height: 6),
              Text(
                account['user_name']?.toString() ?? '--',
                style: AppText.cardTitle(context),
              ),
              Text(
                'UID: ${account['display_uid'] ?? '--'}',
                style: AppText.meta(context),
              ),
              Text(
                'VIP: ${account['vip_level'] ?? '--'}',
                style: AppText.meta(context),
              ),
              Text(
                l.dbOnlinePan115AccountExpiry(
                  account['is_forever'] == true
                      ? l.dbOnlinePan115Forever
                      : account['expire_date']?.toString() ?? '--',
                ),
                style: AppText.meta(context),
              ),
            ],
          ),
        );
      },
    );
  }
}
