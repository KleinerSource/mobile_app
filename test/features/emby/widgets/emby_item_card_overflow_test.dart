import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/features/emby/models/emby_models.dart';
import 'package:omm/features/i18n/badge_position_provider.dart';
import 'package:omm/features/privacy/privacy_providers.dart';
import 'package:omm/features/emby/providers/emby_providers.dart';
import 'package:omm/features/emby/widgets/emby_item_card.dart';

class _PrivacyState extends PrivacyShieldNotifier {
  _PrivacyState(this.enabled);

  final bool enabled;

  @override
  bool build() => enabled;
}

class _BadgePositionsState extends BadgePositionsNotifier {
  _BadgePositionsState(this.value);

  final BadgePositions value;

  @override
  BadgePositions build() => value;
}

EmbyItem _item({String type = 'Movie', String series = ''}) {
  return EmbyItem.fromJson({
    'Id': 'item-1',
    'Name': '非常长的影片标题用来测试两行折行之后的卡片高度表现',
    'Type': type,
    'ProductionYear': 2024,
    'RunTimeTicks': 54000000000,
    if (series.isNotEmpty) 'SeriesName': series,
    if (series.isNotEmpty) 'ParentIndexNumber': 1,
    if (series.isNotEmpty) 'IndexNumber': 2,
    'UserData': const {'PlaybackPositionTicks': 0},
  });
}

Future<void> _pumpGrid(WidgetTester tester, double aspectRatio) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  final width = (390.0 - 44 - 20) / 3;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        privacyShieldProvider.overrideWith(() => _PrivacyState(false)),
        badgePositionsProvider.overrideWith(
          () => _BadgePositionsState(const BadgePositions()),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: GridView.count(
            crossAxisCount: 3,
            childAspectRatio: aspectRatio,
            crossAxisSpacing: 10,
            mainAxisSpacing: 14,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            children: [
              EmbyItemCard(item: _item(), urls: _urls(), width: width),
              EmbyItemCard(
                item: _item(type: 'Episode', series: '很长的剧集名称同样会占满一行'),
                urls: _urls(),
                width: width,
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

// EmbyServerUrls 只做字符串拼接，不触网。
EmbyServerUrls _urls() => EmbyServerUrls(baseUrl: 'http://img.test', token: 't');

void main() {
  testWidgets('aspect 0.5 下 CatalogMovieCard 内容溢出网格单元（复现）', (
    tester,
  ) async {
    await _pumpGrid(tester, 0.5);
    final exception = tester.takeException();
    expect(exception, isNotNull, reason: '0.5 宽高比应触发 RenderFlex 溢出');
  });

  testWidgets('加高网格单元后不再溢出', (tester) async {
    await _pumpGrid(tester, 0.43);
    expect(tester.takeException(), isNull);
  });
}
