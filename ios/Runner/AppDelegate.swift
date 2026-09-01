import Flutter
import CoreTelephony
import Darwin
import Foundation
import Network
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "OmmPlayer") else {
      return
    }
    let statsChannel = FlutterMethodChannel(
      name: "omm/player_stats",
      binaryMessenger: registrar.messenger()
    )
    let statsReader = PlayerStatsReader()
    statsChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "readStats":
        result(statsReader.read())
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let deviceLockChannel = FlutterEventChannel(
      name: "omm/device_lock",
      binaryMessenger: registrar.messenger()
    )
    deviceLockChannel.setStreamHandler(DeviceLockStreamHandler())

    // 亮度直通通道：只做即时读写，不缓存、不监听生命周期、不恢复。
    // 手势写入 UIScreen.brightness 即系统亮度，退出播放器/退出 app 均保持。
    let brightnessChannel = FlutterMethodChannel(
      name: "omm/screen_brightness",
      binaryMessenger: registrar.messenger()
    )
    brightnessChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "getBrightness":
        result(Double(Self.currentScreen().brightness))
      case "setBrightness":
        guard let arguments = call.arguments as? [String: Any],
              let brightness = arguments["brightness"] as? NSNumber else {
          result(FlutterError(code: "-2", message: "Unexpected brightness argument", details: nil))
          return
        }
        Self.currentScreen().brightness = CGFloat(brightness.doubleValue)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func currentScreen() -> UIScreen {
    for scene in UIApplication.shared.connectedScenes {
      if let windowScene = scene as? UIWindowScene, scene.activationState == .foregroundActive {
        return windowScene.screen
      }
    }
    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
      return windowScene.screen
    }
    return UIScreen.main
  }
}

private final class DeviceLockStreamHandler: NSObject, FlutterStreamHandler {
  private var sink: FlutterEventSink?
  private var observers: [NSObjectProtocol] = []

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    removeObservers()
    sink = events
    let center = NotificationCenter.default
    observers = [
      center.addObserver(
        forName: UIApplication.protectedDataWillBecomeUnavailableNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        self?.sink?("locked")
      },
      center.addObserver(
        forName: UIApplication.protectedDataDidBecomeAvailableNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        self?.sink?("unlocked")
      },
    ]
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    removeObservers()
    sink = nil
    return nil
  }

  private func removeObservers() {
    let center = NotificationCenter.default
    observers.forEach { center.removeObserver($0) }
    observers.removeAll()
  }
}

private final class PlayerStatsReader {
  private let pathMonitor = NWPathMonitor()
  private let pathMonitorQueue = DispatchQueue(label: "omm.player_stats.network")
  private let pathLock = NSLock()
  private var latestPath: NWPath?
  private let telephonyInfo = CTTelephonyNetworkInfo()

  private var previousNetwork: (rx: UInt64, tx: UInt64)?
  private var previousNetworkAt: TimeInterval?
  private var previousCpu: (total: UInt64, idle: UInt64)?
  private var previousProcessCpuTime: TimeInterval?
  private var previousProcessCpuAt: TimeInterval?

  init() {
    pathMonitor.pathUpdateHandler = { [weak self] path in
      guard let self else { return }
      self.pathLock.lock()
      self.latestPath = path
      self.pathLock.unlock()
    }
    pathMonitor.start(queue: pathMonitorQueue)
  }

  deinit {
    pathMonitor.cancel()
  }

  func read() -> [String: Any] {
    let now = Date().timeIntervalSince1970
    let network = readNetworkBytes()
    var download: Int?
    var upload: Int?
    if let network = network,
       let previousNetwork = previousNetwork,
       let previousNetworkAt = previousNetworkAt {
      let elapsed = now - previousNetworkAt
      if elapsed > 0 {
        download = Int(rate(current: network.rx, previous: previousNetwork.rx, elapsed: elapsed))
        upload = Int(rate(current: network.tx, previous: previousNetwork.tx, elapsed: elapsed))
      }
    }
    if let network = network {
      previousNetwork = network
      previousNetworkAt = now
    }

    var result: [String: Any] = [:]
    if let cpu = readCpuUsage() { result["cpu_percent"] = cpu }
    if let processCpu = readProcessCpuUsage() {
      result["process_cpu_percent"] = processCpu
    }
    if let ram = readProcessMemoryMegabytes() { result["ram_used_mb"] = ram }
    if let battery = readBatteryPercent() { result["battery_percent"] = battery }
    if let download = download { result["download_bps"] = download }
    if let upload = upload { result["upload_bps"] = upload }
    result["network_type"] = readNetworkType()
    return result
  }

  private func readNetworkType() -> String {
    pathLock.lock()
    let path = latestPath
    pathLock.unlock()

    guard let path else { return "unknown" }
    guard path.status == .satisfied else { return "offline" }
    if path.usesInterfaceType(.wifi) { return "wifi" }
    if path.usesInterfaceType(.cellular) { return readCellularNetworkType() }
    if path.usesInterfaceType(.wiredEthernet) { return "ethernet" }
    return "unknown"
  }

  private func readCellularNetworkType() -> String {
    let technologies = telephonyInfo.serviceCurrentRadioAccessTechnology
      .map { Array($0.values) } ?? []
    if #available(iOS 14.1, *),
       technologies.contains(CTRadioAccessTechnologyNR) ||
       technologies.contains(CTRadioAccessTechnologyNRNSA) {
      return "5g"
    }
    if technologies.contains(CTRadioAccessTechnologyLTE) {
      return "4g"
    }
    return "mobile"
  }

