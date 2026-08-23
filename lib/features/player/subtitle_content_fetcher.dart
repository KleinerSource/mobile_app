import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/dio_factory.dart';

/// 下载字幕内容并做基本校验，失败时抛出带可读文案的 [ApiException]。
///
/// 字幕由客户端下载而非交给 mpv 直接请求：接口返回 404/超时等失败只会
/// 在这一层抛异常（上层转 SnackBar 提示），不会影响正在进行的播放。
Future<String> fetchSubtitleContent(Dio dio, String url) async {
  final Response<String> response;
  try {
    response = await dio.get<String>(
      url,
      options: Options(
        responseType: ResponseType.plain,
        // 内嵌字幕转换端点最长可跑 30 秒。
        receiveTimeout: const Duration(seconds: 60),
      ),
    );
  } on DioException catch (error) {
    throw subtitleFetchError(error);
  }
  final content = (response.data ?? '').trim();
  // 后端两个字幕端点都输出 WebVTT；没有时间轴行说明内容不可用。
  if (!content.contains('-->')) {
    throw StateError('字幕内容无效或为空');
  }
  return content;
}

/// 以纯文本模式请求时错误响应体不会自动解码成 JSON envelope，
/// 这里手动提取后端 message，让提示保持“字幕不存在”这类可读文案。
ApiException subtitleFetchError(DioException error) {
  final data = error.response?.data;
  if (data is String) {
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map && decoded['message'] is String) {
        return ApiException(
          decoded['message'] as String,
          status: error.response?.statusCode,
        );
      }
    } catch (_) {}
  }
  return toApiException(error);
}
