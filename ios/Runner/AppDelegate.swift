import Flutter
import Darwin
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

    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "MdCenterPlayer") else {
      return
    }
    let statsChannel = FlutterMethodChannel(
      name: "md_center/player_stats",
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

    let capabilitiesChannel = FlutterMethodChannel(
      name: "md_center/player_capabilities",
      binaryMessenger: registrar.messenger()
    )
    capabilitiesChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "enterPictureInPicture":
        // media_kit uses libmpv on iOS, so the app-level AVPictureInPictureController
        // cannot be attached to its video surface. Dart reports that PiP is unavailable.
        result(false)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

private final class PlayerStatsReader {
  private var previousNetwork: (rx: UInt64, tx: UInt64)?
  private var previousNetworkAt: TimeInterval?
  private var previousCpu: (total: UInt64, idle: UInt64)?

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
    if let battery = readBatteryPercent() { result["battery_percent"] = battery }
    if let download = download { result["download_bps"] = download }
    if let upload = upload { result["upload_bps"] = upload }
    return result
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
