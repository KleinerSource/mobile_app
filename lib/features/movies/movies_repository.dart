import '../../core/api/api_exception.dart';
import '../../core/api/dio_factory.dart';
import '../../core/api/envelope.dart';
import '../../core/api/services/favorites_api.dart';
import '../../core/api/services/movies_api.dart';
import '../../core/api/services/movies_extended_api.dart';
import '../../core/api/services/system_api.dart';
import '../../core/models/media_streams.dart';
import '../../core/models/movie.dart';
import '../../core/models/paged_result.dart';
import '../../core/models/resource_scan.dart';
import '../../core/models/subtitle_search.dart';
import '../../core/models/watch_record.dart';
import 'movie_data_changes.dart';
import 'movie_filter.dart';

class MoviesRepository {
  MoviesRepository(
    this._api,
    this._favorites,
    this._system, {
    MoviesExtendedApi? extendedApi,
  }) : _extendedApi = extendedApi;
  final MoviesApi _api;
  final FavoritesApi _favorites;
  final SystemApi _system;
  final MoviesExtendedApi? _extendedApi;

  Future<PagedResult<MovieListItem>> list(
    MovieFilter filter, {
    required int limit,
    required int offset,
    bool compact = false,
  }) async {
    final query = filter.toQuery(limit: limit, offset: offset);
    if (compact) query['compact'] = true;
    final raw = await _api.getMovies(query);
    return unwrapMovieList<MovieListItem>(raw, MovieListItem.fromJson);
  }

  Future<MovieDetail> detail(int id) async {
    final raw = await _api.getMovieDetail(id);
    return unwrapStd<MovieDetail>(
      raw,
      (d) => MovieDetail.fromJson(Map<String, dynamic>.from(d as Map)),
    );
  }

  Future<List<String>> extraFanarts(int id) async {
    final raw = await _api.getExtraFanarts(id);
    return unwrapStd<List<String>>(raw, (d) {
      if (d is List) {
        return d.whereType<String>().toList();
      }
      return const <String>[];
    });
  }

  Future<void> downloadExtraFanarts(int id) async {
    final api = _extendedApi;
    if (api == null) {
      throw ApiException('预览图获取接口不可用，请更新服务器后重试');
    }
    await api.downloadDbonlineExtrafanart(id);
  }

  /// 一次请求返回文件级摘要与 video / audio_streams / subtitle_streams。
  Future<MediaInfoDetail?> mediaInfoDetail(int id) async {
    try {
      final raw = await _api.getMediaInfo(id);
      return unwrapStd<MediaInfoDetail?>(raw, (d) {
        if (d is Map) {
          return MediaInfoDetail.fromJson(Map<String, dynamic>.from(d));
        }
        return null;
      });
    } on ApiException {
      // backend returns 404 when no media info; surface as null instead of error
      return null;
    }
  }

  Future<bool> toggleFavorite(int id) async {
    final raw = await _favorites.toggle(id);
    final value = unwrapStd<bool>(raw, (d) {
      if (d is Map) {
        final v = d['is_favorited'];
        return v == true;
      }
      return false;
    });
    MovieDataChanges.bumpMetadata(movieId: id);
    return value;
  }

  Future<void> markWatched(int id, bool completed) async {
    await _api.upsertWatchRecord(id, {'ended': completed});
    MovieDataChanges.bumpProgress(movieId: id);
  }

  Future<WatchRecord?> watchRecord(int id) async {
    try {
      final raw = await _api.getWatchRecord(id);
      return unwrapStd<WatchRecord?>(raw, (data) {
        if (data is! Map) return null;
        return WatchRecord.fromJson(Map<String, dynamic>.from(data));
      });
    } catch (error) {
      if (toApiException(error).status == 404) return null;
      rethrow;
    }
  }

  Future<void> acknowledgeResources(int id) async {
    final raw = await _api.acknowledgeResources(id);
    unwrapStd<void>(raw, (_) {});
    // 注意:这里不做变更计数。详情页的"进入即确认"安全网几乎每次都会调用,
    // 若计数会导致纯浏览也触发刷新;由确知存在新资源标记的调用方自行计数。
  }

