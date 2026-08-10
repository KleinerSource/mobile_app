import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/config/server_config_provider.dart';
import 'security_biometric_coordinator.dart';
import 'security_repository.dart';

final securityRepositoryProvider = Provider<SecurityRepository>((ref) {
  return SecurityRepository(
    preferences: ref.watch(sharedPrefsProvider),
    storage: const FlutterSecureStorage(),
    localAuthentication: LocalAuthentication(),
  );
});

final securityBiometricCoordinatorProvider =
    Provider<SecurityBiometricCoordinator>((ref) {
  return SecurityBiometricCoordinator();
});

final securityControllerProvider =
    AsyncNotifierProvider<SecurityController, SecuritySettings>(
  SecurityController.new,
);

class SecurityController extends AsyncNotifier<SecuritySettings> {
  @override
  Future<SecuritySettings> build() {
    return ref.read(securityRepositoryProvider).load();
  }

  SecurityRepository get _repository => ref.read(securityRepositoryProvider);

  Future<bool>? _enableBiometricsRequest;

  Future<void> savePin(String pin) => _reload(() => _repository.savePin(pin));

  Future<void> clearPin() async {
    final current = await _repository.load();
    if (current.biometricEnabled) {
      throw StateError('请先关闭生物识别，再清除进入密码');
    }
    await _reload(_repository.clearPin);
  }

  Future<void> saveGesture(Iterable<int> pattern) {
    return _reload(() => _repository.saveGesture(pattern));
  }

  Future<void> clearGesture() => _reload(_repository.clearGesture);

  Future<bool> enableBiometrics() {
    final pending = _enableBiometricsRequest;
    if (pending != null) return pending;
    final request = _enableBiometrics();
    _enableBiometricsRequest = request;
    return request.whenComplete(() {
      if (identical(_enableBiometricsRequest, request)) {
        _enableBiometricsRequest = null;
      }
    });
  }

  Future<bool> _enableBiometrics() async {
    final current = await _repository.load();
    if (!current.hasPin) return false;
    if (!await _repository.canUseBiometrics()) return false;
    final coordinator = ref.read(securityBiometricCoordinatorProvider);
    coordinator.beginAuthentication();
    try {
      if (!await _repository.authenticateBiometric()) return false;
      await _reload(() => _repository.setBiometricEnabled(true));
      return true;
    } finally {
      coordinator.endAuthentication();
    }
  }

  Future<void> disableBiometrics() {
    return _reload(() => _repository.setBiometricEnabled(false));
  }

  Future<void> _reload(Future<void> Function() action) async {
    final previous = state.valueOrNull ?? const SecuritySettings.empty();
    state = AsyncData(previous);
    try {
      await action();
      state = AsyncData(await _repository.load());
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}
