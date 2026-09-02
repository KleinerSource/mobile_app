import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/glass.dart';
import '../../shared/sheet_controls.dart';
import '../../shared/glow_background.dart';
import '../../shared/shake_error_text.dart';
import '../settings/settings_common.dart';
import 'security_pattern_pad.dart';
import 'security_pin_pad.dart';
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
    final l = AppL10n.of(context);
    return SettingsFixedHeaderLayout(
      header: SettingsSubPageHeader(
        eyebrow: l.settingsAppSettings,
        title: l.settingsSecurity,
        subtitle: l.securitySettingsSub,
      ),
      body: ListView(
        primary: true,
        children: [
          SettingsGroup(
            title: l.securityUnlockMethods,
            items: [
              _BiometricTile(
                enabled: settings.biometricEnabled,
                hasPin: settings.hasPin,
                onConfigurePin: () => _configurePin(context, ref),
              ),
              SettingsTile(
                title: l.securityAppPassword,
                subtitle: settings.hasPin
                    ? l.securityPinSet
                    : l.securityNotSet,
                leadingIcon: Icons.password_outlined,
                onTap: () => _openPinActions(context, ref, settings.hasPin),
              ),
              SettingsTile(
                title: l.securityGesturePassword,
                subtitle: settings.hasGesture
                    ? l.securityGestureSet
                    : l.securityNotSet,
                leadingIcon: Icons.gesture_rounded,
                onTap: () =>
                    _openGestureActions(context, ref, settings.hasGesture),
              ),
            ],
          ),
          SettingsGroup(
            title: l.securityUsageNotes,
            items: [
              SettingsTile(
                title: l.securityLockVerifyTitle,
                subtitle: l.securityLockVerifyDesc,
                leadingIcon: Icons.lock_outline,
              ),
            ],
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Future<void> _openPinActions(
    BuildContext context,
    WidgetRef ref,
    bool configured,
  ) async {
    final l = AppL10n.of(context);
    if (!configured) {
      await _configurePin(context, ref);
      return;
    }
    final action = await showGlassSheet<_CredentialAction>(
      context: context,
      builder: (context) => _CredentialActionSheet(
        title: l.securityAppPassword,
        icon: Icons.password_outlined,
      ),
    );
    if (!context.mounted || action == null) return;
    if (action == _CredentialAction.configure) {
      await _configurePin(context, ref);
    } else {
      await _clearCredential(
        context,
        title: l.securityClearPin,
        onConfirm: () =>
            ref.read(securityControllerProvider.notifier).clearPin(),
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
          SnackBar(content: Text(AppL10n.of(context).securityPinSaved)),
        );
      }
    } on FormatException {
      if (context.mounted) {
        _showError(context, AppL10n.of(context).securityPinInvalid);
      }
    } catch (error) {
      if (context.mounted) {
        _showError(
          context,
          AppL10n.of(context).securityPinSaveFailed(error.toString()),
        );
      }
    }
  }

  Future<void> _openGestureActions(
    BuildContext context,
    WidgetRef ref,
    bool configured,
  ) async {
    final l = AppL10n.of(context);
    if (!configured) {
      await _configureGesture(context, ref);
      return;
    }
    final action = await showGlassSheet<_CredentialAction>(
      context: context,
      builder: (context) => _CredentialActionSheet(
        title: l.securityGesturePassword,
        icon: Icons.gesture_rounded,
      ),
    );
    if (!context.mounted || action == null) return;
    if (action == _CredentialAction.configure) {
      await _configureGesture(context, ref);
    } else {
      await _clearCredential(
        context,
        title: l.securityClearGesture,
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
          SnackBar(content: Text(AppL10n.of(context).securityGestureSaved)),
        );
      }
    } on FormatException {
      if (context.mounted) {
        _showError(context, AppL10n.of(context).securityGestureMin);
      }
    } catch (error) {
      if (context.mounted) {
        _showError(
          context,
          AppL10n.of(context).securityGestureSaveFailed(error.toString()),
        );
      }
    }
  }

  Future<void> _clearCredential(
    BuildContext context, {
    required String title,
    required Future<void> Function() onConfirm,
  }) async {
    final l = AppL10n.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(l.securityClearConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.commonClear),
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
          SnackBar(
            content: Text(AppL10n.of(context).securityUnlockMethodCleared),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        _showError(
          context,
          AppL10n.of(context).securityClearFailed(error.toString()),
        );
      }
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _BiometricTile extends ConsumerWidget {
  const _BiometricTile({
    required this.enabled,
    required this.hasPin,
    required this.onConfigurePin,
  });

  final bool enabled;
  final bool hasPin;
  final Future<void> Function() onConfigurePin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    return SettingsTile(
      title: l.securityBiometricUnlock,
      subtitle: enabled
          ? l.securityBiometricOnDesc
          : l.securityBiometricNeedsPin,
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
        var pinConfigured =
            ref.read(securityControllerProvider).value?.hasPin ?? hasPin;
        if (!pinConfigured) {
          await onConfigurePin();
          if (!context.mounted) return;
          pinConfigured =
              ref.read(securityControllerProvider).value?.hasPin ?? false;
          if (!pinConfigured) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(AppL10n.of(context).securitySetPinFirst)),
            );
            return;
          }
        }
        final enabled = await controller.enableBiometrics();
        if (!enabled && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppL10n.of(context).securityBiometricUnavailable),
            ),
          );
        }
      } else {
        await controller.disableBiometrics();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppL10n.of(context).securityBiometricDisabled),
            ),
          );
        }
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppL10n.of(
                context,
              ).securityBiometricUpdateFailed(error.toString()),
            ),
          ),
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
    final l = AppL10n.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SheetHeader(
            icon: icon,
            title: title,
            padding: const EdgeInsets.fromLTRB(22, 6, 22, 8),
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: Text(l.commonChange),
            onTap: () => Navigator.pop(context, _CredentialAction.configure),
          ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: colors.danger),
            title: Text(
              l.commonClear,
              style: TextStyle(color: colors.danger),
            ),
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
  String? _firstPin;
  String? _error;
  int _errorToken = 0;
  Timer? _errorTimer;
  String get _message => _error ?? (_firstPin == null
      ? AppL10n.of(context).securityPinEnterFirst
      : AppL10n.of(context).securityPinEnterAgain);

  @override
  void dispose() {
    _errorTimer?.cancel();
    super.dispose();
  }

  void _showTransientError(String message) {
    _errorTimer?.cancel();
    setState(() {
      _errorToken++;
      _error = message;
    });
    _errorTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _error = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return AlertDialog(
      title: Text(l.securitySetPinTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null)
              ShakeErrorText(_message, replayToken: _errorToken)
            else
              Text(_message, style: AppText.meta(context)),
            const SizedBox(height: 12),
            SecurityPinPad(
              key: ValueKey(_firstPin == null ? 'first' : 'confirm'),
              showError: _error != null,
              onCompleted: _handlePin,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
      ],
    );
  }

  Future<void> _handlePin(String pin) async {
    final first = _firstPin;
    if (first == null) {
      setState(() {
        _firstPin = pin;
        _error = null;
      });
      return;
    }
    if (first != pin) {
      AppHaptics.error();
      setState(() => _firstPin = null);
      _showTransientError(AppL10n.of(context).securityPinMismatch);
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
  String? _error;
  int _errorToken = 0;
  Timer? _errorTimer;
  String get _message => _error ?? (_firstPattern == null
      ? AppL10n.of(context).securityPatternEnterFirst
      : AppL10n.of(context).securityPatternEnterAgain);

  @override
  void dispose() {
    _errorTimer?.cancel();
    super.dispose();
  }

  void _showTransientError(String message) {
    _errorTimer?.cancel();
    setState(() {
      _errorToken++;
      _error = message;
    });
    _errorTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _error = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return AlertDialog(
      title: Text(l.securitySetPatternTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null)
            ShakeErrorText(_message, replayToken: _errorToken)
          else
            Text(_message, style: AppText.meta(context)),
          const SizedBox(height: 12),
          SecurityPatternPad(
            size: 240,
            showError: _error != null,
            replayToken: _errorToken,
            onCompleted: _handlePattern,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
      ],
    );
  }

  void _handlePattern(List<int> pattern) {
    if (!isValidSecurityPattern(pattern)) {
      AppHaptics.error();
      _showTransientError(AppL10n.of(context).securityPatternTooFew);
      return;
    }
    final first = _firstPattern;
    if (first == null) {
      setState(() {
        _firstPattern = pattern;
        _error = null;
      });
      return;
    }
    if (listEquals(first, pattern)) {
      AppHaptics.medium();
      Navigator.pop(context, pattern);
      return;
    }
    AppHaptics.error();
    setState(() => _firstPattern = null);
    _showTransientError(AppL10n.of(context).securityPatternMismatch);
  }
}

class _SecuritySettingsError extends StatelessWidget {
  const _SecuritySettingsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l.securityLoadFailed(message),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(l.commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}
