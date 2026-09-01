import 'package:flutter_test/flutter_test.dart';
import 'package:omm/features/jellyfin/providers/jellyfin_providers.dart';

void main() {
  test('includeItemTypesForView 按库类型映射条目过滤', () {
    expect(includeItemTypesForView('movies'), 'Movie');
    expect(includeItemTypesForView('TVShows'), 'Series');
    // 混合库（类型为空或未知）不过滤，展示全部条目。
    expect(includeItemTypesForView(null), isNull);
    expect(includeItemTypesForView('mixed'), isNull);
  });

  test('isSkippableViewType 识别无海报内容的库', () {
    expect(isSkippableViewType('music'), isTrue);
    expect(isSkippableViewType('books'), isTrue);
    expect(isSkippableViewType('movies'), isFalse);
    expect(isSkippableViewType(null), isFalse);
  });

  test('JellyfinViewLatestRequest 全字段相等语义', () {
    const request = JellyfinViewLatestRequest(
      serverId: 's1',
      viewId: 'v1',
      includeItemTypes: 'Movie',
    );

    expect(
      request,
      const JellyfinViewLatestRequest(
        serverId: 's1',
        viewId: 'v1',
        includeItemTypes: 'Movie',
      ),
    );
    expect(
      request,
      isNot(
        const JellyfinViewLatestRequest(serverId: 's2', viewId: 'v1'),
      ),
    );
  });
}
