import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/features/media_browser/widgets/media_browser_library_refresh_indicator.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('实际媒体库使用的进度组件支持确定和不确定进度', (tester) async {
    Future<void> pump(double? ratio) => tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(body: MediaBrowserLibraryRefreshIndicator(ratio: ratio)),
      ),
    );
    await pump(0.42);
    expect(
      tester
          .widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          )
          .value,
      0.42,
    );
    expect(find.text('42%'), findsOneWidget);
    await pump(null);
    expect(
      tester
          .widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          )
          .value,
      isNull,
    );
    expect(find.text('42%'), findsNothing);
  });
}
