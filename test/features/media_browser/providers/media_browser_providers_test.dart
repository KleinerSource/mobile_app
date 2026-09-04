import 'package:flutter_test/flutter_test.dart';
import 'package:omm/features/media_browser/api/media_browser_config.dart';
import 'package:omm/features/media_browser/models/media_browser_models.dart';
import 'package:omm/features/media_browser/providers/media_browser_providers.dart';

void main() {
  test('MediaBrowserServerUrls.thumbnail Thumb 优先、Primary 兜底、无图为 null', () {
    final urls = MediaBrowserServerUrls(
      config: MediaBrowserConfig.jellyfin,
      baseUrl: 'http://test',
    );

    // 分集一般只有 Primary 静帧：退回 Primary 端点（此前误请求 Thumb
    // 端点导致封面 404 不显示）。
    final still = const MediaBrowserItem(
      id: 'ep-1',
      name: '第 1 集',
      type: 'Episode',
      primaryImageTag: 'primary-tag',
    );
    expect(
      urls.thumbnail(still),
      'http://test/Items/ep-1/Images/Primary'
      '?maxWidth=440&quality=90&tag=primary-tag',
    );

    // 带 Thumb 图的条目用 Thumb 端点 + Thumb tag。
    final wide = const MediaBrowserItem(
      id: 'ep-2',
      name: '第 2 集',
      type: 'Episode',
      primaryImageTag: 'primary-tag',
      thumbImageTag: 'thumb-tag',
    );
    expect(
      urls.thumbnail(wide),
      'http://test/Items/ep-2/Images/Thumb'
      '?maxWidth=440&quality=90&tag=thumb-tag',
    );

    expect(
      urls.thumbnail(
        const MediaBrowserItem(id: 'ep-3', name: '第 3 集', type: 'Episode'),
      ),
      isNull,
    );
  });

  test('personImage Emby 用 /Images/Primary + tag，无 tag 返回 null', () {
    final urls = MediaBrowserServerUrls(
      config: MediaBrowserConfig.emby,
      baseUrl: 'http://test',
    );
    const withTag = MediaBrowserPerson(
      id: 'p-1',
      name: '演员一',
      primaryImageTag: 'person-img-tag',
    );
    expect(
      urls.personImage(withTag),
      'http://test/emby/Items/p-1/Images/Primary'
      '?maxWidth=240&quality=90&tag=person-img-tag',
    );
    // People 条目没有 PrimaryImageTag 说明服务器上无头像。
    expect(
      urls.personImage(const MediaBrowserPerson(id: 'p-2', name: '演员二')),
      isNull,
    );
  });

  test('飞牛图片和播放请求头都包含登录令牌、Cookie 和客户端标识', () {
    final urls = MediaBrowserServerUrls(
      config: MediaBrowserConfig.feiniu,
      baseUrl: 'http://test',
      token: 'Bearer test-token',
      cookie: 'sid=session-1',
    );

    expect(urls.directHeaders, {
      'Authorization': 'Bearer test-token',
      'Cookie': 'sid=session-1',
      'X-Trim-Client': 'web',
      'X-Trim-Client-Version': '616',
    });
    expect(urls.imageHeaders, urls.directHeaders);
  });

  test('飞牛图片 URL 使用 sys/img 和原生宽度参数', () {
    final urls = MediaBrowserServerUrls(
      config: MediaBrowserConfig.feiniu,
      baseUrl: 'http://test/v',
    );

    expect(
      urls.poster('item-1', tag: '/58/06/poster.webp'),
      'http://test/v/api/v1/sys/img/58/06/poster.webp?w=400',
    );
    expect(
      urls.personImage(
        const MediaBrowserPerson(
          id: 'person-1',
          name: '演员一',
          profilePath: '58/06/person.webp',
        ),
      ),
      'http://test/v/api/v1/sys/img/58/06/person.webp?w=240',
    );
  });

  test('Stash 图片、预览和直链使用根地址并携带 ApiKey', () {
    final urls = MediaBrowserServerUrls(
      config: MediaBrowserConfig.stash,
      baseUrl: 'http://stash.test:9999',
      token: 'stash-key',
    );

    expect(
      urls.poster('scene-1', tag: '/screenshots/scene-1.jpg'),
      'http://stash.test:9999/screenshots/scene-1.jpg',
    );
    expect(
      urls.backdrop('scene-1', tag: 'screenshots/scene-1.jpg'),
      'http://stash.test:9999/screenshots/scene-1.jpg',
    );
    expect(
      urls.preview('/previews/scene-1.mp4'),
      'http://stash.test:9999/previews/scene-1.mp4',
    );
    expect(urls.imageHeaders, {'ApiKey': 'stash-key'});
    expect(urls.directHeaders, {'ApiKey': 'stash-key'});
  });

  test('Stash 预览资源为空时返回 null，且不把路径当静态图', () {
    final urls = MediaBrowserServerUrls(
      config: MediaBrowserConfig.stash,
      baseUrl: 'http://stash.test:9999',
      token: 'stash-key',
    );

    expect(urls.preview(null), isNull);
    expect(urls.preview(''), isNull);
  });

  test('首页展示图跳过空背景路径并按背景到海报回退', () {
    final urls = MediaBrowserServerUrls(
      config: MediaBrowserConfig.stash,
      baseUrl: 'http://stash.test:9999',
      token: 'stash-key',
    );

    expect(
      urls.heroImage(
        const MediaBrowserItem(
          id: 'scene-1',
          name: 'Scene',
          type: 'Movie',
          primaryImageTag: '/images/poster.webp',
          backdropImageTags: ['', '/images/screenshot.jpg'],
        ),
      ),
      'http://stash.test:9999/images/screenshot.jpg',
    );
    expect(
      urls.heroImage(
        const MediaBrowserItem(
          id: 'scene-2',
          name: 'Scene',
          type: 'Movie',
          primaryImageTag: '/images/poster.webp',
        ),
      ),
      'http://stash.test:9999/images/poster.webp',
    );
  });

  test('includeItemTypesForView 按库类型映射条目过滤', () {
    expect(includeItemTypesForView('movies'), 'Movie');
    expect(includeItemTypesForView('TVShows'), 'Series');
    // 音乐库出「最新专辑」行。
    expect(includeItemTypesForView('music'), 'MusicAlbum');
    expect(includeItemTypesForView('Music'), 'MusicAlbum');
    // 混合库（类型为空或未知）不过滤，展示全部条目。
    expect(includeItemTypesForView(null), isNull);
    expect(includeItemTypesForView('mixed'), isNull);
    expect(includeItemTypesForView('homevideos'), isNull);
  });

  test('isSkippableViewType 识别无海报内容的库', () {
    // 音乐库已改为展示专辑行,不再跳过
    expect(isSkippableViewType('music'), isFalse);
    expect(isSkippableViewType('books'), isTrue);
    expect(isSkippableViewType('audiobooks'), isTrue);
    expect(isSkippableViewType('photos'), isTrue);
    expect(isSkippableViewType('playlists'), isTrue);
    expect(isSkippableViewType('movies'), isFalse);
    expect(isSkippableViewType('tvshows'), isFalse);
    expect(isSkippableViewType(null), isFalse);
    expect(isSkippableViewType('mixed'), isFalse);
  });

  test('MediaBrowserViewLatestRequest 全字段相等语义', () {
    const request = MediaBrowserViewLatestRequest(
      serverId: 's1',
      viewId: 'v1',
      includeItemTypes: 'Movie',
    );

    expect(
      request,
      const MediaBrowserViewLatestRequest(
        serverId: 's1',
        viewId: 'v1',
        includeItemTypes: 'Movie',
      ),
    );
    expect(
      request,
      isNot(
        const MediaBrowserViewLatestRequest(
          serverId: 's1',
          viewId: 'v1',
          includeItemTypes: 'Series',
        ),
      ),
    );
    expect(
      request,
      isNot(const MediaBrowserViewLatestRequest(serverId: 's1', viewId: 'v2')),
    );
  });
}
