import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/api/api_client.dart';
import 'package:omm/core/models/media_streams.dart';
import 'package:omm/core/models/movie.dart';
import 'package:omm/core/sources/media/omm_media_source_adapter.dart';
import 'package:omm/features/oh_my_media/movies/media_repository.dart';
import 'package:omm/features/oh_my_media/movies/movie_data_changes.dart';

void main() {
  for (final refreshed in [true, false, null]) {
    test('媒体信息响应 refreshed=$refreshed 仅在重新探测后标记信息变化', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.path, '/movies/id/7/media-info');
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                data: {
                  'success': true,
                  'data': {
                    if (refreshed != null) 'refreshed': refreshed,
                    'resolution_tier': '4k',
                    'video_width': 3840,
                    'video_height': 2160,
                    'bit_rate': 8000000,
                  },
                },
              ),
            );
          },
        ),
      );
      final source = OmmMediaSourceAdapter(ApiClient(dio));
      final repo = MediaRepository(
        catalog: source,
        details: source,
        operations: source.operations,
      );
      final before = MovieDataChanges.snapshot(movieId: 7);
      final other = MovieDataChanges.snapshot(movieId: 8);
      final info = await repo.mediaInfoDetail(7);
      expect(info!.resolutionTier, ResolutionTier.uhd);
      expect(info.bitRate, 8000000);
      expect(
        before.latest.metadata,
        before.metadata + (refreshed == true ? 1 : 0),
      );
      expect(before.latest.images, before.images);
      expect(before.latest.progress, before.progress);
      expect(other.latest.changedSince(other), isFalse);
    });
  }

  test('媒体信息缺省刷新标记兼容旧接口', () {
    expect(MediaInfoDetail.fromJson({}).refreshed, isFalse);
  });

  for (final status in [404, 500]) {
    test('媒体信息请求失败 $status 不发出列表或封面变更', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response<dynamic>(
                  requestOptions: options,
                  statusCode: status,
                ),
                type: DioExceptionType.badResponse,
              ),
            );
          },
        ),
      );
      final source = OmmMediaSourceAdapter(ApiClient(dio));
      final repo = MediaRepository(
        catalog: source,
        details: source,
        operations: source.operations,
      );
      final before = MovieDataChanges.snapshot(movieId: 7);
      if (status == 404) {
        expect(await repo.mediaInfoDetail(7), isNull);
      } else {
        await expectLater(repo.mediaInfoDetail(7), throwsException);
      }
      expect(before.latest.changedSince(before), isFalse);
    });
  }
}
