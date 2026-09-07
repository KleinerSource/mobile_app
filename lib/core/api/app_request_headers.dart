import 'package:dio/dio.dart';

import '../platform/app_version.dart';

final Expando<bool> _appUserAgentInterceptorInstalled = Expando<bool>();
const _appUserAgentHeader = 'User-Agent';

/// 为普通请求头强制写入唯一的应用 User-Agent。
///
/// 所有非 User-Agent 请求头都会保留；已有 UA 不区分大小写删除，避免
/// Dart、播放器或服务端下发的值与应用 UA 同时发送。
Future<Map<String, String>> mergeAppRequestHeaders(
  Map<String, String>? headers,
) async {
  final merged = <String, String>{};
  for (final entry in (headers ?? const <String, String>{}).entries) {
    if (entry.key.toLowerCase() == _appUserAgentHeader.toLowerCase()) {
      continue;
    }
    merged[entry.key] = entry.value;
  }
  merged[_appUserAgentHeader] = await appUserAgent();
  return merged;
}

/// 为 Dio 安装幂等的应用 User-Agent 拦截器。
///
/// 该拦截器放在调用方已有拦截器之后，确保请求真正发出前应用 UA 覆盖
/// 所有已有大小写变体。通过 [Expando] 标记，重复配置同一个 Dio 不会
/// 添加重复拦截器。
void installAppUserAgentInterceptor(Dio dio) {
  if (_appUserAgentInterceptorInstalled[dio] == true) return;
  _appUserAgentInterceptorInstalled[dio] = true;
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final keys = options.headers.keys
            .where(
              (key) => key.toLowerCase() == _appUserAgentHeader.toLowerCase(),
            )
            .toList(growable: false);
        for (final key in keys) {
          options.headers.remove(key);
        }
        options.headers[_appUserAgentHeader] = await appUserAgent();
        handler.next(options);
      },
    ),
  );
}
