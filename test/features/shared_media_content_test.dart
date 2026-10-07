import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/models/movie.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/core/sources/media/media_browser/media_browser_config.dart';
import 'package:omm/core/sources/media/media_browser/media_browser_models.dart';
import 'package:omm/features/home/continue_watching_section.dart';
import 'package:omm/features/media_browser/providers/media_browser_providers.dart';
import 'package:omm/features/media_browser/widgets/media_browser_item_card.dart';
import 'package:omm/features/oh_my_media/lists/add_to_list_sheet.dart';
import 'package:omm/features/oh_my_media/lists/create_list_dialog.dart';
import 'package:omm/features/oh_my_media/lists/lists_providers.dart';
import 'package:omm/features/oh_my_media/movies/omm_movie_paged_sliver.dart';
import 'package:omm/features/privacy/privacy_mask.dart';
import 'package:omm/features/privacy/privacy_providers.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/poster.dart';

class _PrivacyOff extends PrivacyShieldNotifier {
  @override
  bool build() => false;
}

Future<ProviderContainer> _pump(WidgetTester tester, Widget child) async {
  SharedPreferences.setMockInitialValues({
    'visited.movies.v1.': ['movie-1'],
  });
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        privacyShieldProvider.overrideWith(_PrivacyOff.new),
      ],
      child: MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
}

void main() {
  testWidgets('继续观看保留年份占位、隐私层和独立播放点击', (tester) async {
    var opened = 0;
    var resumed = 0;
    await _pump(
      tester,
      ContinueWatchingSection(
        entries: [
          ContinueWatchingEntry(
            privacyId: 42,
            title: '影片',
            year: 2024,
            meta: null,
            progress: 0,
            showEmptyProgress: true,
            onOpen: () => opened++,
            onResume: () => resumed++,
          ),
        ],
      ),
    );
    expect(tester.widget<Poster>(find.byType(Poster)).year, 2024);
    expect(find.byType(PrivacyMask), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      0,
    );
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    expect(resumed, 1);
    expect(opened, 0);
    await tester.tap(find.byType(Poster));
    expect(opened, 1);
    expect(find.text(''), findsNothing);
  });

  testWidgets('未开始播放的公共卡片默认不显示空进度槽', (tester) async {
    await _pump(
      tester,
      ContinueWatchingSection(
        entries: [
          ContinueWatchingEntry(
            privacyId: 42,
            title: '下一集',
            meta: '',
            onOpen: () {},
            onResume: () {},
          ),
        ],
      ),
    );
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('OMM 公共列表保留选择和新资源插槽、观看进度及点击', (tester) async {
    var taps = 0;
    await _pump(
      tester,
      OmmMovieListRow(
        movie: const MovieListItem(
          id: 1,
          title: '影片',
          watchRecord: WatchRecordSummary(progressRatio: 0.4),
        ),
        urlBuilder: (uuid) => uuid,
        leading: const Icon(Icons.check_circle_rounded),
        titleTrailing: const Icon(Icons.fiber_new),
        onTap: () => taps++,
      ),
    );
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.byIcon(Icons.fiber_new), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);
    await tester.tap(find.byType(PrivacyText));
    expect(taps, 1);
  });

  testWidgets('MediaBrowser 公共行保留封面回退和访问置灰，收藏内容保留原规则', (tester) async {
    final item = MediaBrowserItem.fromJson(const {
      'Id': 'movie-1',
      'Name': '影片',
      'Type': 'Movie',
      'BackdropImageTags': ['backdrop'],
    });
    final urls = MediaBrowserServerUrls(
      config: MediaBrowserConfig.emby,
      baseUrl: 'http://mb.test',
      token: 't',
    );
    await _pump(
      tester,
      Column(
        children: [
          MediaBrowserListRow(item: item, urls: urls, onTap: () {}),
          MediaBrowserListRowContent(
            item: item,
            posterUrl: null,
            imageHeaders: urls.imageHeaders,
            onTap: () {},
            selecting: true,
            selected: true,
            borderRadius: 12,
          ),
        ],
      ),
    );
    final posters = tester.widgetList<Poster>(find.byType(Poster)).toList();
    expect(posters.first.url, urls.heroImage(item));
    expect(posters.last.url, isNull);
    final titles = tester
        .widgetList<PrivacyText>(find.byType(PrivacyText))
        .toList();
    final colors = appColors(tester.element(find.byType(Column).first));
    expect(titles.first.style.color, colors.muted);
    expect(titles.last.style.color, colors.text);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('片单弹窗取消不返回数据，确认返回修剪名称与选中颜色', (tester) async {
    ({String name, int hue})? result;
    await _pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await showCreateListDialog(context),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    var l = AppL10n.of(tester.element(find.byType(AlertDialog)));
    await tester.enterText(find.byType(TextField), '不保存');
    await tester.tap(find.widgetWithText(TextButton, l.cancel));
    await tester.pumpAndSettle();
    expect(result, isNull);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    l = AppL10n.of(tester.element(find.byType(AlertDialog)));
    await tester.enterText(find.byType(TextField), '  我的片单  ');
    final hue = AppHues.all.last;
    await tester.tap(find.byKey(ValueKey(hue)));
    await tester.tap(find.widgetWithText(FilledButton, l.listCreate));
    await tester.pumpAndSettle();
    expect(result, (name: '我的片单', hue: hue));
    expect(tester.takeException(), isNull);
  });

  testWidgets('加入片单入口创建后将当前影片加入新片单', (tester) async {
    final container = await _pump(
      tester,
      const AddToListSheet(movieId: 42, movieTitle: '影片'),
    );
    final before = container.read(listsProvider).length;
    final l = AppL10n.of(tester.element(find.byType(AddToListSheet)));
    await tester.tap(find.text(l.newList));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '新片单');
    await tester.tap(find.widgetWithText(FilledButton, l.listCreate));
    await tester.pumpAndSettle();
    final lists = container.read(listsProvider);
    expect(lists, hasLength(before + 1));
    expect(lists.last.name, '新片单');
    expect(lists.last.movieIds, [42]);
    expect(tester.takeException(), isNull);
  });
}
