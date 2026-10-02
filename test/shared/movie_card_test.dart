import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/models/movie.dart';
import 'package:omm/shared/movie_card.dart';
import 'package:omm/shared/poster.dart';
import 'package:omm/shared/preview/preview_surface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

void main() {
  Future<Widget> wrap(Widget child) async {
    // MovieCard 现在用 ConsumerWidget · privacy 状态依赖 sharedPrefsProvider
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    return ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(
          body: Center(child: SizedBox(width: 140, child: child)),
        ),
      ),
    );
  }

  testWidgets('横屏封面按 fanart、thumb、poster 优先级选择', (tester) async {
    Future<String?> pumpMovie(
      MovieListItem movie, {
      bool landscape = true,
    }) async {
      String? renderedUuid;
      await tester.pumpWidget(
        await wrap(
          MovieCard(
            movie: movie,
            landscape: landscape,
            posterUrlBuilder: (uuid) {
              renderedUuid = uuid;
              return '';
            },
          ),
        ),
      );
      return renderedUuid;
    }

    expect(
      await pumpMovie(
        const MovieListItem(
          id: 3,
          fanartUuid: 'fanart',
          thumbUuid: 'thumb',
          posterUuid: 'poster',
        ),
      ),
      'fanart',
    );
    expect(
      await pumpMovie(
        const MovieListItem(id: 4, thumbUuid: 'thumb', posterUuid: 'poster'),
      ),
      'thumb',
    );
    expect(
      await pumpMovie(const MovieListItem(id: 5, posterUuid: 'poster')),
      'poster',
    );
    expect(
      await pumpMovie(
        const MovieListItem(
          id: 6,
          fanartUuid: 'fanart',
          thumbUuid: 'thumb',
          posterUuid: 'poster',
        ),
        landscape: false,
      ),
      'poster',
    );
  });

  testWidgets('横版预览指示器与右上角角标共用同一堆叠层', (tester) async {
    const movie = MovieListItem(
      id: 10,
      title: '带预览影片',
      rating: 8.6,
      hasExternalSubtitle: true,
      hasNewResources: true,
    );

    await tester.pumpWidget(
      await wrap(
        MovieCard(
          movie: movie,
          landscape: true,
          posterUrlBuilder: (uuid) => 'http://x/$uuid',
        ),
      ),
    );
    await tester.pump();

    final cardWithoutIndicator = tester.getRect(find.byType(MovieCard));
    final newResourcesWithoutIndicator = tester.getRect(
      find.byIcon(Icons.auto_awesome_rounded),
    );
    expect(
      newResourcesWithoutIndicator.right,
      closeTo(cardWithoutIndicator.right - 6, 1.1),
    );

    await tester.pumpWidget(
      await wrap(
        MovieCard(
          movie: movie,
          landscape: true,
          posterUrlBuilder: (uuid) => 'http://x/$uuid',
          landscapeOverlayTopRightIndicator: const Icon(
            Icons.swipe_rounded,
            size: 20,
            color: Colors.white70,
          ),
          landscapeOverlay: const PreviewGestureSurface(
            onTap: _noop,
            renderTopRightIndicators: false,
            child: SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.pump();

    final card = tester.getRect(find.byType(MovieCard));
    final swipe = tester.getRect(find.byIcon(Icons.swipe_rounded));
    final rating = tester.getRect(find.byType(RatingBadge));
    final subtitle = tester.getRect(find.byIcon(Icons.closed_caption_rounded));
    final newResources = tester.getRect(
      find.byIcon(Icons.auto_awesome_rounded),
    );

    expect(swipe.right, closeTo(card.right - 10, 1.1));
    expect(rating.right, lessThan(swipe.left));
    expect(subtitle.right, lessThan(swipe.left));
    expect(newResources.right, lessThan(swipe.left));
    expect(rating.overlaps(swipe), isFalse);
    expect(subtitle.overlaps(swipe), isFalse);
    expect(newResources.overlaps(swipe), isFalse);
  });

  testWidgets('completed=true 显示已看完角标 (隐私关闭)', (tester) async {
    SharedPreferences.setMockInitialValues({
      'privacy.app_switcher_shield': false,
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 140,
                child: MovieCard(
                  movie: const MovieListItem(
                    id: 1,
                    title: 'A',
                    watchRecord: WatchRecordSummary(
                      progressRatio: 1.0,
                      completed: true,
                    ),
                  ),
                  posterUrlBuilder: (u) => 'http://x/$u',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('已看完'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('未完成有进度时显示进度条 (隐私关闭)', (tester) async {
    SharedPreferences.setMockInitialValues({
      'privacy.app_switcher_shield': false,
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 140,
                child: MovieCard(
                  movie: const MovieListItem(
                    id: 1,
                    title: 'A',
                    watchRecord: WatchRecordSummary(
                      progressRatio: 0.4,
                      completed: false,
                    ),
                  ),
                  posterUrlBuilder: (u) => 'http://x/$u',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('外挂字幕与 AI 字幕同时存在时徽章正常堆叠', (tester) async {
    await tester.pumpWidget(
      await wrap(
        MovieCard(
          movie: const MovieListItem(
            id: 9,
            title: 'AI 字幕卡片',
            hasExternalSubtitle: true,
            hasAiSubtitle: true,
          ),
          posterUrlBuilder: (u) => 'http://x/$u',
        ),
      ),
    );

    expect(find.byTooltip('外挂字幕'), findsOneWidget);
    expect(find.byTooltip('AI 字幕'), findsOneWidget);
  });
}

void _noop() {}
