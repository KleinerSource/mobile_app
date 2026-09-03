import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/dio_factory.dart';
import '../../core/api/providers.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/auth/auth_session.dart';
import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/glow_background.dart';
import 'settings_common.dart';

/// 服务器访问控制 · 登录凭据、会话策略和 TOTP
class AccessControlPage extends ConsumerStatefulWidget {
  const AccessControlPage({super.key});

  @override
  ConsumerState<AccessControlPage> createState() => _AccessControlPageState();
}

class _AccessControlPageState extends ConsumerState<AccessControlPage> {
  final _passwordController = TextEditingController();
  final _refreshDaysController = TextEditingController();
  final _maxAttemptsController = TextEditingController();
  final _lockMinutesController = TextEditingController();

  bool _loading = true;
  bool _loadFailed = false;
  bool _saving = false;
  bool _totpBusy = false;
  bool _enabled = false;
  bool _configured = false;
  bool _passwordLoginDisabled = false;
  bool _totpConfigured = false;
  bool _webAuthnConfigured = false;
  bool _showPassword = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _refreshDaysController.dispose();
    _maxAttemptsController.dispose();
    _lockMinutesController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final config = await ref.read(requiredApiClientProvider).auth.config();
      if (!mounted) return;
      _applyConfig(config);
      setState(() => _loading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
        _error = toApiException(error).message;
      });
    }
  }

  void _applyConfig(AuthConfig config) {
    _enabled = config.enabled;
    _configured = config.configured;
    _passwordLoginDisabled = config.passwordLoginDisabled;
    _totpConfigured = config.totpConfigured;
    _webAuthnConfigured = config.webAuthnConfigured;
    _passwordController.clear();
    _refreshDaysController.text = '${config.refreshTokenExpireDays}';
    _maxAttemptsController.text = '${config.maxFailedAttempts}';
    _lockMinutesController.text = '${config.lockMinutes}';
  }

  Future<void> _save() async {
    final l = AppL10n.of(context);
    final password = _passwordController.text.trim();
    if (password.isNotEmpty && password.length < 8) {
      setState(() => _error = l.accessPasswordTooShort);
      return;
    }

    final refreshDays = _parseInt(
      _refreshDaysController,
      min: 1,
      max: 90,
      label: l.accessRefreshTokenDays,
    );
    final maxAttempts = _parseInt(
      _maxAttemptsController,
      min: 1,
      max: 100,
      label: l.accessMaxFailedAttempts,
    );
    final lockMinutes = _parseInt(
      _lockMinutesController,
      min: 1,
      max: 1440,
      label: l.accessLockDuration,
    );
    if (refreshDays == null || maxAttempts == null || lockMinutes == null) {
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final config = await ref
          .read(requiredApiClientProvider)
          .auth
          .updateConfig(
            enabled: _enabled,
            password: password.isEmpty ? null : password,
            refreshTokenExpireDays: refreshDays,
            maxFailedAttempts: maxAttempts,
            lockMinutes: lockMinutes,
          );
      if (!mounted) return;
      setState(() => _applyConfig(config));
      ref.invalidate(authControllerProvider);
      AppHaptics.medium();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppL10n.of(context).accessConfigSaved),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = toApiException(error).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  int? _parseInt(
    TextEditingController controller, {
    required int min,
    required int max,
    required String label,
  }) {
    final value = int.tryParse(controller.text.trim());
    if (value == null || value < min || value > max) {
      setState(
        () => _error = AppL10n.of(context).accessRangeError(label, min, max),
      );
      return null;
    }
    return value;
  }

  Future<void> _beginTotp() async {
    if (!_enabled) {
      setState(() => _error = AppL10n.of(context).accessEnableFirst);
      return;
    }
    setState(() {
      _totpBusy = true;
      _error = null;
    });
    try {
      final setup = await ref.read(requiredApiClientProvider).auth.beginTotp();
      if (!mounted) return;
      final code = await _showTotpDialog(setup);
      if (!mounted || code == null || code.isEmpty) return;
      await ref
          .read(requiredApiClientProvider)
          .auth
          .finishTotp(sessionId: setup.sessionId, code: code);
      if (!mounted) return;
      setState(() => _totpConfigured = true);
      ref.invalidate(authControllerProvider);
      AppHaptics.medium();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppL10n.of(context).accessTotpEnabled),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = toApiException(error).message);
    } finally {
      if (mounted) setState(() => _totpBusy = false);
    }
  }

  Future<void> _deleteTotp() async {
    final l = AppL10n.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.accessDeleteTotp),
        content: Text(l.accessDeleteTotpConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _totpBusy = true;
      _error = null;
    });
    try {
      await ref.read(requiredApiClientProvider).auth.deleteTotp();
      if (!mounted) return;
      setState(() => _totpConfigured = false);
      ref.invalidate(authControllerProvider);
      AppHaptics.medium();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppL10n.of(context).accessTotpDeleted),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = toApiException(error).message);
    } finally {
      if (mounted) setState(() => _totpBusy = false);
    }
  }

  Future<String?> _showTotpDialog(TotpSetup setup) async {
    final codeController = TextEditingController();
    final qrBytes = _decodeQrData(setup.qrDataUrl);
    final l = AppL10n.of(context);
    try {
      return await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l.accessBindTotp),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (qrBytes != null) ...[
                  Image.memory(qrBytes, width: 192, height: 192),
                  const SizedBox(height: 12),
                ],
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(l.accessTotpManualKey),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  setup.secret,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: codeController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  maxLength: 8,
                  textAlignVertical: TextAlignVertical.center,
                  decoration: InputDecoration(
                    labelText: l.accessTotpCode,
                    hintText: l.accessTotpCodeHint,
                    prefixIcon: const Icon(Icons.timer_outlined),
                    counterText: '',
                  ),
                  onSubmitted: (value) {
                    if (value.trim().isNotEmpty) {
                      Navigator.of(ctx).pop(value.trim());
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: () {
                final value = codeController.text.trim();
                if (value.isNotEmpty) Navigator.of(ctx).pop(value);
              },
              child: Text(l.accessTotpConfirmBind),
            ),
          ],
        ),
      );
    } finally {
      codeController.dispose();
    }
  }

  static Uint8List? _decodeQrData(String value) {
    final comma = value.indexOf(',');
    if (comma < 0) return null;
    try {
      return base64Decode(value.substring(comma + 1));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: GlowBackground(child: SafeArea(child: _buildBody(c))),
    );
  }

  Widget _buildBody(AppColors c) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadFailed) return _buildLoadError();
    return _buildForm(c);
  }

  Widget _buildForm(AppColors c) {
    final l = AppL10n.of(context);
    final active = _enabled && _configured;
    final statusTitle = active
        ? l.accessStatusActive
        : _configured
        ? l.accessStatusConfigured
        : l.accessStatusNotConfigured;
    final statusDescription = active
        ? l.accessStatusActiveDesc
        : _configured
        ? l.accessStatusConfiguredDesc
        : l.accessStatusNotConfiguredDesc;

    return SettingsFixedHeaderLayout(
      header: SettingsSubPageHeader(
        eyebrow: l.settingsGroupSystem,
        title: l.accessControlTitle,
        subtitle: l.accessControlSubtitle,
      ),
      body: ListView(
        primary: true,
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
        children: [
          _statusCard(
            c,
            title: statusTitle,
            description: statusDescription,
            icon: active ? Icons.verified_user_outlined : Icons.info_outline,
            color: c.accent,
          ),
          const SizedBox(height: 18),
          _sectionLabel(
            l.accessSectionProtection,
            l.accessSectionProtectionHelp,
          ),
          _switchCard(c),
          const SizedBox(height: 18),
          _sectionLabel(
            _configured ? l.accessChangePassword : l.accessSetPassword,
            _configured ? l.accessChangePasswordHelp : l.accessSetPasswordHelp,
          ),
          _passwordInput(c),
          const SizedBox(height: 18),
          _sectionLabel(l.accessSectionSession, l.accessSectionSessionHelp),
          _numberInput(
            c,
            label: l.accessRefreshTokenDays,
            suffix: l.unitDays,
            controller: _refreshDaysController,
            icon: Icons.schedule,
            help: l.accessRefreshDaysHelp,
          ),
          const SizedBox(height: 12),
          _numberInput(
            c,
            label: l.accessMaxFailedAttempts,
            suffix: l.unitTimes,
            controller: _maxAttemptsController,
            icon: Icons.error_outline,
            help: l.accessMaxAttemptsHelp,
          ),
          const SizedBox(height: 12),
          _numberInput(
            c,
            label: l.accessLockDuration,
            suffix: l.unitMinutes,
            controller: _lockMinutesController,
            icon: Icons.lock_clock,
            help: l.accessLockMinutesHelp,
          ),
          const SizedBox(height: 18),
          _sectionLabel(l.accessSectionMfa, l.accessSectionMfaHelp),
          _totpCard(c),
          if (_webAuthnConfigured || _passwordLoginDisabled) ...[
            const SizedBox(height: 10),
            _infoBox(
              c,
              _passwordLoginDisabled
                  ? l.accessPasskeyOnlyInfo
                  : l.accessPasskeyConfiguredInfo,
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 14),
            _errorBox(_error!),
          ],
          const SizedBox(height: 28),
          SettingsSaveButton(onPressed: _save, saving: _saving),
        ],
      ),
    );
  }

  Widget _buildLoadError() {
    final l = AppL10n.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error ?? l.accessLoadFailed, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _loadFailed = false;
                  _error = null;
                });
                unawaited(_load());
              },
              icon: const Icon(Icons.refresh),
              label: Text(l.commonRetry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusCard(
    AppColors c, {
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: c.text,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(description, style: AppText.meta(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label, String help) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppText.eyebrow(context)),
          const SizedBox(height: 2),
          Text(help, style: AppText.meta(context).copyWith(fontSize: 10.5)),
        ],
      ),
    );
  }

  Widget _switchCard(AppColors c) {
    final l = AppL10n.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: settingsCardDecoration(context),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _enabled ? l.accessEnabled : l.accessDisabled,
              style: TextStyle(
                color: c.text,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          SettingsSwitch(
            value: _enabled,
            onChanged: _saving
                ? null
                : (value) => setState(() => _enabled = value),
          ),
        ],
      ),
    );
  }

  Widget _passwordInput(AppColors c) {
    final l = AppL10n.of(context);
    return Container(
      decoration: settingsCardDecoration(context),
      child: TextField(
        controller: _passwordController,
        obscureText: !_showPassword,
        autocorrect: false,
        textAlignVertical: TextAlignVertical.center,
        decoration: settingsInputDecoration(
          context,
          borderless: true,
          hintText: _configured
              ? l.accessNewPasswordHint
              : l.accessPasswordMinHint,
          prefixIcon: const Icon(Icons.key_outlined),
          suffixIcon: IconButton(
            tooltip: _showPassword
                ? l.commonHidePassword
                : l.commonShowPassword,
            icon: Icon(
              _showPassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 18,
              color: c.muted,
            ),
            onPressed: () => setState(() => _showPassword = !_showPassword),
          ),
        ),
        style: TextStyle(
          color: c.text,
          fontFamily: 'monospace',
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _numberInput(
    AppColors c, {
    required String label,
    required String suffix,
    required TextEditingController controller,
    required String help,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: c.text2, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: settingsCardDecoration(context),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  textAlignVertical: TextAlignVertical.center,
                  decoration: settingsInputDecoration(
                    context,
                    prefixIcon: icon == null ? null : Icon(icon),
                    borderless: true,
                  ),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Text(suffix, style: AppText.meta(context)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 3),
        Text(help, style: AppText.meta(context)),
      ],
    );
  }

  Widget _totpCard(AppColors c) {
    final l = AppL10n.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: settingsCardDecoration(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user_outlined, color: c.accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.accessTotpTwoFactor,
                  style: TextStyle(
                    color: c.text,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _totpConfigured
                      ? l.accessTotpBoundDesc
                      : l.accessTotpUnboundDesc,
                  style: AppText.meta(context),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _totpBusy || !_enabled ? null : _beginTotp,
                      icon: _totpBusy
                          ? const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              _totpConfigured ? Icons.refresh : Icons.add,
                              size: 16,
                            ),
                      label: Text(
                        _totpConfigured ? l.accessRebindTotp : l.accessBindTotp,
                      ),
                    ),
                    if (_totpConfigured)
                      IconButton(
                        tooltip: l.accessDeleteTotp,
                        onPressed: _totpBusy || !_enabled ? null : _deleteTotp,
                        icon: Icon(Icons.delete_outline, color: c.danger),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoBox(AppColors c, String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.accent.withValues(alpha: 0.08),
        border: Border.all(color: c.accent.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: c.accent),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: AppText.meta(context))),
        ],
      ),
    );
  }

  Widget _errorBox(String message) {
    final c = appColors(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.danger.withValues(alpha: 0.1),
        border: Border.all(color: c.danger.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 16, color: c.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: c.danger,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
