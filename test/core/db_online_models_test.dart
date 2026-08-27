import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/models/db_online_movie.dart';

void main() {
  test('dbonline 详情模型解析实体、资源、媒体库和播放源', () {
    final detail = DbOnlineMovieDetail.fromJson(const {
      'code': 'ABC-001',
      'title': '示例影片',
      'overview': '影片简介',
      'video_id': 'vid-1',
      'duration': 120,
      'has_cnsub': true,
      'director': {'external_id': 'd1', 'name': '导演'},
      'maker': {'name': '片商'},
      'categories': [
        {'external_id': '88', 'name': '剧情'},
      ],
      'actors': [
        {
          'external_id': 'a1',
          'name': '演员',
          'name_zht': '演員',
          'other_name': 'Alias',
          'gender': '♀',
          'uncensored': true,
        },
      ],
      'relative_movies': [
        {
          'id': 'rel-1',
          'number': 'DEF-002',
          'title': '关联影片',
          'duration': 90,
          'can_play': true,
        },
      ],
      'magnets': [
        {'name': '磁链', 'magnet': 'magnet:?xt=urn:btih:x', 'size_mb': '12.5'},
      ],
      'ed2ks': [
        {'name': '文件', 'ed2k': 'ed2k://|file|x'},
      ],
      'library': {'in_library': true, 'name': 'Emby'},
      'can_play': true,
      'play_sources': [
        {'id': 3, 'name': 'JavDB'},
      ],
    });

    expect(detail.code, 'ABC-001');
    expect(detail.overview, '影片简介');
    expect(detail.duration, 120);
    expect(detail.hasCnsub, isTrue);
    expect(detail.director?.externalId, 'd1');
    expect(detail.categories.single.name, '剧情');
    expect(detail.actors.single.gender, '♀');
    expect(detail.actors.single.nameZht, '演員');
    expect(detail.actors.single.otherName, 'Alias');
    expect(detail.actors.single.uncensored, isTrue);
    expect(detail.relativeMovies.single.number, 'DEF-002');
    expect(detail.relativeMovies.single.duration, 90);
    expect(detail.relativeMovies.single.canPlay, isTrue);
    expect(detail.magnets.single.sizeMb, 12.5);
    expect(detail.ed2ks.single.ed2k, startsWith('ed2k:'));
    expect(detail.library?.inLibrary, isTrue);
    expect(detail.playSources.single.id, 3);
  });

  test('播放剧集按指定清晰度选择地址并回退到默认地址', () {
    const episode = DbOnlinePlayEpisode(
      index: 0,
      name: '第 1 集',
      url: '/default.m3u8',
      qualities: [
        DbOnlinePlayQuality(name: '1080p', url: '/1080.m3u8'),
        DbOnlinePlayQuality(name: '720p', url: '/720.m3u8'),
      ],
    );

    expect(episode.urlForQuality('720p'), '/720.m3u8');
    expect(episode.urlForQuality('missing'), '/default.m3u8');
    expect(episode.urlForQuality(null), '/default.m3u8');
  });
}
