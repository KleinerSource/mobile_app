import AVFoundation
import AVKit
import Combine
import Flutter
import Foundation
import KSPlayer
import UIKit

public final class OmmKsplayerPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let manager = KsPlayerManager(messenger: registrar.messenger())
    OmmKsPlayerHostApiSetup.setUp(
      binaryMessenger: registrar.messenger(),
      api: manager
    )
    registrar.register(
      KsPlayerViewFactory(manager: manager),
      withId: "omm_ksplayer/view"
    )
  }
}

private final class KsPlayerManager: NSObject, OmmKsPlayerHostApi {
  private let flutterApi: OmmKsPlayerFlutterApi
  private var sessions: [Int64: KsPlayerSession] = [:]

  init(messenger: FlutterBinaryMessenger) {
    flutterApi = OmmKsPlayerFlutterApi(binaryMessenger: messenger)
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
    videoCodec: String?,
    preloadBytes: Int64?,
    hardwareAcceleration: Bool,
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
        videoCodec: videoCodec,
        preloadBytes: preloadBytes,
        hardwareAcceleration: hardwareAcceleration,
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
  private let flutterApi: OmmKsPlayerFlutterApiProtocol
  private var layer: KSPlayerLayer
  private weak var attachedView: KsPlayerContainerView?
  private var attachedGravity = "contain"
  private var pipCancellable: AnyCancellable?
  private var pendingOpen: ((Result<Void, Error>) -> Void)?
  private var pendingStartPositionMs: Double = 0
  private var pendingStartVerificationMs: Double = 0
  private var startVerificationGeneration = 0
  private var openGeneration = 0
  private var pendingAutoplay = true
  private var desiredRate: Float = 1
  private var disposed = false
  private var layerIsStopped = true
  private var lastVideoSize = CGSize.zero

  init(playerId: Int64, flutterApi: OmmKsPlayerFlutterApiProtocol) {
    self.playerId = playerId
    self.flutterApi = flutterApi
    let options = KSOptions()
    layer = KSPlayerLayer(
      url: URL(string: "about:blank")!,
      isAutoPlay: false,
      options: options
    )
    super.init()
    installLayerCallbacks()
  }

  func attach(to view: KsPlayerContainerView, gravity: String) {
    attachedView = view
    attachedGravity = gravity
    guard let playerView = layer.player.view else { return }
    view.attach(playerView, gravity: gravity)
  }

  func open(
    url: String,
    startPositionMs: Double?,
    autoplay: Bool,
    headers: [String: String]?,
    formatHint: String?,
    videoCodec: String?,
    preloadBytes: Int64?,
    hardwareAcceleration: Bool,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    guard let mediaURL = URL(string: url), mediaURL.scheme != nil else {
      completion(.failure(KsPlayerPluginError.invalidUrl))
      return
    }
    // Flutter 统一处理播放失败，不允许 KSPlayer 在内部再切换到第二套内核。
    KSOptions.secondPlayerType = nil
    let useFfmpegPlayer = prefersFfmpegPlayer(
      url: mediaURL,
      formatHint: formatHint,
      videoCodec: videoCodec
    )
    KSOptions.firstPlayerType = useFfmpegPlayer ? KSMEPlayer.self : KSAVPlayer.self

    openGeneration += 1
    pendingOpen?(.failure(KsPlayerPluginError.cancelled))
    pendingOpen = nil
    recreateLayer()
    pendingOpen = completion
    pendingAutoplay = autoplay
    let startSeconds = max(0, startPositionMs ?? 0) / 1000
    startVerificationGeneration += 1

    lastVideoSize = .zero
    let options = KSOptions()
    options.startPlayRate = desiredRate
    options.isSeekedAutoPlay = autoplay
    options.hardwareDecode = hardwareAcceleration
    let isHls = isHlsStream(url: mediaURL, formatHint: formatHint)
    if isHls {
      // HLS seek 后只需拉取目标切片及少量后续切片即可恢复播放。
      // 复用本地文件的大前向缓存会让 KSPlayer 在定位后等待很久。
      options.preferredForwardBufferDuration = 3
      options.maxBufferDuration = 8
    } else {
      let bufferSeconds = forwardBufferDuration(for: preloadBytes)
      options.preferredForwardBufferDuration = bufferSeconds
      options.maxBufferDuration = bufferSeconds
    }
    // HLS 与 AVPlayer 使用 KSPlayer 的秒开门控；KSMEPlayer 直流容器（尤其
    // MKV）需要先完成默认前向缓冲，否则可能只渲染首帧而没有启动音视频时钟。
    options.isSecondOpen = isHls || !useFfmpegPlayer
    if let headers, !headers.isEmpty {
      options.appendHeader(headers)
    }
    if useFfmpegPlayer, startSeconds > 0 {
      // KSMEPlayer 的 startPlayTime 快路径会在首帧显示后留下停住的音视频时钟；
      // 恢复早期已验证的 ready 后 seek 路径，由 KSPlayerLayer 统一启动播放。
      pendingStartPositionMs = startSeconds * 1000
      pendingStartVerificationMs = 0
    } else {
      pendingStartPositionMs = startSeconds * 1000
      pendingStartVerificationMs = startSeconds >= 2.5 ? startSeconds * 1000 : 0
    }
    layer.set(url: mediaURL, options: options)
    layer.prepareToPlay()
    layerIsStopped = false
  }

  /// 将播放器设置中的预加载字节档位映射为 KSPlayer 支持的时间缓冲。
  /// KSPlayer 不提供 libmpv 的字节级 demuxer 缓冲参数，使用保守的 8 MB/s
  /// 估算，同时限制时间范围，避免启动时等待过久或占用过多内存。
  private func forwardBufferDuration(for preloadBytes: Int64?) -> TimeInterval {
    let bytes = max(0, preloadBytes ?? 0)
    guard bytes > 0 else { return 30 }
    let seconds = Double(bytes) / (8 * 1024 * 1024)
    return min(max(seconds, 30), 120)
  }

  private func isHlsStream(url: URL, formatHint: String?) -> Bool {
    let hint = formatHint?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
    if hint == "m3u8" ||
        hint == "hls" ||
        hint.contains("mpegurl") {
      return true
    }
    return url.pathExtension.lowercased() == "m3u8"
  }

  private func installLayerCallbacks() {
    layer.delegate = self
    layer.player.contentMode = .scaleAspectFit
    pipCancellable = layer.$isPipActive.sink { [weak self] active in
      self?.send(.pictureInPicture, boolValue: active)
    }
  }

  /// 页面切换前会先通过 HostApi stop 当前 layer。KSPlayerLayer.stop() 没有
  /// 幂等保护，重复调用会再次执行底层 player.shutdown()；重建时只清理尚未
  /// 停止的旧 layer，避免“页面 stop → open recreateLayer stop”的双重关闭。
  private func recreateLayer() {
    let oldLayer = layer
    pipCancellable = nil
    oldLayer.isPipActive = false
    oldLayer.delegate = nil
    if !layerIsStopped {
      oldLayer.stop()
    }

    let options = KSOptions()
    layer = KSPlayerLayer(
      url: URL(string: "about:blank")!,
      isAutoPlay: false,
      options: options
    )
    layerIsStopped = true
    installLayerCallbacks()
    if let attachedView {
      attach(to: attachedView, gravity: attachedGravity)
    }
  }

  private func prefersFfmpegPlayer(
    url: URL,
    formatHint: String?,
    videoCodec: String?
  ) -> Bool {
    // M3U8/HLS 统一交给 KSMEPlayer：FFmpeg 对 HLS（含 AES-128 加密流）的
    // 远距离 seek 更稳，SMB 回环代理地址上的 m3u8 同样适用。
    if isHlsStream(url: url, formatHint: formatHint) {
      return true
    }
    let isLoopback = url.host == "127.0.0.1" ||
      url.host == "localhost" ||
      url.host == "::1"
    if isLoopback {
      return true
    }
    if let videoCodec, isFfmpegVideoCodec(videoCodec) {
      return true
    }
    let hint = [formatHint, url.pathExtension]
      .compactMap { $0?.lowercased() }
      .joined(separator: ",")
    let tokens = hint.split { !$0.isLetter && !$0.isNumber }
    return tokens.contains { token in
      token == "mkv" || token == "matroska" || token == "webm"
    }
  }

  private func isFfmpegVideoCodec(_ codec: String) -> Bool {
    let normalized = codec
      .lowercased()
      .replacingOccurrences(of: ".", with: "")
      .replacingOccurrences(of: "-", with: "")
      .replacingOccurrences(of: "_", with: "")
    return normalized.contains("hevc") ||
      normalized.contains("h265") ||
      normalized.contains("hvc1") ||
      normalized.contains("hev1") ||
      normalized.contains("x265")
  }

  func play() throws {
    guard !disposed else { throw KsPlayerPluginError.disposed }
    layer.play()
    layerIsStopped = false
  }

  func pause() throws {
    guard !disposed else { throw KsPlayerPluginError.disposed }
    layer.pause()
  }

  func stop() throws {
    guard !disposed else { throw KsPlayerPluginError.disposed }
    openGeneration += 1
    pendingOpen?(.failure(KsPlayerPluginError.cancelled))
    pendingOpen = nil
    pendingStartVerificationMs = 0
    startVerificationGeneration += 1
    if !layerIsStopped {
      layer.stop()
      layerIsStopped = true
    }
  }

  func seek(
    positionMs: Double,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    guard !disposed else {
      completion(.failure(KsPlayerPluginError.disposed))
      return
    }
    pendingStartVerificationMs = 0
    startVerificationGeneration += 1
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
    if !layerIsStopped {
      layer.stop()
      layerIsStopped = true
    }
  }

  func player(layer callbackLayer: KSPlayerLayer, state: KSPlayerState) {
    guard callbackLayer === layer else { return }
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
      verifyStartPositionLater()
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

  func player(
    layer callbackLayer: KSPlayerLayer,
    currentTime: TimeInterval,
    totalTime: TimeInterval
  ) {
    guard callbackLayer === layer else { return }
    send(.position, numberValue: milliseconds(currentTime))
    send(.duration, numberValue: milliseconds(totalTime))
    sendVideoSizeIfNeeded()
  }

  func player(layer callbackLayer: KSPlayerLayer, finish error: Error?) {
    guard callbackLayer === layer else { return }
    if let error {
      let message = error.localizedDescription.isEmpty ? "KSPlayer 播放失败" : error.localizedDescription
      send(.error, stringValue: message)
      pendingOpen?(.failure(error))
      pendingOpen = nil
    } else {
      send(.completed, boolValue: true)
    }
  }

  func player(
    layer callbackLayer: KSPlayerLayer,
    bufferedCount _: Int,
    consumeTime _: TimeInterval
  ) {
    guard callbackLayer === layer else { return }
    // KSPlayer exposes buffer loading progress, not a reliable buffered-end timestamp.
    // Keep the unified timeline buffered value at zero rather than fabricating one.
  }

  private func finishPendingOpenIfReady() {
    let generation = openGeneration
    let currentLayer = layer
    guard pendingOpen != nil else { return }
    let finish: () -> Void = { [weak self] in
      guard let self,
            self.openGeneration == generation,
            let completion = self.pendingOpen
      else { return }
      self.pendingOpen = nil
      completion(.success(()))
    }
    if pendingStartPositionMs > 0 {
      let start = pendingStartPositionMs / 1000
      // AVPlayer 切换 HLS 时可能不回调 seek completion。媒体已经 ready 后，
      // 初始 seek 只负责定位，不应继续阻塞 Pigeon open；稍后的定位校验负责兜底。
      currentLayer.seek(time: start, autoPlay: pendingAutoplay) { _ in }
      finish()
    } else {
      if pendingAutoplay { currentLayer.play() }
      finish()
    }
  }

  /// AVPlayer ready 后的初始 seek 可能落在 0 附近；就绪片刻后比对实际
  /// 播放位置，失准则再 seek 补救。KSMEPlayer 走 ready 后 seek，不使用此快路。
  /// 只能从 .readyToPlay 调度——那之前读线程可能尚未定位，位置恒为 0 会误判。
  private func verifyStartPositionLater() {
    let targetMs = pendingStartVerificationMs
    guard targetMs > 0 else { return }
    let generation = startVerificationGeneration
    Task { @MainActor [weak self] in
      try? await Task.sleep(nanoseconds: 350_000_000)
      guard let self, !self.disposed, self.startVerificationGeneration == generation else {
        return
      }
      self.pendingStartVerificationMs = 0
      let target = targetMs / 1000
      let player = self.layer.player
      guard player.currentPlaybackTime + 1.5 < target else { return }
      let duration = player.duration
      guard duration <= 0 || target < duration else { return }
      self.layer.seek(time: target, autoPlay: self.pendingAutoplay) { _ in }
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
    send(
      .size,
      numberValue: size.width,
      secondaryNumberValue: size.height,
      stringValue: mediaInfoPayload()
    )
    send(.firstFrame, boolValue: true)
  }

  private func mediaInfoPayload() -> String? {
    let videoTrack = layer.player.tracks(mediaType: .video).first
    let audioTrack = layer.player.tracks(mediaType: .audio).first
    var payload: [String: Any] = [
      "internal_player": internalPlayerLabel,
    ]
    if let videoTrack {
      let codec = videoTrack.description.split(separator: ",", maxSplits: 1).first
      if let codec, !codec.isEmpty { payload["video_codec"] = String(codec) }
      if videoTrack.bitRate > 0 { payload["video_bitrate"] = videoTrack.bitRate }
      if videoTrack.nominalFrameRate > 0 {
        payload["video_fps"] = Double(videoTrack.nominalFrameRate)
      }
    }
    if let audioTrack {
      let codec = audioTrack.description.split(separator: ",", maxSplits: 1).first
      if let codec, !codec.isEmpty { payload["audio_codec"] = String(codec) }
      if audioTrack.bitRate > 0 { payload["audio_bitrate"] = audioTrack.bitRate }
    }
    guard JSONSerialization.isValidJSONObject(payload),
          let data = try? JSONSerialization.data(withJSONObject: payload),
          let value = String(data: data, encoding: .utf8)
    else { return nil }
    return value
  }

  private var internalPlayerLabel: String {
    if layer.player is KSMEPlayer { return "KSMEPlayer" }
    if layer.player is KSAVPlayer { return "AVPlayer" }
    return String(describing: type(of: layer.player))
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
