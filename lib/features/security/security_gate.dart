import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/app_haptics.dart';
import '../../core/platform/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/glow_background.dart';
import '../../shared/shake_error_text.dart';
import 'device_lock_monitor.dart';
import 'security_pattern_pad.dart';
import 'security_pin_pad.dart';
import 'security_providers.dart';
import 'security_repository.dart';

/// 在应用内容外层提供本地应用锁，不影响服务端登录会话。
class SecurityGate extends ConsumerStatefulWidget {
  const SecurityGate({super.key, required this.child, this.onReady});

  final Widget child;
  final VoidCallback? onReady;

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
  bool _readyNotified = false;
  bool _readyScheduled = false;
  Timer? _readyTimer;
  bool _wasBackgrounded = false;
  bool _appResumed = true;
  Timer? _backgroundLockTimer;
  Timer? _authenticationGraceTimer;
  StreamSubscription<String>? _deviceLockSubscription;
  bool _ignoreBackgroundUntilResume = false;
  String? _error;
  int _errorToken = 0;
  Timer? _errorTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _deviceLockSubscription = DeviceLockMonitor.events.listen(
      _onDeviceLockEvent,
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _backgroundLockTimer?.cancel();
    _authenticationGraceTimer?.cancel();
    _readyTimer?.cancel();
    _errorTimer?.cancel();
    _deviceLockSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _appResumed = false;
      ref.read(securityBiometricCoordinatorProvider).didEnterInactive();
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _appResumed = false;
      final coordinator = ref.read(securityBiometricCoordinatorProvider);
      coordinator.didEnterInactive();
      if (coordinator.isSessionAuthenticated) {
        _wasBackgrounded = false;
        return;
      }
      if (_ignoreBackgroundUntilResume ||
          coordinator.isAuthenticationInFlight ||
          _biometricInFlight) {
        _wasBackgrounded = false;
        return;
      }
      _wasBackgrounded = true;
      _scheduleBackgroundLock();
      return;
    }
    if (state != AppLifecycleState.resumed || !mounted) return;
    _appResumed = true;
    _backgroundLockTimer?.cancel();

    final coordinator = ref.read(securityBiometricCoordinatorProvider);
    if (coordinator.consumeDeviceLockResume()) {
      _wasBackgrounded = false;
      _notifyReady();
      return;
    }

    // local_auth 的系统验证页也会触发一次生命周期切换。这个切换不是
    // 用户离开应用，不能在验证成功后再次锁定并重复弹出生物识别。
    if (ref.read(securityBiometricCoordinatorProvider).consumeResume() ||
        _biometricInFlight) {
      _wasBackgrounded = false;
      _notifyReady();
      return;
    }
    if (coordinator.isSessionAuthenticated) {
      _wasBackgrounded = false;
      _notifyReady();
      return;
    }
    if (_ignoreBackgroundUntilResume) {
      _ignoreBackgroundUntilResume = false;
      _authenticationGraceTimer?.cancel();
      _authenticationGraceTimer = null;
      _wasBackgrounded = false;
      _notifyReady();
      return;
    }
    if (!_wasBackgrounded) {
      _notifyReady();
      return;
    }
    _wasBackgrounded = false;

