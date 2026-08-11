import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../core/platform/app_haptics.dart';
import '../../l10n/generated/app_localizations.dart';
import 'privacy_providers.dart';
import 'shake_detector.dart';

/// 包裹整个 app 的隐私遮罩
///
/// - 监听 [AppLifecycleState.inactive] / [paused] → 显示全屏遮罩
/// - resumed 时移除
/// - Android 设置 FLAG_SECURE 让 Recents 截图被系统抹黑 (双重保险)
class PrivacyShield extends ConsumerStatefulWidget {
  const PrivacyShield({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PrivacyShield> createState() => _PrivacyShieldState();
}

class _PrivacyShieldState extends ConsumerState<PrivacyShield>
    with WidgetsBindingObserver {
  bool _covered = false;
  StreamSubscription<UserAccelerometerEvent>? _shakeSubscription;
  late final ShakeDetector _shakeDetector;
  bool _privacyToggleInFlight = false;

  @override
  void initState() {
    super.initState();
    _shakeDetector = ShakeDetector(onShake: _togglePrivacyMode);
    WidgetsBinding.instance.addObserver(this);
    _startShakeDetection();
  }

  @override
  void dispose() {
    _stopShakeDetection();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startShakeDetection();
    } else {
      _stopShakeDetection();
    }

    final enabled = ref.read(privacyShieldProvider);
    if (!enabled) return;

    // iOS: inactive 发生在 App Switcher 出现时(包括拉控制中心 / 来电等),paused 是真后台
    // Android: paused 是后台。两种都需遮罩。
    final shouldCover = state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden;

    if (shouldCover != _covered) {
      setState(() => _covered = shouldCover);
    }
  }

  void _startShakeDetection() {
    if (!mounted || _shakeSubscription != null) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;

    _shakeDetector.reset();
    _shakeSubscription = userAccelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 100),
    ).listen(
      (event) => _shakeDetector.handle(
        x: event.x,
        y: event.y,
        z: event.z,
      ),
      onError: (_) {
        _shakeSubscription = null;
      },
    );
  }

  void _stopShakeDetection() {
    final subscription = _shakeSubscription;
    _shakeSubscription = null;
    _shakeDetector.reset();
    if (subscription != null) unawaited(subscription.cancel());
  }

  Future<void> _togglePrivacyMode() async {
    if (!mounted || !ref.read(privacyShakeProvider)) return;
    if (_privacyToggleInFlight) return;

    _privacyToggleInFlight = true;
    try {
      final next = !ref.read(privacyShieldProvider);
      await ref.read(privacyShieldProvider.notifier).setEnabled(next);
      AppHaptics.medium();
    } finally {
      _privacyToggleInFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // FLAG_SECURE 仅在 Android 启用 (iOS 不需要,inactive 时遮罩已生效)
    return Stack(
      children: [
        widget.child,
        if (_covered)
          const Positioned.fill(child: _ShieldOverlay()),
      ],
    );
  }
}

class _ShieldOverlay extends StatelessWidget {
  const _ShieldOverlay();

  @override
  Widget build(BuildContext context) {
    // 隐私遮罩可能在 MaterialApp.builder 注入,这里 context 可能尚未注入 l10n
    // (例如 splash 阶段),做防御 fallback
    String locked;
    String mode;
    try {
      final l = AppL10n.of(context);
      locked = l.privacyLockedTitle;
      mode = l.privacyMode;
    } catch (_) {
      locked = '已锁定';
      mode = 'PRIVACY MODE';
    }

    return Material(
      color: const Color(0xFF0F0E14),
      child: Stack(
        children: [
          // 紫粉光晕背景
          const Positioned(
            top: -120,
            left: -100,
            width: 400,
            height: 400,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x4D7C4DFF),
              ),
            ),
          ),
          const Positioned(
            bottom: -120,
            right: -80,
            width: 320,
            height: 320,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x4DFF6B9D),
              ),
            ),
          ),
          // 中央 logo + 提示
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _Brand(),
                const SizedBox(height: 16),
                Text(
                  locked,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
                    fontSize: 24,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  mode,
                  style: const TextStyle(
                    color: Color(0x80FFFFFF),
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: 2.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF6B9D), Color(0xFF9F6BFF)],
        ),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.lock,
        color: Colors.white,
        size: 26,
      ),
    );
  }
}

/// Android 启用 FLAG_SECURE 让系统 Recents 缩略图自动抹黑
///
/// 在 main.dart 启动后调用一次,与 PrivacyShield 双重保险
Future<void> applyAndroidFlagSecure(bool enabled) async {
  if (!Platform.isAndroid) return;
  try {
    // 通过 MethodChannel 设置 Activity flag
    const channel = MethodChannel('md_center/privacy');
    await channel.invokeMethod(enabled ? 'enableSecure' : 'disableSecure');
  } catch (_) {
    // 没注册 native handler 也不影响 widget 层遮罩
  }
}