  private func rate(
    current: UInt64,
    previous: UInt64,
    elapsed: TimeInterval
  ) -> UInt64 {
    guard current >= previous else { return 0 }
    return UInt64(Double(current - previous) / elapsed)
  }

  private func readBatteryPercent() -> Int? {
    let device = UIDevice.current
    device.isBatteryMonitoringEnabled = true
    let level = device.batteryLevel
    guard level >= 0 else { return nil }
    return Int((level * 100).rounded()).clamped(to: 0...100)
  }

  private func readCpuUsage() -> Double? {
    var cpuInfo: processor_info_array_t?
    var numCpuInfo: mach_msg_type_number_t = 0
    var numCpus: natural_t = 0
    let result = host_processor_info(
      mach_host_self(),
      PROCESSOR_CPU_LOAD_INFO,
      &numCpus,
      &cpuInfo,
      &numCpuInfo
    )
    guard result == KERN_SUCCESS, let cpuInfo = cpuInfo else { return nil }
    defer {
      vm_deallocate(
        mach_task_self_,
        vm_address_t(bitPattern: cpuInfo),
        vm_size_t(numCpuInfo) * vm_size_t(MemoryLayout<integer_t>.stride)
      )
    }

    var total: UInt64 = 0
    var idle: UInt64 = 0
    for cpu in 0..<Int(numCpus) {
      let offset = Int(CPU_STATE_MAX) * cpu
      let user = UInt64(max(0, cpuInfo[offset + Int(CPU_STATE_USER)]))
      let system = UInt64(max(0, cpuInfo[offset + Int(CPU_STATE_SYSTEM)]))
      let nice = UInt64(max(0, cpuInfo[offset + Int(CPU_STATE_NICE)]))
      let cpuIdle = UInt64(max(0, cpuInfo[offset + Int(CPU_STATE_IDLE)]))
      total += user + system + nice + cpuIdle
      idle += cpuIdle
    }

    let current = (total: total, idle: idle)
    let previous = previousCpu
    previousCpu = current
    guard let previous = previous else { return nil }
    let totalDelta = current.total >= previous.total
      ? current.total - previous.total
      : 0
    let idleDelta = current.idle >= previous.idle
      ? current.idle - previous.idle
      : 0
    guard totalDelta > 0 else { return nil }
    return (Double(totalDelta - min(idleDelta, totalDelta)) / Double(totalDelta) * 100)
      .clamped(to: 0...100)
  }

  private func readProcessCpuUsage() -> Double? {
    guard let info = readTaskBasicInfo() else { return nil }
    let current = cpuTime(from: info)
    let now = ProcessInfo.processInfo.systemUptime
    let previousCpu = previousProcessCpuTime
    let previousAt = previousProcessCpuAt
    previousProcessCpuTime = current
    previousProcessCpuAt = now
    guard let previousCpu = previousCpu,
          let previousAt = previousAt else { return nil }
    let elapsed = now - previousAt
    let cpuDelta = current - previousCpu
    guard elapsed > 0, cpuDelta >= 0 else { return nil }
    // 单核口径：100% = 跑满 1 个核，多线程可超过 100%。
    let processorCount = Double(max(ProcessInfo.processInfo.activeProcessorCount, 1))
    return (cpuDelta / elapsed * 100).clamped(to: 0...(100.0 * processorCount))
  }

  private func readProcessMemoryMegabytes() -> Int? {
    guard let info = readTaskBasicInfo() else { return nil }
    return Int((Double(info.resident_size) / 1_048_576).rounded())
  }

  private func readTaskBasicInfo() -> mach_task_basic_info? {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(
      MemoryLayout<mach_task_basic_info_data_t>.stride / MemoryLayout<integer_t>.stride
    )
    let result = withUnsafeMutablePointer(to: &info) { pointer in
      pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        task_info(
          mach_task_self_,
          task_flavor_t(MACH_TASK_BASIC_INFO),
          $0,
          &count
        )
      }
    }
    guard result == KERN_SUCCESS else { return nil }
    return info
  }

  private func cpuTime(from info: mach_task_basic_info) -> TimeInterval {
    let user = Double(info.user_time.seconds)
      + Double(info.user_time.microseconds) / 1_000_000
    let system = Double(info.system_time.seconds)
      + Double(info.system_time.microseconds) / 1_000_000
    return user + system
  }

  private func readNetworkBytes() -> (rx: UInt64, tx: UInt64)? {
    var pointer: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&pointer) == 0, let first = pointer else { return nil }
    defer { freeifaddrs(pointer) }

    var rx: UInt64 = 0
    var tx: UInt64 = 0
    var current: UnsafeMutablePointer<ifaddrs>? = first
    while let address = current {
      let name = String(cString: address.pointee.ifa_name)
      let tracked = name == "en0" || name.hasPrefix("en") || name.hasPrefix("pdp_ip")
      if tracked, let data = address.pointee.ifa_data {
        let stats = data.assumingMemoryBound(to: if_data.self).pointee
        let inbound = Int64(stats.ifi_ibytes)
        let outbound = Int64(stats.ifi_obytes)
        if inbound > 0 { rx += UInt64(inbound) }
        if outbound > 0 { tx += UInt64(outbound) }
      }
      current = address.pointee.ifa_next
    }
    return (rx, tx)
  }
}

private extension Comparable {
  func clamped(to range: ClosedRange<Self>) -> Self {
    min(max(self, range.lowerBound), range.upperBound)
  }
}
