import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:omm/core/platform/app_version.dart';
import 'package:omm/features/cache/image_cache_manager.dart';

class _RecordingFileService extends FileService {
  Map<String, String>? requestHeaders;

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    requestHeaders = headers;
    return _FakeFileServiceResponse();
  }
}

class _FakeFileServiceResponse implements FileServiceResponse {
  @override
  Stream<List<int>> get content => Stream.value(const <int>[0xFF, 0xD8]);

  @override
  int? get contentLength => 2;

  @override
  String? get eTag => null;

  @override
  String get fileExtension => '.jpg';

  @override
  int get statusCode => 200;

  @override
  DateTime get validTill => DateTime.now().add(const Duration(days: 1));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('图片文件服务覆盖 UA 并保留鉴权头', () async {
    PackageInfo.setMockInitialValues(
      appName: 'Oh My Media',
      packageName: 'com.ohmymedia.omm',
      version: '0.92.10',
      buildNumber: '745',
      buildSignature: '',
    );
    resetAppVersionCache();

    final delegate = _RecordingFileService();
    final service = AppImageFileService(delegate: delegate);
    await service.get(
      'https://example.test/cover.jpg',
      headers: const {
        'Authorization': 'Bearer token',
        'uSeR-aGeNt': 'legacy-image/1.0',
      },
    );

    expect(delegate.requestHeaders, {
      'Authorization': 'Bearer token',
      'User-Agent': 'omm/0.92.10',
    });
  });
}
