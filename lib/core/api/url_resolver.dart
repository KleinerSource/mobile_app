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
  final basePath = base.path.endsWith('/') ? base.path : '${base.path}/';
  final relative = raw.startsWith('/') ? raw.substring(1) : raw;
  final baseWithPath = base.replace(
    path: basePath,
    query: null,
    fragment: null,
  );
  return baseWithPath.resolveUri(Uri.parse(relative)).toString();
}

String resolveApiUrl(ServerConfig config, String value) {
  final raw = value.trim();
  final path = raw.startsWith('/') ? raw : '/$raw';
  final hasApiPrefix = path == '/api' || path.startsWith('/api/');
  return resolveServerUrl(config, hasApiPrefix ? path : '/api$path');
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

/// 判断地址是否属于外部媒体源。
///
/// 相对地址和当前服务器的绝对地址需要继续携带服务器鉴权；
/// .strm 解析出的跨域地址交给外部媒体服务器处理，不能透传服务器令牌。
bool isExternalUrl(ServerConfig config, String value) {
  final parsed = Uri.tryParse(value.trim());
  if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) {
    return false;
  }
  final base = Uri.tryParse(config.baseUrl);
  if (base == null) return true;
  return parsed.scheme.toLowerCase() != base.scheme.toLowerCase() ||
      parsed.host.toLowerCase() != base.host.toLowerCase() ||
      _effectivePort(parsed) != _effectivePort(base);
}

/// 为同服务器地址追加临时 token；跨服务器地址视为外部媒体源并原样返回。
String resolveProtectedUrl(ServerConfig config, String value, String? token) {
  if (isExternalUrl(config, value)) return value;
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
