import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/config/server_config.dart';
import 'package:omm/features/db_online/models/db_online_movie.dart';
import 'package:omm/features/db_online/widgets/db_online_movie_card.dart';
import 'package:omm/features/i18n/badge_position_provider.dart';
import 'package:omm/features/privacy/privacy_providers.dart';
import 'package:omm/shared/poster.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

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

void main() {
  const config = ServerConfig(baseUrl: 'http://example.test');

  Future<void> pumpCard(
    WidgetTester tester, {
    required bool canPlay,
    VoidCallback? onTap,
    bool privacyOn = false,
    bool hasCnsub = false,
    String? duration,
    BadgePositions? badgePositions,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          privacyShieldProvider.overrideWith(() => _PrivacyState(privacyOn)),
          badgePositionsProvider.overrideWith(
            () =>
                _BadgePositionsState(badgePositions ?? const BadgePositions()),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(
            body: DbOnlineMovieCard(
              movie: DbOnlineMovie(
                id: 'movie-1',
                number: 'ABC-001',
                title: '示例影片',
                canPlay: canPlay,
                hasCnsub: hasCnsub,
                duration: duration,
              ),
              config: config,
              onTap: onTap,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('can_play=true 时显示在线播放角标', (tester) async {
    await pumpCard(tester, canPlay: true);

    expect(find.text('在线播放'), findsNothing);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

    final poster = tester.getRect(find.byType(Poster));
    final badgeIcon = tester.getRect(find.byIcon(Icons.play_arrow_rounded));
    expect(badgeIcon.left, lessThan(poster.center.dx));
    expect(badgeIcon.top, lessThan(poster.center.dy));
  });

  testWidgets('时长统一显示为分钟', (tester) async {
    await pumpCard(tester, canPlay: false, duration: '90m');

    expect(find.text('90 分钟'), findsOneWidget);
  });

  testWidgets('can_play=false 时不显示在线播放角标', (tester) async {
    await pumpCard(tester, canPlay: false);

    expect(find.text('在线播放'), findsNothing);
  });

  testWidgets('has_cnsub=true 时显示字幕 badge，元数据不再显示中字', (tester) async {
    await pumpCard(tester, canPlay: false, hasCnsub: true);

    expect(find.byIcon(Icons.closed_caption_rounded), findsOneWidget);
    expect(find.text('中字'), findsNothing);
  });

  testWidgets('封面角标设置控制 DBO 字幕 badge 的位置和显示', (tester) async {
    await pumpCard(
      tester,
      canPlay: false,
      hasCnsub: true,
      badgePositions: const BadgePositions(subtitle: BadgeCorner.topRight),
    );

    final poster = tester.getRect(find.byType(Poster));
    final badge = tester.getRect(find.byIcon(Icons.closed_caption_rounded));
    expect(badge.top, lessThan(poster.center.dy));
    expect(badge.left, greaterThan(poster.center.dx));

    await pumpCard(
      tester,
      canPlay: false,
      hasCnsub: true,
      badgePositions: const BadgePositions(subtitleEnabled: false),
    );
    expect(find.byIcon(Icons.closed_caption_rounded), findsNothing);
  });

  testWidgets('首页卡片点击回调使用 dbonline 番号进入详情链路', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          privacyShieldProvider.overrideWith(() => _PrivacyState(false)),
          badgePositionsProvider.overrideWith(
            () => _BadgePositionsState(const BadgePositions()),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          locale: const Locale('zh'),
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
      ),
    );
    await tester.tap(find.byType(DbOnlineMovieCard));
    expect(tapped, isTrue);
  });

  testWidgets('dbonline 卡片长按不启用 InkWell 按压反馈', (tester) async {
    await pumpCard(tester, canPlay: false, onTap: () {});

    final inkWell = tester.widget<InkWell>(find.byType(InkWell));
    expect(inkWell.onTap, isNull);
    expect(
      find.descendant(
        of: find.byType(DbOnlineMovieCard),
        matching: find.byWidgetPredicate(
          (widget) => widget is GestureDetector && widget.onTap != null,
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('隐私模式下首次点击只揭示 DBO 卡片，第二次才触发详情', (tester) async {
    var tapped = false;
    await pumpCard(
      tester,
      canPlay: true,
      privacyOn: true,
      onTap: () => tapped = true,
    );

    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    expect(find.text('▆▆▆▆▆'), findsNWidgets(3));

    await tester.tap(find.byType(DbOnlineMovieCard));
    await tester.pump();
    expect(tapped, isFalse);
    expect(find.byIcon(Icons.visibility_off_outlined), findsNothing);
    expect(find.text('▆▆▆▆▆'), findsNothing);
    expect(find.text('示例影片'), findsNWidgets(2));
    expect(find.text('ABC-001'), findsOneWidget);

    await tester.tap(find.byType(DbOnlineMovieCard));
    expect(tapped, isTrue);
  });
}
