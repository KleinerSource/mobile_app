import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omm/core/api/dio_factory.dart';
import 'package:omm/core/platform/app_haptics.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/shared/glow_background.dart';
import 'package:omm/features/settings/settings_common.dart';
import 'package:omm/features/db_online/settings/db_online_backend_config.dart';

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
    return Column(
      children: [
        for (final group in dboBackendConfigGroups)
          SettingsGroup(
            title: group.title,
            items: [
              for (final section in group.sections)
                SettingsTile(
                  title: section.title,
                  subtitle: _sectionSubtitle(section),
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

  static String _sectionSubtitle(DboBackendConfigSection section) {
    final test = section.testName == null ? '' : ' · 支持测试连接';
    return '${section.fields.length} 项配置$test';
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
      'mediaserver.player' => Icons.play_circle_outline,
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
      body: const GlowBackground(
        child: SafeArea(
          child: SettingsFixedHeaderLayout(
            header: SettingsSubPageHeader(
              eyebrow: 'DB ONLINE',
              title: '后台配置',
              subtitle: '配置 DBO 服务端的 API、订阅、代理、下载器和播放器。',
            ),
            body: DboBackendSettingsContent(scrollable: true),
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
                  '无法读取 DBO 配置',
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
              toApiException(error).message,
              style: AppText.meta(context).copyWith(color: c.danger),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('重试'),
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
  bool _saving = false;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    final subtree = _readPath(widget.config, widget.section.basePath);
    _working = subtree is Map
        ? Map<String, dynamic>.from(jsonDecode(jsonEncode(subtree)) as Map)
        : <String, dynamic>{};
    for (final field in widget.section.fields) {
      if (_isTextField(field.type)) {
        _controllers[field.path] = TextEditingController(
          text: _readPath(_working, field.path)?.toString() ?? '',
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
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(dbOnlineBackendConfigProvider.notifier)
          .save(_buildNested(widget.section.basePath, _working));
      if (!mounted) return;
      AppHaptics.medium();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已保存')));
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(toApiException(error).message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _testConnection() async {
    final name = widget.section.testName;
    if (_testing || name == null) return;
    setState(() => _testing = true);
    try {
      final result = await ref
          .read(dbOnlineBackendConfigProvider.notifier)
          .testConnection(name, _working);
      final success = result['success'] == true;
      final message =
          result['message'] ?? result['error'] ?? (success ? '连接正常' : '连接失败');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message.toString())));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(toApiException(error).message)));
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleFields = widget.section.fields
        .where((field) => field.visibleWhen?.call(_working) ?? true)
        .toList();
    return Scaffold(
      backgroundColor: appColors(context).bg,
      body: GlowBackground(
        child: SafeArea(
          child: SettingsFixedHeaderLayout(
            header: SettingsSubPageHeader(
              eyebrow: 'DB ONLINE · 后台配置',
              title: widget.section.title,
              subtitle: '修改后仅更新当前配置分区。',
            ),
            body: ListView(
              primary: true,
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 30),
              children: [
                Container(
                  decoration: settingsCardDecoration(context),
                  child: Column(
                    children: [
                      for (var i = 0; i < visibleFields.length; i++) ...[
                        if (i > 0)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Divider(
                              height: 1,
                              color: appColors(context).divider,
                            ),
                          ),
                        _buildField(visibleFields[i]),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (widget.section.testName != null) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _testing ? null : _testConnection,
                      icon: _testing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.wifi_tethering_outlined, size: 18),
                      label: const Text('测试连接'),
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
    switch (field.type) {
      case DboBackendConfigFieldType.toggle:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(child: _fieldLabel(field)),
              SettingsSwitch(
                value: _readPath(_working, field.path) == true,
                onChanged: (value) =>
                    setState(() => _writePath(_working, field.path, value)),
              ),
            ],
          ),
        );
      case DboBackendConfigFieldType.select:
        final options = field.options ?? const <DboBackendConfigOption>[];
        if (options.isEmpty) return const SizedBox.shrink();
        final raw = _readPath(_working, field.path)?.toString();
        final current = options.firstWhere(
          (option) => option.value == raw,
          orElse: () => options.first,
        );
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: InputDecorator(
            decoration: settingsInputDecoration(
              context,
              labelText: field.label,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: current.value,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                items: [
                  for (final option in options)
                    DropdownMenuItem(
                      value: option.value,
                      child: Text(option.label),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  AppHaptics.selection();
                  setState(() => _writePath(_working, field.path, value));
                },
              ),
            ),
          ),
        );
      case DboBackendConfigFieldType.text:
      case DboBackendConfigFieldType.password:
      case DboBackendConfigFieldType.number:
        final controller = _controllers[field.path]!;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _fieldLabel(field),
              const SizedBox(height: 7),
              TextField(
                controller: controller,
                obscureText: field.type == DboBackendConfigFieldType.password,
                keyboardType: field.type == DboBackendConfigFieldType.number
                    ? TextInputType.number
                    : TextInputType.text,
                autocorrect: false,
                decoration: settingsInputDecoration(
                  context,
                  hintText: field.type == DboBackendConfigFieldType.password
                      ? '留空或保持掩码表示不修改'
                      : null,
                  borderless: true,
                ),
                onChanged: (value) {
                  final next = field.type == DboBackendConfigFieldType.number
                      ? num.tryParse(value) ?? value
                      : value;
                  _writePath(_working, field.path, next);
                },
              ),
            ],
          ),
        );
    }
  }

  Widget _fieldLabel(DboBackendConfigField field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(field.label, style: AppText.cardTitle(context)),
        if (field.hint != null) ...[
          const SizedBox(height: 2),
          Text(field.hint!, style: AppText.meta(context)),
        ],
      ],
    );
  }

  static bool _isTextField(DboBackendConfigFieldType type) {
    return type == DboBackendConfigFieldType.text ||
        type == DboBackendConfigFieldType.password ||
        type == DboBackendConfigFieldType.number;
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
