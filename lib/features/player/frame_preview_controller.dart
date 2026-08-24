import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';

import 'player_session_controller.dart';

class FramePreviewController extends ChangeNotifier {
  FramePreviewController(
    this._session, {
    this.interval = const Duration(milliseconds: 250),
    this.cacheEntries = 12,
  });

  final PlayerSessionController _session;
  final Duration interval;
  final int cacheEntries;
  final LinkedHashMap<int, Uint8List> _cache = LinkedHashMap();

  String? _sourceUrl;
  Map<String, String>? _headers;
  Duration? _pending;
  DateTime? _lastCaptureAt;
  int _generation = 0;
  bool _running = false;
  bool _disposed = false;

  Uint8List? frame;
  Duration? position;
  bool unavailable = false;

  void configureSource(String? sourceUrl, Map<String, String>? headers) {
    if (_sourceUrl == sourceUrl && mapEquals(_headers, headers)) return;
    cancel(clearCache: true);
    _sourceUrl = sourceUrl;
    _headers = headers == null ? null : Map<String, String>.from(headers);
  }

  void request(Duration target) {
    if (_disposed || !_session.capabilities.framePreview) return;
    position = target;
    unavailable = false;
    final key = _cacheKey(target);
    final cached = _cache.remove(key);
    if (cached != null) {
      _cache[key] = cached;
      frame = cached;
      notifyListeners();
      return;
    }
    _pending = target;
    notifyListeners();
    if (!_running) unawaited(_run(_generation));
  }

  Future<void> _run(int generation) async {
    _running = true;
    try {
      while (!_disposed && generation == _generation) {
        var target = _pending;
        if (target == null) break;
        _pending = null;
        final last = _lastCaptureAt;
        if (last != null) {
          final remaining = interval - DateTime.now().difference(last);
          if (remaining > Duration.zero) await Future<void>.delayed(remaining);
          if (_disposed || generation != _generation) break;
          target = _pending ?? target;
          _pending = null;
        }
        final captured = await _session.captureFrame(
          target,
          sourceUrl: _sourceUrl,
          headers: _headers,
        );
        _lastCaptureAt = DateTime.now();
        if (_disposed || generation != _generation) break;
        if (captured == null || captured.isEmpty) {
          frame = null;
          unavailable = true;
          notifyListeners();
          break;
        }
        final key = _cacheKey(target);
        _cache[key] = captured;
        while (_cache.length > cacheEntries) {
          _cache.remove(_cache.keys.first);
        }
        frame = captured;
        unavailable = false;
        notifyListeners();
      }
    } catch (_) {
      if (!_disposed && generation == _generation) {
        frame = null;
        unavailable = true;
        notifyListeners();
      }
    } finally {
      _running = false;
      if (!_disposed && _pending != null) {
        unawaited(_run(_generation));
      }
    }
  }

  int _cacheKey(Duration value) => value.inMilliseconds ~/ 1000;

  void cancel({bool clearCache = false}) {
    _generation++;
    _pending = null;
    _lastCaptureAt = null;
    frame = null;
    position = null;
    unavailable = false;
    if (clearCache) _cache.clear();
    if (!_disposed) notifyListeners();
    unawaited(_session.clearFramePreview());
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _pending = null;
    _cache.clear();
    unawaited(_session.clearFramePreview());
    super.dispose();
  }
}
