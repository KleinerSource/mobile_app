import 'package:flutter_test/flutter_test.dart';
import 'package:omm/features/media_browser/models/media_browser_models.dart';

void main() {
  test('MediaBrowserItem.fromJson 解析电影条目的核心字段', () {
    final item = MediaBrowserItem.fromJson(const {
      'Id': 'item-1',
      'Name': '示例电影',
      'Type': 'Movie',
      'ServerId': 'server-1',
      'ProductionYear': 2024,
      'CommunityRating': 8.4,
      'RunTimeTicks': 72000000000, // 7200s = 120m
      'Overview': '  剧情简介  ',
      'Genres': ['科幻', '悬疑'],
      'People': [
        {'Id': 'p1', 'Name': '导演一', 'Type': 'Director'},
        {'Id': 'p2', 'Name': '演员一', 'Type': 'Actor', 'Role': '主角'},
      ],
      'UserData': {
        'PlaybackPositionTicks': 3600000000, // 360s
        'PlayCount': 1,
        'IsFavorite': true,
        'Played': false,
      },
      'ImageTags': {'Primary': 'primary-tag', 'Thumb': 'thumb-tag'},
      'BackdropImageTags': ['backdrop-tag'],
      'MediaSources': [
        {
          'Id': 'ms-1',
          'Path': '/media/movie.mkv',
          'Container': 'mkv',
          'Size': 1024,
          'SupportsDirectPlay': true,
          'MediaStreams': [
            {'Index': 0, 'Type': 'Video', 'Codec': 'hevc'},
            {
              'Index': 1,
              'Type': 'Audio',
              'Codec': 'flac',
              'DisplayTitle': 'FLAC 5.1',
            },
            {
              'Index': 2,
              'Type': 'Subtitle',
              'Codec': 'ass',
              'IsExternal': true,
            },
          ],
        },
      ],
    });

    expect(item.id, 'item-1');
    expect(item.isMovie, isTrue);
    expect(item.isPlayable, isTrue);
    expect(item.productionYear, 2024);
    expect(item.communityRating, 8.4);
    expect(item.runtimeMinutes, 120);
    expect(item.overview, '剧情简介');
    expect(item.genres, ['科幻', '悬疑']);
    expect(item.people, hasLength(2));
    expect(item.people[1].role, '主角');
    expect(item.userData.isFavorite, isTrue);
    expect(item.userData.resumeSeconds, 360);
    expect(item.primaryImageTag, 'primary-tag');
    expect(item.backdropImageTags, ['backdrop-tag']);
    final source = item.mediaSources.single;
    expect(source.id, 'ms-1');
    expect(source.path, '/media/movie.mkv');
    expect(source.supportsDirectPlay, isTrue);
    expect(source.mediaStreams, hasLength(3));
    expect(source.mediaStreams[2].isExternal, isTrue);
  });

  test('MediaBrowserItem.fromJson 解析剧集分集字段', () {
    final item = MediaBrowserItem.fromJson(const {
      'Id': 'ep-1',
      'Name': '第一集',
      'Type': 'Episode',
      'SeriesId': 'series-1',
      'SeriesName': '示例剧集',
      'SeasonId': 'season-1',
      'ParentIndexNumber': 2,
      'IndexNumber': 3,
    });

    expect(item.isEpisode, isTrue);
    expect(item.isPlayable, isTrue);
    expect(item.seriesId, 'series-1');
    expect(item.seriesName, '示例剧集');
    expect(item.parentIndexNumber, 2);
    expect(item.indexNumber, 3);
  });

  test('MediaBrowserItem.fromJson 解析剧集年份和总集数', () {
    final item = MediaBrowserItem.fromJson(const {
      'Id': 'series-1',
      'Name': '示例剧集',
      'Type': 'Series',
      'PremiereDate': '2019-09-01T00:00:00Z',
      'EndDate': '2024-05-20T00:00:00Z',
      'Status': 'Ended',
      'UserData': {'PlayCount': 0, 'UnplayedItemCount': 24},
    });

    expect(item.productionYear, 2019);
    expect(item.endYear, 2024);
    expect(item.status, 'Ended');
    expect(item.userData.unplayedItemCount, 24);
    expect(item.totalEpisodeCount, 24);
  });

  test('Jellyfin 剧集列表条目解析 ChildCount 和 UserData 计数', () {
    final item = MediaBrowserItem.fromJson(const {
      'Name': '侠探杰克',
      'Id': 'series-jellyfin',
      'PremiereDate': '2022-02-03T00:00:00.0000000Z',
      'ProductionYear': 2022,
      'Type': 'Series',
      'UserData': {'PlayCount': 0, 'UnplayedItemCount': 24},
      'ChildCount': 24,
      'Status': 'Continuing',
      'EndDate': '2025-03-27T00:00:00.0000000Z',
    });

    expect(item.isSeries, isTrue);
    expect(item.childCount, 24);
    expect(item.totalEpisodeCount, 24);
  });

  test('剧集总集数兼容 Emby 容器计数回退', () {
    final item = MediaBrowserItem.fromJson(const {
      'Id': 'series-2',
      'Name': '旧版剧集',
      'Type': 'Series',
      'ProductionYear': 2019,
      'ChildCount': 12,
    });

    expect(item.totalEpisodeCount, 12);
  });

  test('Emby 剧集总集数为已看与未看集数之和', () {
    final item = MediaBrowserItem.fromJson(const {
      'Id': 'series-2b',
      'Name': '已部分观看剧集',
      'Type': 'Series',
      'UserData': {'PlayCount': 5, 'UnplayedItemCount': 19},
    });

    expect(item.totalEpisodeCount, 24);
  });

  test('剧集总集数忽略零值并回退到有效计数', () {
    final item = MediaBrowserItem.fromJson(const {
      'Id': 'series-3',
      'Name': '部分计数剧集',
      'Type': 'Series',
      'ChildCount': 0,
      'RecursiveItemCount': 18,
      'EpisodeCount': 12,
    });

    expect(item.totalEpisodeCount, 18);
  });

  test('MediaBrowserItemPage.fromJson 过滤无 ID 条目并计算 hasMore', () {
    final page = MediaBrowserItemPage.fromJson(const {
      'Items': [
        {'Id': 'a', 'Name': 'A', 'Type': 'Movie'},
        {'Name': '无 ID', 'Type': 'Movie'},
      ],
      'TotalRecordCount': 30,
      'StartIndex': 0,
    });

    expect(page.items, hasLength(1));
    expect(page.total, 30);
    expect(page.hasMore, isTrue);

    final lastPage = MediaBrowserItemPage.fromJson(const {
      'Items': [
        {'Id': 'z', 'Name': 'Z', 'Type': 'Movie'},
      ],
      'TotalRecordCount': 25,
      'StartIndex': 24,
    });
    expect(lastPage.hasMore, isFalse);
  });

  test('MediaBrowserAuthResult.fromJson 解析认证响应', () {
    final result = MediaBrowserAuthResult.fromJson(const {
      'AccessToken': 'token-1',
      'User': {'Id': 'user-1', 'Name': 'Alice'},
    });

    expect(result.accessToken, 'token-1');
    expect(result.user.id, 'user-1');
    expect(result.user.name, 'Alice');
  });

  test('tick 与秒互转保持 100ns 单位语义', () {
    expect(mediaBrowserTicksToSeconds(10000000), 1);
    expect(mediaBrowserTicksToSeconds(null), 0);
    expect(mediaBrowserTicksToSeconds(-5), 0);
    expect(secondsToMediaBrowserTicks(90), 900000000);
    expect(mediaBrowserTicksToSeconds(secondsToMediaBrowserTicks(1234)), 1234);
  });

  test('MediaBrowserItem.fromJson 解析音频曲目的音乐字段', () {
    final track = MediaBrowserItem.fromJson(const {
      'Id': 'track-1',
      'Name': '曲目一',
      'Type': 'Audio',
      'Album': '专辑一',
      'AlbumId': 'album-1',
      'AlbumArtist': '专辑艺术家',
      'Artists': ['艺术家 A', '艺术家 B'],
      'IndexNumber': 3,
      'ParentIndexNumber': 2,
      'RunTimeTicks': 2400000000,
      'ImageTags': {'Primary': 'primary-tag'},
    });

    expect(track.isAudio, isTrue);
    expect(track.isMusicAlbum, isFalse);
    expect(track.album, '专辑一');
    expect(track.albumId, 'album-1');
    expect(track.indexNumber, 3);
    expect(track.parentIndexNumber, 2);
    // 专辑艺术家优先于参与艺术家。
    expect(track.displayArtist, '专辑艺术家');

    final withoutAlbumArtist = MediaBrowserItem.fromJson(const {
      'Id': 'track-2',
      'Name': '曲目二',
      'Type': 'Audio',
      'Artists': ['艺术家 A', ''],
    });
    expect(withoutAlbumArtist.displayArtist, '艺术家 A');
  });

  test('MusicAlbum 条目识别与艺术家回退', () {
    final album = MediaBrowserItem.fromJson(const {
      'Id': 'album-1',
      'Name': '专辑一',
      'Type': 'MusicAlbum',
      'AlbumArtist': '',
      'Artists': [],
      'ChildCount': 10,
      'ProductionYear': 2023,
    });

    expect(album.isMusicAlbum, isTrue);
    expect(album.childCount, 10);
    expect(album.displayArtist, isNull);
  });

  test('MediaBrowserLibrary.fromJson 解析路径、启用状态并保留高级 LibraryOptions', () {
    final library = MediaBrowserLibrary.fromJson(const {
      'ItemId': 'library-1',
      'Name': '电影库',
      'CollectionType': 'movies',
      'Locations': ['/media/movies', '/media/movies'],
      'LibraryOptions': {
        'Enabled': false,
        'EnableRealtimeMonitor': true,
        'MetadataSavers': ['Nfo'],
      },
    });

    expect(library.id, 'library-1');
    expect(library.name, '电影库');
    expect(library.collectionType, 'movies');
    expect(library.paths, ['/media/movies']);
    expect(library.enabled, isFalse);
    expect(library.libraryOptions['EnableRealtimeMonitor'], isTrue);
    expect(library.libraryOptions['MetadataSavers'], ['Nfo']);
    expect(library.libraryOptions['PathInfos'], [
      {'Path': '/media/movies'},
    ]);
  });

  test('MediaBrowserLibrary.fromJson 可从 PathInfos 回退路径并展示未知类型', () {
    final library = MediaBrowserLibrary.fromJson(const {
      'Id': 'library-2',
      'Name': '自定义库',
      'CollectionType': 'custom-type',
      'LibraryOptions': {
        'PathInfos': [
          {'Path': '/media/custom'},
          {'Path': ''},
          {'Path': '/media/custom'},
        ],
      },
    });

    expect(library.id, 'library-2');
    expect(library.collectionType, 'custom-type');
    expect(library.paths, ['/media/custom']);
    expect(library.enabled, isTrue);
  });
}
