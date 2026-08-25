import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/ks_player_api.g.dart',
    dartOptions: DartOptions(),
    swiftOut: 'ios/Classes/KsPlayerApi.g.swift',
    swiftOptions: SwiftOptions(),
    dartPackageName: 'md_center_ksplayer',
  ),
)
enum KsPlayerEventType {
  ready,
  playing,
  buffering,
  position,
  duration,
  size,
  completed,
  error,
  firstFrame,
  pictureInPicture,
}

class KsPlayerEvent {
  KsPlayerEvent({
    required this.playerId,
    required this.type,
    this.boolValue,
    this.numberValue,
    this.secondaryNumberValue,
    this.stringValue,
  });

  int playerId;
  KsPlayerEventType type;
  bool? boolValue;
  double? numberValue;
  double? secondaryNumberValue;
  String? stringValue;
}

class KsPlayerAudioTrack {
  KsPlayerAudioTrack({
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
abstract class MdCenterKsPlayerHostApi {
  void create(int playerId);

  @async
  void open(
    int playerId,
    String url,
    double? startPositionMs,
    bool autoplay,
    Map<String, String>? headers,
    String? formatHint,
  );

  void play(int playerId);
  void pause(int playerId);
  void stop(int playerId);

  @async
  void seek(int playerId, double positionMs);

  void setRate(int playerId, double rate);

  @async
  List<KsPlayerAudioTrack> audioTracks(int playerId);

  @async
  void selectAudioTrack(int playerId, String trackId);

  @async
  void selectSubtitleTrack(int playerId, String trackId, int? fallbackIndex);

  @async
  void clearSubtitleTrack(int playerId);

  @async
  Uint8List? captureFrame(int playerId, double positionMs);

  void cancelFramePreview(int playerId);

  @async
  bool startPictureInPicture(int playerId);

  void stopPictureInPicture(int playerId);
  void dispose(int playerId);
}

@FlutterApi()
abstract class MdCenterKsPlayerFlutterApi {
  void onEvent(KsPlayerEvent event);
}
