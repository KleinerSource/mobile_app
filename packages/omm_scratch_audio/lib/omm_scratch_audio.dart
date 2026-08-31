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
    required String sourceId,
    Map<String, String>? headers,
  }) async {
    final result = await _channel.invokeMethod<Object?>('prepare', {
      'source': source,
      'sourceId': sourceId,
      'headers': headers ?? const <String, String>{},
    });
    return ScratchAudioState.fromObject(result);
  }

  static Future<void> start({
    required Duration position,
    required String sourceId,
    bool autoplay = true,
  }) async {
    await _channel.invokeMethod<void>('start', {
      'positionMs': position.inMilliseconds,
      'sourceId': sourceId,
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

  static Future<AudioSpectrumFrame> spectrum({
    required Duration position,
    int bandCount = AudioSpectrumFrame.defaultBandCount,
  }) async {
    final safeBandCount = bandCount.clamp(8, 96);
    final result = await _channel.invokeMethod<Object?>('spectrum', {
      'positionMs': position.inMilliseconds,
      'bandCount': safeBandCount,
    });
    return AudioSpectrumFrame.fromObject(result, bandCount: safeBandCount);
  }

  static Future<void> stop() => _channel.invokeMethod<void>('stop');
}

final class AudioSpectrumFrame {
  const AudioSpectrumFrame({
    required this.rms,
    required this.peak,
    required this.bands,
    required this.ready,
    required this.sourceId,
  });

  static const int defaultBandCount = 48;

  final double rms;
  final double peak;
  final List<double> bands;
  final bool ready;
  final String sourceId;

  bool get isSilent =>
      !ready || (rms <= 0 && peak <= 0 && bands.every((value) => value <= 0));

  factory AudioSpectrumFrame.silence({
    int bandCount = defaultBandCount,
    String sourceId = '',
  }) {
    final safeBandCount = bandCount.clamp(8, 96);
    return AudioSpectrumFrame(
      rms: 0,
      peak: 0,
      bands: List<double>.unmodifiable(List<double>.filled(safeBandCount, 0)),
      ready: false,
      sourceId: sourceId,
    );
  }

  factory AudioSpectrumFrame.fromObject(
    Object? raw, {
    int bandCount = defaultBandCount,
  }) {
    final safeBandCount = bandCount.clamp(8, 96);
    final value = raw is Map ? raw : const <Object?, Object?>{};
    final rawBands = value['bands'] is List
        ? value['bands'] as List
        : const <Object?>[];
    final bands = List<double>.generate(safeBandCount, (index) {
      if (index >= rawBands.length) return 0;
      return _normalized(rawBands[index]);
    }, growable: false);
    return AudioSpectrumFrame(
      rms: _normalized(value['rms']),
      peak: _normalized(value['peak']),
      bands: List<double>.unmodifiable(bands),
      ready: value['ready'] == true,
      sourceId: value['sourceId']?.toString() ?? '',
    );
  }

  static double _normalized(Object? value) {
    final number = value is num ? value.toDouble() : 0.0;
    if (!number.isFinite) return 0;
    return number.clamp(0.0, 1.0).toDouble();
  }
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
    required this.sourceId,
  });

  final Duration position;
  final Duration duration;
  final double rate;
  final bool playing;
  final bool ready;
  final bool outputReady;
  final int lastWriteResult;
  final String sourceId;

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
      sourceId: value['sourceId']?.toString() ?? '',
    );
  }

  static double _number(Object? value, {double fallback = 0}) {
    final number = value is num ? value.toDouble() : fallback;
    return number.isFinite ? number : fallback;
  }
}
