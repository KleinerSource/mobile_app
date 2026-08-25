import AVFoundation
import AVKit
import Combine
import Flutter
import KSPlayer
import UIKit

public final class MdCenterKsplayerPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let manager = KsPlayerManager(messenger: registrar.messenger())
    MdCenterKsPlayerHostApiSetup.setUp(
      binaryMessenger: registrar.messenger(),
      api: manager
    )
    registrar.register(
      KsPlayerViewFactory(manager: manager),
      withId: "md_center_ksplayer/view"
    )
  }
}

private final class KsPlayerManager: NSObject, MdCenterKsPlayerHostApi {
  private let flutterApi: MdCenterKsPlayerFlutterApi
  private var sessions: [Int64: KsPlayerSession] = [:]

  init(messenger: FlutterBinaryMessenger) {
    flutterApi = MdCenterKsPlayerFlutterApi(binaryMessenger: messenger)
  }

  func create(playerId: Int64) throws {
    guard sessions[playerId] == nil else { return }
    sessions[playerId] = MainActor.assumeIsolated {
      KsPlayerSession(playerId: playerId, flutterApi: flutterApi)
    }
  }

  func open(
    playerId: Int64,
    url: String,
    startPositionMs: Double?,
    autoplay: Bool,
    headers: [String: String]?,
    formatHint: String?,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    guard let session = sessions[playerId] else {
      completion(.failure(KsPlayerPluginError.missingPlayer))
      return
    }
    MainActor.assumeIsolated {
      session.open(
        url: url,
        startPositionMs: startPositionMs,
        autoplay: autoplay,
        headers: headers,
        formatHint: formatHint,
        completion: completion
      )
    }
  }

  func play(playerId: Int64) throws {
    try MainActor.assumeIsolated { try session(playerId).play() }
  }

  func pause(playerId: Int64) throws {
    try MainActor.assumeIsolated { try session(playerId).pause() }
  }

  func stop(playerId: Int64) throws {
    try MainActor.assumeIsolated { try session(playerId).stop() }
  }

  func seek(
    playerId: Int64,
    positionMs: Double,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    guard let session = sessions[playerId] else {
      completion(.failure(KsPlayerPluginError.missingPlayer))
      return
    }
    MainActor.assumeIsolated {
      session.seek(positionMs: positionMs, completion: completion)
    }
  }

  func setRate(playerId: Int64, rate: Double) throws {
    try MainActor.assumeIsolated { try session(playerId).setRate(rate) }
  }

  func audioTracks(
    playerId: Int64,
    completion: @escaping (Result<[KsPlayerAudioTrack], Error>) -> Void
  ) {
    guard let session = sessions[playerId] else {
      completion(.failure(KsPlayerPluginError.missingPlayer))
      return
    }
    MainActor.assumeIsolated {
      completion(.success(session.audioTracks()))
    }
  }

  func selectAudioTrack(
    playerId: Int64,
    trackId: String,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    guard let session = sessions[playerId] else {
      completion(.failure(KsPlayerPluginError.missingPlayer))
      return
    }
    MainActor.assumeIsolated {
      completion(session.selectAudioTrack(trackId))
    }
  }

  func selectSubtitleTrack(
    playerId: Int64,
    trackId: String,
    fallbackIndex: Int64?,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    guard let session = sessions[playerId] else {
      completion(.failure(KsPlayerPluginError.missingPlayer))
      return
    }
    MainActor.assumeIsolated {
      completion(session.selectSubtitleTrack(trackId, fallbackIndex: fallbackIndex))
    }
  }

  func clearSubtitleTrack(
    playerId: Int64,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    guard let session = sessions[playerId] else {
      completion(.failure(KsPlayerPluginError.missingPlayer))
      return
    }
    MainActor.assumeIsolated {
      completion(session.clearSubtitleTrack())
    }
  }

  func captureFrame(
    playerId: Int64,
    positionMs: Double,
    completion: @escaping (Result<FlutterStandardTypedData?, Error>) -> Void
  ) {
    guard let session = sessions[playerId] else {
      completion(.failure(KsPlayerPluginError.missingPlayer))
      return
    }
    MainActor.assumeIsolated {
      session.captureFrame(positionMs: positionMs, completion: completion)
    }
  }

  func cancelFramePreview(playerId: Int64) throws {
    try MainActor.assumeIsolated { try session(playerId).cancelFramePreview() }
  }

