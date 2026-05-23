import '../../core/api/api_exception.dart';
import '../../core/api/envelope.dart';
import '../../core/api/services/favorites_api.dart';
import '../../core/api/services/movies_api.dart';
import '../../core/api/services/system_api.dart';
import '../../core/models/media_info.dart';
import '../../core/models/movie.dart';
import '../../core/models/paged_result.dart';
import '../../core/models/subtitle_search.dart';
import 'movie_filter.dart';

class MoviesRepository {
  MoviesRepository(this._api, this._favorites, this._system);
  final MoviesApi _api;
  final FavoritesApi _favorites;
  final SystemApi _system;

  Future<PagedResult<MovieListItem>> list(
    MovieFilter filter, {
    required int limit,
    required int offset,
  }) async {
    final raw = await _api.getMovies(filter.toQuery(limit: limit, offset: offset));
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

  Future<MediaInfo?> mediaInfo(int id) async {
    try {
      final raw = await _api.getMediaInfo(id);
      return unwrapStd<MediaInfo?>(raw, (d) {
        if (d is Map) {
          return MediaInfo.fromJson(Map<String, dynamic>.from(d));
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
    return unwrapStd<bool>(raw, (d) {
      if (d is Map) {
        final v = d['is_favorited'];
        return v == true;
      }
      return false;
    });
  }

  Future<void> markWatched(int id, bool completed) async {
    await _api.upsertWatchRecord(id, {'completed': completed});
  }

  // ===== 详情页操作 =====

  /// 编辑影片字段 · 字段可包含 title/plot/year/rating/num/...
  Future<MovieDetail> updateMovie(int id, Map<String, dynamic> body) async {
    final raw = await _api.updateMovie(id, body);
    return unwrapStd<MovieDetail>(
      raw,
      (d) => MovieDetail.fromJson(Map<String, dynamic>.from(d as Map)),
    );
  }

  /// 删除影片 (含磁盘文件)
  Future<void> deleteMovie(int id, {bool force = false}) async {
    final raw = await _api.deleteMovies({
      'movie_ids': [id],
      'force': force,
    });
    unwrapStd<void>(raw, (_) {});
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
  }

  // ===== 字幕搜索 =====

  Future<({String keyword, List<SubtitleSearchItem> items})>
      searchSubtitles(int id) async {
    final raw = await _api.searchThunderSubtitles(id);
    return unwrapStd<({String keyword, List<SubtitleSearchItem> items})>(raw,
        (d) {
      if (d is Map) {
        final m = Map<String, dynamic>.from(d);
        final list = (m['items'] as List?) ?? const [];
        return (
          keyword: m['keyword']?.toString() ?? '',
          items: list
              .whereType<Map>()
              .map((e) =>
                  SubtitleSearchItem.fromJson(Map<String, dynamic>.from(e)))
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
  Future<({List<Map<String, dynamic>> magnets, List<Map<String, dynamic>> ed2ks, List<String> warnings})>
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
        final warnings = (m['warnings'] as List?)
                ?.whereType<String>()
                .toList() ??
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

  /// 合并 detail / custom / nyaa 三个源, 容错单源失败
  Future<({List<Map<String, dynamic>> magnets, List<Map<String, dynamic>> ed2ks, List<String> warnings})>
      getAllResources(int id) async {
    const sources = ['detail', 'custom', 'nyaa'];
    final magnets = <Map<String, dynamic>>[];
    final ed2ks = <Map<String, dynamic>>[];
    final warnings = <String>[];
    final errors = <String>[];
    for (final s in sources) {
      try {
        final r = await getResourcesBySource(id, s);
        magnets.addAll(r.magnets);
        ed2ks.addAll(r.ed2ks);
        warnings.addAll(r.warnings);
      } catch (e) {
        errors.add('$s: ${e is ApiException ? e.message : e.toString()}');
      }
    }
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
      return items.whereType<Map>().map((e) {
        final m = Map<String, dynamic>.from(e);
        final name = (m['name'] ?? '').toString();
        final display = (m['display_name'] ?? m['displayName'] ?? name).toString();
        return (name: name, displayName: display);
      }).where((e) => e.name.isNotEmpty).toList();
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
    final msg = raw is Map ? (raw['message']?.toString() ?? '下载任务已添加') : '下载任务已添加';
    String lastDownloadedAt = '';
    if (raw is Map && raw['data'] is Map) {
      lastDownloadedAt =
          ((raw['data'] as Map)['last_downloaded_at'] ?? '').toString();
    }
    return (message: msg, lastDownloadedAt: lastDownloadedAt);
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