    final settings = ref.read(securityControllerProvider).value;
    if (settings?.requiresUnlock != true) return;
    setState(() {
      _locked = true;
      _error = null;
      _biometricAttempted = false;
    });
    _scheduleBiometric(settings!);
  }

  void _onDeviceLockEvent(String event) {
    final coordinator = ref.read(securityBiometricCoordinatorProvider);
    if (event == 'locked') {
      _backgroundLockTimer?.cancel();
      coordinator.didLockDevice();
      _wasBackgrounded = false;
    } else if (event == 'unlocked') {
      coordinator.didUnlockDevice();
    }
  }

  void _scheduleBackgroundLock() {
    _backgroundLockTimer?.cancel();
    _backgroundLockTimer = Timer(const Duration(milliseconds: 350), () {
      _backgroundLockTimer = null;
      if (!mounted) return;
      final coordinator = ref.read(securityBiometricCoordinatorProvider);
      if (coordinator.isDeviceLocked ||
          coordinator.hasDeviceLockCycle ||
          coordinator.isAuthenticationInFlight ||
          _biometricInFlight) {
        return;
      }
      _lockForBackground();
    });
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
          // 已验证状态只存在于当前进程。后台切回前台不重新锁定，进程重启
          // 后 coordinator 会重新创建，才会再次执行启动验证。
          _locked =
              settings.requiresUnlock &&
              !ref
                  .read(securityBiometricCoordinatorProvider)
                  .isSessionAuthenticated;
        }
        if (!settings.requiresUnlock || !_locked) {
          _notifyReady();
          return widget.child;
        }
        _scheduleBiometric(settings);
        return Stack(
          fit: StackFit.expand,
          children: [
            Offstage(offstage: true, child: widget.child),
            _SecurityUnlockView(
              settings: settings,
              busy: _busy,
              error: _error,
              errorToken: _errorToken,
              onBiometric: _authenticateBiometric,
              onPin: _verifyPin,
              onGesture: _verifyGesture,
            ),
          ],
        );
      },
    );
  }

  void _notifyReady() {
    if (_readyNotified || _readyScheduled) return;
    _readyScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _readyTimer = Timer(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        _readyTimer = null;
        _readyScheduled = false;
        if (_locked || _biometricInFlight || !_appResumed) return;
        _readyNotified = true;
        widget.onReady?.call();
      });
    });
  }

  void _scheduleBiometric(SecuritySettings settings) {
    if (!_appResumed ||
        !settings.biometricEnabled ||
        _biometricAttempted ||
        _busy) {
      return;
    }
    _biometricAttempted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_authenticateBiometric());
    });
  }

  void _lockForBackground() {
    if (!mounted || _locked) return;
    final coordinator = ref.read(securityBiometricCoordinatorProvider);
    if (coordinator.isSessionAuthenticated ||
        coordinator.isDeviceLocked ||
        coordinator.hasDeviceLockCycle) {
      return;
    }
    final settings = ref.read(securityControllerProvider).value;
    if (settings?.requiresUnlock != true) return;
    setState(() {
      _locked = true;
      _error = null;
      _biometricAttempted = false;
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
          .authenticateBiometric(
            localizedReason: AppL10n.of(context).securityBiometricReason,
          );
    } finally {
      _biometricInFlight = false;
      coordinator.endAuthentication();
    }
    if (!mounted) return;
    if (success) {
      coordinator.markSessionAuthenticated();
    }
    setState(() {
      _busy = false;
      if (success) {
        _locked = false;
        _backgroundLockTimer?.cancel();
        _wasBackgrounded = false;
        _ignoreBackgroundUntilResume = true;
        _authenticationGraceTimer?.cancel();
        _authenticationGraceTimer = Timer(const Duration(seconds: 1), () {
          _ignoreBackgroundUntilResume = false;
          _authenticationGraceTimer = null;
        });
      } else {
        _error = AppL10n.of(context).securityVerifyIncomplete;
      }
    });
  }

  /// 错误提示短暂展示后自动消失，避免常驻遮挡。
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

  Future<void> _verifyPin(String pin) async {
    if (_busy || !mounted) return;
    _errorTimer?.cancel();
    setState(() {
      _busy = true;
      _error = null;
    });
    final success = await ref.read(securityRepositoryProvider).verifyPin(pin);
    if (!mounted) return;
    if (success) {
      ref.read(securityBiometricCoordinatorProvider).markSessionAuthenticated();
    }
    setState(() => _busy = false);
    if (success) {
      _locked = false;
      AppHaptics.medium();
    } else {
      _showTransientError(AppL10n.of(context).securityPinIncorrect);
    }
  }

  Future<void> _verifyGesture(List<int> pattern) async {
    if (_busy || !mounted) return;
    _errorTimer?.cancel();
    setState(() {
      _busy = true;
      _error = null;
    });
    final success = await ref
        .read(securityRepositoryProvider)
        .verifyGesture(pattern);
    if (!mounted) return;
    if (success) {
      ref.read(securityBiometricCoordinatorProvider).markSessionAuthenticated();
    }
    setState(() => _busy = false);
    if (success) {
      _locked = false;
      AppHaptics.medium();
    } else {
      _showTransientError(AppL10n.of(context).securityPatternIncorrect);
    }
  }
}

class _SecurityUnlockView extends StatefulWidget {
  const _SecurityUnlockView({
    required this.settings,
    required this.busy,
    required this.error,
    required this.errorToken,
    required this.onBiometric,
    required this.onPin,
    required this.onGesture,
  });

  final SecuritySettings settings;
  final bool busy;
  final String? error;
  final int errorToken;
  final Future<void> Function() onBiometric;
  final Future<void> Function(String pin) onPin;
  final Future<void> Function(List<int> pattern) onGesture;

  @override
  State<_SecurityUnlockView> createState() => _SecurityUnlockViewState();
}

enum _UnlockMethod { pin, gesture }

/// 错误提示占位高度，保证文字出现/消失时键盘不上下跳动。
const _errorSlotHeight = 22.0;

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
                    Text(
                      AppL10n.of(context).securityAppLocked,
                      style: AppText.sectionTitle(context),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      AppL10n.of(context).securityUnlockPrompt,
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
                            widget.busy
                                ? AppL10n.of(context).securityVerifying
                                : AppL10n.of(context).securityBiometricUnlock,
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
                        label: Text(AppL10n.of(context).securityPasswordUnlock),
                      ),
                    if (_showFallback &&
                        widget.settings.biometricEnabled &&
                        methods.isNotEmpty)
                      const SizedBox(height: 16),
                    if (_showFallback && methods.length > 1)
                      SegmentedButton<_UnlockMethod>(
                        segments: [
                          ButtonSegment(
                            value: _UnlockMethod.pin,
                            icon: const Icon(Icons.password_outlined),
                            label: Text(AppL10n.of(context).securityPinCode),
                          ),
                          ButtonSegment(
                            value: _UnlockMethod.gesture,
                            icon: const Icon(Icons.gesture_rounded),
                            label: Text(
                              AppL10n.of(context).securitySwipeUnlock,
                            ),
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
                    // 固定高度占位：错误文字出现/消失时键盘位置保持不动。
                    SizedBox(
                      height: _errorSlotHeight,
                      child: widget.error != null
                          ? ShakeErrorText(
                              widget.error!,
                              textAlign: TextAlign.center,
                              replayToken: widget.errorToken,
                            )
                          : null,
                    ),
                    const SizedBox(height: 12),
                    if (_showFallback &&
                        _method == _UnlockMethod.pin &&
                        widget.settings.hasPin)
                      SecurityPinPad(
                        busy: widget.busy,
                        showError: widget.error != null,
                        onCompleted: widget.onPin,
                      ),
                    if (_showFallback &&
                        _method == _UnlockMethod.gesture &&
                        widget.settings.hasGesture)
                      SecurityPatternPad(
                        size: 260,
                        enabled: !widget.busy,
                        showError: widget.error != null,
                        replayToken: widget.errorToken,
                        onCompleted: (pattern) =>
                            unawaited(widget.onGesture(pattern)),
                      ),
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
              Text(
                AppL10n.of(context).securityUnavailable,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(AppL10n.of(context).commonRetry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
