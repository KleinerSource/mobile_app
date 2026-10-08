import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/features/cache/disk_cache.dart';
import 'package:omm/features/cache/music_cache.dart';
import 'package:omm/features/settings/cache_management_page.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

void main() {
  Future<void> open(WidgetTester tester, _Disk disk, _Music music) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          diskCacheServiceProvider.overrideWithValue(disk),
          musicCacheServiceProvider.overrideWithValue(music),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: CacheManagementPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('取消不清理，图片、其他与音乐入口分别清理并更新统计', (tester) async {
    final disk = _Disk();
    final music = _Music();
    await open(tester, disk, music);
    await tester.tap(find.text('清理缓存').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(disk.categories, isEmpty);
    for (var index = 0; index < 3; index++) {
      await tester.ensureVisible(find.text('清理缓存').at(index));
      await tester.tap(find.text('清理缓存').at(index));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('清理缓存'),
        ),
      );
      await tester.pumpAndSettle();
    }
    expect(disk.categories, [CacheCategory.image, CacheCategory.other]);
    expect(music.clears, 1);
    expect(disk.reads, greaterThan(1));
    expect(music.reads, greaterThan(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('一键清理期间禁用重复操作，部分失败仍刷新统计且可重试', (tester) async {
    final disk = _Disk()..pending = Completer<void>();
    final music = _Music()..fail = true;
    await open(tester, disk, music);
    await tester.ensureVisible(find.text('一键清理'));
    await tester.tap(find.text('一键清理'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('一键清理'),
      ),
    );
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton).first).onPressed,
      isNull,
    );
    expect(disk.allClears, 1);
    expect(music.clears, 1);
    disk.pending!.complete();
    await tester.pumpAndSettle();
    expect(find.textContaining('清理缓存失败'), findsOneWidget);
    expect(disk.reads, 2);
    expect(music.reads, 2);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton).first).onPressed,
      isNotNull,
    );
    music.fail = false;
    disk.pending = null;
    await tester.tap(find.text('一键清理'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('一键清理'),
      ),
    );
    await tester.pumpAndSettle();
    expect(disk.allClears, 2);
    expect(music.clears, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('清理期间离开页面不会访问已销毁的 ref', (tester) async {
    final disk = _Disk()..pending = Completer<void>();
    await open(tester, disk, _Music());
    await tester.ensureVisible(find.text('一键清理'));
    await tester.tap(find.text('一键清理'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('一键清理'),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    disk.pending!.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

class _Disk extends DiskCacheService {
  final categories = <CacheCategory>[];
  int reads = 0;
  int allClears = 0;
  Completer<void>? pending;
  @override
  Future<CacheUsage> usage() async {
    reads++;
    return const CacheUsage(imageBytes: 1024, otherBytes: 2048);
  }

  @override
  Future<void> clear(CacheCategory category) async => categories.add(category);
  @override
  Future<void> clearAll() async {
    allClears++;
    await pending?.future;
  }
}

class _Music extends MusicCacheService {
  int reads = 0;
  int clears = 0;
  bool fail = false;
  @override
  Future<int> usage() async {
    reads++;
    return 4096;
  }

  @override
  Future<void> clear() async {
    clears++;
    if (fail) throw StateError('模拟失败');
  }
}
