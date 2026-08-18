import Flutter
import KSPlayer
import UIKit

let ksPlayerViewType = "md_center/ksplayer_view"

final class KSPlayerPlatformViewFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    KSPlayerPlatformView(
      frame: frame,
      viewIdentifier: viewId,
      arguments: args,
      messenger: messenger
    )
  }
}

final class KSPlayerPlatformView: NSObject, FlutterPlatformView {
  private let nativeView: KSPlayerFlutterView
  private let channel: FlutterMethodChannel

  init(
    frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?,
    messenger: FlutterBinaryMessenger
  ) {
    let channel = FlutterMethodChannel(
      name: "md_center/ksplayer/\(viewId)",
      binaryMessenger: messenger
    )
    self.channel = channel
    self.nativeView = KSPlayerFlutterView(
      frame: frame,
      channel: channel,
      arguments: args
    )
    super.init()

    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  func view() -> UIView {
    nativeView
  }

  deinit {
    channel.setMethodCallHandler(nil)
    nativeView.disposePlayer()
  }

  private func handle(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    DispatchQueue.main.async { [weak self] in
      guard let self else {
        result(false)
        return
      }

      switch call.method {
      case "play":
        self.nativeView.playPlayer()
        result(nil)
      case "pause":
        self.nativeView.pausePlayer()
        result(nil)
      case "seek":
        let arguments = call.arguments as? [String: Any]
        let positionMs = number(arguments?["position_ms"]) ?? 0
        self.nativeView.seekPlayer(
          to: max(0, positionMs) / 1000,
          completion: result
        )
      case "setRate":
        let arguments = call.arguments as? [String: Any]
        let rate = number(arguments?["rate"]) ?? 1
        self.nativeView.setRate(Float(max(0.1, rate)))
        result(nil)
      case "stop":
        self.nativeView.stopPlayer()
        result(nil)
      case "dispose":
        self.nativeView.disposePlayer()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func number(_ value: Any?) -> Double? {
    if let value = value as? NSNumber {
      return value.doubleValue
    }
    if let value = value as? Double {
      return value
    }
    if let value = value as? Int {
      return Double(value)
    }
    return Double(value as? String ?? "")
  }
}

private final class KSPlayerFlutterView: IOSVideoPlayerView {
  private let channel: FlutterMethodChannel
  private var pendingStartTime: TimeInterval?
  private var definitionLabels = [String]()
  private var isDisposed = false

  init(
    frame: CGRect,
    channel: FlutterMethodChannel,
    arguments: Any?
  ) {
    self.channel = channel
    super.init(frame: frame)
    configureNativePlayerOptions()
    backBlock = { [weak self] in
      self?.emit("back", arguments: nil)
    }
    configure(arguments: arguments)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func playPlayer() {
    playerLayer?.play()
  }

  func pausePlayer() {
    playerLayer?.pause()
  }

  func seekPlayer(
    to time: TimeInterval,
    completion: @escaping FlutterResult
  ) {
    guard let playerLayer else {
      completion(false)
      return
    }
    let shouldResumePlayback = playerLayer.state.isPlaying
    playerLayer.seek(time: time, autoPlay: shouldResumePlayback) { finished in
      DispatchQueue.main.async {
        completion(finished)
      }
    }
  }

  func setRate(_ rate: Float) {
    playerLayer?.player.playbackRate = rate
  }

  func stopPlayer() {
    playerLayer?.stop()
  }

  func disposePlayer() {
    guard !isDisposed else { return }
    isDisposed = true
    panGesture.isEnabled = false
    playerLayer?.stop()
    resetPlayer()
  }

  override func judgePanGesture() {
    // media_kit 在暂停态仍允许 seek/亮度/音量手势。保留 KSPlayer 的
    // 原生方向判定和提交逻辑，只放宽它在 iPhone 竖屏下对播放按钮状态的限制。
    panGesture.isEnabled = playerLayer != nil &&
      !replayButton.isSelected &&
      !isLock
  }

  private func configureNativePlayerOptions() {
    // KSPlayer 2.3.4 已原生实现左亮度、右音量、横向 seek 和长按 2x。
    // 显式配置这些开关，避免上游默认值或其他页面配置改变本应用的交互契约。
    KSOptions.enableBrightnessGestures = true
    KSOptions.enableVolumeGestures = true
    KSOptions.enablePlaytimeGestures = true
    // media_kit 页面在 3 秒无操作后隐藏控制层，与原生控制层保持一致。
    KSOptions.animateDelayTimeInterval = 3
  }

  override func player(
    layer: KSPlayerLayer,
    state: KSPlayerState
  ) {
    super.player(layer: layer, state: state)
    if state == .readyToPlay, let pendingStartTime {
      self.pendingStartTime = nil
      layer.seek(time: pendingStartTime, autoPlay: true) { _ in }
    }
    emit(
      "state",
      arguments: [
        "value": state.description,
        "is_playing": state.isPlaying,
      ]
    )
  }

  override func player(
    layer: KSPlayerLayer,
    currentTime: TimeInterval,
    totalTime: TimeInterval
  ) {
    super.player(
      layer: layer,
      currentTime: currentTime,
      totalTime: totalTime
    )
    emit(
      "time",
      arguments: [
        "position_ms": milliseconds(currentTime),
        "duration_ms": milliseconds(totalTime),
        "is_playing": layer.state.isPlaying,
      ]
    )
  }

  override func player(
    layer: KSPlayerLayer,
    finish error: Error?
  ) {
    super.player(layer: layer, finish: error)
    if let error {
      emit("error", arguments: ["message": error.localizedDescription])
    } else {
      emit("finished", arguments: nil)
    }
  }

  override func change(definitionIndex: Int) {
    super.change(definitionIndex: definitionIndex)
    let label = definitionIndex >= 0 && definitionIndex < definitionLabels.count
      ? definitionLabels[definitionIndex]
      : ""
    emit(
      "definitionChanged",
      arguments: ["index": definitionIndex, "label": label]
    )
  }

  private func configure(arguments: Any?) {
    guard let values = arguments as? [String: Any],
          let urlString = values["url"] as? String,
          let url = URL(string: urlString),
          url.scheme != nil else {
      emit("error", arguments: ["message": "KSPlayer 播放地址无效"])
      return
    }

    let title = values["title"] as? String ?? ""
    let headers = stringDictionary(values["headers"])
    let subtitleURLs = (values["subtitle_urls"] as? [String] ?? [])
      .compactMap(URL.init(string:))
    pendingStartTime = max(0, number(values["start_position_ms"])) / 1000

    let rawDefinitions = values["definitions"] as? [[String: Any]] ?? []
    let definitions = rawDefinitions.compactMap { item -> KSPlayerResourceDefinition? in
      guard let value = item["url"] as? String,
            let definitionURL = URL(string: value),
            definitionURL.scheme != nil else {
        return nil
      }
      let options = KSOptions()
      let definitionHeaders = stringDictionary(item["headers"]) ?? headers
      if let definitionHeaders, !definitionHeaders.isEmpty {
        options.appendHeader(definitionHeaders)
      }
      let label = item["label"] as? String ?? ""
      definitionLabels.append(label)
      return KSPlayerResourceDefinition(
        url: definitionURL,
        definition: label,
        options: options
      )
    }

    if definitions.isEmpty {
      let options = KSOptions()
      if let headers, !headers.isEmpty {
        options.appendHeader(headers)
      }
      let resource = KSPlayerResource(
        url: url,
        options: options,
        name: title,
        subtitleURLs: subtitleURLs.isEmpty ? nil : subtitleURLs
      )
      set(resource: resource)
      return
    }

    let subtitleSource = subtitleURLs.isEmpty
      ? nil
      : URLSubtitleDataSouce(urls: subtitleURLs)
    let resource = KSPlayerResource(
      name: title,
      definitions: definitions,
      subtitleDataSouce: subtitleSource
    )
    set(resource: resource)
  }

  private func stringDictionary(_ value: Any?) -> [String: String]? {
    guard let value = value as? [String: Any] else {
      return value as? [String: String]
    }
    var result = [String: String]()
    for (key, rawValue) in value {
      if let string = rawValue as? String {
        result[key] = string
      }
    }
    return result
  }

  private func number(_ value: Any?) -> Double {
    if let value = value as? NSNumber {
      return value.doubleValue
    }
    if let value = value as? Double {
      return value
    }
    if let value = value as? Int {
      return Double(value)
    }
    return Double(value as? String ?? "") ?? 0
  }

  private func milliseconds(_ value: TimeInterval) -> Int {
    guard value.isFinite, value > 0 else { return 0 }
    return Int(min(value * 1000, Double(Int.max)))
  }

  private func emit(_ method: String, arguments: Any?) {
    guard !isDisposed else { return }
    DispatchQueue.main.async { [weak self] in
      guard let self, !self.isDisposed else { return }
      self.channel.invokeMethod(method, arguments: arguments)
    }
  }
}
