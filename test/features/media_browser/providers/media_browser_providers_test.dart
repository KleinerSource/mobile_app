import 'package:flutter_test/flutter_test.dart';
import 'package:omm/features/media_browser/providers/media_browser_providers.dart';

void main() {
  test('includeItemTypesForView 按库类型映射条目过滤', () {
    expect(includeItemTypesForView('movies'), 'Movie');
    expect(includeItemTypesForView('TVShows'), 'Series');
    // 混合库（类型为空或未知）不过滤，展示全部条目。
    expect(includeItemTypesForView(null), isNull);
    expect(includeItemTypesForView('mixed'), isNull);
    expect(includeItemTypesForView('homevideos'), isNull);
  });

  test('isSkippableViewType 识别无海报内容的库', () {
    expect(isSkippableViewType('music'), isTrue);
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
