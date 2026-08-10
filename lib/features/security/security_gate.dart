import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';
import '../../shared/glow_background.dart';
import 'security_pattern_pad.dart';
import 'security_pin_pad.dart';
import 'security_providers.dart';
import 'security_repository.dart';

/// 在主界面外层提供本地应用锁，不影响服务端登录会话。
class SecurityGate extends ConsumerStatefulWidget {
  const SecurityGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SecurityGate> createState() => _SecurityGateState();
}

class _SecurityGateState extends ConsumerState<SecurityGate>
    with WidgetsBindingObserver {
  bool _locked = false;
  bool _securityInitialized = false;
  bool _busy = false;
  bool _biometricInFlight = false;
  bool _biometricAttempted = false;
  bool _wasBackgrounded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _wasBackgrounded = true;
      ref.read(securityBiometricCoordinatorProvider).didEnterInactive();
      return;
    }
    if (state != AppLifecycleState.resumed || !mounted) return;

    // local_auth 的系统验证页也会触发一次生命周期切换。这个切换不是
    // 用户离开应用，不能在验证成功后再次锁定并重复弹出生物识别。
    if (ref.read(securityBiometricCoordinatorProvider).consumeResume() ||
        _biometricInFlight) {
      _wasBackgrounded = false;
      return;
    }
    if (!_wasBackgrounded) return;
    _wasBackgrounded = false;

    final settings = ref.read(securityControllerProvider).valueOrNull;
    if (settings?.requiresUnlock != true) return;
    setState(() {
      _locked = true;
      _error = null;
      _biometricAttempted = false;
    });
    _scheduleBiometric(settings!);
  }

  @override
  Widget build(BuildContext context) {
    final security = ref.watch(securityControllerProvider);
    return security.when(
      loading: () => const _SecurityLoadingView(),
      error: (error, _) => _SecurityErrorView(
        message: error.toString(),
        onRetry: () => ref.invalidate(securityControllerProvider),
      ),
      data: (settings) {
        if (!_securityInitialized) {
          _securityInitialized = true;
          // 首次加载没有凭据时保持已解锁；如果已有凭据，则从启动开始锁定。
          _locked = settings.requiresUnlock;
        }
        if (!settings.requiresUnlock || !_locked) return widget.child;
        _scheduleBiometric(settings);
        return Stack(
          fit: StackFit.expand,
          children: [
            Offstage(offstage: true, child: widget.child),
            _SecurityUnlockView(
              settings: settings,
              busy: _busy,
              error: _error,
              onBiometric: _authenticateBiometric,
              onPin: _verifyPin,
              onGesture: _verifyGesture,
            ),
          ],
        );
      },
    );
  }

  void _scheduleBiometric(SecuritySettings settings) {
    if (!settings.biometricEnabled || _biometricAttempted || _busy) return;
    _biometricAttempted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_authenticateBiometric());
    });
  }

  Future<void> _authenticateBiometric() async {
    if (_busy || !mounted) return;
    final coordinator = ref.read(securityBiometricCoordinatorProvider);
    coordinator.beginAuthentication();
    _biometricInFlight = true;
    setState(() {
      _busy = true;
      _error = null;
    });
    bool success = false;
    try {
      success = await ref
          .read(securityRepositoryProvider)
          .authenticateBiometric();
    } finally {
      _biometricInFlight = false;
      coordinator.endAuthentication();
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (success) {
        _locked = false;
      } else {
        _error = '验证未完成，请重试或使用其他解锁方式';
      }
    });
  }

  Future<void> _verifyPin(String pin) async {
    if (_busy || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final success =
        await ref.read(securityRepositoryProvider).verifyPin(pin);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (success) {
        _locked = false;
      } else {
        _error = '数字密码不正确';
      }
    });
    if (success) AppHaptics.medium();
  }

  Future<void> _verifyGesture(List<int> pattern) async {
    if (_busy || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final success =
        await ref.read(securityRepositoryProvider).verifyGesture(pattern);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (success) {
        _locked = false;
      } else {
        _error = '手势密码不正确';
      }
    });
    if (success) AppHaptics.medium();
  }
}

class _SecurityUnlockView extends StatefulWidget {
  const _SecurityUnlockView({
    required this.settings,
    required this.busy,
    required this.error,
    required this.onBiometric,
    required this.onPin,
    required this.onGesture,
  });

