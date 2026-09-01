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
}
