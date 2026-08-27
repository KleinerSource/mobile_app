import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/config/server_config.dart';
import 'package:omm/core/models/db_online_movie.dart';
import 'package:omm/features/db_online/db_online_home_page.dart';

void main() {
  const config = ServerConfig(baseUrl: 'http://example.test');

  Future<void> pumpCard(WidgetTester tester, {required bool canPlay}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DbOnlineMovieCard(
            movie: DbOnlineMovie(
              id: 'movie-1',
              number: 'ABC-001',
              title: '示例影片',
              canPlay: canPlay,
            ),
            config: config,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('can_play=true 时显示在线播放角标', (tester) async {
    await pumpCard(tester, canPlay: true);

    expect(find.text('在线播放'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
  });

  testWidgets('can_play=false 时不显示在线播放角标', (tester) async {
    await pumpCard(tester, canPlay: false);

    expect(find.text('在线播放'), findsNothing);
  });

  testWidgets('首页卡片点击回调使用 dbonline 番号进入详情链路', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DbOnlineMovieCard(
            movie: const DbOnlineMovie(
              id: 'db-id',
              number: 'ABC-001',
              title: '示例影片',
            ),
            config: config,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(DbOnlineMovieCard));
    expect(tapped, isTrue);
  });
}
