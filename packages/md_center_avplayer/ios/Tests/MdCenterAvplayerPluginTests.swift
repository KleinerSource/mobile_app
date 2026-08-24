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