  func startPictureInPicture(
    playerId: Int64,
    completion: @escaping (Result<Bool, Error>) -> Void
  ) {
    guard let session = sessions[playerId] else {
      completion(.failure(KsPlayerPluginError.missingPlayer))
      return
    }
    MainActor.assumeIsolated {
      completion(.success(session.startPictureInPicture()))
    }
  }

  func stopPictureInPicture(playerId: Int64) throws {
    try MainActor.assumeIsolated { try session(playerId).stopPictureInPicture() }
  }

  func dispose(playerId: Int64) throws {
    MainActor.assumeIsolated {
      sessions.removeValue(forKey: playerId)?.dispose()
    }
  }

  func attach(playerId: Int64, to view: KsPlayerContainerView, gravity: String) {
    guard let session = sessions[playerId] else { return }
    MainActor.assumeIsolated {
      session.attach(to: view, gravity: gravity)
    }
  }

  private func session(_ playerId: Int64) throws -> KsPlayerSession {
    guard let session = sessions[playerId] else {
      throw KsPlayerPluginError.missingPlayer
    }
    return session
  }
}

private final class KsPlayerViewFactory: NSObject, FlutterPlatformViewFactory {
  private let manager: KsPlayerManager

  init(manager: KsPlayerManager) {
    self.manager = manager
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier _: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    let values = args as? [String: Any]
    let playerId = (values?["playerId"] as? NSNumber)?.int64Value ?? -1
    let gravity = values?["videoGravity"] as? String ?? "contain"
    let platformView = KsPlayerPlatformView(frame: frame)
    manager.attach(playerId: playerId, to: platformView.container, gravity: gravity)
    return platformView
  }
}

private final class KsPlayerPlatformView: NSObject, FlutterPlatformView {
  let container: KsPlayerContainerView

  init(frame: CGRect) {
    container = KsPlayerContainerView(frame: frame)
    super.init()
  }

  func view() -> UIView { container }
}

private final class KsPlayerContainerView: UIView {
  private weak var videoView: UIView?

