import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import 'update_models.dart';

class UpdateException implements Exception {
  const UpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}

class GitHubUpdateService {
  GitHubUpdateService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 20),
              headers: const {
                'Accept': 'application/vnd.github+json',
                'X-GitHub-Api-Version': '2022-11-28',
                'User-Agent': 'MD-Center-App',
              },
            ),
          );

  final Dio _dio;

  Future<UpdateCheckResult> check({
    required String repositoryUrl,
    required UpdatePlatform platform,
    required AppReleaseVersion currentVersion,
    bool includeDevelopment = false,
  }) async {
    final repository = GitHubRepository.parse(repositoryUrl);
    try {
      final releases = await _loadReleases(
        repository,
        platform,
        includeDevelopment: includeDevelopment,
      );
      final candidate = selectLatestCandidate(
        releases,
        platform,
        includeDevelopment: includeDevelopment,
      );
      if (candidate == null) {
        throw UpdateException('没有找到适用于 ${platform.label} 的安装包');
      }
      return UpdateCheckResult(
        repository: repository,
        currentVersion: currentVersion,
        candidate: candidate,
      );
    } on UpdateException {
      rethrow;
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 403) {
        throw const UpdateException('GitHub 请求次数已达到限制，请稍后重试');
      }
      if (status == 404) {
        throw const UpdateException('GitHub 仓库不存在或没有公开 Release');
      }
      throw const UpdateException('无法连接 GitHub，请检查网络或仓库地址');
    } catch (_) {
      throw const UpdateException('读取 GitHub Release 失败');
    }
  }

  Future<List<GitHubRelease>> _loadReleases(
    GitHubRepository repository,
    UpdatePlatform platform, {
    required bool includeDevelopment,
  }) async {
    final rollingReleases = <GitHubRelease>[];
    final channels = [false, if (includeDevelopment) true];
    for (final development in channels) {
      try {
        final response = await _dio.get<dynamic>(
          repository.releaseTagApiUrl(platform, development: development),
        );
        final data = response.data;
        if (data is Map) {
          rollingReleases.add(
            GitHubRelease.fromJson(Map<String, dynamic>.from(data)),
          );
        }
      } on DioException catch (error) {
        // 自建仓库可能没有使用对应滚动标签，继续检查其他渠道或回退列表。
        if (error.response?.statusCode != 404) rethrow;
      }
    }

    final publishedRollingReleases = rollingReleases
        .where((release) => !release.draft)
        .toList();
    if (selectLatestCandidate(
          publishedRollingReleases,
          platform,
          includeDevelopment: includeDevelopment,
        ) !=
        null) {
      return publishedRollingReleases;
    }

    final response = await _dio.get<dynamic>(repository.releasesApiUrl);
    final rawReleases = response.data;
    if (rawReleases is! List) {
      throw const UpdateException('GitHub 返回的 Release 数据格式不正确');
    }
    return [
      ...publishedRollingReleases,
      ...rawReleases
          .whereType<Map>()
          .map(
            (item) => GitHubRelease.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((release) => !release.draft),
    ];
  }

  static GitHubUpdateCandidate? selectLatestCandidate(
    Iterable<GitHubRelease> releases,
    UpdatePlatform platform, {
    bool includeDevelopment = false,
  }) {
    final candidates = <GitHubUpdateCandidate>[];
    for (final release in releases) {
      if (!includeDevelopment && release.isDevelopment) continue;
      final asset = release.assetFor(
        platform,
        includeDevelopment: includeDevelopment,
      );
      if (asset == null) continue;
      final version = release.versionFor(asset);
      if (version == null) continue;
      candidates.add(
        GitHubUpdateCandidate(release: release, asset: asset, version: version),
      );
    }
    if (candidates.isEmpty) return null;
    candidates.sort((left, right) {
      final versionResult = left.version.compareTo(right.version);
      if (versionResult != 0) return versionResult;
      final leftDate = left.release.publishedAt;
      final rightDate = right.release.publishedAt;
      if (leftDate == null && rightDate == null) return 0;
      if (leftDate == null) return -1;
      if (rightDate == null) return 1;
      return leftDate.compareTo(rightDate);
    });
    return candidates.last;
  }

  Future<File> download(
    GitHubReleaseAsset asset, {
    void Function(int received, int total)? onReceiveProgress,
  }) async {
    final directory = await getTemporaryDirectory();
    final fileName = _safeFileName(asset.name);
    final file = File(
      '${directory.path}${Platform.pathSeparator}omm_update_$fileName',
    );
    if (await file.exists()) await file.delete();
    try {
      await _dio.download(
        asset.downloadUrl,
        file.path,
        onReceiveProgress: onReceiveProgress,
        options: Options(
          responseType: ResponseType.bytes,
          headers: const {'Accept': 'application/octet-stream'},
        ),
      );
      return file;
    } on DioException {
      if (await file.exists()) await file.delete();
      throw const UpdateException('下载安装包失败，请稍后重试');
    } catch (_) {
      if (await file.exists()) await file.delete();
      throw const UpdateException('保存安装包失败');
    }
  }

  String _safeFileName(String raw) {
    final name = raw.trim().replaceAll(RegExp(r'[^A-Za-z0-9._+-]'), '_');
    return name.isEmpty ? 'package' : name;
  }
}
