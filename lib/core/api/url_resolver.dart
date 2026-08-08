import '../config/server_config.dart';

/// 把后端返回的相对地址解析为可交给播放器或外部应用的绝对地址。
String resolveServerUrl(ServerConfig config, String value) {
  final raw = value.trim();
  if (raw.isEmpty) return config.baseUrl;
  final parsed = Uri.tryParse(raw);
  if (parsed != null && parsed.hasScheme && parsed.host.isNotEmpty) {
    return raw;
  }

  final base = Uri.parse(config.baseUrl);
  final target = Uri.parse(raw.startsWith('/') ? raw : '/$raw');
  final basePath = base.path.replaceFirst(RegExp(r'/+$'), '');
  final targetPath = target.path.replaceFirst(RegExp(r'^/+'), '');
  final path = '$basePath/$targetPath'.replaceFirst(RegExp(r'^([^/])'), r'/$1');
  return base
      .replace(
        path: path,
        query: target.query,
        fragment: target.fragment,
      )
      .toString();
}

String resolveApiUrl(ServerConfig config, String value) {
  final path = value.startsWith('/') ? value : '/$value';
  return resolveServerUrl(
    config,
    path.startsWith('/api/') ? path : '/api$path',
  );
}

String appendQueryToken(String value, String? token) {
  final cleanToken = token?.trim() ?? '';
  if (cleanToken.isEmpty) return value;
  final uri = Uri.parse(value);
  final query = <String, List<String>>{
    for (final entry in uri.queryParametersAll.entries)
      entry.key: [...entry.value],
  };
  query['token'] = [cleanToken];
  return uri.replace(queryParameters: _flattenQuery(query)).toString();
}

/// 为同服务器地址追加临时 token；跨服务器地址视为外部媒体源并原样返回。
String resolveProtectedUrl(
  ServerConfig config,
  String value,
  String? token,
) {
  final parsed = Uri.tryParse(value.trim());
  if (parsed != null && parsed.hasScheme && parsed.host.isNotEmpty) {
    final base = Uri.tryParse(config.baseUrl);
    final sameServer = base != null &&
        parsed.scheme.toLowerCase() == base.scheme.toLowerCase() &&
        parsed.host.toLowerCase() == base.host.toLowerCase() &&
        _effectivePort(parsed) == _effectivePort(base);
    if (!sameServer) return value;
  }
  return appendQueryToken(resolveServerUrl(config, value), token);
}

int _effectivePort(Uri uri) {
  if (uri.port != 0) return uri.port;
  return switch (uri.scheme.toLowerCase()) {
    'https' || 'wss' => 443,
    _ => 80,
  };
}

Map<String, String> _flattenQuery(Map<String, List<String>> query) {
  final result = <String, String>{};
  for (final entry in query.entries) {
    if (entry.value.isNotEmpty) result[entry.key] = entry.value.last;
  }
  return result;
}
