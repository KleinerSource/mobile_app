import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

final class OmmScratchAudio {
  OmmScratchAudio._();

  static const MethodChannel _channel = MethodChannel('omm/scratch_audio');
  static double? _pendingRate;
  static Future<void>? _rateDrain;

  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<ScratchAudioState> prepare({
    required String source,
    Map<String, String>? headers,
  }) async {
    final result = await _channel.invokeMethod<Object?>('prepare', {
      'source': source,
      'headers': headers ?? const <String, String>{},
    });
    return ScratchAudioState.fromObject(result);
  }

  static Future<void> start({
    required Duration position,
    bool autoplay = true,
  }) async {
    await _channel.invokeMethod<void>('start', {
      'positionMs': position.inMilliseconds,
      'autoplay': autoplay,
    });
  }

  static Future<void> play() => _channel.invokeMethod<void>('play');

  static Future<void> pause() => _channel.invokeMethod<void>('pause');

  static Future<void> seek(Duration position) => _channel.invokeMethod<void>(
    'seek',
    {'positionMs': position.inMilliseconds},
  );

  static Future<void> setRate(double rate) async {
    if (!rate.isFinite) return;
    _pendingRate = rate;
    final activeDrain = _rateDrain;
    if (activeDrain != null) {
      await activeDrain;
      return;
    }

    late final Future<void> drain;
    drain = _drainRates();
    _rateDrain = drain;
    try {
      await drain;
    } finally {
      if (identical(_rateDrain, drain)) _rateDrain = null;
    }
  }

  static Future<void> _drainRates() async {
    while (_pendingRate != null) {
      final rate = _pendingRate!;
      _pendingRate = null;
      await _channel.invokeMethod<void>('setRate', {'rate': rate});
    }
  }

  static Future<ScratchAudioState> state() async {
    final result = await _channel.invokeMethod<Object?>('state');
    return ScratchAudioState.fromObject(result);
  }

  static Future<void> stop() => _channel.invokeMethod<void>('stop');
}

final class ScratchAudioState {
  const ScratchAudioState({
    required this.position,
    required this.duration,
    required this.rate,
    required this.playing,
    required this.ready,
    required this.outputReady,
    required this.lastWriteResult,
  });

  final Duration position;
  final Duration duration;
  final double rate;
  final bool playing;
  final bool ready;
  final bool outputReady;
  final int lastWriteResult;

  factory ScratchAudioState.fromObject(Object? raw) {
    final value = raw is Map ? raw : const <Object?, Object?>{};
    final positionMs = _number(value['positionMs']);
    final durationMs = _number(value['durationMs']);
    return ScratchAudioState(
      position: Duration(milliseconds: positionMs.round().clamp(0, 1 << 31)),
      duration: Duration(milliseconds: durationMs.round().clamp(0, 1 << 31)),
      rate: _number(value['rate'], fallback: 1),
      playing: value['playing'] == true,
      ready: value['ready'] == true,
      outputReady: value['outputReady'] == true,
      lastWriteResult: value['lastWriteResult'] is num
          ? (value['lastWriteResult'] as num).toInt()
          : 0,
    );
  }

  static double _number(Object? value, {double fallback = 0}) {
    final number = value is num ? value.toDouble() : fallback;
    return number.isFinite ? number : fallback;
  }
}
