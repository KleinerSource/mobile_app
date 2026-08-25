import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../models/playback.dart';
import '../envelope.dart';

class PlaybackApi {
  PlaybackApi(this._dio);

  final Dio _dio;

  Future<PlaybackDecision> decision(
    int movieId,
    PlaybackClientCaps caps,
  ) async {
    final response = await _dio.post<dynamic>(
      '/movies/id/$movieId/playback-decision',
      data: caps.toJson(),
    );
    return unwrapStd<PlaybackDecision>(
      response.data,
      (data) =>
          PlaybackDecision.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }

  Future<String> streamUrl(int movieId) async {
    final response = await _dio.get<dynamic>('/movies/id/$movieId/stream-url');
    return unwrapStd<String>(response.data, (data) {
      if (data is Map) return data['url']?.toString() ?? '';
      return data?.toString() ?? '';
    });
  }

  Future<TranscodeStatus> status(
    int movieId, {
    String quality = 'auto',
    String? mode,
    int? audioStreamIndex,
    String? subtitleTrackId,
  }) async {
    final response = await _dio.get<dynamic>(
      '/movies/id/$movieId/transcode-status',
      queryParameters: _transcodeSessionQuery(
        quality: quality,
        mode: mode,
        audioStreamIndex: audioStreamIndex,
        subtitleTrackId: subtitleTrackId,
      ),
    );
    return unwrapStd<TranscodeStatus>(
      response.data,
      (data) =>
          TranscodeStatus.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }

  Future<void> stop(int movieId) async {
    final response = await _dio.delete<dynamic>(
      '/movies/id/$movieId/transcode-session',
    );
    unwrapStd<void>(response.data, (_) {});
  }

  Stream<TranscodeStatus> events(
    int movieId, {
    String quality = 'auto',
    String? mode,
    int? audioStreamIndex,
    String? subtitleTrackId,
  }) async* {
    final response = await _dio.get<ResponseBody>(
      '/movies/id/$movieId/transcode-events',
      queryParameters: _transcodeSessionQuery(
        quality: quality,
        mode: mode,
        audioStreamIndex: audioStreamIndex,
        subtitleTrackId: subtitleTrackId,
      ),
      options: Options(responseType: ResponseType.stream),
    );
    final body = response.data;
    if (body == null) return;

    String? eventName;
    final dataLines = <String>[];
    await for (final line
        in utf8.decoder.bind(body.stream).transform(const LineSplitter())) {
      if (line.startsWith('event:')) {
        eventName = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        dataLines.add(line.substring(5).trimLeft());
      } else if (line.isEmpty) {
        final payload = dataLines.join('\n');
        if (payload.isNotEmpty &&
            (eventName == null || eventName == 'status')) {
          final decoded = jsonDecode(payload);
          if (decoded is Map) {
            yield TranscodeStatus.fromJson(Map<String, dynamic>.from(decoded));
          }
        }
        eventName = null;
        dataLines.clear();
      }
    }
  }
}

Map<String, dynamic> _transcodeSessionQuery({
  required String quality,
  String? mode,
  int? audioStreamIndex,
  String? subtitleTrackId,
}) => {
  'quality': quality,
  if (mode?.trim().isNotEmpty == true) 'mode': mode!.trim(),
  if (audioStreamIndex != null) 'audio_stream_index': audioStreamIndex,
  if (subtitleTrackId?.trim().isNotEmpty == true)
    'subtitle_track_id': subtitleTrackId!.trim(),
};
