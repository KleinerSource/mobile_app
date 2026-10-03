import 'package:flutter_test/flutter_test.dart';

import 'package:omm/core/sources/media/dbo/db_online_following.dart';
import 'package:omm/core/sources/media/dbo/db_online_resource_filter.dart';

void main() {
  group('dbOnlineResourceConditionLetters', () {
    test('按固定顺序 m,c,s,p 归一化', () {
      expect(
        dbOnlineResourceConditionLetters({'p', 's', 'c', 'm'}),
        ['m', 'c', 's', 'p'],
      );
      expect(dbOnlineResourceConditionLetters({'s'}), ['s']);
      expect(dbOnlineResourceConditionLetters({'x', 'p'}), ['p']);
      expect(dbOnlineResourceConditionLetters({}), isEmpty);
    });
  });

  group('dbOnlineMovieFilterByLetters', () {
    test('映射全词并跳过搜索端点不支持的 p', () {
      expect(dbOnlineMovieFilterByLetters({'m', 'p'}), 'magnets');
      expect(
        dbOnlineMovieFilterByLetters({'p', 'c', 's', 'm'}),
        'magnets,subtitle,single',
      );
    });

    test('空集或仅选 p 时返回 all', () {
      expect(dbOnlineMovieFilterByLetters({}), 'all');
      expect(dbOnlineMovieFilterByLetters({'p'}), 'all');
    });
  });

  group('dbOnlineSanitizeResourceConditions', () {
    test('白名单过滤未知字母并按固定顺序去重', () {
      expect(
        dbOnlineSanitizeResourceConditions(['s', 'x', 'm', 's', 'p']),
        ['m', 's', 'p'],
      );
      expect(dbOnlineSanitizeResourceConditions(['x']), isEmpty);
      expect(dbOnlineSanitizeResourceConditions([]), isEmpty);
    });
  });

  group('DbOnlineFollowingFilter 默认值', () {
    test('basic 默认有磁链，filter_by 默认串为全空条件', () {
      const filter = DbOnlineFollowingFilter();
      expect(filter.basic, dbOnlineFollowingDefaultBasic);
      expect(filter.filterBy, '0:t:m::::');
      expect(dbOnlineFollowingDefaultFilterBy, '0:t:::::');
    });

    test('含 p 的 basic 拼入 filter_by', () {
      const filter = DbOnlineFollowingFilter(basic: ['m', 'p']);
      expect(filter.filterBy, '0:t:m,p::::');
    });
  });

  group('DbOnlineFollowingPreset.fromJson', () {
    test('basic 保留 p（可播放）并丢弃未知字母', () {
      final preset = DbOnlineFollowingPreset.fromJson(const {
        'id': 1,
        'name': '在线播',
        'basic': 'p,m,x',
      });
      expect(preset.filter.basic, ['m', 'p']);
    });
  });
}
