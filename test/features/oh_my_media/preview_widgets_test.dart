import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omm/core/api/services/configs_api.dart';
import 'package:omm/core/api/services/configs_extended_api.dart';
import 'package:omm/core/models/preview_config.dart';
import 'package:omm/features/oh_my_media/configs/configs_providers.dart';
import 'package:omm/features/oh_my_media/configs/configs_repository.dart';
import 'package:omm/features/oh_my_media/configs/preview_settings_page.dart';
import 'package:omm/features/oh_my_media/movie_detail/movie_detail_media_viewers.dart';
import 'package:omm/features/oh_my_media/movies/movies_providers.dart';
import 'package:omm/features/settings/settings_common.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/preview/preview_surface.dart';

void main() {
  testWidgets('预览设置页加载配置并保存编辑后的值', (tester) async {
    final repository = _FakeConfigsRepository(
      const PreviewConfig(segments: 24, segmentDuration: 1.5),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          configsRepositoryProvider.overrideWithValue(repository),
          previewConfigProvider.overrideWith((ref) async => repository.current),
        ],
        child: _localizedApp(const PreviewSettingsPage()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('预览生成'), findsOneWidget);
    expect(find.text('配置预览视频、Sprite 和 VTT 的生成策略。'), findsOneWidget);
    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(fields.first.controller?.text, '24');
    expect(fields[1].controller?.text, '1.5');

    await tester.scrollUntilVisible(
      find.byType(SettingsSaveButton),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byType(SettingsSaveButton));
    await tester.pumpAndSettle();

    expect(repository.saved?.segments, 24);
    expect(find.text('预览配置已保存'), findsOneWidget);
  });

  testWidgets('已生成预览视频排在预告片和预览图之前', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          extraFanartsProvider(7).overrideWith((ref) async => const ['image']),
        ],
        child: _localizedApp(
          const Scaffold(
            body: MovieExtraFanartSection(
              movieId: 7,
              movieTitle: '长视频',
              canFetch: false,
              previewVideoUrl: 'https://omm.example/preview.mp4',
              trailerUrl: 'https://omm.example/trailer.mp4',
              posterUrl: null,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final preview = tester.getRect(find.text('预览视频'));
    final trailer = tester.getRect(find.text('预告片'));
    expect(preview.left, lessThan(trailer.left));
  });

  testWidgets('横版预览覆盖层只在有预览视频时显示动态标识', (tester) async {
    await tester.pumpWidget(
      _localizedApp(
        const Scaffold(
          body: SizedBox(
            width: 320,
            height: 180,
            child: PreviewGestureSurface(
              onTap: _noop,
              showAvailabilityBadge: true,
              availabilityLabel: '预览视频',
              child: SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.motion_photos_on_rounded), findsOneWidget);
    expect(find.bySemanticsLabel('预览视频'), findsOneWidget);

    await tester.pumpWidget(
      _localizedApp(
        const Scaffold(
          body: SizedBox(
            width: 320,
            height: 180,
            child: PreviewGestureSurface(
              onTap: _noop,
              child: SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byIcon(Icons.motion_photos_on_rounded), findsNothing);
  });

  testWidgets('滑动和 Live Photo 指示器固定右上角并向左避让其他图标', (tester) async {
    await tester.pumpWidget(
      _localizedApp(
        const Scaffold(
          body: SizedBox(
            width: 320,
            height: 180,
            child: PreviewGestureSurface(
              onTap: _noop,
              loading: true,
              showHint: true,
              showAvailabilityBadge: true,
              child: SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final surface = tester.getRect(find.byType(PreviewGestureSurface));
    final loading = tester.getRect(find.byType(CircularProgressIndicator));
    final swipe = tester.getRect(find.byIcon(Icons.swipe_rounded));
    final livePhoto = tester.getRect(
      find.byIcon(Icons.motion_photos_on_rounded),
    );

    expect(livePhoto.right, closeTo(surface.right - 10, 0.01));
    expect(livePhoto.top, greaterThanOrEqualTo(surface.top + 10));
    expect(loading.right, lessThan(swipe.left));
    expect(swipe.right, lessThan(livePhoto.left));
    expect(loading.overlaps(swipe), isFalse);
    expect(swipe.overlaps(livePhoto), isFalse);
  });
}

void _noop() {}

Widget _localizedApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    locale: const Locale('zh'),
    home: child,
  );
}

class _FakeConfigsRepository extends ConfigsRepository {
  _FakeConfigsRepository(this.current)
    : super(ConfigsApi(Dio()), ConfigsExtendedApi(Dio()));

  PreviewConfig current;
  PreviewConfig? saved;

  @override
  Future<PreviewConfig> getPreview() async => current;

  @override
  Future<PreviewConfig> savePreview(PreviewConfig config) async {
    current = config;
    saved = config;
    return config;
  }
}
