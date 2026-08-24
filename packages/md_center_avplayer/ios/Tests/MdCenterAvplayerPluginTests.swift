import AVFoundation
import Flutter
import XCTest
@testable import md_center_avplayer

final class MdCenterAvplayerPluginTests: XCTestCase {
  func testTimeConversionClampsInvalidValues() {
    XCTAssertEqual(AvPlayerTime.milliseconds(.invalid), 0)
    XCTAssertEqual(AvPlayerTime.time(milliseconds: -20).seconds, 0)
    XCTAssertEqual(
      AvPlayerTime.milliseconds(AvPlayerTime.time(milliseconds: 12_345)),
      12_345,
      accuracy: 1
    )
  }

  func testSessionCommandsAndRepeatedDisposeAreSafe() {
    let sink = RecordingEventSink()
    let eventExpectation = expectation(description: "KVO event forwarded")
    sink.onFirstEvent = { eventExpectation.fulfill() }
    let session = AvPlayerSession(playerId: 7, flutterApi: sink)

    session.setRate(1.5)
    session.play()
    session.pause()
    session.cancelFramePreview()
    session.stopPictureInPicture()
    wait(for: [eventExpectation], timeout: 1)

    session.dispose()
    session.dispose()
  }

  func testPlaybackStatePreservesPlayIntentWhileBuffering() {
    let waiting = AvPlayerSession.playbackState(
      for: .waitingToPlayAtSpecifiedRate,
      wantsToPlay: true
    )
    XCTAssertTrue(waiting.playing)
    XCTAssertTrue(waiting.buffering)

    let paused = AvPlayerSession.playbackState(for: .paused, wantsToPlay: false)
    XCTAssertFalse(paused.playing)
    XCTAssertFalse(paused.buffering)
  }

  func testOnlyInitialAutoplayWithoutResumeStartsImmediately() {
    XCTAssertTrue(
      AvPlayerSession.shouldStartImmediatelyOnOpen(
        autoplay: true,
        startPositionMs: 0
      )
    )
    XCTAssertFalse(
      AvPlayerSession.shouldStartImmediatelyOnOpen(
        autoplay: false,
        startPositionMs: 0
      )
    )
    XCTAssertFalse(
      AvPlayerSession.shouldStartImmediatelyOnOpen(
        autoplay: true,
        startPositionMs: 12_000
      )
    )
    XCTAssertEqual(AvPlayerSession.initialSeekTolerance, 0.5)
  }

  func testBufferedProgressUsesRangeContinuousFromCurrentPosition() {
    let ranges = [
      CMTimeRange(
        start: CMTime(seconds: 0, preferredTimescale: 600),
        duration: CMTime(seconds: 60, preferredTimescale: 600)
      ),
      CMTimeRange(
        start: CMTime(seconds: 120, preferredTimescale: 600),
        duration: CMTime(seconds: 20, preferredTimescale: 600)
      ),
    ]

    XCTAssertEqual(
      AvPlayerSession.continuousBufferedEnd(
        ranges: ranges,
        position: CMTime(seconds: 130, preferredTimescale: 600)
      ),
      140,
      accuracy: 0.001
    )
    XCTAssertEqual(
      AvPlayerSession.continuousBufferedEnd(
        ranges: ranges,
        position: CMTime(seconds: 80, preferredTimescale: 600)
      ),
      0,
      accuracy: 0.001
    )
  }

  func testSessionConfiguresForwardBufferAndForwardsStall() throws {
    let sink = RecordingEventSink()
    let player = AVPlayer()
    let session = AvPlayerSession(playerId: 8, flutterApi: sink, player: player)

    XCTAssertTrue(player.automaticallyWaitsToMinimizeStalling)
    session.setRate(1.5)
    XCTAssertEqual(player.defaultRate, 1.5)

    session.open(
      url: "file:///tmp/md-center-missing-video.mp4",
      startPositionMs: nil,
      autoplay: false
    ) { _ in }
    let item = try XCTUnwrap(player.currentItem)
    XCTAssertEqual(AvPlayerSession.preferredForwardBufferDuration, 60)
    XCTAssertEqual(item.preferredForwardBufferDuration, 0)

    session.play()
    NotificationCenter.default.post(name: .AVPlayerItemPlaybackStalled, object: item)
    XCTAssertEqual(
      sink.events.last(where: { $0.type == .playing })?.boolValue,
      true
    )
    XCTAssertEqual(
      sink.events.last(where: { $0.type == .buffering })?.boolValue,
      true
    )

    session.pause()
    session.dispose()
  }

  func testPlaybackFailureIsForwardedOnlyOnce() throws {
    let sink = RecordingEventSink()
    let player = AVPlayer()
    let session = AvPlayerSession(playerId: 9, flutterApi: sink, player: player)
    session.open(
      url: "file:///tmp/md-center-missing-video.mp4",
      startPositionMs: nil,
      autoplay: false
    ) { _ in }
    let item = try XCTUnwrap(player.currentItem)
    let error = NSError(domain: "MdCenterAvPlayerTests", code: 1)

    for _ in 0..<2 {
      NotificationCenter.default.post(
        name: .AVPlayerItemFailedToPlayToEndTime,
        object: item,
        userInfo: [AVPlayerItemFailedToPlayToEndTimeErrorKey: error]
      )
    }

    XCTAssertEqual(sink.events.filter { $0.type == .error }.count, 1)
    session.dispose()
  }
}

private final class RecordingEventSink: MdCenterAvPlayerFlutterApiProtocol {
  var events: [AvPlayerEvent] = []
  var onFirstEvent: (() -> Void)?

  func onEvent(
    event: AvPlayerEvent,
    completion: @escaping (Result<Void, PigeonError>) -> Void
  ) {
    events.append(event)
    if events.count == 1 { onFirstEvent?() }
    completion(.success(()))
  }
}
