import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/config/server_config.dart';
import 'package:omm/features/db_online/navigation/db_online_movie_navigation.dart';

void main() {
  group('dbOnlineMovieWebUrl', () {
    test('常规地址：番号 + video_id 消歧', () {
      const config = ServerConfig(baseUrl: 'https://example.test');
      expect(
        dbOnlineMovieWebUrl(config, code: 'ABC-001', videoId: 'v-9'),
        'https://example.test/video/ABC-001?video_id=v-9',
      );
    });

    test('无 video_id 时省略查询参数', () {
      const config = ServerConfig(baseUrl: 'https://example.test');
      expect(
        dbOnlineMovieWebUrl(config, code: 'ABC-001'),
        'https://example.test/video/ABC-001',
      );
    });

    test('服务根地址带 /api 或尾斜杠时仍指向网页根', () {
      const config = ServerConfig(baseUrl: 'https://example.test/api/');
      expect(
        dbOnlineMovieWebUrl(config, code: 'ABC-001', videoId: '1'),
        'https://example.test/video/ABC-001?video_id=1',
      );
    });

    test('番号需要编码时保留可读路径段', () {
      const config = ServerConfig(baseUrl: 'https://example.test');
      final url = dbOnlineMovieWebUrl(
        config,
        code: 'FC2 PPV 123',
        videoId: 'a b',
      );
      // query 值的空格按表单编码为 +，与 Uri.queryParameters 约定一致。
      expect(url, 'https://example.test/video/FC2%20PPV%20123?video_id=a+b');
    });

    test('配置缺失或番号为空时返回 null', () {
      const config = ServerConfig(baseUrl: 'https://example.test');
      expect(dbOnlineMovieWebUrl(null, code: 'ABC-001'), isNull);
      expect(dbOnlineMovieWebUrl(config, code: '  '), isNull);
      expect(dbOnlineMovieWebUrl(config, code: ''), isNull);
    });
  });
}