  Future<ResourceScanStartResult> startResourceScan({
    List<int>? movieIds,
    MovieFilter? filter,
    bool favoriteOnly = false,
  }) async {
    final api = _extendedApi;
    if (api == null) {
      throw ApiException('资源扫描接口不可用，请更新服务器后重试');
    }
    final ids = movieIds?.where((id) => id > 0).toSet().toList(growable: false);
    final body = ids != null && ids.isNotEmpty
        ? <String, dynamic>{'movie_ids': ids}
        : <String, dynamic>{
            'scan_all': true,
            'favorite_only': favoriteOnly,
            'filters': (filter ?? const MovieFilter()).toResourceScanBody(),
          };
    final data = await api.batchResourceScan(body);
    if (data is! Map) {
      throw ApiException('资源扫描响应格式错误');
    }
    return ResourceScanStartResult.fromJson(Map<String, dynamic>.from(data));
  }

  Future<ResourceScanTask> resourceScanProgress(String taskId) async {
    final api = _extendedApi;
    if (api == null) {
      throw ApiException('资源扫描接口不可用，请更新服务器后重试');
    }
    final data = await api.resourceScanProgress(taskId);
    if (data is! Map) {
      throw ApiException('资源扫描进度响应格式错误');
    }
    return ResourceScanTask.fromJson(Map<String, dynamic>.from(data));
  }

  /// 更新观看进度 · positionSec / durationSec 由播放器上报
  Future<void> upsertWatchRecord(
    int id, {
    required int positionSec,
    required int durationSec,
    bool? completed,
  }) async {
    final body = <String, dynamic>{
      'last_position_sec': positionSec,
      'duration_sec': durationSec,
    };
    if (completed != null) body['ended'] = completed;
    await _api.upsertWatchRecord(id, body);
    // 播放器实际上报过进度,返回列表/首页时才需要刷新进度展示。
    MovieDataChanges.bumpProgress(movieId: id);
  }

  // ===== 详情页操作 =====

  /// 编辑影片字段 · 字段可包含 title/plot/year/rating/num/...
  Future<MovieDetail> updateMovie(int id, Map<String, dynamic> body) async {
    final raw = await _api.updateMovie(id, body);
    final detail = unwrapStd<MovieDetail>(
      raw,
      (d) => MovieDetail.fromJson(Map<String, dynamic>.from(d as Map)),
    );
    MovieDataChanges.bumpMetadata(movieId: id);
    return detail;
  }

  /// 删除影片 (含磁盘文件)
  Future<void> deleteMovie(int id, {bool force = false}) async {
    final raw = await _api.deleteMovies({
      'movie_ids': [id],
      'force': force,
    });
    unwrapStd<void>(raw, (_) {});
    MovieDataChanges.bumpMetadata(movieId: id);
  }

  /// NFO 同步 (元数据 → nfo 文件)
  Future<void> syncNfo(int id) async {
    final raw = await _api.syncNfo(id);
    unwrapStd<void>(raw, (_) {});
  }

  /// NFO 重载 (nfo 文件 → 元数据)
  Future<void> refreshFromNfo(int id) async {
    final raw = await _api.refreshFromNfo(id);
    unwrapStd<void>(raw, (_) {});
    // NFO 重载可能同时改写元数据与封面图片。
    MovieDataChanges.bumpMetadata(movieId: id);
    MovieDataChanges.bumpImages(movieId: id);
  }

  // ===== 字幕搜索 =====