  func attach(_ view: UIView, gravity: String) {
    videoView?.removeFromSuperview()
    view.removeFromSuperview()
    view.contentMode = switch gravity {
    case "cover": .scaleAspectFill
    case "fill": .scaleToFill
    default: .scaleAspectFit
    }
    view.translatesAutoresizingMaskIntoConstraints = false
    addSubview(view)
    NSLayoutConstraint.activate([
      view.topAnchor.constraint(equalTo: topAnchor),
      view.leadingAnchor.constraint(equalTo: leadingAnchor),
      view.trailingAnchor.constraint(equalTo: trailingAnchor),
      view.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
    videoView = view
  }
}

@MainActor
private final class KsPlayerSession: NSObject, KSPlayerLayerDelegate {
  private let playerId: Int64
  private let flutterApi: MdCenterKsPlayerFlutterApiProtocol
  private let layer: KSPlayerLayer
  private var pipCancellable: AnyCancellable?
  private var pendingOpen: ((Result<Void, Error>) -> Void)?
  private var pendingStartPositionMs: Double = 0
  private var pendingAutoplay = true
  private var desiredRate: Float = 1
  private var disposed = false
  private var lastVideoSize = CGSize.zero

  init(playerId: Int64, flutterApi: MdCenterKsPlayerFlutterApiProtocol) {
    self.playerId = playerId
    self.flutterApi = flutterApi
    let options = KSOptions()
    layer = KSPlayerLayer(
      url: URL(string: "about:blank")!,
      isAutoPlay: false,
      options: options
    )
    super.init()
    layer.delegate = self
    layer.player.contentMode = .scaleAspectFit
    pipCancellable = layer.$isPipActive.sink { [weak self] active in
      self?.send(.pictureInPicture, boolValue: active)
    }
  }

  func attach(to view: KsPlayerContainerView, gravity: String) {
    guard let playerView = layer.player.view else { return }
    view.attach(playerView, gravity: gravity)
  }

  func open(
    url: String,
    startPositionMs: Double?,
    autoplay: Bool,
    headers: [String: String]?,
    formatHint: String?,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    guard let mediaURL = URL(string: url), mediaURL.scheme != nil else {
      completion(.failure(KsPlayerPluginError.invalidUrl))
      return
    }
    pendingOpen?(.failure(KsPlayerPluginError.cancelled))
    pendingOpen = completion
    pendingStartPositionMs = max(0, startPositionMs ?? 0)
    pendingAutoplay = autoplay

    layer.stop()
    // Flutter 统一处理播放失败，不允许 KSPlayer 在内部再切换到第二套内核。
    KSOptions.secondPlayerType = nil
    KSOptions.firstPlayerType = prefersFfmpegPlayer(
      url: mediaURL,
      formatHint: formatHint
    ) ? KSMEPlayer.self : KSAVPlayer.self
    lastVideoSize = .zero
    let options = KSOptions()
    options.startPlayRate = desiredRate
    options.isSeekedAutoPlay = autoplay
    if let headers, !headers.isEmpty {
      options.appendHeader(headers)
    }
    layer.set(url: mediaURL, options: options)
    layer.prepareToPlay()
  }

  private func prefersFfmpegPlayer(url: URL, formatHint: String?) -> Bool {
    let hint = [formatHint, url.pathExtension]
      .compactMap { $0?.lowercased() }
      .joined(separator: ",")
    let tokens = hint.split { !$0.isLetter && !$0.isNumber }
    return tokens.contains { token in
      token == "mkv" || token == "matroska" || token == "webm"
    }
  }

  func play() throws {
    guard !disposed else { throw KsPlayerPluginError.disposed }
    layer.play()
  }

  func pause() throws {
    guard !disposed else { throw KsPlayerPluginError.disposed }
    layer.pause()
  }

  func stop() throws {
    guard !disposed else { throw KsPlayerPluginError.disposed }
    layer.stop()
  }

  func seek(
    positionMs: Double,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    guard !disposed else {
      completion(.failure(KsPlayerPluginError.disposed))
      return
    }
    layer.seek(time: max(0, positionMs) / 1000, autoPlay: layer.state.isPlaying) { finished in
      completion(finished ? .success(()) : .failure(KsPlayerPluginError.cancelled))
    }
  }

  func setRate(_ rate: Double) throws {
    guard !disposed else { throw KsPlayerPluginError.disposed }
    desiredRate = Float(max(0.25, min(4, rate)))
    layer.player.playbackRate = desiredRate
  }

  func audioTracks() -> [KsPlayerAudioTrack] {
    layer.player.tracks(mediaType: .audio).map { track in
      KsPlayerAudioTrack(
        id: String(track.trackID),
        title: track.name,
        language: track.languageCode ?? "",
        selected: track.isEnabled
      )
    }
  }

  func selectAudioTrack(_ trackId: String) -> Result<Void, Error> {
    guard let track = findTrack(
      mediaType: .audio,
      id: trackId,
      fallbackIndex: nil
    ) else {
      return .failure(KsPlayerPluginError.missingTrack)
    }
    layer.player.select(track: track)
    return .success(())
  }

  func selectSubtitleTrack(
    _ trackId: String,
    fallbackIndex: Int64?
  ) -> Result<Void, Error> {
    guard let track = findTrack(
      mediaType: .subtitle,
      id: trackId,
      fallbackIndex: fallbackIndex
    ) else {
      return .failure(KsPlayerPluginError.missingTrack)
    }
    layer.player.select(track: track)
    return .success(())
  }

  func clearSubtitleTrack() -> Result<Void, Error> {
    for track in layer.player.tracks(mediaType: .subtitle) {
      track.isEnabled = false
    }
    return .success(())
  }

  func captureFrame(
    positionMs: Double,
    completion: @escaping (Result<FlutterStandardTypedData?, Error>) -> Void
  ) {
    guard !disposed else {
      completion(.failure(KsPlayerPluginError.disposed))
      return
    }
    Task { @MainActor [weak self] in
      guard let self, !self.disposed else {
        completion(.failure(KsPlayerPluginError.disposed))
        return
      }
      guard let image = await self.layer.previewImage(at: max(0, positionMs) / 1000),
            let data = UIImage(cgImage: image).jpegData(compressionQuality: 0.78)
      else {
        completion(.success(nil))
        return
      }
      completion(.success(FlutterStandardTypedData(bytes: data)))
    }
  }

  func cancelFramePreview() throws {
    guard !disposed else { throw KsPlayerPluginError.disposed }
    layer.cancelPreviewThumbnails()
  }

  func startPictureInPicture() -> Bool {
    guard !disposed,
          AVPictureInPictureController.isPictureInPictureSupported(),
          layer.player.pipController != nil
    else { return false }
    layer.isPipActive = true
    return true
  }

  func stopPictureInPicture() throws {
    guard !disposed else { throw KsPlayerPluginError.disposed }
    layer.isPipActive = false
  }

  func dispose() {
    guard !disposed else { return }
    disposed = true
    pendingOpen?(.failure(KsPlayerPluginError.cancelled))
    pendingOpen = nil
    layer.isPipActive = false
    layer.delegate = nil
    pipCancellable = nil
    layer.stop()
  }

  func player(layer _: KSPlayerLayer, state: KSPlayerState) {
    switch state {
    case .initialized:
      send(.playing, boolValue: false)
      send(.buffering, boolValue: false)
    case .preparing:
      send(.buffering, boolValue: true)
    case .readyToPlay:
      send(.ready)
      sendVideoSizeIfNeeded()
      finishPendingOpenIfReady()
    case .buffering:
      send(.playing, boolValue: true)
      send(.buffering, boolValue: true)
    case .bufferFinished:
      send(.playing, boolValue: true)
      send(.buffering, boolValue: false)
    case .paused:
      send(.playing, boolValue: false)
      send(.buffering, boolValue: false)
    case .playedToTheEnd:
      send(.playing, boolValue: false)
      send(.completed, boolValue: true)
    case .error:
      send(.playing, boolValue: false)
      send(.buffering, boolValue: false)
    }
  }

  func player(layer _: KSPlayerLayer, currentTime: TimeInterval, totalTime: TimeInterval) {
    send(.position, numberValue: milliseconds(currentTime))
    send(.duration, numberValue: milliseconds(totalTime))
    sendVideoSizeIfNeeded()
  }

  func player(layer _: KSPlayerLayer, finish error: Error?) {
    if let error {
      let message = error.localizedDescription.isEmpty ? "KSPlayer 播放失败" : error.localizedDescription
      send(.error, stringValue: message)
      pendingOpen?(.failure(error))
      pendingOpen = nil
    } else {
      send(.completed, boolValue: true)
    }
  }

  func player(layer _: KSPlayerLayer, bufferedCount _: Int, consumeTime _: TimeInterval) {
    // KSPlayer exposes buffer loading progress, not a reliable buffered-end timestamp.
    // Keep the unified timeline buffered value at zero rather than fabricating one.
  }

  private func finishPendingOpenIfReady() {
    guard let completion = pendingOpen else { return }
    let finish: () -> Void = { [weak self] in
      guard let self, let completion = self.pendingOpen else { return }
      self.pendingOpen = nil
      completion(.success(()))
    }
    if pendingStartPositionMs > 0 {
      let start = pendingStartPositionMs / 1000
      layer.seek(time: start, autoPlay: pendingAutoplay) { [weak self] _ in
        guard let self else { return }
        finish()
      }
    } else {
      if pendingAutoplay { layer.play() }
      finish()
    }
  }

  private func findTrack(
    mediaType: AVMediaType,
    id: String,
    fallbackIndex: Int64?
  ) -> MediaPlayerTrack? {
    let tracks = layer.player.tracks(mediaType: mediaType)
    if let trackId = Int32(id), let track = tracks.first(where: { $0.trackID == trackId }) {
      return track
    }
    if let fallbackIndex,
       let index = Int(exactly: fallbackIndex),
       tracks.indices.contains(index) {
      return tracks[index]
    }
    if let index = Int(id), tracks.indices.contains(index) {
      return tracks[index]
    }
    return nil
  }

  private func sendVideoSizeIfNeeded() {
    let size = layer.player.naturalSize
    guard size.width > 0, size.height > 0, size != lastVideoSize else { return }
    lastVideoSize = size
    send(.size, numberValue: size.width, secondaryNumberValue: size.height)
    send(.firstFrame, boolValue: true)
  }

  private func send(
    _ type: KsPlayerEventType,
    boolValue: Bool? = nil,
    numberValue: Double? = nil,
    secondaryNumberValue: Double? = nil,
    stringValue: String? = nil
  ) {
    guard !disposed else { return }
    let event = KsPlayerEvent(
      playerId: playerId,
      type: type,
      boolValue: boolValue,
      numberValue: numberValue,
      secondaryNumberValue: secondaryNumberValue,
      stringValue: stringValue
    )
    flutterApi.onEvent(event: event) { _ in }
  }

  private func milliseconds(_ seconds: TimeInterval) -> Double {
    seconds.isFinite ? max(0, seconds * 1000) : 0
  }
}

private enum KsPlayerPluginError: LocalizedError {
  case missingPlayer
  case missingTrack
  case invalidUrl
  case cancelled
  case disposed

  var errorDescription: String? {
    switch self {
    case .missingPlayer: "播放器不存在"
    case .missingTrack: "音轨或字幕轨不存在"
    case .invalidUrl: "播放地址无效"
    case .cancelled: "操作已取消"
    case .disposed: "播放器已释放"
    }
  }
}
