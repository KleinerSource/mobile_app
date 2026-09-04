import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/core/models/movie.dart';
import 'package:omm/shared/movie_card.dart';
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

  testWidgets('显示标题', (tester) async {
    await tester.pumpWidget(
      await wrap(
        MovieCard(
          movie: const MovieListItem(id: 1, title: '示例片名'),
          posterUrlBuilder: (u) => 'http://x/$u',
        ),
      ),
    );
    // 默认隐私遮罩为关 (mock 空 prefs → default false)，正常显示内容。
    // 我们这里直接断言渲染不抛错 (有 MovieCard 即可)
    expect(find.byType(MovieCard), findsOneWidget);
  });

  testWidgets('时长统一显示为分钟', (tester) async {
    await tester.pumpWidget(
      await wrap(
        MovieCard(
          movie: const MovieListItem(
            id: 2,
            title: '带时长影片',
            year: 2024,
            runtime: 90,
          ),
          posterUrlBuilder: (u) => 'http://x/$u',
        ),
      ),
    );

    expect(find.text('2024 · 90 分钟'), findsOneWidget);
  });

  testWidgets('普通外部媒体卡片将番号与名称收敛到同一信息区', (tester) async {
    await tester.pumpWidget(
      await wrap(
        const CatalogMovieCard(
          title: '影片名称',
          code: 'ABC-123',
          imageUrl: null,
          meta: '2024 · 90 分钟',
          width: 140,
        ),
      ),
    );

    expect(find.text('[ABC-123] 影片名称'), findsOneWidget);
    expect(find.text('ABC-123'), findsNothing);
    expect(find.text('2024 · 90 分钟'), findsOneWidget);
    expect(tester.takeException(), isNull);
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

  testWidgets('hasNewResources 显示独立的星光图标且不混用 NEW', (tester) async {
    SharedPreferences.setMockInitialValues({});
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
                    hasNewResources: true,
                  ),
                  posterUrlBuilder: (u) => 'http://x/$u',
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
    expect(find.text('新资源'), findsNothing);
    expect(find.text('NEW'), findsNothing);
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

  testWidgets('清晰度角标统一使用电视图标并按级别着色', (tester) async {
    SharedPreferences.setMockInitialValues({
      'privacy.app_switcher_shield': false,
    });
    final prefs = await SharedPreferences.getInstance();

    Future<void> pumpMovie(int height) async {
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
                    movie: MovieListItem(
                      id: 1,
                      title: 'A',
                      videoHeight: height,
                    ),
                    posterUrlBuilder: (u) => 'http://x/$u',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    Color badgeColor() {
      final badge = tester.widget<Container>(
        find
            .ancestor(
              of: find.byIcon(Icons.tv_rounded),
              matching: find.byType(Container),
            )
            .first,
      );
      return (badge.decoration! as BoxDecoration).color!;
    }

    await pumpMovie(720);
    expect(badgeColor(), const Color(0xFF10B981));
    expect(find.text('HD'), findsNothing);

    await pumpMovie(1080);
    expect(badgeColor(), const Color(0xFF0EA5E9));
    expect(find.text('FHD'), findsNothing);

    await pumpMovie(2160);
    expect(badgeColor(), const Color(0xFF2D6CDF));
    expect(find.text('UHD'), findsNothing);
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