  final SecuritySettings settings;
  final bool busy;
  final String? error;
  final Future<void> Function() onBiometric;
  final Future<void> Function(String pin) onPin;
  final Future<void> Function(List<int> pattern) onGesture;

  @override
  State<_SecurityUnlockView> createState() => _SecurityUnlockViewState();
}

enum _UnlockMethod { pin, gesture }

class _SecurityUnlockViewState extends State<_SecurityUnlockView> {
  late _UnlockMethod _method;
  late bool _showFallback;

  @override
  void initState() {
    super.initState();
    _method = widget.settings.hasPin
        ? _UnlockMethod.pin
        : _UnlockMethod.gesture;
    _showFallback = !widget.settings.biometricEnabled;
  }

  @override
  void didUpdateWidget(covariant _SecurityUnlockView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.settings.hasPin && _method == _UnlockMethod.pin) {
      _method = _UnlockMethod.gesture;
    }
    if (!widget.settings.hasGesture && _method == _UnlockMethod.gesture) {
      _method = _UnlockMethod.pin;
    }
    if (!widget.settings.biometricEnabled && !_showFallback) {
      _showFallback = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = appColors(context);
    final methods = [
      if (widget.settings.hasPin) _UnlockMethod.pin,
      if (widget.settings.hasGesture) _UnlockMethod.gesture,
    ];
    return Material(
      color: colors.bg,
      child: GlowBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 36, 24, 36),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: colors.accent.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock_outline,
                        color: colors.accent,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text('应用已锁定', style: AppText.sectionTitle(context)),
                    const SizedBox(height: 6),
                    Text(
                      '验证身份后继续使用 MD Center',
                      style: AppText.meta(context),
                    ),
                    const SizedBox(height: 24),
                    if (widget.settings.biometricEnabled)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: widget.busy
                              ? null
                              : () => unawaited(widget.onBiometric()),
                          icon: const Icon(Icons.fingerprint),
                          label: Text(
                            widget.busy ? '验证中...' : '使用面容/指纹解锁',
                          ),
                        ),
                      ),
                    if (widget.settings.biometricEnabled && methods.isNotEmpty)
                      TextButton.icon(
                        onPressed: widget.busy
                            ? null
                            : () {
                                AppHaptics.selection();
                                setState(() => _showFallback = true);
                              },
                        icon: const Icon(Icons.password_outlined),
                        label: const Text('使用密码/滑动解锁'),
                      ),
                    if (_showFallback &&
                        widget.settings.biometricEnabled &&
                        methods.isNotEmpty)
                      const SizedBox(height: 16),
                    if (_showFallback && methods.length > 1)
                      SegmentedButton<_UnlockMethod>(
                        segments: const [
                          ButtonSegment(
                            value: _UnlockMethod.pin,
                            icon: Icon(Icons.password_outlined),
                            label: Text('数字密码'),
                          ),
                          ButtonSegment(
                            value: _UnlockMethod.gesture,
                            icon: Icon(Icons.gesture_rounded),
                            label: Text('滑动解锁'),
                          ),
                        ],
                        selected: {_method},
                        onSelectionChanged: widget.busy
                            ? null
                            : (value) {
                                if (value.isEmpty) return;
                                AppHaptics.selection();
                                setState(() => _method = value.first);
                              },
                      ),
                    const SizedBox(height: 20),
                    if (_showFallback &&
                        _method == _UnlockMethod.pin &&
                        widget.settings.hasPin)
                      SecurityPinPad(
                        busy: widget.busy,
                        autoSubmit: true,
                        onCompleted: widget.onPin,
                      ),
                    if (_showFallback &&
                        _method == _UnlockMethod.gesture &&
                        widget.settings.hasGesture)
                      SecurityPatternPad(
                        size: 260,
                        enabled: !widget.busy,
                        onCompleted: (pattern) =>
                            unawaited(widget.onGesture(pattern)),
                      ),
                    if (widget.error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        widget.error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.danger),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SecurityLoadingView extends StatelessWidget {
  const _SecurityLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Material(
      color: Color(0xFF0F0E14),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _SecurityErrorView extends StatelessWidget {
  const _SecurityErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: appColors(context).bg,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('安全验证不可用，请重试', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
