import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/av_player_api.g.dart',
    dartOptions: DartOptions(),
    swiftOut: 'ios/Classes/AvPlayerApi.g.swift',
    swiftOptions: SwiftOptions(),
    dartPackageName: 'md_center_avplayer',
  ),
)
enum AvPlayerEventType {
  ready,
  playing,
  buffering,
  position,
  duration,
  buffered,
  size,
  completed,
  error,
  firstFrame,
  pictureInPicture,
}

class AvPlayerEvent {
  AvPlayerEvent({
    required this.playerId,
    required this.type,
    this.boolValue,
    this.numberValue,
    this.secondaryNumberValue,
    this.stringValue,
  });

  int playerId;
  AvPlayerEventType type;
  bool? boolValue;
  double? numberValue;
  double? secondaryNumberValue;
  String? stringValue;
}

class AvPlayerAudioTrack {
  AvPlayerAudioTrack({
    required this.id,
    required this.title,
    required this.language,
    required this.selected,
  });

  String id;
  String title;
  String language;
  bool selected;
}

@HostApi()
abstract class MdCenterAvPlayerHostApi {
  void create(int playerId);

  @async
  void open(int playerId, String url, double? startPositionMs, bool autoplay);

  void play(int playerId);
  void pause(int playerId);

  @async
  void seek(int playerId, double positionMs);

  void setRate(int playerId, double rate);

  @async
  List<AvPlayerAudioTrack> audioTracks(int playerId);

  @async
  void selectAudioTrack(int playerId, String trackId);

  @async
  Uint8List? captureFrame(int playerId, double positionMs);

  void cancelFramePreview(int playerId);

  @async
  bool startPictureInPicture(int playerId);

  void stopPictureInPicture(int playerId);
  void dispose(int playerId);
}

@FlutterApi()
abstract class MdCenterAvPlayerFlutterApi {
  void onEvent(AvPlayerEvent event);
}
