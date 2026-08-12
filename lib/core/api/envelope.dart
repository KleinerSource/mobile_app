import '../models/paged_result.dart';
import 'api_exception.dart';

T unwrapStd<T>(Object? raw, T Function(Object?) decode) {
  if (raw is! Map) {
    throw ApiException('响应格式异常');
  }
  if (raw['success'] != true) {
    throw ApiException(
      (raw['message'] as String?) ?? '操作失败',
      data: raw['data'],
    );
  }
  return decode(raw['data']);
}

PagedResult<T> unwrapMovieList<T>(
  Object? raw,
  T Function(Map<String, dynamic>) decodeItem,
) {
  if (raw is! Map) {
    throw ApiException('响应格式异常');
  }
  if (raw['success'] != true) {
    throw ApiException(
      (raw['message'] as String?) ?? '操作失败',
      data: raw['data'],
    );
  }
  final data = raw['data'];
  if (data is! Map) {
    throw ApiException('列表响应缺少 data');
  }
  final itemsRaw = data['items'];
  final items = (itemsRaw is List)
      ? itemsRaw
          .whereType<Map>()
          .map((e) => decodeItem(Map<String, dynamic>.from(e)))
          .toList()
      : <T>[];
  return PagedResult<T>(
    items: items,
    totalCount: (data['total_count'] as num?)?.toInt() ?? items.length,
    limit: (data['limit'] as num?)?.toInt() ?? items.length,
    offset: (data['offset'] as num?)?.toInt() ?? 0,
  );
}

PagedResult<T> unwrapTopLevelList<T>(
  Object? raw,
  T Function(Map<String, dynamic>) decodeItem,
) {
  if (raw is! Map) {
    throw ApiException('响应格式异常');
  }
  if (raw['success'] != true) {
    throw ApiException(
      (raw['message'] as String?) ?? '操作失败',
      data: raw['data'],
    );
  }
  final dataRaw = raw['data'];
  final items = (dataRaw is List)
      ? dataRaw
          .whereType<Map>()
          .map((e) => decodeItem(Map<String, dynamic>.from(e)))
          .toList()
      : <T>[];
  return PagedResult<T>(
    items: items,
    totalCount: (raw['total_count'] as num?)?.toInt() ?? items.length,
    limit: (raw['limit'] as num?)?.toInt() ?? items.length,
    offset: (raw['offset'] as num?)?.toInt() ?? 0,
  );
}

OptionsResult<T> unwrapOptions<T>(
  Object? raw,
  T Function(Map<String, dynamic>) decodeItem,
) {
  if (raw is! Map) {
    throw ApiException('响应格式异常');
  }
  if (raw['success'] != true) {
    throw ApiException(
      (raw['message'] as String?) ?? '操作失败',
      data: raw['data'],
    );
  }
  final dataRaw = raw['data'];
  final items = (dataRaw is List)
      ? dataRaw
          .whereType<Map>()
          .map((e) => decodeItem(Map<String, dynamic>.from(e)))
          .toList()
      : <T>[];
  return OptionsResult<T>(
    items: items,
    hasMore: raw['has_more'] == true,
    limit: (raw['limit'] as num?)?.toInt() ?? items.length,
    offset: (raw['offset'] as num?)?.toInt() ?? 0,
  );
}
