import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'security_policy.dart';

class SecuritySettings {
  const SecuritySettings({
    required this.hasPin,
    required this.hasGesture,
    required this.biometricEnabled,
  });

  const SecuritySettings.empty()
      : hasPin = false,
        hasGesture = false,
        biometricEnabled = false;

  final bool hasPin;
  final bool hasGesture;
  final bool biometricEnabled;

  bool get requiresUnlock => hasPin || hasGesture || biometricEnabled;
}

class SecurityRepository {
  SecurityRepository({
    required SharedPreferences preferences,
    FlutterSecureStorage? storage,
    LocalAuthentication? localAuthentication,
  })  : _preferences = preferences,
        _storage = storage ?? const FlutterSecureStorage(),
        _localAuthentication = localAuthentication ?? LocalAuthentication();

  static const _pinDigestKey = 'md_center.security.pin_digest';
  static const _gestureDigestKey = 'md_center.security.gesture_digest';
  static const _biometricEnabledKey = 'md_center.security.biometric_enabled';

  final SharedPreferences _preferences;
  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuthentication;

  Future<SecuritySettings> load() async {
    final pinDigest = await _storage.read(key: _pinDigestKey);
    final gestureDigest = await _storage.read(key: _gestureDigestKey);
    final biometricEnabled =
        _preferences.getBool(_biometricEnabledKey) ?? false;
    return SecuritySettings(
      hasPin: pinDigest?.isNotEmpty == true,
      hasGesture: gestureDigest?.isNotEmpty == true,
      biometricEnabled: biometricEnabled,
    );
  }

  Future<void> savePin(String pin) async {
    if (!isValidSecurityPin(pin)) {
      throw const FormatException('数字密码必须为 4–6 位数字');
    }
    await _storage.write(
      key: _pinDigestKey,
      value: securitySecretDigest(pin),
    );
  }

  Future<void> clearPin() => _storage.delete(key: _pinDigestKey);

  Future<bool> verifyPin(String pin) async {
    if (!isValidSecurityPin(pin)) return false;
    final expected = await _storage.read(key: _pinDigestKey);
    return expected != null && expected == securitySecretDigest(pin);
  }

  Future<void> saveGesture(Iterable<int> pattern) async {
    if (!isValidSecurityPattern(pattern)) {
      throw const FormatException('手势密码至少需要连接 4 个节点');
    }
    await _storage.write(
      key: _gestureDigestKey,
      value: securitySecretDigest(encodeSecurityPattern(pattern)),
    );
  }

  Future<void> clearGesture() => _storage.delete(key: _gestureDigestKey);

  Future<bool> verifyGesture(Iterable<int> pattern) async {
    if (!isValidSecurityPattern(pattern)) return false;
    final expected = await _storage.read(key: _gestureDigestKey);
    return expected != null &&
        expected ==
            securitySecretDigest(encodeSecurityPattern(pattern));
  }

  Future<bool> canUseBiometrics() async {
    try {
      final supported = await _localAuthentication.isDeviceSupported();
      if (!supported) return false;
      return (await _localAuthentication.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateBiometric() async {
    try {
      return await _localAuthentication.authenticate(
        localizedReason: '请验证身份以进入 MD Center',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> setBiometricEnabled(bool enabled) {
    return _preferences.setBool(_biometricEnabledKey, enabled);
  }
}
