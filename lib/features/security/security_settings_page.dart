import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/glow_background.dart';
import '../settings/settings_common.dart';
import 'security_pattern_pad.dart';
import 'security_policy.dart';
import 'security_providers.dart';
import 'security_repository.dart';

class SecuritySettingsPage extends ConsumerWidget {
  const SecuritySettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = appColors(context);
    final security = ref.watch(securityControllerProvider);
    return Scaffold(
      backgroundColor: colors.bg,
      body: GlowBackground(
        child: SafeArea(
          child: security.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _SecuritySettingsError(
              message: error.toString(),
              onRetry: () => ref.invalidate(securityControllerProvider),
            ),
            data: (settings) => _SecuritySettingsContent(settings: settings),
          ),
        ),
      ),
    );
  }
}

class _SecuritySettingsContent extends ConsumerWidget {
  const _SecuritySettingsContent({required this.settings});

  final SecuritySettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      children: [
        const SettingsSubPageHeader(
          eyebrow: '应用设置',
          title: '安全设置',
          subtitle: '配置进入 MD Center 时使用的本地验证方式',
        ),
        SettingsGroup(
          title: '解锁方式',
          items: [
            _BiometricTile(enabled: settings.biometricEnabled),
            SettingsTile(
              title: '进入密码',
              subtitle: settings.hasPin ? '已设置 · 4–6 位数字' : '未设置',
              leadingIcon: Icons.password_outlined,
              onTap: () => _openPinActions(context, ref, settings.hasPin),
            ),
            SettingsTile(
              title: '手势密码',
              subtitle: settings.hasGesture ? '已设置 · 3×3 手势图案' : '未设置',
              leadingIcon: Icons.gesture_rounded,
              onTap: () => _openGestureActions(
                context,
                ref,
                settings.hasGesture,
              ),
            ),
          ],
        ),
        const SettingsGroup(
          title: '使用说明',
          items: const [
            SettingsTile(
              title: '应用锁定时验证',
              subtitle: '配置任意一种方式后，应用启动和回到前台时会要求验证。',
              leadingIcon: Icons.lock_outline,
            ),
          ],
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Future<void> _openPinActions(
    BuildContext context,
    WidgetRef ref,
    bool configured,
  ) async {
    if (!configured) {
      await _configurePin(context, ref);
      return;
    }
    final action = await showModalBottomSheet<_CredentialAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => const _CredentialActionSheet(
        title: '进入密码',
        icon: Icons.password_outlined,
      ),
    );
    if (!context.mounted || action == null) return;
    if (action == _CredentialAction.configure) {
      await _configurePin(context, ref);
    } else {
      await _clearCredential(
        context,
        title: '清除数字密码',
        onConfirm: () => ref.read(securityControllerProvider.notifier).clearPin(),
      );
    }
  }

  Future<void> _configurePin(BuildContext context, WidgetRef ref) async {
    final pin = await showDialog<String>(
      context: context,
      builder: (_) => const _PinSetupDialog(),
    );
    if (pin == null || !context.mounted) return;
    try {
      await ref.read(securityControllerProvider.notifier).savePin(pin);
      if (context.mounted) {
        AppHaptics.medium();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('数字密码已保存')),
        );
      }
    } catch (error) {
      if (context.mounted) _showError(context, '数字密码保存失败: $error');
    }
  }

  Future<void> _openGestureActions(
    BuildContext context,
    WidgetRef ref,
    bool configured,
  ) async {
    if (!configured) {
      await _configureGesture(context, ref);
      return;
    }
    final action = await showModalBottomSheet<_CredentialAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => const _CredentialActionSheet(
        title: '手势密码',
        icon: Icons.gesture_rounded,
      ),
    );
    if (!context.mounted || action == null) return;
    if (action == _CredentialAction.configure) {
      await _configureGesture(context, ref);
    } else {
      await _clearCredential(
        context,
        title: '清除手势密码',
        onConfirm: () =>
            ref.read(securityControllerProvider.notifier).clearGesture(),
      );
    }
  }

  Future<void> _configureGesture(BuildContext context, WidgetRef ref) async {
    final pattern = await showDialog<List<int>>(
      context: context,
      builder: (_) => const _PatternSetupDialog(),
    );
    if (pattern == null || !context.mounted) return;
    try {
      await ref.read(securityControllerProvider.notifier).saveGesture(pattern);
      if (context.mounted) {
        AppHaptics.medium();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('手势密码已保存')),
        );
      }
    } catch (error) {
      if (context.mounted) _showError(context, '手势密码保存失败: $error');
    }
  }

  Future<void> _clearCredential(
    BuildContext context, {
    required String title,
    required Future<void> Function() onConfirm,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: const Text('清除后，应用将不再使用此方式解锁。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await onConfirm();
      if (context.mounted) {
        AppHaptics.medium();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('解锁方式已清除')),
        );
      }
    } catch (error) {
      if (context.mounted) _showError(context, '清除失败: $error');
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _BiometricTile extends ConsumerWidget {
  const _BiometricTile({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsTile(
      title: '面容/指纹解锁',
      subtitle: enabled ? '已启用 · 支持时优先使用系统生物识别' : '未启用',
      leadingIcon: Icons.fingerprint,
      trailing: SettingsSwitch(
        value: enabled,
        onChanged: (value) => unawaited(_setEnabled(context, ref, value)),
      ),
    );
  }

  Future<void> _setEnabled(
    BuildContext context,
    WidgetRef ref,
    bool value,
  ) async {
    final controller = ref.read(securityControllerProvider.notifier);
    try {
      if (value) {
        final enabled = await controller.enableBiometrics();
        if (!enabled && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('当前设备没有可用的面容或指纹，或验证未完成')),
          );
        }
      } else {
        await controller.disableBiometrics();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('面容/指纹解锁已关闭')),
          );
        }
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新生物识别设置失败: $error')),
        );
      }
    }
  }
}

