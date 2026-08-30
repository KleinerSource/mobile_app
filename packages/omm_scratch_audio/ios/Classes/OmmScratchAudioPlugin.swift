import AVFoundation
import Flutter
import Foundation
import os.lock

public final class OmmScratchAudioPlugin: NSObject, FlutterPlugin {
  private static let engine = ScratchAudioEngine()

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "omm/scratch_audio",
      binaryMessenger: registrar.messenger()
    )
    let instance = OmmScratchAudioPlugin()
    channel.setMethodCallHandler(instance.handle)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let arguments = call.arguments as? [String: Any]
    switch call.method {
    case "prepare":
      guard let source = arguments?["source"] as? String, !source.isEmpty else {
        result(FlutterError(code: "SCRATCH_PREPARE", message: "Missing audio source", details: nil))
        return
      }
      let headers = arguments?["headers"] as? [String: String] ?? [:]
      Self.engine.prepare(source: source, headers: headers) { state, error in
        DispatchQueue.main.async {
          if let error {
            result(FlutterError(
              code: "SCRATCH_PREPARE",
              message: error.localizedDescription,
              details: nil
            ))
          } else {
            result(state)
          }
        }
      }
    case "start":
      let positionMs = (arguments?["positionMs"] as? NSNumber)?.doubleValue ?? 0
      let autoplay = (arguments?["autoplay"] as? NSNumber)?.boolValue ?? true
      do {
        try Self.engine.start(positionMs: positionMs, autoplay: autoplay)
        result(nil)
      } catch {
        result(FlutterError(
          code: "SCRATCH_AUDIO",
          message: error.localizedDescription,
          details: nil
        ))
      }
    case "setRate":
      Self.engine.setRate((arguments?["rate"] as? NSNumber)?.doubleValue ?? 1)
      result(nil)
    case "state":
      result(Self.engine.state())
    case "stop":
      Self.engine.stop()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

private final class ScratchAudioEngine {
  private var audioEngine = AVAudioEngine()
  private var sourceNode: AVAudioSourceNode?
  private var samples: [[Float]] = []
  private var sampleRate = 0.0
  private var channelCount = 0
  private var sourceFrameCount = 0
  private var sourceFrame = 0.0
  private var playbackRate = 1.0
  private var currentRate = 1.0
  private var playing = false
  private var engineStarted = false
  private var downloadedURL: URL?
  private var stateLock = os_unfair_lock_s()

  func prepare(
    source: String,
    headers: [String: String],
    completion: @escaping ([String: Any]?, Error?) -> Void
  ) {
    resolveSource(source: source, headers: headers) { [weak self] url, error in
      guard let self else { return }
      if let error {
        completion(nil, error)
        return
      }
      guard let url else {
        completion(nil, self.error(code: 1, message: "Invalid audio source"))
        return
      }
      DispatchQueue.global(qos: .userInitiated).async {
        do {
          let decoded = try self.decode(url: url)
          if Thread.isMainThread {
            try self.install(decoded)
          } else {
            try DispatchQueue.main.sync {
              try self.install(decoded)
            }
          }
          completion(self.state(), nil)
        } catch {
          completion(nil, error)
        }
      }
    }
  }

  func start(positionMs: Double, autoplay: Bool) throws {
    let ready = withStateLock {
      guard sourceFrameCount > 1, sampleRate > 0 else { return false }
      sourceFrame = clampFrame(positionMs / 1000 * sampleRate)
      currentRate = playbackRate
      playing = autoplay
      return true
    }
    guard ready else {
      throw error(code: 2, message: "Scratch audio is not prepared")
    }
    do {
      if !engineStarted || !audioEngine.isRunning {
        try audioEngine.start()
        engineStarted = true
      }
    } catch {
      withStateLock { playing = false }
      throw error
    }
  }

  func setRate(_ value: Double) {
    guard value.isFinite else { return }
    withStateLock { playbackRate = min(8, max(-8, value)) }
  }

  func state() -> [String: Any] {
    withStateLock {
      let positionMs = sampleRate > 0 ? sourceFrame * 1000 / sampleRate : 0
      let durationMs = sampleRate > 0
        ? Double(sourceFrameCount) * 1000 / sampleRate
        : 0
      return [
        "positionMs": max(0, positionMs),
        "durationMs": max(0, durationMs),
        "rate": playbackRate,
        "playing": playing,
        "ready": sourceFrameCount > 1,
      ]
    }
  }

  func stop() {
    withStateLock { playing = false }
    if engineStarted || audioEngine.isRunning {
      audioEngine.pause()
    }
    engineStarted = false
  }

  private func install(_ decoded: DecodedAudio) throws {
    if audioEngine.isRunning { audioEngine.stop() }
    engineStarted = false
    if let sourceNode { audioEngine.detach(sourceNode) }

    samples = decoded.samples
    sampleRate = decoded.sampleRate
    channelCount = decoded.channelCount
    sourceFrameCount = decoded.frameCount
    withStateLock {
      sourceFrame = 0
      playbackRate = 1
      currentRate = 1
      playing = false
    }

    guard let format = AVAudioFormat(
      standardFormatWithSampleRate: sampleRate,
      channels: AVAudioChannelCount(channelCount)
    ) else {
      throw error(code: 3, message: "Unable to create PCM format")
    }
    let node = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, buffers in
      guard let self else { return noErr }
      self.render(frameCount: Int(frameCount), audioBufferList: buffers)
      return noErr
    }
    sourceNode = node
    audioEngine.attach(node)
    audioEngine.connect(node, to: audioEngine.mainMixerNode, format: format)
    try configureAudioSession()
    audioEngine.prepare()
  }

  private func render(
    frameCount requestedFrames: Int,
    audioBufferList: UnsafeMutablePointer<AudioBufferList>
  ) {
    let snapshot: RenderSnapshot = withStateLock {
      RenderSnapshot(
        playing: playing,
        rate: playbackRate,
        currentRate: currentRate,
        sourceFrame: sourceFrame,
        frameCount: sourceFrameCount
      )
    }
    let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
    for buffer in buffers {
      guard let data = buffer.mData else { continue }
      let output = data.assumingMemoryBound(to: Float.self)
      for outputFrame in 0..<requestedFrames { output[outputFrame] = 0 }
    }
    guard snapshot.playing, snapshot.frameCount > 1 else { return }
    var frame = snapshot.sourceFrame
    var renderedRate = snapshot.currentRate
    let smoothing = 1 - exp(-1 / (sampleRate * 0.003))
    for outputFrame in 0..<requestedFrames {
      renderedRate += (snapshot.rate - renderedRate) * smoothing
      if abs(renderedRate) < 0.0001 { continue }
      frame = min(Double(snapshot.frameCount - 1), max(0, frame))
      if (frame <= 0 && renderedRate < 0)
          || (frame >= Double(snapshot.frameCount - 1) && renderedRate > 0) {
        continue
      }
      let firstFrame = min(Int(frame.rounded(.down)), snapshot.frameCount - 2)
      let nextFrame = firstFrame + 1
      let fraction = Float(frame - Double(firstFrame))
      for (channel, buffer) in buffers.enumerated() {
        guard let data = buffer.mData else { continue }
        let output = data.assumingMemoryBound(to: Float.self)
        let source = samples[min(channel, samples.count - 1)]
        output[outputFrame] = source[firstFrame]
          + (source[nextFrame] - source[firstFrame]) * fraction
      }
      frame += renderedRate
    }
    withStateLock {
      sourceFrame = clampFrame(frame)
      currentRate = renderedRate
    }
  }

  private func decode(url: URL) throws -> DecodedAudio {
    let file = try AVAudioFile(forReading: url)
    let format = file.processingFormat
    guard format.channelCount > 0, format.channelCount <= 2 else {
      throw error(code: 4, message: "Only mono and stereo audio are supported")
    }
    guard let buffer = AVAudioPCMBuffer(
      pcmFormat: format,
      frameCapacity: AVAudioFrameCount(file.length)
    ) else {
      throw error(code: 5, message: "Unable to allocate PCM buffer")
    }
    try file.read(into: buffer)
    guard let floatData = buffer.floatChannelData else {
      throw error(code: 6, message: "Decoder did not return Float32 PCM")
    }
    let frameCount = Int(buffer.frameLength)
    guard frameCount > 1 else {
      throw error(code: 7, message: "Decoded audio is empty")
    }
    let decodedSamples = (0..<Int(format.channelCount)).map { channel in
      Array(UnsafeBufferPointer(start: floatData[channel], count: frameCount))
    }
    return DecodedAudio(
      samples: decodedSamples,
      sampleRate: format.sampleRate,
      channelCount: Int(format.channelCount),
      frameCount: frameCount
    )
  }

  private func configureAudioSession() throws {
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.playback, mode: .default, options: [])
    try session.setActive(true)
  }

  private func resolveSource(
    source: String,
    headers: [String: String],
    completion: @escaping (URL?, Error?) -> Void
  ) {
    let parsedURL = URL(string: source)
    let localURL = parsedURL?.isFileURL == true
      ? parsedURL!
      : URL(fileURLWithPath: source)
    if FileManager.default.fileExists(atPath: localURL.path) {
      completion(localURL, nil)
      return
    }
    guard let remoteURL = parsedURL,
          let scheme = remoteURL.scheme?.lowercased(),
          scheme == "http" || scheme == "https" else {
      completion(nil, error(code: 8, message: "Unsupported audio source"))
      return
    }
    var request = URLRequest(url: remoteURL)
    headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
    URLSession.shared.downloadTask(with: request) { [weak self] temporaryURL, _, requestError in
      guard let self else { return }
      if let requestError {
        completion(nil, requestError)
        return
      }
      guard let temporaryURL else {
        completion(nil, self.error(code: 9, message: "Audio download returned no file"))
        return
      }
      let destination = FileManager.default.temporaryDirectory
        .appendingPathComponent("omm-scratch-\(UUID().uuidString)")
      do {
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        self.downloadedURL = destination
        completion(destination, nil)
      } catch {
        completion(nil, error)
      }
    }.resume()
  }

  private func clampFrame(_ value: Double) -> Double {
    guard sourceFrameCount > 1 else { return 0 }
    return min(Double(sourceFrameCount - 1), max(0, value))
  }

  private func withStateLock<T>(_ body: () -> T) -> T {
    os_unfair_lock_lock(&stateLock)
    defer { os_unfair_lock_unlock(&stateLock) }
    return body()
  }

  private func error(code: Int, message: String) -> NSError {
    NSError(
      domain: "OmmScratchAudio",
      code: code,
      userInfo: [NSLocalizedDescriptionKey: message]
    )
  }

  private struct DecodedAudio {
    let samples: [[Float]]
    let sampleRate: Double
    let channelCount: Int
    let frameCount: Int
  }

  private struct RenderSnapshot {
    let playing: Bool
    let rate: Double
    let currentRate: Double
    let sourceFrame: Double
    let frameCount: Int
  }
}
