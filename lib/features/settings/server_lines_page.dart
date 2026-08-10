import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/dio_factory.dart';
import '../../core/api/server_compatibility.dart';
import '../../core/auth/auth_session_provider.dart';
import '../../core/config/server_config.dart';
import '../../core/config/server_config_provider.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/glow_background.dart';
import 'settings_common.dart';

class ServerLinesPage extends ConsumerStatefulWidget {
  const ServerLinesPage({super.key});

  @override
  ConsumerState<ServerLinesPage> createState() => _ServerLinesPageState();
}

class _ServerLinesPageState extends ConsumerState<ServerLinesPage> {
  final _testResults = <String, _LineTestResult>{};
  final _testingIds = <String>{};
  List<ServerLine> _lines = const [];
  bool _loaded = false;
  bool _testingAll = false;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final config = ref.watch(serverConfigProvider);
    if (config == null) {
      return Scaffold(
        backgroundColor: colors.bg,
        body: const Center(child: Text('服务器尚未配置')),
      );
    }
    if (!_loaded) {
      _loaded = true;
      _lines = List<ServerLine>.of(config.lines);
    }

    return Scaffold(
      backgroundColor: colors.bg,
      body: GlowBackground(
        child: SafeArea(
          child: Column(
            children: [
              const SettingsSubPageHeader(
                eyebrow: '服务器',
                title: '服务器线路',
                subtitle: '配置多条访问线路，自动测试延迟后选择当前线路',
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 30),
                  children: [
                    _buildActions(),
                    const SizedBox(height: 16),
                    if (_lines.isEmpty)
                      _buildEmpty(colors)
                    else
                      for (final line in _lines) ...[
                        _buildLineCard(context, colors, config, line),
                        const SizedBox(height: 12),
                      ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActions() {
    final disabled = _testingAll || _testingIds.isNotEmpty;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: disabled ? null : () => _editLine(),
            icon: const Icon(Icons.add),
            label: const Text('添加线路'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            onPressed: disabled || _lines.isEmpty ? null : _testAll,
            icon: const Icon(Icons.speed_outlined),
            label: const Text('自动测试'),
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty(AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: settingsCardDecoration(context),
      child: Column(
        children: [
          Icon(Icons.dns_outlined, size: 36, color: colors.muted),
          const SizedBox(height: 10),
          Text('暂无服务器线路', style: AppText.sectionTitle(context)),
          const SizedBox(height: 6),
          Text(
            '添加线路后可以测试延迟并切换当前服务器。',
            textAlign: TextAlign.center,
            style: AppText.meta(context),
          ),
        ],
      ),
    );
  }

  Widget _buildLineCard(
    BuildContext context,
    AppColors colors,
    ServerConfig config,
    ServerLine line,
  ) {
    final active = line.baseUrl == config.baseUrl;
    final testing = _testingIds.contains(line.id);
    final result = _testResults[line.id];
    final statusColor = testing
        ? colors.accent
        : result?.success == true
            ? Colors.green
            : result?.success == false
                ? colors.danger
                : colors.muted;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 12),
      decoration: settingsCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                active ? Icons.radio_button_checked : Icons.dns_outlined,
                color: active ? colors.accent : colors.muted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            line.name,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.cardTitle(context),
                          ),
                        ),
                        if (active) ...[
                          const SizedBox(width: 8),
                          _statusChip('当前', colors.accent),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      line.baseUrl,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.meta(context),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (testing)
                          SizedBox(
                            width: 13,
                            height: 13,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: statusColor,
                            ),
                          )
                        else
                          Icon(
                            result?.success == true
                                ? Icons.check_circle_outline
                                : result?.success == false
                                    ? Icons.error_outline
                                    : Icons.help_outline,
                            size: 15,
                            color: statusColor,
                          ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _statusText(line, result, testing),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SettingsSwitch(
                value: line.enabled,
                onChanged: testing ? null : (value) => _toggle(line, value),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!active)
                OutlinedButton.icon(
                  onPressed: line.enabled && !testing
                      ? () => _activate(line)
                      : null,
                  icon: const Icon(Icons.check_circle_outline, size: 17),
                  label: const Text('使用此线路'),
                ),
              OutlinedButton.icon(
                onPressed: testing ? null : () => _editLine(existing: line),
                icon: const Icon(Icons.edit_outlined, size: 17),
                label: const Text('编辑'),
              ),
              IconButton(
                tooltip: '删除线路',
                onPressed: testing ? null : () => _delete(line),
                icon: Icon(Icons.delete_outline, color: colors.danger),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String text, Color color) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  String _statusText(
    ServerLine line,
    _LineTestResult? result,
    bool testing,
  ) {
    if (testing) return '测试中...';
    if (result?.success == true) return '${result!.latencyMs} ms';
    if (result?.success == false) return '测试失败: ${result!.message}';
    if (line.latencyMs != null) return '上次测试 ${line.latencyMs} ms';
    return '尚未测试';
  }

  Future<void> _testAll() async {
    if (_testingAll || _lines.isEmpty) return;
    final lines = List<ServerLine>.of(_lines);
    setState(() {
      _testingAll = true;
      _testingIds.addAll(lines.map((line) => line.id));
      _testResults.clear();
    });
    try {
      final tested = await Future.wait(
        lines.map(
          (line) async => MapEntry(line.id, await _testLine(line)),
        ),
      );
      if (!mounted) return;
      final resultMap = Map<String, _LineTestResult>.fromEntries(tested);
      final now = DateTime.now();
      final updated = lines
          .map((line) {
            final result = resultMap[line.id];
            if (result?.success != true) return line;
            return line.copyWith(
              latencyMs: result!.latencyMs,
              lastTestedAt: now,
            );
          })
          .toList();
      setState(() {
        _testResults
          ..clear()
          ..addAll(resultMap);
        _lines = updated;
        _testingIds.clear();
      });
      ServerLine? fastestLine;
      var fastestLatency = 0;
      for (final entry in tested) {
        if (!entry.value.success) continue;
        if (fastestLine == null || entry.value.latencyMs < fastestLatency) {
          fastestLine = lines.firstWhere((line) => line.id == entry.key);
          fastestLatency = entry.value.latencyMs;
        }
      }
      if (mounted) {
        final message = fastestLine == null
            ? '自动测试完成，没有可用线路'
            : '最快线路：${fastestLine.name}（$fastestLatency ms）';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (error) {
      if (mounted) _showMessage(toApiException(error).message);
    } finally {
      if (mounted) {
        setState(() {
          _testingAll = false;
          _testingIds.clear();
        });
      }
    }
  }

  Future<void> _editLine({ServerLine? existing}) async {
    if (_testingAll || _testingIds.isNotEmpty) return;
    final draft = await showDialog<_ServerLineDraft>(
      context: context,
      builder: (_) => _ServerLineEditorDialog(existing: existing),
    );
    if (draft == null || !mounted) return;

    final normalized = ServerConfig.normalize(draft.baseUrl);
    final duplicate = _lines.any(
      (item) => item.id != existing?.id && item.baseUrl == normalized,
    );
    if (duplicate) {
      _showMessage('线路地址已存在，请使用不同的地址');
      return;
    }
    final line = ServerLine(
      id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: draft.name,
      baseUrl: normalized,
      enabled: existing?.enabled ?? true,
      latencyMs: existing?.baseUrl == normalized ? existing?.latencyMs : null,
      lastTestedAt:
          existing?.baseUrl == normalized ? existing?.lastTestedAt : null,
    );
    final result = await _testAndShow(line);
    if (!mounted || !result.success) return;

    final testedLine = line.copyWith(
      latencyMs: result.latencyMs,
      lastTestedAt: DateTime.now(),
    );
    final next = existing == null
        ? [..._lines, testedLine]
        : _lines
            .map((item) => item.id == existing.id ? testedLine : item)
            .toList();
    final current = ref.read(serverConfigProvider);
    final editingActive =
        existing != null && current?.baseUrl == existing.baseUrl;
    final activeUrl = current == null
        ? testedLine.baseUrl
        : editingActive
            ? testedLine.baseUrl
            : current.baseUrl;
    try {
      await _persist(next, activeUrl);
      if (mounted) {
        _showMessage(
          editingActive ? '线路已更新并切换' : '线路已保存（${result.latencyMs} ms）',
        );
      }
    } catch (error) {
      if (mounted) _showMessage(toApiException(error).message);
    }
  }

  Future<void> _activate(ServerLine line) async {
    if (!line.enabled || _testingAll || _testingIds.isNotEmpty) return;
    final result = await _testAndShow(line);
    if (!mounted || !result.success) return;
    final testedLine = line.copyWith(
      latencyMs: result.latencyMs,
      lastTestedAt: DateTime.now(),
    );
    final next = _lines
        .map((item) => item.id == line.id ? testedLine : item)
        .toList();
    try {
      await _persist(next, testedLine.baseUrl);
      if (mounted) _showMessage('已切换到 ${line.name}');
    } catch (error) {
      if (mounted) _showMessage(toApiException(error).message);
    }
  }

  Future<void> _toggle(ServerLine line, bool enabled) async {
    final current = ref.read(serverConfigProvider);
    if (current == null) return;
    if (!enabled && line.baseUrl == current.baseUrl) {
      final fallback = _lines.firstWhere(
        (item) => item.id != line.id && item.enabled,
        orElse: () => line,
      );
      if (fallback.id == line.id) {
        _showMessage('至少保留一条启用线路');
        return;
      }
      final next = _lines
          .map((item) => item.id == line.id
              ? item.copyWith(enabled: false)
              : item)
          .toList();
      try {
        await _persist(next, fallback.baseUrl);
      } catch (error) {
        if (mounted) _showMessage(toApiException(error).message);
      }
      return;
    }
    final next = _lines
        .map((item) => item.id == line.id
            ? item.copyWith(enabled: enabled)
            : item)
        .toList();
    try {
      await _persist(next, current.baseUrl);
    } catch (error) {
      if (mounted) _showMessage(toApiException(error).message);
    }
  }

  Future<void> _delete(ServerLine line) async {
    if (_lines.length <= 1) {
      _showMessage('至少保留一条服务器线路');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除服务器线路'),
        content: Text('确定删除“${line.name}”吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final current = ref.read(serverConfigProvider);
    if (current == null) return;
    final next = _lines.where((item) => item.id != line.id).toList();
    final activeUrl = line.baseUrl == current.baseUrl
        ? next.firstWhere((item) => item.enabled, orElse: () => next.first).baseUrl
        : current.baseUrl;
    try {
      await _persist(next, activeUrl);
      if (mounted) _showMessage('线路已删除');
    } catch (error) {
      if (mounted) _showMessage(toApiException(error).message);
    }
  }

  Future<_LineTestResult> _testAndShow(ServerLine line) async {
    setState(() {
      _testingIds.add(line.id);
      _testResults.remove(line.id);
    });
    final result = await _testLine(line);
    if (!mounted) return result;
    setState(() {
      _testingIds.remove(line.id);
      _testResults[line.id] = result;
    });
    if (!result.success) {
      _showMessage('线路测试失败：${result.message}');
    }
    return result;
  }

  Future<_LineTestResult> _testLine(ServerLine line) async {
    final stopwatch = Stopwatch()..start();
    try {
      final dio = buildDio(
        ServerConfig(baseUrl: line.baseUrl),
        connectTimeout: const Duration(seconds: 5),
        sendTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      );
      final response = await dio.get<dynamic>(
        '/version',
        options: Options(extra: {'skipRetry': true}),
      );
      requireCompatibleServerVersion(response.data);
      stopwatch.stop();
      return _LineTestResult.success(stopwatch.elapsedMilliseconds);
    } catch (error) {
      stopwatch.stop();
      return _LineTestResult.failure(toApiException(error).message);
    }
  }

  Future<void> _persist(List<ServerLine> lines, String activeUrl) async {
    final current = ref.read(serverConfigProvider);
    if (current != null && current.baseUrl != activeUrl) {
      await ref.read(authSessionRepositoryProvider).clear();
    }
    await ref.read(serverConfigProvider.notifier).save(
          ServerConfig(baseUrl: activeUrl, lines: lines),
        );
    if (mounted) setState(() => _lines = List<ServerLine>.of(lines));
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _LineTestResult {
  const _LineTestResult._({
    required this.success,
    required this.latencyMs,
    required this.message,
  });

  const _LineTestResult.success(int latencyMs)
      : this._(success: true, latencyMs: latencyMs, message: '');

  const _LineTestResult.failure(String message)
      : this._(success: false, latencyMs: 0, message: message);

  final bool success;
  final int latencyMs;
  final String message;
}

class _ServerLineDraft {
  const _ServerLineDraft({required this.name, required this.baseUrl});

  final String name;
  final String baseUrl;
}

class _ServerLineEditorDialog extends StatefulWidget {
  const _ServerLineEditorDialog({this.existing});

  final ServerLine? existing;

  @override
  State<_ServerLineEditorDialog> createState() => _ServerLineEditorDialogState();
}

class _ServerLineEditorDialogState extends State<_ServerLineEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _baseUrl;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _baseUrl = TextEditingController(text: widget.existing?.baseUrl ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _baseUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? '添加服务器线路' : '编辑服务器线路'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: '线路名称',
                hintText: '例如：家庭网络',
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _baseUrl,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: '服务器地址',
                hintText: 'http://192.168.1.10:8001',
              ),
              validator: (value) {
                final normalized = ServerConfig.normalize(value ?? '');
                if (normalized.isEmpty) return '请输入服务器地址';
                if (!normalized.startsWith('http://') &&
                    !normalized.startsWith('https://')) {
                  return '地址必须以 http:// 或 https:// 开头';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('测试并保存'),
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final name = _name.text.trim();
    Navigator.pop(
      context,
      _ServerLineDraft(
        name: name.isEmpty ? '服务器线路' : name,
        baseUrl: ServerConfig.normalize(_baseUrl.text),
      ),
    );
  }
}
