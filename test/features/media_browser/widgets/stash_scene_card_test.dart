import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omm/features/media_browser/api/media_browser_config.dart';
import 'package:omm/features/media_browser/api/media_browser_server_urls.dart';
import 'package:omm/features/media_browser/models/media_browser_models.dart';
import 'package:omm/features/media_browser/widgets/stash_scene_card.dart';
import 'package:omm/features/privacy/privacy_providers.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

class _PrivacyState extends PrivacyShieldNotifier {
  @override
  bool build() => false;
}

class _FakePreviewPlayer implements StashPreviewPlayer {
  final durationNotifier = ValueNotifier(const Duration(seconds: 10));
  final positionNotifier = ValueNotifier(Duration.zero);
  String? openedUrl;
  Map<String, String>? openedHeaders;
  Duration? lastSeek;
  int stopCount = 0;
  int disposeCount = 0;

  @override
  ValueListenable<Duration> get duration => durationNotifier;

  @override
  ValueListenable<Duration> get position => positionNotifier;

  @override
  Widget buildVideo({BoxFit fit = BoxFit.cover}) =>
      const ColoredBox(color: Colors.black);

  @override
  Future<void> open(String url, {Map<String, String>? headers}) async {
    openedUrl = url;
    openedHeaders = headers;
  }

  @override
  Future<void> seek(Duration position) async {
    lastSeek = position;
    positionNotifier.value = position;
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
  }
}

MediaBrowserItem _item() => const MediaBrowserItem(
  id: 'scene-1',
  name: '测试 Scene',
  type: 'Movie',
  runTimeTicks: 1200000000,
  productionYear: 2024,
  communityRating: 8.6,
  previewPath: '/previews/scene-1.mp4',
  people: [MediaBrowserPerson(id: 'p1', name: '演员一')],
);

MediaBrowserServerUrls _urls() => MediaBrowserServerUrls(
  config: MediaBrowserConfig.stash,
  baseUrl: 'http://stash.test:9999',
  token: 'stash-key',
);

Widget _app({required Widget child}) => ProviderScope(
  overrides: [privacyShieldProvider.overrideWith(_PrivacyState.new)],
  child: MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    home: Scaffold(body: child),
  ),
);

void main() {
  test('自动预览候选在上一张封面离开视口时切到下一张', () {
    expect(
      stashPreviewItemIndexForScroll(
        scrollOffset: 0,
        cardHeight: 200,
        itemGap: 14,
        itemCount: 3,
      ),
      0,
    );
    expect(
      stashPreviewItemIndexForScroll(
        scrollOffset: 199,
        cardHeight: 200,
        itemGap: 14,
        itemCount: 3,
      ),
      0,
    );
    expect(
      stashPreviewItemIndexForScroll(
        scrollOffset: 200,
        cardHeight: 200,
        itemGap: 14,
        itemCount: 3,
      ),
      1,
    );
    expect(
      stashPreviewItemIndexForScroll(
        scrollOffset: 414,
        cardHeight: 200,
        itemGap: 14,
        itemCount: 3,
      ),
      2,
    );
  });

  testWidgets('Stash 卡片占满一行并保持 16:9', (tester) async {
    final player = _FakePreviewPlayer();
    await tester.pumpWidget(
      _app(
        child: StashPreviewScope(
          child: StashSceneCard(
            item: _item(),
            urls: _urls(),
            width: 356,
            playerFactory: () => player,
            onTap: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    final size = tester.getSize(find.byType(StashSceneCard));
    expect(size.width, 356);
    expect(size.height, closeTo(200, 0.5));
  });

  testWidgets('标记为顶部候选时自动启动预览，取消候选时释放', (tester) async {
    final player = _FakePreviewPlayer();
    var autoPlay = true;

    Widget buildCard() => _app(
      child: StashPreviewScope(
        child: StashSceneCard(
          item: _item(),
          urls: _urls(),
          width: 356,
          playerFactory: () => player,
          autoPlayPreview: autoPlay,
          onTap: () {},
        ),
      ),
    );

    await tester.pumpWidget(buildCard());
    await tester.pump();
    expect(player.openedUrl, 'http://stash.test:9999/previews/scene-1.mp4');

    autoPlay = false;
    await tester.pumpWidget(buildCard());
    await tester.pump();
    expect(player.stopCount, 1);
    expect(player.disposeCount, 1);
  });

  testWidgets('长按后横向拖动按预览时间轴 seek，并在松手时释放', (tester) async {
    final player = _FakePreviewPlayer();
    await tester.pumpWidget(
      _app(
        child: StashPreviewScope(
          child: StashSceneCard(
            item: _item(),
            urls: _urls(),
            width: 356,
            playerFactory: () => player,
            onTap: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getTopLeft(find.byType(StashSceneCard)) + const Offset(22, 100),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(player.openedUrl, 'http://stash.test:9999/previews/scene-1.mp4');
    expect(player.openedHeaders, {'ApiKey': 'stash-key'});

    await gesture.moveBy(const Offset(156, 0));
    await tester.pump();
    expect(player.lastSeek, const Duration(seconds: 5));

    await gesture.up();
    await tester.pump();
    expect(player.stopCount, 1);
    expect(player.disposeCount, 1);
  });
}
