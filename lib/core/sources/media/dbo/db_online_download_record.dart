import 'package:flutter/foundation.dart';

@immutable
class DbOnlineDownloadRecordFilter {
  const DbOnlineDownloadRecordFilter({
    this.startDate = '',
    this.endDate = '',
    this.keyword = '',
    this.resourceTypes = const [],
    this.downloader = '',
    this.sourceType = '',
    this.status = '',
  });

  factory DbOnlineDownloadRecordFilter.today([DateTime? now]) {
    final date = (now ?? DateTime.now()).toIso8601String().split('T').first;
    return DbOnlineDownloadRecordFilter(startDate: date, endDate: date);
  }

  final String startDate;
  final String endDate;
  final String keyword;
  final List<String> resourceTypes;
  final String downloader;
  final String sourceType;
  final String status;

  DbOnlineDownloadRecordFilter copyWith({
    String? startDate,
    String? endDate,
    String? keyword,
    List<String>? resourceTypes,
    String? downloader,
    String? sourceType,
    String? status,
  }) => DbOnlineDownloadRecordFilter(
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    keyword: keyword ?? this.keyword,
    resourceTypes: List.unmodifiable(resourceTypes ?? this.resourceTypes),
    downloader: downloader ?? this.downloader,
    sourceType: sourceType ?? this.sourceType,
    status: status ?? this.status,
  );

  Map<String, dynamic> toQuery() => {
    if (startDate.isNotEmpty) 'start_date': startDate,
    if (endDate.isNotEmpty) 'end_date': endDate,
    if (keyword.trim().isNotEmpty) 'keyword': keyword.trim(),
    if (resourceTypes.isNotEmpty) 'resource_types': resourceTypes.join(','),
    if (downloader.isNotEmpty) 'downloader': downloader,
    if (sourceType.isNotEmpty) 'source_type': sourceType,
    if (status.isNotEmpty) 'success': status == 'true',
  };
}

@immutable
class DbOnlineDownloadRecord {
  const DbOnlineDownloadRecord({
    required this.id,
    this.videoId = '',
    this.videoCode = '',
    this.videoTitle = '',
    this.releaseDate = '',
    this.coverUrl = '',
    this.thumbUrl = '',
    this.sourceType = '',
    this.sourceLabel = '',
    this.resourceUrl = '',
    this.resourceProtocol = '',
    this.resourceSite = '',
    this.resourceName = '',
    this.resourceFlags = 0,
    this.resourceDate = '',
    this.resourceTypes = const [],
    this.downloader = '',
    this.success = false,
    this.errorMessage = '',
    this.downloadedAt = '',
  });

  final int id;
  final String videoId;
  final String videoCode;
  final String videoTitle;
  final String releaseDate;
  final String coverUrl;
  final String thumbUrl;
  final String sourceType;
  final String sourceLabel;
  final String resourceUrl;
  final String resourceProtocol;
  final String resourceSite;
  final String resourceName;
  final int resourceFlags;
  final String resourceDate;
  final List<String> resourceTypes;
  final String downloader;
  final bool success;
  final String errorMessage;
  final String downloadedAt;

  factory DbOnlineDownloadRecord.fromJson(Object? raw) {
    final json = _map(raw);
    return DbOnlineDownloadRecord(
      id: _int(json['id']),
      videoId: _text(json['video_id']),
      videoCode: _text(json['video_code']),
      videoTitle: _text(json['video_title']),
      releaseDate: _text(json['release_date']),
      coverUrl: _text(json['cover_url']),
      thumbUrl: _text(json['thumb_url']),
      sourceType: _text(json['source_type']),
      sourceLabel: _text(json['source_label']),
      resourceUrl: _text(json['resource_url']),
      resourceProtocol: _text(json['resource_protocol']).toLowerCase(),
      resourceSite: _text(json['resource_site']),
      resourceName: _text(json['resource_name']),
      resourceFlags: _int(json['resource_flags']),
      resourceDate: _text(json['resource_date']),
      resourceTypes: json['resource_types'] is List
          ? List.unmodifiable((json['resource_types'] as List).map(_text))
          : const [],
      downloader: _text(json['downloader']),
      success: json['success'] == true,
      errorMessage: _text(json['error_message']),
      downloadedAt: _text(json['downloaded_at']),
    );
  }

  Map<String, dynamic> get videoInfo => {
    'video_id': videoId,
    'code': videoCode,
    'title': videoTitle.isEmpty ? resourceName : videoTitle,
    'date': releaseDate,
  };

  /// 重推沿用记录的原始字段，不能由显示用标签重新计算资源标记。
  Map<String, dynamic> get recordResource => {
    'record_id': id,
    'url': resourceUrl,
    'name': resourceName,
    'source_type': sourceType,
    'source_label': sourceLabel,
    'resource_protocol': resourceProtocol,
    'resource_site': resourceSite,
    'resource_flags': resourceFlags,
    'resource_date': resourceDate,
    'video_id': videoId,
    'video_code': videoCode,
    'video_title': videoTitle,
  };

  String resolveSourceLabel(Map<String, String> styles) {
    final match = RegExp(r'^(.+?)\s*\(([0-9,\s]+)\)$').firstMatch(sourceLabel);
    if (match == null) return sourceLabel;
    final ids = match.group(2)!.split(',').map((id) => id.trim()).toList();
    if (!ids.any(styles.containsKey)) return sourceLabel;
    final names = ids.map((id) => styles[id] ?? id).join(' / ');
    final prefix = match.group(1)!;
    return '$prefix ($names)';
  }
}

@immutable
class DbOnlineDownloadRecordPage {
  const DbOnlineDownloadRecordPage({
    required this.records,
    required this.totalCount,
    required this.filteredCount,
    required this.hasMore,
  });

  final List<DbOnlineDownloadRecord> records;
  final int totalCount;
  final int filteredCount;
  final bool hasMore;

  factory DbOnlineDownloadRecordPage.fromJson(Object? raw) {
    final json = _map(raw);
    return DbOnlineDownloadRecordPage(
      records: json['records'] is List
          ? List.unmodifiable(
              (json['records'] as List).map(DbOnlineDownloadRecord.fromJson),
            )
          : const [],
      totalCount: _int(json['total_count']),
      filteredCount: _int(json['filtered_count']),
      hasMore: json['has_more'] == true,
    );
  }
}

@immutable
class DbOnlineRecordDownloader {
  const DbOnlineRecordDownloader({
    required this.name,
    required this.displayName,
    required this.ed2kEnabled,
    this.availableQuota,
  });

  final String name;
  final String displayName;
  final bool ed2kEnabled;
  final int? availableQuota;

  factory DbOnlineRecordDownloader.fromJson(Object? raw) {
    final json = _map(raw);
    final name = _text(json['name']);
    final label = _text(json['display_name']);
    return DbOnlineRecordDownloader(
      name: name,
      displayName: label.isEmpty ? name : label,
      ed2kEnabled: json['ed2k_enabled'] == true,
      availableQuota: json['available_quota'] == null
          ? null
          : _int(json['available_quota']),
    );
  }

  ({String name, String displayName, bool? ed2kEnabled}) get option =>
      (name: name, displayName: displayName, ed2kEnabled: ed2kEnabled);
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};
String _text(Object? value) => value?.toString().trim() ?? '';
int _int(Object? value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;