enum _CredentialAction { configure, clear }

class _CredentialActionSheet extends StatelessWidget {
  const _CredentialActionSheet({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(icon, color: colors.accent),
            title: Text(title, style: AppText.sectionTitle(context)),
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('修改'),
            onTap: () => Navigator.pop(context, _CredentialAction.configure),
          ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: colors.danger),
            title: Text('清除', style: TextStyle(color: colors.danger)),
            onTap: () => Navigator.pop(context, _CredentialAction.clear),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _PinSetupDialog extends StatefulWidget {
  const _PinSetupDialog();

  @override
  State<_PinSetupDialog> createState() => _PinSetupDialogState();
}

class _PinSetupDialogState extends State<_PinSetupDialog> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('设置进入密码'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _pinController,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: securityPinMaxLength,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(securityPinMaxLength),
              ],
              decoration: settingsInputDecoration(
                context,
                labelText: '4–6 位数字',
                prefixIcon: const Icon(Icons.password_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: securityPinMaxLength,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(securityPinMaxLength),
              ],
              decoration: settingsInputDecoration(
                context,
                labelText: '再次输入',
                prefixIcon: const Icon(Icons.check_circle_outline),
              ),
            ),
            if (_error != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _error!,
                  style: TextStyle(color: appColors(context).danger),
                ),
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
          child: const Text('保存'),
        ),
      ],
    );
  }

  void _submit() {
    final pin = _pinController.text;
    final confirm = _confirmController.text;
    if (!isValidSecurityPin(pin)) {
      setState(() => _error = '请输入 4–6 位数字');
      return;
    }
    if (pin != confirm) {
      setState(() => _error = '两次输入的密码不一致');
      return;
    }
    AppHaptics.medium();
    Navigator.pop(context, pin);
  }
}

class _PatternSetupDialog extends StatefulWidget {
  const _PatternSetupDialog();

  @override
  State<_PatternSetupDialog> createState() => _PatternSetupDialogState();
}

class _PatternSetupDialogState extends State<_PatternSetupDialog> {
  List<int>? _firstPattern;
  String _message = '连接至少 4 个节点';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('设置手势密码'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_message, style: AppText.meta(context)),
          const SizedBox(height: 12),
          SecurityPatternPad(
            size: 240,
            onCompleted: _handlePattern,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ],
    );
  }

  void _handlePattern(List<int> pattern) {
    if (!isValidSecurityPattern(pattern)) {
      setState(() => _message = '手势至少需要连接 4 个不同节点');
      return;
    }
    final first = _firstPattern;
    if (first == null) {
      setState(() {
        _firstPattern = pattern;
        _message = '请再次绘制相同手势以确认';
      });
      return;
    }
    if (listEquals(first, pattern)) {
      AppHaptics.medium();
      Navigator.pop(context, pattern);
      return;
    }
    setState(() {
      _firstPattern = null;
      _message = '两次手势不一致，请重新绘制';
    });
  }
}

class _SecuritySettingsError extends StatelessWidget {
  const _SecuritySettingsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('安全设置加载失败\n$message', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}
