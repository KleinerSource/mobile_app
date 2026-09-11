import 'dart:convert';

import '../models/paged_result.dart';
import 'api_exception.dart';
import 'error_codes.dart';

String envelopeMessage(
  Object? raw, {
  String fallback = AppErrorCode.operationFailed,
}) {
  return envelopeMessageOrNull(raw) ?? fallback;
}

/// Reads a server-provided business message without inventing client copy.
///
/// A null result means that the response did not contain a usable `message`
/// or `error`; callers with a UI context should then choose a localized
/// fallback.
String? envelopeMessageOrNull(Object? raw) {
  if (raw is! Map) return null;
  final candidates = <Object?>[
    raw['message'],
    raw['error'],
    if (raw['data'] is Map) (raw['data'] as Map)['message'],
    if (raw['data'] is Map) (raw['data'] as Map)['error'],
  ];
  for (final value in candidates) {
    final message = value?.toString().trim();
    if (message != null && message.isNotEmpty) return message;
  }
  return null;
}

String? envelopeCodeOrNull(Object? raw) {
  if (raw is! Map) return null;
  final candidates = <Object?>[
    raw['code'],
    raw['error_code'],
    if (raw['data'] is Map) (raw['data'] as Map)['code'],
    if (raw['data'] is Map) (raw['data'] as Map)['error_code'],
  ];
  for (final value in candidates) {
    final code = value?.toString().trim();
    if (code != null && code.isNotEmpty) return code;
  }
  return null;
}

/// Attempts to decode a JSON object embedded in a plain-text or byte response.
///
/// Binary endpoints may still return the standard error envelope when the
/// server cannot honour the requested representation. A null result means
/// that the payload is not a JSON object and should be handled as its declared
/// representation by the caller.
Map<String, dynamic>? decodeJsonMap(Object? raw) {
  final text = switch (raw) {
    String value => value.trim(),
    List<int> value => utf8.decode(value, allowMalformed: true).trim(),
    _ => '',
  };
  if (text.isEmpty) return null;
  try {
    final decoded = jsonDecode(text);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
  } catch (_) {
    return null;
  }
}

T unwrapStd<T>(Object? raw, T Function(Object?) decode) {
  if (raw is! Map) {
    throw ApiException(
      AppErrorCode.responseFormatInvalid,
      code: AppErrorCode.responseFormatInvalid,
    );
  }
  if (raw['success'] != true) {
    final message = envelopeMessageOrNull(raw);
    final code = envelopeCodeOrNull(raw);
    throw ApiException(
      message ?? code ?? AppErrorCode.operationFailed,
      code: code ?? (message == null ? AppErrorCode.operationFailed : null),
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
    throw ApiException(
      AppErrorCode.responseFormatInvalid,
      code: AppErrorCode.responseFormatInvalid,
    );
  }
  if (raw['success'] != true) {
    final message = envelopeMessageOrNull(raw);
    final code = envelopeCodeOrNull(raw);
    throw ApiException(
      message ?? code ?? AppErrorCode.operationFailed,
      code: code ?? (message == null ? AppErrorCode.operationFailed : null),
      data: raw['data'],
    );
  }
  final data = raw['data'];
  if (data is! Map) {
    throw ApiException(
      AppErrorCode.responseDataMissing,
      code: AppErrorCode.responseDataMissing,
    );
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
    throw ApiException(
      AppErrorCode.responseFormatInvalid,
      code: AppErrorCode.responseFormatInvalid,
    );
  }
  if (raw['success'] != true) {
    final message = envelopeMessageOrNull(raw);
    final code = envelopeCodeOrNull(raw);
    throw ApiException(
      message ?? code ?? AppErrorCode.operationFailed,
      code: code ?? (message == null ? AppErrorCode.operationFailed : null),
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
    throw ApiException(
      AppErrorCode.responseFormatInvalid,
      code: AppErrorCode.responseFormatInvalid,
    );
  }
  if (raw['success'] != true) {
    final message = envelopeMessageOrNull(raw);
    final code = envelopeCodeOrNull(raw);
    throw ApiException(
      message ?? code ?? AppErrorCode.operationFailed,
      code: code ?? (message == null ? AppErrorCode.operationFailed : null),
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
