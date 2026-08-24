import AVFoundation
import AVKit
import Flutter
import UIKit

public final class MdCenterAvplayerPlugin: NSObject, FlutterPlugin {
  private let manager: AvPlayerManager

  private init(messenger: FlutterBinaryMessenger) {
    manager = AvPlayerManager(messenger: messenger)
    super.init()
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let plugin = MdCenterAvplayerPlugin(messenger: registrar.messenger())
    MdCenterAvPlayerHostApiSetup.setUp(
      binaryMessenger: registrar.messenger(),
      api: plugin.manager
    )
    registrar.register(
      AvPlayerViewFactory(manager: plugin.manager),
      withId: "md_center_avplayer/view"
    )
  }
}

private final class AvPlayerManager: NSObject, MdCenterAvPlayerHostApi {
  private let flutterApi: MdCenterAvPlayerFlutterApi
  private var sessions: [Int64: AvPlayerSession] = [:]

  init(messenger: FlutterBinaryMessenger) {
    flutterApi = MdCenterAvPlayerFlutterApi(binaryMessenger: messenger)
  }

  func create(playerId: Int64) throws {
    guard sessions[playerId] == nil else { return }
    sessions[playerId] = AvPlayerSession(playerId: playerId, flutterApi: flutterApi)
  }

  func open(
    playerId: Int64,
    url: String,
    startPositionMs: Double?,
    autoplay: Bool,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    guard let session = sessions[playerId] else {
      completion(.failure(AvPlayerPluginError.missingPlayer))
      return
    }
    session.open(
      url: url,
      startPositionMs: startPositionMs,
      autoplay: autoplay,
      completion: completion
    )
  }

  func play(playerId: Int64) throws {
    try session(playerId).play()
  }

  func pause(playerId: Int64) throws {
    try session(playerId).pause()
  }

  func seek(
    playerId: Int64,
    positionMs: Double,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    guard let session = sessions[playerId] else {
      completion(.failure(AvPlayerPluginError.missingPlayer))
      return
    }
    session.seek(positionMs: positionMs, completion: completion)
  }

  func setRate(playerId: Int64, rate: Double) throws {
    try session(playerId).setRate(rate)
  }

  func audioTracks(
    playerId: Int64,
    completion: @escaping (Result<[AvPlayerAudioTrack], Error>) -> Void
  ) {
    guard let session = sessions[playerId] else {
      completion(.failure(AvPlayerPluginError.missingPlayer))
      return
    }
    completion(.success(session.audioTracks()))
  }

  func selectAudioTrack(
    playerId: Int64,
    trackId: String,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    guard let session = sessions[playerId] else {
      completion(.failure(AvPlayerPluginError.missingPlayer))
      return
    }
    completion(session.selectAudioTrack(trackId))
  }

  func captureFrame(
    playerId: Int64,
    positionMs: Double,
    completion: @escaping (Result<FlutterStandardTypedData?, Error>) -> Void
  ) {
    guard let session = sessions[playerId] else {
      completion(.failure(AvPlayerPluginError.missingPlayer))
      return
    }
    session.captureFrame(positionMs: positionMs, completion: completion)
  }

  func cancelFramePreview(playerId: Int64) throws {
    try session(playerId).cancelFramePreview()
  }

  func startPictureInPicture(
    playerId: Int64,
    completion: @escaping (Result<Bool, Error>) -> Void
  ) {
    guard let session = sessions[playerId] else {
      completion(.failure(AvPlayerPluginError.missingPlayer))
      return
    }
    session.startPictureInPicture(completion: completion)
  }

  func stopPictureInPicture(playerId: Int64) throws {
    try session(playerId).stopPictureInPicture()
  }

  func dispose(playerId: Int64) throws {
    sessions.removeValue(forKey: playerId)?.dispose()
  }

  func attach(playerId: Int64, to view: PlayerContainerView, gravity: String) {
    sessions[playerId]?.attach(to: view, gravity: gravity)
  }

  private func session(_ playerId: Int64) throws -> AvPlayerSession {
    guard let session = sessions[playerId] else {
      throw AvPlayerPluginError.missingPlayer
    }
    return session
  }
}

private final class AvPlayerViewFactory: NSObject, FlutterPlatformViewFactory {
  private let manager: AvPlayerManager

  init(manager: AvPlayerManager) {
    self.manager = manager
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    let values = args as? [String: Any]
    let playerId = (values?["playerId"] as? NSNumber)?.int64Value ?? -1
    let gravity = values?["videoGravity"] as? String ?? "contain"
    let platformView = AvPlayerPlatformView(frame: frame)
    manager.attach(playerId: playerId, to: platformView.container, gravity: gravity)
    return platformView
  }
}