  Future<({String keyword, List<SubtitleSearchItem> items})> searchSubtitles(
    int id,
  ) async {
    final raw = await _api.searchThunderSubtitles(id);
    return unwrapStd<({String keyword, List<SubtitleSearchItem> items})>(raw, (
      d,
    ) {
      if (d is Map) {
        final m = Map<String, dynamic>.from(d);
        final list = (m['items'] as List?) ?? const [];
        return (
          keyword: m['keyword']?.toString() ?? '',
          items: list
              .whereType<Map>()
              .map(
                (e) =>
                    SubtitleSearchItem.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList(),
        );
      }
      return (keyword: '', items: <SubtitleSearchItem>[]);
    });
  }

  /// 预览字幕 · 返回 (content, duration?)
  Future<String> previewSubtitle(int id, String url) async {
    final raw = await _api.previewThunderSubtitle(id, {'url': url});
    return unwrapStd<String>(raw, (d) {
      if (d is Map) return d['content']?.toString() ?? '';
      return d?.toString() ?? '';
    });
  }

  Future<void> downloadSubtitle(
    int id, {
    required String url,
    required String ext,
    bool overwrite = false,
  }) async {
    final raw = await _api.downloadThunderSubtitle(id, {
      'url': url,
      'ext': ext,
      'overwrite': overwrite,
    });
    unwrapStd<void>(raw, (_) {});
  }

  // ===== DBO 接口 =====

  Future<Map<String, dynamic>> getDbonlineMetadata(int id) async {
    final raw = await _api.getDbonlineMetadata(id);
    return unwrapStd<Map<String, dynamic>>(raw, (d) {
      if (d is Map) return Map<String, dynamic>.from(d);
      return <String, dynamic>{};
    });
  }

  /// 拉取单个 source 的资源 · 返回 {magnets, ed2ks, warnings}
  Future<
    ({
      List<Map<String, dynamic>> magnets,
      List<Map<String, dynamic>> ed2ks,
      List<String> warnings,
    })
  >
  getResourcesBySource(int id, String source) async {
    final raw = await _api.getResources(id, source);
    return unwrapStd(raw, (d) {
      if (d is Map) {
        final m = Map<String, dynamic>.from(d);
        List<Map<String, dynamic>> toList(dynamic v) {
          if (v is! List) return const <Map<String, dynamic>>[];
          return v
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }

        final warnings =
            (m['warnings'] as List?)?.whereType<String>().toList() ??
            const <String>[];
        return (
          magnets: toList(m['magnets']),
          ed2ks: toList(m['ed2ks']),
          warnings: warnings,
        );
      }
      return (
        magnets: <Map<String, dynamic>>[],
        ed2ks: <Map<String, dynamic>>[],
        warnings: <String>[],
      );
    });
  }

  /// 合并 detail / custom / nyaa 三个源, 容错单源失败。
  ///
  /// 三个源并发请求，避免单个慢源阻塞其它源。
  Future<
    ({
      List<Map<String, dynamic>> magnets,
      List<Map<String, dynamic>> ed2ks,
      List<String> warnings,
    })
  >
  getAllResources(int id) async {
    const sources = ['detail', 'custom', 'nyaa'];
    final magnets = <Map<String, dynamic>>[];
    final ed2ks = <Map<String, dynamic>>[];
    final warnings = <String>[];
    final errors = <String>[];

    await Future.wait(
      sources.map((s) async {
        try {
          final r = await getResourcesBySource(id, s);
          magnets.addAll(r.magnets);
          ed2ks.addAll(r.ed2ks);
          warnings.addAll(r.warnings);
        } catch (e) {
          errors.add('$s: ${e is ApiException ? e.message : e.toString()}');
        }
      }),
    );
    if (magnets.isEmpty && ed2ks.isEmpty && errors.isNotEmpty) {
      throw ApiException(errors.first);
    }
    return (magnets: magnets, ed2ks: ed2ks, warnings: warnings);
  }

  // ===== 下载器 / 推送下载 / 下载历史 =====

  /// 已配置的下载器列表 · 仅返回 (name, displayName)
  Future<List<({String name, String displayName})>> getDownloaders() async {
    final raw = await _system.getDownloaders();
    return unwrapStd<List<({String name, String displayName})>>(raw, (d) {
      List items = const [];
      if (d is Map && d['downloaders'] is List) {
        items = d['downloaders'] as List;
      } else if (d is List) {
        items = d;
      }
      return items
          .whereType<Map>()
          .map((e) {
            final m = Map<String, dynamic>.from(e);
            final name = (m['name'] ?? '').toString();
            final display = (m['display_name'] ?? m['displayName'] ?? name)
                .toString();
            return (name: name, displayName: display);
          })
          .where((e) => e.name.isNotEmpty)
          .toList();
    });
  }

  /// 影片下载历史 · 返回大写 hash → 时间字符串
  Future<({Map<String, String> magnets, Map<String, String> ed2ks})>
  getDownloadHistory(int id) async {
    final raw = await _api.getDownloadHistory(id);
    return unwrapStd(raw, (d) {
      Map<String, String> norm(dynamic v) {
        if (v is! Map) return <String, String>{};
        final out = <String, String>{};
        for (final e in v.entries) {
          final k = e.key.toString().trim().toUpperCase();
          if (k.isEmpty) continue;
          out[k] = (e.value ?? '').toString();
        }
        return out;
      }

      if (d is Map) {
        final m = Map<String, dynamic>.from(d);
        return (magnets: norm(m['magnets']), ed2ks: norm(m['ed2ks']));
      }
      return (magnets: <String, String>{}, ed2ks: <String, String>{});
    });
  }

  /// 推送 URL 到下载器 · 返回 (message, lastDownloadedAt)
  Future<({String message, String lastDownloadedAt})> pushDownload({
    required List<String> urls,
    required String downloader,
    required int movieId,
    Map<String, dynamic>? videoInfo,
    List<Map<String, dynamic>> recordResources = const [],
    String savePath = '',
  }) async {
    final body = <String, dynamic>{
      'urls': urls,
      'downloader': downloader,
      'save_path': savePath,
      'video_info': videoInfo,
      'record_resources': recordResources,
      'movie_id': movieId,
    };
    final raw = await _system.pushDownload(body);
    if (raw is Map && raw['success'] == false) {
      throw ApiException((raw['message'] as String?) ?? '推送失败');
    }
    final msg = raw is Map
        ? (raw['message']?.toString() ?? '下载任务已添加')
        : '下载任务已添加';
    String lastDownloadedAt = '';
    if (raw is Map && raw['data'] is Map) {
      lastDownloadedAt = ((raw['data'] as Map)['last_downloaded_at'] ?? '')
          .toString();
    }
    return (message: msg, lastDownloadedAt: lastDownloadedAt);
  }

  // ===== 批量操作 =====

  /// 批量添加 tag/genre/series 关联
  Future<void> batchAddAssociations({
    required List<int> movieIds,
    List<int> tagIds = const [],
    List<int> genreIds = const [],
    int? seriesId,
  }) async {
    final body = <String, dynamic>{'movie_ids': movieIds};
    if (tagIds.isNotEmpty) body['tag_ids'] = tagIds;
    if (genreIds.isNotEmpty) body['genre_ids'] = genreIds;
    if (seriesId != null) body['series_id'] = seriesId;
    final raw = await _api.batchAddAssociations(body);
    if (raw is Map && raw['success'] == false) {
      throw ApiException((raw['message'] as String?) ?? '批量编辑失败');
    }
  }

  /// 批量移除 tag/genre/series 关联
  Future<void> batchRemoveAssociations({
    required List<int> movieIds,
    List<int> tagIds = const [],
    List<int> genreIds = const [],
    int? seriesId,
  }) async {
    final body = <String, dynamic>{'movie_ids': movieIds};
    if (tagIds.isNotEmpty) body['tag_ids'] = tagIds;
    if (genreIds.isNotEmpty) body['genre_ids'] = genreIds;
    if (seriesId != null) body['series_id'] = seriesId;
    final raw = await _api.batchRemoveAssociations(body);
    if (raw is Map && raw['success'] == false) {
      throw ApiException((raw['message'] as String?) ?? '批量编辑失败');
    }
  }

  /// 批量裁剪 + 水印 · 返回 (success, failed)
  Future<({int successCount, int failedCount})> batchWatermark({
    required List<int> movieIds,
    bool subtitle = false,
    bool exsub = false,
    bool crack = false,
    bool uhd = false,
  }) async {
    final body = <String, dynamic>{
      'movie_ids': movieIds,
      'subtitle': subtitle,
      'exsub': exsub,
      'crack': crack,
      'uhd': uhd,
    };
    final raw = await _api.batchWatermark(body);
    if (raw is Map && raw['success'] == false) {
      throw ApiException((raw['message'] as String?) ?? '海报裁剪失败');
    }
    if (raw is Map && raw['data'] is Map) {
      final d = Map<String, dynamic>.from(raw['data']);
      return (
        successCount: (d['success_count'] as num?)?.toInt() ?? 0,
        failedCount: (d['failed_count'] as num?)?.toInt() ?? 0,
      );
    }
    return (successCount: 0, failedCount: 0);
  }

  /// 合并重复番号 · 返回 taskId (可选)
  Future<String?> mergeDuplicateFiles({
    required List<int> movieIds,
    required int targetMovieId,
  }) async {
    final raw = await _api.mergeDuplicateFiles({
      'movie_ids': movieIds,
      'target_movie_id': targetMovieId,
    });
    if (raw is Map && raw['success'] == false) {
      throw ApiException((raw['message'] as String?) ?? '合并失败');
    }
    if (raw is Map && raw['data'] is Map) {
      return (raw['data'] as Map)['task_id']?.toString();
    }
    return null;
  }

  /// 比较重复番号 NFO · 返回 raw map (含 movies, scalar_fields, num)
  Future<Map<String, dynamic>> compareDuplicateNfo(List<int> movieIds) async {
    final raw = await _api.compareDuplicateNfo({'movie_ids': movieIds});
    return unwrapStd<Map<String, dynamic>>(raw, (d) {
      if (d is Map) return Map<String, dynamic>.from(d);
      return <String, dynamic>{};
    });
  }

  /// 应用 NFO 选择
  Future<void> applyDuplicateNfo(Map<String, dynamic> payload) async {
    final raw = await _api.applyDuplicateNfo(payload);
    if (raw is Map && raw['success'] == false) {
      throw ApiException((raw['message'] as String?) ?? '应用失败');
    }
  }

  /// 提交批量下载请求 · 返回 message
  Future<String> requestDownload({
    required List<int> movieIds,
    required Map<String, dynamic> requirements,
  }) async {
    final raw = await _api.requestDownload({
      'movie_ids': movieIds,
      'requirements': requirements,
    });
    if (raw is Map && raw['success'] == false) {
      throw ApiException((raw['message'] as String?) ?? '下载请求失败');
    }
    return raw is Map ? (raw['message']?.toString() ?? '下载请求已提交') : '下载请求已提交';
  }

  // ===== 海报裁剪 + 水印 =====

  /// 应用裁剪 + 水印
  Future<void> applyPosterCrop(
    int id, {
    required double cropOffset,
    bool subtitle = false,
    bool exsub = false,
    bool crack = false,
    bool uhd = false,
  }) async {
    final raw = await _api.updatePosterWatermark(id, {
      'subtitle': subtitle,
      'exsub': exsub,
      'crack': crack,
      'uhd': uhd,
      'crop_offset': cropOffset,
    });
    if (raw is Map && raw['success'] == false) {
      throw ApiException((raw['message'] as String?) ?? '裁剪失败');
    }
    // 裁剪/水印在原 UUID 上替换了封面内容,需要刷新图片缓存。
    MovieDataChanges.bumpImages(movieId: id);
  }

  /// 预览裁剪 · 返回 JPEG bytes
  Future<List<int>> previewPosterCrop(
    int id, {
    required double cropOffset,
    bool subtitle = false,
    bool exsub = false,
    bool crack = false,
    bool uhd = false,
  }) async {
    final res = await _api.previewPosterWatermark(id, {
      'subtitle': subtitle,
      'exsub': exsub,
      'crack': crack,
      'uhd': uhd,
      'crop_offset': cropOffset,
    });
    return res.data;
  }
}
