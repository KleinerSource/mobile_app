import 'package:flutter_test/flutter_test.dart';
import 'package:omm/features/oh_my_media/movie_detail/resources_sheet.dart';

void main() {
  test('ED2K 下载器优先使用服务端能力字段', () {
    expect(supportsEd2kDownloader('custom', true), isTrue);
    expect(supportsEd2kDownloader('thunder', false), isFalse);
  });

  test('ED2K 下载器兼容默认名称和 OpenList 实例名称', () {
    expect(supportsEd2kDownloader(' thunder ', null), isTrue);
    expect(supportsEd2kDownloader('openlist:家庭盘', null), isTrue);
    expect(supportsEd2kDownloader('qbittorrent', null), isFalse);
  });
}
