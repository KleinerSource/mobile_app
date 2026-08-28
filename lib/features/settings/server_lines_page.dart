import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/dio_factory.dart';
import '../../core/api/server_compatibility.dart';
import '../../core/config/server_config.dart';
import '../../core/config/server_config_provider.dart';
import '../../core/config/server_line_probe.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/glow_background.dart';
import '../../shared/swipe_actions.dart';
import 'settings_common.dart';

class ServerLinesPage extends ConsumerStatefulWidget {
  const ServerLinesPage({super.key, this.serverId});

  final String? serverId;

  @override
  ConsumerState<ServerLinesPage> createState() => _ServerLinesPageState();
}

class _ServerLinesPageState extends ConsumerState<ServerLinesPage> {
  final _testResults = <String, ServerLineProbeResult>{};
  final _testingIds = <String>{};

  /// 当前左滑展开的线路行，同一时刻只展开一个。
  final SwipeActionGroup _openSwipe = SwipeActionGroup(null);
  final _scrollController = ScrollController();
  List<ServerLine> _lines = const [];
  bool _loaded = false;
  bool _testingAll = false;

  ServerLineProbeCoordinator get _probeCoordinator =>
      ref.read(serverLineProbeCoordinatorProvider);

  ServerProfile? _serverFor(ServerConfig config) {
    if (config.servers.isEmpty) return null;
    if (widget.serverId == null) return config.activeServer;
    for (final server in config.servers) {
      if (server.id == widget.serverId) return server;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_closeSwipeOnScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_closeSwipeOnScroll);
    _openSwipe.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 列表开始滚动时收起已展开的左滑操作。
  void _closeSwipeOnScroll() {
    if (_openSwipe.value != null) _openSwipe.value = null;
  }

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
    final server = _serverFor(config);
    if (server == null) {
      return Scaffold(
        backgroundColor: colors.bg,
        body: const Center(child: Text('服务器不存在')),
      );
    }
    if (!_loaded) {
      _loaded = true;
      _lines = List<ServerLine>.of(server.lines);
    }

    return Scaffold(
      backgroundColor: colors.bg,
      body: GlowBackground(
        child: SafeArea(
          child: SettingsFixedHeaderLayout(
            scrollController: _scrollController,
            header: SettingsSubPageHeader(
              eyebrow: '服务器 · ${server.name}',
              title: '服务器线路',
              subtitle: '当前服务器可配置多条线路，自动选择最快可用线路',
            ),
            body: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 30),
              children: [
                _buildActions(),
                const SizedBox(height: 16),
                if (_lines.isEmpty)
                  _buildEmpty(colors)
                else
                  // 线路列表合并为设置页式分组卡，行间细分隔线。
                  Container(
                    decoration: settingsCardDecoration(context),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Column(
                        children: [
                          for (var i = 0; i < _lines.length; i++) ...[
                            if (i > 0)
                              Divider(height: 1, color: colors.divider),
                            SwipeActionCell(
                              group: _openSwipe,
                              cellKey: _lines[i].id,
                              enabled:
                                  !_testingAll &&
                                  !_testingIds.contains(_lines[i].id),
                              actions: _lineSwipeActions(
                                colors,
                                server,
                                _lines[i],
                              ),
                              child: _buildLineCard(
                                context,
                                colors,
                                server,
                                _lines[i],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
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
            label: const Text('自动选择'),
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
    ServerProfile server,
    ServerLine line,
  ) {
    final active = line.id == server.activeLine?.id;
    final testing = _testingIds.contains(line.id);
    final result = _testResults[line.id];
    final latencyText = _latencyText(line, result, testing);
    final statusColor = testing
        ? colors.accent
        : result?.success == true
        ? Colors.green
        : result?.success == false
        ? colors.danger
        : colors.muted;

    // 分组连排行：透明背景，由外层分组容器提供表面。
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            active ? Icons.radio_button_checked : Icons.dns_outlined,
            color: active ? colors.accent : colors.muted,
            size: 21,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        line.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.cardTitle(context),
                      ),
                    ),
                    if (latencyText != null) ...[
                      const SizedBox(width: 7),
                      if (testing) ...[
                        SizedBox(
                          width: 11,
                          height: 11,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.8,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        latencyText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (active) ...[
                      const SizedBox(width: 7),
                      _statusChip('当前', colors.accent),
                    ],
                    if (!line.enabled) ...[
                      const SizedBox(width: 7),
                      _statusChip('已禁用', colors.muted),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  line.baseUrl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.meta(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 单条线路的左滑操作集：当前线路与已禁用线路不再提供“使用”。
  List<SwipeActionData> _lineSwipeActions(
    AppColors colors,
    ServerProfile server,
    ServerLine line,
  ) {
    final active = line.id == server.activeLine?.id;
    return [
      if (!active && line.enabled)
        SwipeActionData(
          icon: Icons.check_circle_outline,
          label: '使用',
          color: AppHues.top(AppHues.mint),
          onPressed: () => _activate(line),
        ),
      SwipeActionData(
        icon: Icons.edit_outlined,
        label: '编辑',
        color: colors.accent,
        onPressed: () => _editLine(existing: line),
      ),
      SwipeActionData(
        icon: line.enabled ? Icons.block_rounded : Icons.check_rounded,
        label: line.enabled ? '禁用' : '启用',
        color: colors.warning,
        onPressed: () => _toggle(line, !line.enabled),
      ),
      SwipeActionData(
        icon: Icons.delete_outline,
        label: '删除',
        color: colors.danger,
        onPressed: () => _delete(line),
      ),
    ];
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

  String? _latencyText(
    ServerLine line,
    ServerLineProbeResult? result,
    bool testing,
  ) {
    if (testing) return 'Testing';
    if (result?.success == true) return '${result!.latencyMs} ms';
    if (result?.success == false) return 'Failed';
    if (line.latencyMs != null) return '${line.latencyMs} ms';
    return null;
  }

  Future<void> _testAll() async {
    if (_testingAll || _lines.isEmpty) return;
    final lines = _lines.where((line) => line.enabled).toList();
    if (lines.isEmpty) {
      _showMessage('没有启用的服务器线路');
      return;
    }
    setState(() {
      _testingAll = true;
      _testingIds.addAll(lines.map((line) => line.id));
      _testResults.clear();
    });
    final initialConfig = ref.read(serverConfigProvider);
    final server = initialConfig == null ? null : _serverFor(initialConfig);
    final batch = _probeCoordinator.probeAll(
      lines,
      onResult: _recordProbeResult,
      expectedProjectName: server?.projectName,
    );
    try {
      final selected = await batch.firstAvailable;
      if (selected != null && mounted) {
        // 首个健康线路立即成为当前服务器的线路，不再等待最慢线路的超时结果。
        await _persist(_lines, selected.line.baseUrl, validatedProbe: selected);
        if (mounted) {
          setState(() => _testingAll = false);
          _showMessage('已选择 ${selected.line.name}（${selected.latencyMs} ms）');
        }
      }

      final tested = await batch.completed;
      if (!mounted) return;
      final current = ref.read(serverConfigProvider);
      final server = current == null ? null : _serverFor(current);
      final activeUrl = selected?.line.baseUrl ?? server?.activeLine?.baseUrl;
      if (activeUrl != null) {
        await _persist(_lines, activeUrl);
      }
      if (selected == null) {
        _showMessage('自动测试完成，没有可用线路');
      } else if (tested.isNotEmpty) {
        final fastest = tested
            .where((result) => result.success)
            .fold<ServerLineProbeResult?>(
              null,
              (best, result) =>
                  best == null || result.latencyMs < best.latencyMs
                  ? result
                  : best,
            );
        if (fastest != null && fastest.line.id != selected.line.id) {
          _showMessage('测试完成，最快线路为 ${fastest.line.name}');
        }
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
      lastTestedAt: existing?.baseUrl == normalized
          ? existing?.lastTestedAt
          : null,
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
    final server = current == null ? null : _serverFor(current);
    if (server == null) return;
    final editingActive =
        existing != null && server.activeLine?.id == existing.id;
    final activeUrl = editingActive
        ? testedLine.baseUrl
        : server.activeLine?.baseUrl ?? testedLine.baseUrl;
    try {
      await _persist(next, activeUrl, validatedProbe: result);
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
      await _persist(next, testedLine.baseUrl, validatedProbe: result);
      if (mounted) _showMessage('已切换到 ${line.name}');
    } catch (error) {
      if (mounted) _showMessage(toApiException(error).message);
    }
  }

  Future<void> _toggle(ServerLine line, bool enabled) async {
    final current = ref.read(serverConfigProvider);
    final server = current == null ? null : _serverFor(current);
    if (current == null || server == null) return;
    if (!enabled && line.id == server.activeLine?.id) {
      final fallbackLines = _lines
          .where((item) => item.id != line.id && item.enabled)
          .toList();
      if (fallbackLines.isEmpty) {
        _showMessage('至少保留一条启用线路');
        return;
      }
      setState(() => _testingIds.addAll(fallbackLines.map((item) => item.id)));
      final batch = _probeCoordinator.probeAll(
        fallbackLines,
        onResult: _recordProbeResult,
        expectedProjectName: server.projectName,
      );
      final selected = await batch.firstAvailable;
      if (!mounted) return;
      if (selected == null) {
        setState(() => _testingIds.clear());
        _showMessage('没有可用的备用线路，未关闭当前线路');
        unawaited(batch.completed);
        return;
      }
      final next = _lines
          .map(
            (item) => item.id == line.id ? item.copyWith(enabled: false) : item,
          )
          .toList();
      try {
        await _persist(next, selected.line.baseUrl, validatedProbe: selected);
      } catch (error) {
        if (mounted) _showMessage(toApiException(error).message);
      }
      unawaited(batch.completed);
      return;
    }
    final next = _lines
        .map(
          (item) => item.id == line.id ? item.copyWith(enabled: enabled) : item,
        )
        .toList();
    try {
      await _persist(next, server.activeLine?.baseUrl ?? line.baseUrl);
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
    final server = _serverFor(current);
    if (server == null) return;
    final next = _lines.where((item) => item.id != line.id).toList();
    ServerLineProbeResult? validatedProbe;
    final deletingActive = line.id == server.activeLine?.id;
    final String activeUrl;
    if (deletingActive) {
      ServerLine? fallback;
      for (final item in next) {
        if (item.enabled) {
          fallback = item;
          break;
        }
      }
      final fallbackLine = fallback;
      if (fallbackLine == null) {
        _showMessage('至少保留一条启用线路，无法删除当前线路');
        return;
      }
      validatedProbe = await _testAndShow(fallbackLine);
      if (!mounted || !validatedProbe.success) return;
      activeUrl = fallbackLine.baseUrl;
    } else {
      activeUrl = server.activeLine?.baseUrl ?? next.first.baseUrl;
    }
    try {
      await _persist(next, activeUrl, validatedProbe: validatedProbe);
      if (mounted) _showMessage('线路已删除');
    } catch (error) {
      if (mounted) _showMessage(toApiException(error).message);
    }
  }

  Future<ServerLineProbeResult> _testAndShow(
    ServerLine line, {
    bool showFailure = true,
  }) async {
    setState(() {
      _testingIds.add(line.id);
      _testResults.remove(line.id);
    });
    final config = ref.read(serverConfigProvider);
    final server = config == null ? null : _serverFor(config);
    final result = await _probeCoordinator.probeAll([
      line,
    ], expectedProjectName: server?.projectName).firstAvailable;
    final resolved = result ?? ServerLineProbeResult.failure(line, '线路没有响应');
    if (!mounted) return resolved;
    setState(() {
      _testingIds.remove(line.id);
      _testResults[line.id] = resolved;
    });
    if (!resolved.success && showFailure) {
      _showMessage('线路测试失败：${resolved.message}');
    }
    return resolved;
  }

  void _recordProbeResult(ServerLineProbeResult result) {
    if (!mounted) return;
    final now = DateTime.now();
    setState(() {
      _testingIds.remove(result.line.id);
      _testResults[result.line.id] = result;
      if (result.success) {
        _lines = _lines
            .map(
              (line) => line.id == result.line.id
                  ? line.copyWith(
                      latencyMs: result.latencyMs,
                      lastTestedAt: now,
                    )
                  : line,
            )
            .toList();
      }
    });
  }

  Future<void> _persist(
    List<ServerLine> lines,
    String activeUrl, {
    ServerLineProbeResult? validatedProbe,
  }) async {
    final config = ref.read(serverConfigProvider);
    final server = config == null ? null : _serverFor(config);
    if (server == null) return;
    final selectedLine = lines.firstWhere(
      (line) => line.baseUrl == activeUrl,
      orElse: () =>
          lines.firstWhere((line) => line.enabled, orElse: () => lines.first),
    );
    final activeLineChanged =
        ServerConfig.normalize(server.activeLine?.baseUrl ?? '') !=
        ServerConfig.normalize(selectedLine.baseUrl);
    if (activeLineChanged &&
        !_isValidProbeForLine(validatedProbe, selectedLine)) {
      final probe = await _testAndShow(selectedLine, showFailure: false);
      if (!probe.success || probe.versionInfo == null) {
        throw ServerCompatibilityException(
          probe.message.isEmpty ? '服务器版本检测失败，未保存线路' : probe.message,
        );
      }
      validatedProbe = probe;
    }
    final versionInfo =
        validatedProbe?.versionInfo ??
        _testResults[selectedLine.id]?.versionInfo;
    await ref
        .read(serverConfigProvider.notifier)
        .saveServer(
          server.copyWith(
            lines: lines,
            activeLineId: selectedLine.id,
            serverVersion: versionInfo?.version ?? server.serverVersion,
          ),
          select: config?.activeServerId == server.id,
          validatedProbe: validatedProbe,
        );
    if (mounted) setState(() => _lines = List<ServerLine>.of(lines));
  }

  bool _isValidProbeForLine(ServerLineProbeResult? probe, ServerLine line) {
    return probe?.success == true &&
        probe?.versionInfo != null &&
        ServerConfig.normalize(probe!.line.baseUrl) ==
            ServerConfig.normalize(line.baseUrl);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
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
  State<_ServerLineEditorDialog> createState() =>
      _ServerLineEditorDialogState();
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
              textAlignVertical: TextAlignVertical.center,
              decoration: const InputDecoration(
                labelText: '线路名称',
                hintText: '例如：家庭网络',
                prefixIcon: Icon(Icons.drive_file_rename_outline),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _baseUrl,
              keyboardType: TextInputType.url,
              autocorrect: false,
              textAlignVertical: TextAlignVertical.center,
              decoration: const InputDecoration(
                labelText: '服务器地址',
                hintText: 'http://192.168.1.10:8001',
                prefixIcon: Icon(Icons.link),
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
        FilledButton(onPressed: _submit, child: const Text('测试并保存')),
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