private final class AvPlayerPlatformView: NSObject, FlutterPlatformView {
  let container: PlayerContainerView

  init(frame: CGRect) {
    container = PlayerContainerView(frame: frame)
    super.init()
  }

  func view() -> UIView { container }
}

final class PlayerContainerView: UIView {
  weak var playerLayer: AVPlayerLayer?

  override func layoutSubviews() {
    super.layoutSubviews()
    playerLayer?.frame = bounds
  }
}

final class AvPlayerSession: NSObject, AVPictureInPictureControllerDelegate {
  private let playerId: Int64
  private let flutterApi: MdCenterAvPlayerFlutterApiProtocol
  private let player = AVPlayer()
  private let playerLayer: AVPlayerLayer

  private var item: AVPlayerItem?
  private var statusObservation: NSKeyValueObservation?
  private var loadedRangesObservation: NSKeyValueObservation?
  private var sizeObservation: NSKeyValueObservation?
  private var timeControlObservation: NSKeyValueObservation?
  private var firstFrameObservation: NSKeyValueObservation?
  private var timeObserver: Any?
  private var endObserver: NSObjectProtocol?
  private var pendingOpen: ((Result<Void, Error>) -> Void)?
  private var pendingStartPositionMs: Double = 0
  private var pendingAutoplay = true
  private var desiredRate: Float = 1
  private var previewGenerator: AVAssetImageGenerator?
  private var pictureInPictureController: AVPictureInPictureController?
  private var pictureInPictureCompletion: ((Result<Bool, Error>) -> Void)?

  init(playerId: Int64, flutterApi: MdCenterAvPlayerFlutterApiProtocol) {
    self.playerId = playerId
    self.flutterApi = flutterApi
    playerLayer = AVPlayerLayer(player: player)
    playerLayer.videoGravity = .resizeAspect
    super.init()
    observePlayer()
  }

  func attach(to view: PlayerContainerView, gravity: String) {
    playerLayer.removeFromSuperlayer()
    playerLayer.videoGravity = switch gravity {
    case "cover": .resizeAspectFill
    case "fill": .resize
    default: .resizeAspect
    }
    view.layer.addSublayer(playerLayer)
    view.playerLayer = playerLayer
    playerLayer.frame = view.bounds
  }

  func open(
    url: String,
    startPositionMs: Double?,
    autoplay: Bool,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    guard let mediaUrl = URL(string: url), mediaUrl.scheme != nil else {
      completion(.failure(AvPlayerPluginError.invalidUrl))
      return
    }
    clearItemObservers()
    pendingOpen?(.failure(AvPlayerPluginError.cancelled))
    pendingOpen = completion
    pendingStartPositionMs = max(0, startPositionMs ?? 0)
    pendingAutoplay = autoplay

    let asset = AVURLAsset(url: mediaUrl)
    let nextItem = AVPlayerItem(asset: asset)
    item = nextItem
    player.replaceCurrentItem(with: nextItem)
    observe(item: nextItem)
  }

  func play() {
    player.playImmediately(atRate: desiredRate)
  }

  func pause() {
    player.pause()
  }

