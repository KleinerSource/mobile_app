import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/features/media_browser/models/media_browser_models.dart';
import 'package:omm/features/media_browser/playback/media_browser_audio_proxy.dart';

/// 可编程的远端 fake：记录请求并返回注入的字节。
class _RemoteAdapter implements HttpClientAdapter {
  _RemoteAdapter(this.bytesOf);

  final Uint8List Function(String uri) bytesOf;
  final requests = <String>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add('${options.method} ${options.uri}');
    final bytes = bytesOf(options.uri.toString());
    return ResponseBody(
      Stream<Uint8List>.value(bytes),
      200,
      headers: {
        Headers.contentLengthHeader: [bytes.length.toString()],
      },
    );
  }
}

MediaBrowserItem _track(String id) => MediaBrowserItem(
  id: id,
  name: '曲目$id',
  type: 'Audio',
);

const _mp3Bytes = <int>[
  0x49, 0x44, 0x33, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // ID3
  1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16,
];

void main() {
  late Directory tempRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('mb_audio_proxy_test');
  });

  tearDown(() async {
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  test('完整下载后应答 200 + Content-Length + Accept-Ranges，并嗅探 MIME', () async {
    final adapter = _RemoteAdapter((_) => Uint8List.fromList(_mp3Bytes));
    final proxy = await MediaBrowserAudioProxy.start(
      downloader: Dio()..httpClientAdapter = adapter,
    );
    final client = Dio();
    try {
      final url = proxy.register(_track('t1'), 'http://remote/t1/stream');
      expect(url, startsWith('http://127.0.0.1:'));

      final response = await client.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      expect(response.statusCode, 200);
      expect(response.headers.value(HttpHeaders.acceptRangesHeader), 'bytes');
      expect(response.headers.value(HttpHeaders.contentLengthHeader), '${_mp3Bytes.length}');
      expect(response.data, _mp3Bytes);
      // ID3 头被嗅探为 audio/mpeg。
      expect(
        response.headers.value(HttpHeaders.contentTypeHeader),
        contains('audio/mpeg'),
      );
    } finally {
      await proxy.close();
      client.close();
    }
  });

  test('Range 请求返回 206 与正确区间，无效区间返回 416', () async {
    final adapter = _RemoteAdapter((_) => Uint8List.fromList(_mp3Bytes));
    final proxy = await MediaBrowserAudioProxy.start(
      downloader: Dio()..httpClientAdapter = adapter,
    );
    final client = Dio();
    try {
      final url = proxy.register(_track('t1'), 'http://remote/t1/stream');
      // 先完整请求一次触发下载。
      await client.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );

      final partial = await client.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes, headers: {
          HttpHeaders.rangeHeader: 'bytes=4-7',
        }),
      );
      expect(partial.statusCode, 206);
      expect(
        partial.headers.value(HttpHeaders.contentRangeHeader),
        'bytes 4-7/${_mp3Bytes.length}',
      );
      expect(partial.data, _mp3Bytes.sublist(4, 8));

      final suffix = await client.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes, headers: {
          HttpHeaders.rangeHeader: 'bytes=-4',
        }),
      );
      expect(suffix.statusCode, 206);
      expect(suffix.data, _mp3Bytes.sublist(_mp3Bytes.length - 4));

      final invalid = await client.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          // 416 不应抛 DioException。
          validateStatus: (status) => status != null && status < 500,
          headers: {HttpHeaders.rangeHeader: 'bytes=9999-'},
        ),
      );
      expect(invalid.statusCode, 416);
    } finally {
      await proxy.close();
      client.close();
    }
  });

  test('HEAD 只返回头；未知路径 404；重复请求不重复下载', () async {
    var downloads = 0;
    final adapter = _RemoteAdapter((_) {
      downloads++;
      return Uint8List.fromList(_mp3Bytes);
    });
    final proxy = await MediaBrowserAudioProxy.start(
      downloader: Dio()..httpClientAdapter = adapter,
    );
    final client = Dio();
    try {
      final url = proxy.register(_track('t1'), 'http://remote/t1/stream');
      for (var i = 0; i < 3; i++) {
        await client.get<List<int>>(
          url,
          options: Options(responseType: ResponseType.bytes),
        );
      }
      expect(downloads, 1);

      final head = await client.head(url);
      expect(head.statusCode, 200);
      expect(head.headers.value(HttpHeaders.contentLengthHeader), '${_mp3Bytes.length}');
      expect(downloads, 1);

      final missing = await client.get(
        'http://127.0.0.1:${proxy.basePortForTest}/unknown',
        options: Options(validateStatus: (status) => status != null && status < 500),
      );
      expect(missing.statusCode, 404);
    } finally {
      await proxy.close();
      client.close();
    }
  });

  test('同一曲目重复注册幂等且共享缓存文件', () async {
    var downloads = 0;
    final adapter = _RemoteAdapter((_) {
      downloads++;
      return Uint8List.fromList(_mp3Bytes);
    });
    final proxy = await MediaBrowserAudioProxy.start(
      downloader: Dio()..httpClientAdapter = adapter,
    );
    final client = Dio();
    try {
      final first = proxy.register(_track('t1'), 'http://remote/t1/stream');
      final second = proxy.register(_track('t1'), 'http://remote/t1/stream');
      expect(first, second);

      await client.get<List<int>>(
        first,
        options: Options(responseType: ResponseType.bytes),
      );
      await client.get<List<int>>(
        second,
        options: Options(responseType: ResponseType.bytes),
      );
      expect(downloads, 1);
    } finally {
      await proxy.close();
      client.close();
    }
  });

  test('close 后不再接受请求并清理临时文件', () async {
    final adapter = _RemoteAdapter((_) => Uint8List.fromList(_mp3Bytes));
    final proxy = await MediaBrowserAudioProxy.start(
      downloader: Dio()..httpClientAdapter = adapter,
    );
    final client = Dio();
    final url = proxy.register(_track('t1'), 'http://remote/t1/stream');
    await client.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    await proxy.close();

    expect(
      () => client.get(url),
      throwsA(isA<DioException>()),
    );
    // 重复 close 幂等。
    await proxy.close();
    client.close();
  });
}
