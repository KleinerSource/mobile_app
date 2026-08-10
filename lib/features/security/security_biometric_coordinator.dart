/// 协调系统生物验证产生的生命周期切换，避免被安全锁误判为离开应用。
class SecurityBiometricCoordinator {
  bool _authenticationInFlight = false;
  bool _skipNextResume = false;
  bool _sawInactive = false;
  bool _deviceLocked = false;
  bool _deviceLockCycle = false;

  bool get isAuthenticationInFlight => _authenticationInFlight;
  bool get isDeviceLocked => _deviceLocked;
  bool get hasDeviceLockCycle => _deviceLockCycle;

  void beginAuthentication() {
    _authenticationInFlight = true;
    _skipNextResume = true;
    _sawInactive = false;
  }

  void endAuthentication() {
    _authenticationInFlight = false;
    if (!_sawInactive) _skipNextResume = false;
  }

  void didEnterInactive() {
    if (_authenticationInFlight) _sawInactive = true;
  }

  void didLockDevice() {
    _deviceLocked = true;
    _deviceLockCycle = true;
  }

  void didUnlockDevice() {
    _deviceLocked = false;
  }

  /// 返回 true 表示本次 resumed 属于系统设备解锁，应跳过应用锁定。
  bool consumeDeviceLockResume() {
    if (!_deviceLockCycle) return false;
    _deviceLockCycle = false;
    _deviceLocked = false;
    return true;
  }

  /// 返回 true 表示本次 resumed 属于系统验证，应跳过应用锁定。
  bool consumeResume() {
    if (!_authenticationInFlight && !_skipNextResume) return false;
    _skipNextResume = false;
    _sawInactive = false;
    return true;
  }
}
