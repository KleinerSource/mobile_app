import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/models/movie.dart';
import 'package:omm/features/media_browser/models/media_browser_models.dart';
import 'package:omm/features/media_browser/providers/media_browser_providers.dart';
import 'package:omm/features/media_browser/api/media_browser_config.dart';
import 'package:omm/features/media_browser/widgets/media_browser_item_card.dart';
import 'package:omm/features/i18n/badge_position_provider.dart';
import 'package:omm/features/privacy/privacy_providers.dart';
import 'package:omm/shared/movie_card.dart';
import 'package:omm/shared/poster.dart';

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

const _longTitle = '非常长的影片标题用来测试两行折行之后的卡片高度表现';

MediaBrowserItem _mediaBrowserItem({
  String type = 'Movie',
  String series = '',
}) {
  return MediaBrowserItem.fromJson({
    'Id': 'item-1',
    'Name': _longTitle,
    'Type': type,
    'ProductionYear': 2024,
    'RunTimeTicks': 54000000000,
    'CommunityRating': 7.6,
    if (series.isNotEmpty) 'SeriesName': series,
    if (series.isNotEmpty) 'ParentIndexNumber': 1,
    if (series.isNotEmpty) 'IndexNumber': 2,
    'UserData': const {'PlaybackPositionTicks': 0},
  });
}

MovieListItem _ommItem() {
  return MovieListItem.fromJson(const {
    'id': 1,
    'title': _longTitle,
    'year': 2024,
    'runtime': 90,
    'rating': 7.6,
    'poster_uuid': 'uuid-1',
  });
}

// MediaBrowserServerUrls 只做字符串拼接，不触网。
MediaBrowserServerUrls _urls() => MediaBrowserServerUrls(
  config: MediaBrowserConfig.emby,
  baseUrl: 'http://img.test',
  token: 't',
);

Widget _grid(List<Widget> children, double aspectRatio) {
  return ProviderScope(
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
          children: children,
        ),
      ),
    ),
  );
}

/// 测试字体（Ahem）度量与真机 Inter 不同，卡片文字行的亚像素差异会被
/// 放大成溢出条；这里以 OMM MovieCard 在同一环境下的表现为基准，
/// 断言 MediaBrowser 卡片的几何不超过 OMM。
Future<void> _pumpBoth(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  const aspectRatio = 0.5;
  final width = (390.0 - 44 - 20) / 3;

  await tester.pumpWidget(
    _grid([
      MovieCard(
        movie: _ommItem(),
        posterUrlBuilder: (uuid) => 'http://img.test/$uuid',
      ),
    ], aspectRatio),
  );
  await tester.pump();
  final ommException = tester.takeException();
  final ommHeight = tester.getSize(find.byType(Column).first).height;

  await tester.pumpWidget(
    _grid([
      MediaBrowserItemCard(
        item: _mediaBrowserItem(),
        urls: _urls(),
        width: width,
      ),
      MediaBrowserItemCard(
        item: _mediaBrowserItem(type: 'Episode', series: '很长的剧集名称同样会占满一行'),
        urls: _urls(),
        width: width,
      ),
    ], aspectRatio),
  );
  await tester.pump();
  final mediaBrowserException = tester.takeException();
  final mediaBrowserHeight = tester.getSize(find.byType(Column).first).height;

  // ignore: avoid_print
  print(
    'geometry: omm=$ommHeight (exception=${ommException != null}) '
    'mediaBrowser=$mediaBrowserHeight (exception=${mediaBrowserException != null})',
  );

  // 几何一致：卡片总高与 OMM 差异在亚像素级。
  expect((mediaBrowserHeight - ommHeight).abs(), lessThan(2.0));
  // 溢出状态一致：OMM 不溢出时 MediaBrowser 也不溢出。
  if (ommException == null) {
    expect(
      mediaBrowserException,
      isNull,
      reason: 'OMM 不溢出时 MediaBrowser 卡片也不应溢出',
    );
  }
}

void main() {
  test('剧集 meta 显示起止年份、总集数和连载状态', () {
    final ended = MediaBrowserItem.fromJson(const {
      'Id': 'series-1',
      'Name': '已完结剧集',
      'Type': 'Series',
      'ProductionYear': 2019,
      'EndDate': '2024-05-20T00:00:00Z',
      'Status': 'Ended',
      'ChildCount': 24,
    });
    final ongoing = MediaBrowserItem.fromJson(const {
      'Id': 'series-2',
      'Name': '连载剧集',
      'Type': 'Series',
      'ProductionYear': 2019,
      'EndDate': '2024-05-20T00:00:00Z',
      'Status': 'CONTINUING',
      'ChildCount': 12,
    });
    final legacy = MediaBrowserItem.fromJson(const {
      'Id': 'series-3',
      'Name': '旧版剧集',
      'Type': 'Series',
      'ProductionYear': 2019,
      'EndDate': '2024-05-20T00:00:00Z',
      'ChildCount': 8,
    });

    expect(mediaBrowserItemMetaText(ended), '2019 - 2024 · 24集');
    expect(mediaBrowserItemMetaText(ongoing), '2019 - 现在 · 12集');
    expect(mediaBrowserItemMetaText(legacy), '2019 - 2024 · 8集');
  });

  testWidgets('MediaBrowser 卡片风格尺寸与 OMM MovieCard 一致（0.5 网格）', (tester) async {
    await _pumpBoth(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('meta 行格式与 OMM 一致；无在线播放角标', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _grid([
        MediaBrowserItemCard(
          item: _mediaBrowserItem(),
          urls: _urls(),
          width: 132,
        ),
        MediaBrowserItemCard(
          item: _mediaBrowserItem(type: 'Episode', series: '很长的剧集名称同样会占满一行'),
          urls: _urls(),
          width: 132,
        ),
      ], 0.4),
    );
    await tester.pump();
    tester.takeException();

    expect(find.text('2024 · 90m'), findsOneWidget);
    expect(find.text('S01E02 · 很长的剧集名称同样会占满一行'), findsOneWidget);
    // OMM 卡片没有在线播放角标；播放入口在详情页。
    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
  });

  testWidgets('播放中的条目显示贴海报底部的进度条', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final item = MediaBrowserItem.fromJson(const {
      'Id': 'item-2',
      'Name': '观看中的影片',
      'Type': 'Movie',
      'RunTimeTicks': 72000000000,
      'UserData': {'PlaybackPositionTicks': 3600000000},
    });
    await tester.pumpWidget(
      _grid([MediaBrowserItemCard(item: item, urls: _urls(), width: 132)], 0.4),
    );
    await tester.pump();

    final progressRect = tester.getRect(find.byType(LinearProgressIndicator));
    final posterRect = tester.getRect(find.byType(Poster));
    expect(
      progressRect.bottom,
      moreOrLessEquals(posterRect.bottom, epsilon: 1),
    );
    // 5% 进度（360s / 7200s）。
    final progress = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(progress.value, moreOrLessEquals(0.05, epsilon: 0.01));
  });
}
