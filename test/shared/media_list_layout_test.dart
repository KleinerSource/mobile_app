import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/models/movie.dart';
import 'package:omm/core/sources/media/dbo/db_online_movie.dart';
import 'package:omm/core/sources/media/media_browser/media_browser_config.dart';
import 'package:omm/core/sources/media/media_browser/media_browser_models.dart';
import 'package:omm/core/sources/media/media_browser/media_browser_server_urls.dart';
import 'package:omm/features/db_online/widgets/db_online_movie_card.dart';
import 'package:omm/features/media_browser/widgets/media_browser_item_card.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/media_list_layout.dart';
import 'package:omm/shared/movie_card.dart';
import 'package:omm/shared/poster.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _card(int index) => switch (index % 3) {
  0 => MovieCard(
    movie: MovieListItem(id: index, title: '影片', year: 2024, runtime: 90),
    posterUrlBuilder: (_) => '',
  ),
  1 => DbOnlineMovieCard(
    movie: DbOnlineMovie(id: '$index', number: 'ABC-001', title: '影片'),
    config: null,
    width: double.infinity,
  ),
  _ => MediaBrowserItemCard(
    item: MediaBrowserItem(id: '$index', name: '影片', type: 'Movie'),
    urls: MediaBrowserServerUrls(
      config: MediaBrowserConfig.emby,
      baseUrl: 'https://example.test',
      token: '',
    ),
    width: double.infinity,
  ),
};

void main() {
  Future<Widget> app(Widget child) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    return ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(body: child),
      ),
    );
  }

  for (final (width, columns) in [
    (390.0, 3),
    (599.0, 3),
    (600.0, 4),
    (819.0, 4),
    (820.0, 5),
    (1099.0, 5),
    (1100.0, 6),
  ]) {
    testWidgets('不同来源影片在 $width 宽的容器中使用 $columns 列及相同几何尺寸', (tester) async {
      // 屏幕比容器宽，防止列数再次依赖整屏 MediaQuery。
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        await app(
          Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: GridView.builder(
                padding: MediaListLayout.padding,
                gridDelegate: const MediaGridDelegate(),
                itemCount: 12,
                itemBuilder: (_, index) =>
                    SizedBox.expand(key: ValueKey(index), child: _card(index)),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final first = tester.getRect(find.byKey(const ValueKey(0)));
      final second = tester.getRect(find.byKey(const ValueKey(1)));
      final lastInRow = tester.getRect(find.byKey(ValueKey(columns - 1)));
      final nextRow = tester.getRect(find.byKey(ValueKey(columns)));
      expect(first.left, 22);
      expect(lastInRow.right, closeTo(width - 22, 0.001));
      expect(second.left - first.right, closeTo(10, 0.001));
      expect(nextRow.top - first.bottom, closeTo(14, 0.001));
      expect(first.width / first.height, closeTo(0.5, 0.001));
      expect(second.size, first.size);
      for (final poster in find.byType(Poster).evaluate()) {
        final size = tester.getSize(find.byWidget(poster.widget));
        expect(size.width / size.height, closeTo(2 / 3, 0.001));
      }
      expect(tester.takeException(), isNull);
    });
  }

}
