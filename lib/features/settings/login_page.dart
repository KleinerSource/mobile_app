import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/dio_factory.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/auth/auth_session.dart';
import '../../core/config/server_config_provider.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/glow_background.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _passwordController = TextEditingController();
  final _totpController = TextEditingController();
  bool _totpRequired = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _totpController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() => _error = '请输入密码');
      return;
    }
    if (_totpRequired && _totpController.text.trim().isEmpty) {
      setState(() => _error = '请输入 TOTP 验证码');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final authenticated = await ref.read(authControllerProvider.notifier).login(
            password: password,
            totpCode: _totpRequired ? _totpController.text : null,
          );
      if (mounted && !authenticated) {
        setState(() {
          _totpRequired = true;
          _error = '请输入 TOTP 验证码';
        });
      }
    } catch (e) {
      if (!mounted) return;
      final ex = toApiException(e);
      final status = ref.read(authControllerProvider).valueOrNull?.status;
      if (status?.passwordLoginDisabled == true) {
        setState(() => _error = '服务器已禁用密码登录，当前版本暂不支持 Passkey');
      } else {
        final message = ex.message.trim();
        setState(() {
          _error = message.isEmpty ? '登录失败，请检查密码或服务器连接' : message;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeServer() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final config = ref.read(serverConfigProvider);
      if (config?.hasMultipleServers == true) {
        ref.read(serverConfigProvider.notifier).showServerSelection();
      } else {
        ref.read(serverConfigProvider.notifier).beginEdit();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final auth = ref.watch(authControllerProvider).valueOrNull;
    final status = auth?.status;
    final requiresTotp = _totpRequired || auth?.phase == AuthPhase.totpRequired;
    final localError = _error?.trim();
    final authError = auth?.message?.trim();
    final visibleError = localError?.isNotEmpty == true
        ? localError
        : authError?.isNotEmpty == true
            ? authError
            : null;

    return Scaffold(
      backgroundColor: c.bg,
      body: GlowBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 36, 28, 36),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) => Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 18 * (1 - value)),
                    child: child,
                  ),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AUTHENTICATE', style: AppText.eyebrow(context)),
                      const SizedBox(height: 6),
                      Text('登录 MD Center', style: AppText.pageTitle(context)),
                      const SizedBox(height: 12),
                      Text(
                        status?.totpConfigured == true
                            ? '此服务器需要密码和 TOTP 验证码。'
                            : '请输入服务器密码继续。',
                        style: AppText.body(context),
                      ),
                      const SizedBox(height: 28),
                      _input(
                        context,
                        controller: _passwordController,
                        label: '密码',
                        obscureText: true,
                        icon: Icons.key_outlined,
                        onSubmitted: (_) => _login(),
                      ),
                      if (requiresTotp) ...[
                        const SizedBox(height: 14),
                        _input(
                          context,
                          controller: _totpController,
                          label: 'TOTP 验证码',
                          keyboardType: TextInputType.number,
                          icon: Icons.timer_outlined,
                          onSubmitted: (_) => _login(),
                        ),
                      ],
                      if (visibleError != null) ...[
                        const SizedBox(height: 12),
                        Text(visibleError, style: TextStyle(color: c.danger)),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _busy ? null : _login,
                          icon: _busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.login),
                          label: Text(_busy ? '登录中...' : '登录'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: TextButton.icon(
                          onPressed: _busy ? null : () => _changeServer(),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('返回服务器地址编辑'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _input(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    bool obscureText = false,
    TextInputType? keyboardType,
    IconData? icon,
    ValueChanged<String>? onSubmitted,
  }) {
    final c = appColors(context);
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon == null ? null : Icon(icon),
        filled: true,
        fillColor: c.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.cardBorder),
        ),
      ),
    );
  }
}
