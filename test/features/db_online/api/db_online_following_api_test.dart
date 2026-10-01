import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/sources/media/dbo/db_online_api.dart';
import 'package:omm/core/sources/media/dbo/db_online_following.dart';

import '../support/following_test_support.dart';

void main() {
  test('关注筛选保留网页七段格式和风格组合，不添加 can_play', () {
    const defaults = DbOnlineFollowingFilter();
    expect(defaults.filterBy, '0:t:m::::');
    expect(defaults.filterBy.split(':'), hasLength(7));
    const filter = DbOnlineFollowingFilter(
      basic: ['m', 'c', 's'],
      styles: ['9', '8'],
      year: '2025',
      month: '03',
    );
    expect(filter.filterBy, '0:t:m,c,s:9,8:2025::03');
    expect(filter.followExternalId, '9,8');
    expect(filter.copyWith(category: '1').followExternalId, isEmpty);
    expect(
      filter.copyWith(styles: ['1', '2', '3', '4', '5', '6']).followExternalId,
      isEmpty,
    );
    expect(
      filter.copyWith(year: '2024', month: '02').filterBy,
      '0:t:m,c,s:9,8:2024::02',
    );
  });

  test('影片查询传递排序、分页和完整筛选条件', () async {
    final backend = FollowingTestBackend();
    final dio = backend.dio('https://a.test');
    addTearDown(dio.close);
    final api = DbOnlineApi(dio);
    final result = await api.taggedMoviesPage(
      filterBy: '4:t:c,s:8:2025::02',
      page: 2,
      sortBy: 'release',
      orderBy: 'asc',
    );
    expect(result.movies.single.id, 'film');
    expect(backend.to('/subs/tags').single.queryParameters, {
      'filter_by': '4:t:c,s:8:2025::02',
      'page': 2,
      'limit': 24,
      'sort_by': 'release',
      'order_by': 'asc',
    });
  });

  test('预设创建、编辑、排序、删除复用已有契约', () async {
    final backend = FollowingTestBackend();
    final dio = backend.dio('https://a.test');
    addTearDown(dio.close);
    final api = DbOnlineApi(dio).following;
    final first = await api.savePreset(
      const DbOnlineFollowingPreset(
        id: 0,
        name: '一',
        filter: DbOnlineFollowingFilter(),
      ),
    );
    final second = await api.savePreset(
      const DbOnlineFollowingPreset(
        id: 0,
        name: '二',
        filter: DbOnlineFollowingFilter(styles: ['9']),
      ),
    );
    await api.savePreset(
      DbOnlineFollowingPreset(
        id: first.id,
        name: '修改',
        remark: '备注',
        filter: first.filter,
      ),
    );
    await api.reorderPresets([second.id, first.id]);
    expect((await api.presets()).map((item) => item.name), ['二', '修改']);
    expect(backend.to('/following/presets/reorder').single.data, {
      'ids': [2, 1],
    });
    await api.deletePreset(second.id);
    expect((await api.presets()).single.remark, '备注');
  });

  test('用户 ID 保留字符串，并反馈重复关注与批量取消', () async {
    final backend = FollowingTestBackend();
    final dio = backend.dio('https://a.test');
    addTearDown(dio.close);
    final api = DbOnlineApi(dio).following;
    expect((await api.followUser('00001')).userId, '00001');
    expect((await api.followUser('00001')).created, isFalse);
    await api.followUser('00002');
    backend.refreshFailed = 1;
    final result = await api.refreshUsers();
    expect(result.failed, 1);
    expect(result.users.map((user) => user.userId), ['00002', '00001']);
    await api.unfollowUsers(['00001', '00002']);
    expect(await api.users(), isEmpty);
    expect(
      backend
          .to('/following/users')
          .singleWhere((request) => request.method == 'DELETE')
          .data,
      {
        'user_ids': ['00001', '00002'],
      },
    );
  });

  test('评论资源按 review_id 补全，保留原始请求字段并去重', () async {
    final backend = FollowingTestBackend();
    final review = followingReview(1, '影片');
    (review['magnets'] as List).add({
      'magnet': 'magnet:?xt=urn:btih:abcdef',
      'name': '重复',
    });
    backend.respond = (request) => request.path == '/users/resources/metadata'
        ? {
            'success': true,
            'data': {
              'items': [
                {
                  'review_id': 1,
                  'magnets': [
                    {
                      'name': '补全',
                      'magnet': 'magnet:?xt=urn:btih:ABCDEF',
                      'tags': ['高清', '字幕', '破解'],
                    },
                    {'name': '重复', 'magnet': 'magnet:?xt=urn:btih:abcdef'},
                  ],
                },
              ],
            },
          }
        : null;
    final dio = backend.dio('https://a.test');
    addTearDown(dio.close);
    final item = DbOnlineReviewResourceItem.fromJson(review);
    expect(item.magnets, hasLength(1));
    final metadata = await DbOnlineApi(dio).following.resourceMetadata([item]);
    final enriched = item.withMagnets(metadata[1]!);
    expect(enriched.magnets, hasLength(1));
    expect(enriched.magnets.single.tags, ['高清', '字幕', '破解']);
    expect(
      (backend.to('/users/resources/metadata').single.data as Map)['items'],
      [
        {'review_id': 1, 'magnets': review['magnets']},
      ],
    );
  });
}