  func seek(
    positionMs: Double,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    let time = AvPlayerTime.time(milliseconds: positionMs)
    player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) {
      finished in
      completion(finished ? .success(()) : .failure(AvPlayerPluginError.cancelled))
    }
  }

  func setRate(_ rate: Double) {
    desiredRate = Float(max(0.25, min(4, rate)))
    if player.timeControlStatus == .playing {
      player.rate = desiredRate
    }
  }

  func audioTracks() -> [AvPlayerAudioTrack] {
    guard let item,
          let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .audible)
    else { return [] }
    let selected = item.currentMediaSelection.selectedMediaOption(in: group)
    return group.options.enumerated().map { index, option in
      AvPlayerAudioTrack(
        id: String(index),
        title: option.displayName,
        language: option.extendedLanguageTag ?? option.locale?.identifier ?? "",
        selected: option === selected
      )
    }
  }

  func selectAudioTrack(_ trackId: String) -> Result<Void, Error> {
    guard let index = Int(trackId),
          let item,
          let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .audible),
          group.options.indices.contains(index)
    else { return .failure(AvPlayerPluginError.missingTrack) }
    item.select(group.options[index], in: group)
    return .success(())
  }

  func captureFrame(
    positionMs: Double,
    completion: @escaping (Result<FlutterStandardTypedData?, Error>) -> Void
  ) {
    guard let asset = item?.asset else {
      completion(.failure(AvPlayerPluginError.missingItem))
      return
    }
    previewGenerator?.cancelAllCGImageGeneration()
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.requestedTimeToleranceBefore = CMTime(seconds: 0.2, preferredTimescale: 600)
    generator.requestedTimeToleranceAfter = CMTime(seconds: 0.2, preferredTimescale: 600)
    previewGenerator = generator
    let time = AvPlayerTime.time(milliseconds: positionMs)
    generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) {
      [weak self, weak generator] _, image, _, result, error in
      guard let self, let generator, self.previewGenerator === generator else {
        completion(.failure(AvPlayerPluginError.cancelled))
        return
      }
      self.previewGenerator = nil
      if result == .succeeded, let image,
         let data = UIImage(cgImage: image).jpegData(compressionQuality: 0.78) {
        completion(.success(FlutterStandardTypedData(bytes: data)))
      } else if result == .cancelled {
        completion(.failure(AvPlayerPluginError.cancelled))
      } else {
        completion(.failure(error ?? AvPlayerPluginError.frameUnavailable))
      }
    }
  }

  func cancelFramePreview() {
    previewGenerator?.cancelAllCGImageGeneration()
    previewGenerator = nil
  }

  func startPictureInPicture(
    completion: @escaping (Result<Bool, Error>) -> Void
  ) {
    guard AVPictureInPictureController.isPictureInPictureSupported(),
          pictureInPictureCompletion == nil else {
      completion(.success(false))
      return
    }
    do {
      let audio = AVAudioSession.sharedInstance()
      try audio.setCategory(.playback, mode: .moviePlayback)
      try audio.setActive(true)
    } catch {
      // 已被其他播放器激活时继续尝试 PiP。
    }
    guard let controller = AVPictureInPictureController(playerLayer: playerLayer) else {
      completion(.success(false))
      return
    }
    pictureInPictureController = controller
    pictureInPictureCompletion = completion
    controller.delegate = self
    if controller.isPictureInPicturePossible {
      controller.startPictureInPicture()
    } else {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
        guard let self, self.pictureInPictureCompletion != nil else { return }
        if controller.isPictureInPicturePossible {
          controller.startPictureInPicture()
        } else {
          self.finishPictureInPictureStart(false)
        }
      }
    }
  }

  func stopPictureInPicture() {
    pictureInPictureController?.stopPictureInPicture()
  }

  func pictureInPictureControllerDidStartPictureInPicture(
    _ pictureInPictureController: AVPictureInPictureController
  ) {
    send(.pictureInPicture, boolValue: true)
    finishPictureInPictureStart(true)
  }

  func pictureInPictureController(
    _ pictureInPictureController: AVPictureInPictureController,
    failedToStartPictureInPictureWithError error: Error
  ) {
    finishPictureInPictureStart(false)
  }

  func pictureInPictureControllerDidStopPictureInPicture(
    _ pictureInPictureController: AVPictureInPictureController
  ) {
    send(.pictureInPicture, boolValue: false)
    self.pictureInPictureController?.delegate = nil
    self.pictureInPictureController = nil
  }

  func dispose() {
    pendingOpen?(.failure(AvPlayerPluginError.cancelled))
    pendingOpen = nil
    pictureInPictureCompletion?(.success(false))
    pictureInPictureCompletion = nil
    stopPictureInPicture()
    previewGenerator?.cancelAllCGImageGeneration()
    previewGenerator = nil
    clearItemObservers()
    if let timeObserver {
      player.removeTimeObserver(timeObserver)
      self.timeObserver = nil
    }
    timeControlObservation = nil
    player.pause()
    player.replaceCurrentItem(with: nil)
    playerLayer.player = nil
    playerLayer.removeFromSuperlayer()
  }

  private func observePlayer() {
    timeControlObservation = player.observe(
      \.timeControlStatus,
      options: [.initial, .new]
    ) { [weak self] player, _ in
      guard let self else { return }
      self.send(.playing, boolValue: player.timeControlStatus == .playing)
      self.send(
        .buffering,
        boolValue: player.timeControlStatus == .waitingToPlayAtSpecifiedRate
      )
    }
    timeObserver = player.addPeriodicTimeObserver(
      forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
      queue: .main
    ) { [weak self] time in
      guard let self else { return }
      let milliseconds = AvPlayerTime.milliseconds(time)
      self.send(.position, numberValue: milliseconds)
    }
  }

  private func observe(item: AVPlayerItem) {
    statusObservation = item.observe(\.status, options: [.initial, .new]) {
      [weak self] item, _ in
      self?.handleStatus(item.status)
    }
    loadedRangesObservation = item.observe(
      \.loadedTimeRanges,
      options: [.initial, .new]
    ) { [weak self] item, _ in
      let end = item.loadedTimeRanges
        .compactMap { $0.timeRangeValue }
        .map { $0.start.seconds + $0.duration.seconds }
        .filter { $0.isFinite }
        .max() ?? 0
      self?.send(.buffered, numberValue: max(0, end * 1000))
    }
    sizeObservation = item.observe(\.presentationSize, options: [.initial, .new]) {
      [weak self] item, _ in
      self?.send(
        .size,
        numberValue: item.presentationSize.width,
        secondaryNumberValue: item.presentationSize.height
      )
    }
    firstFrameObservation = playerLayer.observe(
      \.isReadyForDisplay,
      options: [.initial, .new]
    ) { [weak self] layer, _ in
      if layer.isReadyForDisplay { self?.send(.firstFrame, boolValue: true) }
    }
    endObserver = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemDidPlayToEndTime,
      object: item,
      queue: .main
    ) { [weak self] _ in
      self?.send(.completed, boolValue: true)
    }
  }

  private func handleStatus(_ status: AVPlayerItem.Status) {
    switch status {
    case .readyToPlay:
      guard let item else { return }
      let seconds = item.duration.seconds
      send(.duration, numberValue: seconds.isFinite ? max(0, seconds * 1000) : 0)
      send(.ready, boolValue: true)
      let finishOpen = { [weak self] in
        guard let self else { return }
        if self.pendingAutoplay { self.play() }
        let completion = self.pendingOpen
        self.pendingOpen = nil
        completion?(.success(()))
      }
      if pendingStartPositionMs > 0 {
        seek(positionMs: pendingStartPositionMs) { _ in finishOpen() }
      } else {
        finishOpen()
      }
    case .failed:
      let error = item?.error ?? AvPlayerPluginError.openFailed
      send(.error, stringValue: error.localizedDescription)
      let completion = pendingOpen
      pendingOpen = nil
      completion?(.failure(error))
    case .unknown:
      break
    @unknown default:
      let error = AvPlayerPluginError.openFailed
      send(.error, stringValue: error.localizedDescription)
      pendingOpen?(.failure(error))
      pendingOpen = nil
    }
  }

  private func clearItemObservers() {
    statusObservation = nil
    loadedRangesObservation = nil
    sizeObservation = nil
    firstFrameObservation = nil
    if let endObserver {
      NotificationCenter.default.removeObserver(endObserver)
      self.endObserver = nil
    }
  }

  private func finishPictureInPictureStart(_ started: Bool) {
    let completion = pictureInPictureCompletion
    pictureInPictureCompletion = nil
    completion?(.success(started))
    if !started {
      pictureInPictureController?.delegate = nil
      pictureInPictureController = nil
    }
  }

  private func send(
    _ type: AvPlayerEventType,
    boolValue: Bool? = nil,
    numberValue: Double? = nil,
    secondaryNumberValue: Double? = nil,
    stringValue: String? = nil
  ) {
    let event = AvPlayerEvent(
      playerId: playerId,
      type: type,
      boolValue: boolValue,
      numberValue: numberValue,
      secondaryNumberValue: secondaryNumberValue,
      stringValue: stringValue
    )
    flutterApi.onEvent(event: event) { _ in }
  }
}

enum AvPlayerPluginError: LocalizedError {
  case missingPlayer
  case missingItem
  case missingTrack
  case invalidUrl
  case openFailed
  case frameUnavailable
  case cancelled

  var errorDescription: String? {
    switch self {
    case .missingPlayer: "播放器不存在"
    case .missingItem: "媒体尚未打开"
    case .missingTrack: "音轨不存在"
    case .invalidUrl: "播放地址无效"
    case .openFailed: "AVPlayer 无法打开媒体"
    case .frameUnavailable: "预览帧不可用"
    case .cancelled: "操作已取消"
    }
  }
}

enum AvPlayerTime {
  static func time(milliseconds: Double) -> CMTime {
    CMTime(seconds: max(0, milliseconds) / 1000, preferredTimescale: 600)
  }

  static func milliseconds(_ time: CMTime) -> Double {
    time.seconds.isFinite ? max(0, time.seconds * 1000) : 0
  }
}
