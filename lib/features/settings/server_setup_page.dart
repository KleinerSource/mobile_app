import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/dio_factory.dart';
import '../../core/config/server_config.dart';
import '../../core/config/server_config_provider.dart';
import '../../core/ui/app_scaffold.dart';
import '../../core/ui/tokens.dart';

class ServerSetupPage extends ConsumerStatefulWidget {
  const ServerSetupPage({super.key});

  @override
  ConsumerState<ServerSetupPage> createState() => _ServerSetupPageState();
}

class _ServerSetupPageState extends ConsumerState<ServerSetupPage> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = ref.read(serverConfigProvider);
    if (existing != null) _controller.text = existing.baseUrl;
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
      await dio.get<dynamic>('/health');
      await ref
          .read(serverConfigProvider.notifier)
          .save(ServerConfig(baseUrl: normalized));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = toApiException(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    return AppScaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Text(
              '连接 md_center 后端',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: c.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '请输入服务器地址，包含协议和端口。例：http://192.168.1.10:8001',
              style: TextStyle(fontSize: 13, color: c.textMuted),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                controller: _controller,
                keyboardType: TextInputType.url,
                autocorrect: false,
                style: TextStyle(fontSize: 14, color: c.text),
                cursorColor: c.brand,
                decoration: InputDecoration(
                  isCollapsed: true,
                  hintText: 'http://192.168.1.10:8001',
                  hintStyle: TextStyle(fontSize: 14, color: c.textMuted),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Color(0xFFEF4444))),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _testAndSave,
              child: _busy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('测试并保存'),
            ),
          ],
        ),
      ),
    );
  }
}
