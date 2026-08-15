import Flutter
import AVFoundation
import AVKit
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
    let pictureInPictureManager = IOSPictureInPictureManager(
      channel: capabilitiesChannel
    )
    capabilitiesChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "enterPictureInPicture":
        pictureInPictureManager.enter(arguments: call.arguments, result: result)
      case "stopPictureInPicture":
        pictureInPictureManager.stop(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let deviceLockChannel = FlutterEventChannel(
      name: "md_center/device_lock",
      binaryMessenger: registrar.messenger()
    )
    deviceLockChannel.setStreamHandler(DeviceLockStreamHandler())
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

/// 为 media_kit 提供 iOS 系统画中画桥接。
///
/// media_kit 在 iOS 上通过 Flutter texture 渲染 libmpv 画面，系统的
/// AVPictureInPictureController 无法直接接管该 texture。进入 PiP 时使用
/// 同一地址创建短生命周期的原生 AVPlayer，退出 PiP 后由 Dart 将进度同步
/// 回 media_kit。
private final class IOSPictureInPictureManager: NSObject,
  AVPictureInPictureControllerDelegate {
  private let channel: FlutterMethodChannel

  private var player: AVPlayer?
  private var playerItem: AVPlayerItem?
  private var playerLayer: AVPlayerLayer?
  private var pictureInPictureController: AVPictureInPictureController?
  private var hostView: UIView?
  private var statusObservation: NSKeyValueObservation?
  private var startTimeoutWorkItem: DispatchWorkItem?
  private var pendingResult: FlutterResult?
  private var startAttempts = 0
  private var startRequested = false
  private var hasStarted = false
  private var shouldAutoplay = true
  private var startPositionSeconds = 0.0

  init(channel: FlutterMethodChannel) {
    self.channel = channel
    super.init()
  }

  func enter(arguments: Any?, result: @escaping FlutterResult) {
    DispatchQueue.main.async { [weak self] in
      self?.begin(arguments: arguments, result: result)
    }
  }

  func stop(result: @escaping FlutterResult) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else {
        result(true)
        return
      }
      if let controller = self.pictureInPictureController,
         controller.isPictureInPictureActive {
        controller.stopPictureInPicture()
      } else {
        self.cleanup()
      }
      result(true)
    }
  }

  private func begin(arguments: Any?, result: @escaping FlutterResult) {
    if let controller = pictureInPictureController,
       controller.isPictureInPictureActive {
      result(true)
      return
    }
    guard pendingResult == nil else {
      result(false)
      return
    }
    guard AVPictureInPictureController.isPictureInPictureSupported() else {
      result(false)
      return
    }
    guard let request = parseRequest(arguments: arguments) else {
      result(false)
      return
    }
    guard attachPlayerLayer() else {
      result(false)
      return
    }

    pendingResult = result
    shouldAutoplay = request.autoplay
    startPositionSeconds = request.positionSeconds
    startAttempts = 0
    startRequested = false
    hasStarted = false

    // 同服务器地址在 Dart 层已经通过 token query 参数完成鉴权。Apple 未将
    // AVURLAssetHTTPHeaderFieldsKey 作为公开 API，因此这里不依赖该私有选项。
    let asset = AVURLAsset(url: request.url)
    let item = AVPlayerItem(asset: asset)
    let avPlayer = AVPlayer(playerItem: item)
    let layer = AVPlayerLayer(player: avPlayer)
    layer.videoGravity = .resizeAspect

    player = avPlayer
    playerItem = item
    playerLayer = layer
    hostView?.layer.addSublayer(layer)
    layer.frame = hostView?.bounds ?? CGRect(x: 0, y: 0, width: 16, height: 9)

    do {
      let audioSession = AVAudioSession.sharedInstance()
      try audioSession.setCategory(.playback, mode: .moviePlayback)
      try audioSession.setActive(true)
    } catch {
      // PiP 不应因为音频会话已被 media_kit 占用而直接失败。
    }

    guard let pictureInPictureController = AVPictureInPictureController(
      playerLayer: layer
    ) else {
      failStart()
      return
    }
    pictureInPictureController.delegate = self
    self.pictureInPictureController = pictureInPictureController

    statusObservation = item.observe(\.status, options: [.initial, .new]) {
      [weak self] item, _ in
      DispatchQueue.main.async {
        self?.handleItemStatus(item.status)
      }
    }
    startTimeoutWorkItem = DispatchWorkItem { [weak self] in
      guard let self = self, self.pendingResult != nil, !self.hasStarted else {
        return
      }
      self.failStart()
    }
    if let workItem = startTimeoutWorkItem {
      DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: workItem)
    }
  }

  private func handleItemStatus(_ status: AVPlayerItem.Status) {
    switch status {
    case .readyToPlay:
      requestPictureInPictureStart()
    case .failed:
      failStart()
    case .unknown:
      break
    @unknown default:
      failStart()
    }
  }

  private func requestPictureInPictureStart() {
    guard !startRequested,
          let player = player,
          let controller = pictureInPictureController,
          playerItem?.status == .readyToPlay else {
      return
    }
    guard controller.isPictureInPicturePossible else {
      guard startAttempts < 60 else {
        failStart()
        return
      }
      startAttempts += 1
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        [weak self] in
        self?.requestPictureInPictureStart()
      }
      return
    }

    startRequested = true
    let start = { [weak self] in
      guard let self = self,
            let player = self.player,
            let controller = self.pictureInPictureController else {
        return
      }
      if self.shouldAutoplay {
        player.play()
      }
      controller.startPictureInPicture()
    }

    if startPositionSeconds > 0 {
      let time = CMTime(
        seconds: startPositionSeconds,
        preferredTimescale: 600
      )
      player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) {
        _ in
        DispatchQueue.main.async(execute: start)
      }
    } else {
      start()
    }
  }

  private func parseRequest(arguments: Any?) -> PictureInPictureRequest? {
    guard let values = arguments as? [String: Any],
          let urlString = values["url"] as? String,
          let url = URL(string: urlString),
          url.scheme != nil else {
      return nil
    }

    let positionMilliseconds = (values["position_ms"] as? NSNumber)?.doubleValue ?? 0
    let positionSeconds = max(0, positionMilliseconds / 1000)
    let autoplay = (values["autoplay"] as? NSNumber)?.boolValue ?? true
    return PictureInPictureRequest(
      url: url,
      positionSeconds: positionSeconds,
      autoplay: autoplay
    )
  }

  private func attachPlayerLayer() -> Bool {
    let scenes = UIApplication.shared.connectedScenes.compactMap {
      $0 as? UIWindowScene
    }
    let windows = scenes.flatMap { $0.windows }
    guard let window = windows.first(where: { $0.isKeyWindow }) ?? windows.first,
          let rootView = window.rootViewController?.view else {
      return false
    }

    let view = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 9))
    view.isUserInteractionEnabled = false
    view.backgroundColor = .clear
    // 保证 layer 位于有效的 view hierarchy 中，但不覆盖 Flutter 播放画面。
    view.alpha = 0.01
    rootView.addSubview(view)
    hostView = view
    return true
  }

  private func failStart() {
    let result = pendingResult
    pendingResult = nil
    result?(false)
    cleanup()
  }

  func pictureInPictureControllerDidStartPictureInPicture(
    _ pictureInPictureController: AVPictureInPictureController
  ) {
    hasStarted = true
    startTimeoutWorkItem?.cancel()
    startTimeoutWorkItem = nil
    let result = pendingResult
    pendingResult = nil
    result?(true)
  }

  func pictureInPictureControllerDidStopPictureInPicture(
    _ pictureInPictureController: AVPictureInPictureController
  ) {
    if let result = pendingResult {
      pendingResult = nil
      result(false)
    }
    if hasStarted {
      let seconds = player?.currentTime().seconds ?? 0
      let milliseconds = seconds.isFinite && seconds > 0
        ? Int(seconds * 1000)
        : 0
      channel.invokeMethod(
        "pictureInPictureStopped",
        arguments: ["position_ms": milliseconds]
      )
    }
    cleanup()
  }

  func pictureInPictureController(
    _ pictureInPictureController: AVPictureInPictureController,
    restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
  ) {
    completionHandler(true)
  }

  private func cleanup() {
    startTimeoutWorkItem?.cancel()
    startTimeoutWorkItem = nil
    statusObservation = nil
    pictureInPictureController?.delegate = nil
    player?.pause()
    playerLayer?.player = nil
    playerLayer?.removeFromSuperlayer()
    hostView?.removeFromSuperview()
    pictureInPictureController = nil
    playerLayer = nil
    playerItem = nil
    player = nil
    hostView = nil
    startAttempts = 0
    startRequested = false
    hasStarted = false
  }
}

private struct PictureInPictureRequest {
  let url: URL
  let positionSeconds: Double
  let autoplay: Bool
}

private final class PlayerStatsReader {
  private let pathMonitor = NWPathMonitor()
  private let pathMonitorQueue = DispatchQueue(label: "md_center.player_stats.network")
  private let pathLock = NSLock()
  private var latestPath: NWPath?
  private let telephonyInfo = CTTelephonyNetworkInfo()

  private var previousNetwork: (rx: UInt64, tx: UInt64)?
  private var previousNetworkAt: TimeInterval?
  private var previousCpu: (total: UInt64, idle: UInt64)?

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
