import 'package:flutter/foundation.dart';

@immutable
class DbOnlineWatchedFilter {
  const DbOnlineWatchedFilter({
    this.type = 'all',
    this.star = '',
    this.sortBy = 'create',
    this.orderBy = 'desc',
  });

  static const pageSize = 24;
  final String type;
  final String star;
  final String sortBy;
  final String orderBy;

  Map<String, dynamic> toJson() => {
    'type': type,
    'star': star,
    'sort_by': sortBy,
    'order_by': orderBy,
  };

  DbOnlineWatchedFilter copyWith({
    String? type,
    String? star,
    String? sortBy,
    String? orderBy,
  }) => DbOnlineWatchedFilter(
    type: type ?? this.type,
    star: star ?? this.star,
    sortBy: sortBy ?? this.sortBy,
    orderBy: orderBy ?? this.orderBy,
  );

  @override
  bool operator ==(Object other) =>
      other is DbOnlineWatchedFilter &&
      type == other.type &&
      star == other.star &&
      sortBy == other.sortBy &&
      orderBy == other.orderBy;
  @override
  int get hashCode => Object.hash(type, star, sortBy, orderBy);
}

/// 看过影片的单页缓存始终包含服务器标识。
typedef DbOnlineWatchedQuery = ({
  String serverId,
  int page,
  DbOnlineWatchedFilter filter,
});

@immutable
class DbOnlineRecheckRequirements {
  const DbOnlineRecheckRequirements({
    this.quality = '',
    this.requireSub = false,
    this.requireUncensored = false,
    this.preDownloadMode = false,
    this.washMode = false,
    this.minSizeMb = 0,
    this.maxSizeMb = 0,
    this.maxFileCount = 0,
    this.afterDate = '',
  });

  factory DbOnlineRecheckRequirements.fromJson(Map<String, dynamic> json) =>
      DbOnlineRecheckRequirements(
        quality: json['quality']?.toString() ?? '',
        requireSub: json['require_sub'] == true,
        requireUncensored: json['require_uncensored'] == true,
        preDownloadMode: json['pre_download_mode'] == true,
        washMode: json['wash_mode'] == true,
        minSizeMb: double.tryParse(json['min_size_mb']?.toString() ?? '') ?? 0,
        maxSizeMb: double.tryParse(json['max_size_mb']?.toString() ?? '') ?? 0,
        maxFileCount:
            int.tryParse(json['max_file_count']?.toString() ?? '') ?? 0,
        afterDate: json['after_date']?.toString() ?? '',
      );

  final String quality;
  final bool requireSub;
  final bool requireUncensored;
  final bool preDownloadMode;
  final bool washMode;
  final double minSizeMb;
  final double maxSizeMb;
  final int maxFileCount;
  final String afterDate;

  Map<String, dynamic> toJson() => {
    'quality': quality,
    'require_sub': requireSub,
    'require_uncensored': requireUncensored,
    'pre_download_mode': preDownloadMode,
    'wash_mode': washMode,
    'min_size_mb': minSizeMb,
    'max_size_mb': maxSizeMb,
    'max_file_count': maxFileCount,
    'after_date': afterDate,
  };
}
