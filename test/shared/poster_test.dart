import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/shared/poster.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('网络海报按布局物理宽度解码并限制磁盘缓存尺寸', (tester) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        locale: Locale('zh'),
        home: Center(
          child: SizedBox(
            width: 120,
            child: Poster(url: 'https://example.com/poster.jpg', title: '海报'),
          ),
        ),
      ),
    );

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(image.memCacheWidth, 360);
    expect(image.maxWidthDiskCache, 1080);
  });

  testWidgets('零宽布局不传入非法内存缓存尺寸', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        locale: Locale('zh'),
        home: Center(
          child: SizedBox(
            width: 0,
            child: Poster(url: 'https://example.com/poster.jpg', title: '海报'),
          ),
        ),
      ),
    );

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(image.memCacheWidth, isNull);
  });

  testWidgets('图片请求可以携带媒体服务器请求头', (tester) async {
    const headers = {
      'Authorization': 'Bearer test-token',
      'X-Trim-Client': 'web',
    };
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        locale: Locale('zh'),
        home: Center(
          child: Poster(
            url: 'https://example.com/poster.jpg',
            title: '海报',
            httpHeaders: headers,
          ),
        ),
      ),
    );

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(image.httpHeaders, headers);
  });

  testWidgets('多张海报最多显示三张并排封面', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        locale: Locale('zh'),
        home: Center(
          child: SizedBox(
            width: 300,
            child: Poster(
              urls: [
                'https://example.com/poster-1.jpg',
                'https://example.com/poster-2.jpg',
                'https://example.com/poster-3.jpg',
                'https://example.com/poster-4.jpg',
              ],
              title: '媒体库',
              aspectRatio: 5 / 3,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(CachedNetworkImage), findsNWidgets(3));
    expect(
      tester
          .widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage))
          .map((image) => image.imageUrl),
      [
        'https://example.com/poster-1.jpg',
        'https://example.com/poster-2.jpg',
        'https://example.com/poster-3.jpg',
      ],
    );
  });
}
