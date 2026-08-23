import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/dio_factory.dart';
import '../../core/api/server_compatibility.dart';
import '../../core/config/server_config.dart';
import '../../core/config/server_config_provider.dart';
import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/glass.dart';
import '../../shared/glow_background.dart';
import 'settings_common.dart';

class ServerSetupPage extends ConsumerStatefulWidget {
  const ServerSetupPage({super.key});

  @override
  ConsumerState<ServerSetupPage> createState() => _ServerSetupPageState();
}

class _ServerSetupPageState extends ConsumerState<ServerSetupPage> {
  final _controller = TextEditingController();
  ServerConfig? _savedConfig;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _savedConfig =
        ref.read(serverConfigProvider) ??
        ref.read(serverConfigRepoProvider).load();
    if (_savedConfig != null) _controller.text = _savedConfig!.baseUrl;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _testAndSave() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = '请输入服务器地址');
      return;
    }
    final normalized = ServerConfig.normalize(raw);
    if (!normalized.startsWith('http://') &&
        !normalized.startsWith('https://')) {
      setState(() => _error = '地址必须以 http:// 或 https:// 开头');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final dio = buildDio(ServerConfig(baseUrl: normalized));
      final response = await dio.get<dynamic>('/version');
      requireCompatibleServerVersion(response.data);
      final existing =
          _savedConfig ??
          ref.read(serverConfigProvider) ??
          ref.read(serverConfigRepoProvider).load();
      final config = ServerConfig(
        baseUrl: normalized,
        lines: existing?.baseUrl == normalized ? existing!.lines : const [],
        servers: existing?.baseUrl == normalized ? existing!.servers : const [],
        activeServerId: existing?.baseUrl == normalized
            ? existing!.activeServerId
            : null,
      );
      await ref.read(serverConfigProvider.notifier).save(config);
      _savedConfig = ref.read(serverConfigProvider);
      AppHaptics.medium();
      if (mounted) await Navigator.of(context).maybePop();
    } catch (e) {
      final exception = toApiException(e);
      final incompatible = exception.status == 401 || exception.status == 404;
      setState(
        () => _error = incompatible
            ? serverCompatibilityRequirementMessage
            : exception.message,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final editing = _savedConfig != null;
    return Scaffold(
      backgroundColor: c.bg,
      body: GlowBackground(
        child: SafeArea(
          child: SettingsFixedHeaderLayout(
            header: SettingsSubPageHeader(
              eyebrow: '服务器',
              title: editing ? '更换服务器' : '连接到 MD Center',
              subtitle: editing
                  ? '修改服务器地址后重新测试连接。'
                  : '输入服务器地址，包含协议和端口。\n例：http://192.168.1.10:8001',
              showBackButton: Navigator.of(context).canPop(),
            ),
            body: ListView(
              primary: true,
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 30),
              children: [
                GlassPanel(
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: c.accent.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Icon(
                                Icons.dns_outlined,
                                color: c.accent,
                                size: 21,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '服务器地址',
                                  style: AppText.cardTitle(context),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'SERVER URL',
                                  style: AppText.eyebrow(context),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            color: c.surfaceAlt,
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(color: c.cardBorder),
                          ),
                          child: TextField(
                            controller: _controller,
                            keyboardType: TextInputType.url,
                            autocorrect: false,
                            style: TextStyle(
                              color: c.text,
                              fontFamily: 'monospace',
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: 'http://192.168.1.10:8001',
                              hintStyle: TextStyle(
                                color: c.muted2,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w500,
                              ),
                              prefixIcon: Icon(
                                Icons.link,
                                color: c.muted,
                                size: 19,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 16,
                              ),
                            ),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: c.danger.withValues(alpha: 0.09),
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(
                                color: c.danger.withValues(alpha: 0.18),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: c.danger,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: TextStyle(
                                      color: c.danger,
                                      fontSize: 13,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SettingsSaveButton(
                  onPressed: _testAndSave,
                  saving: _busy,
                  label: '测试并保存',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
