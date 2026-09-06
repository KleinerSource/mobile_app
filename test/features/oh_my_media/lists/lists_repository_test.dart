import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:omm/core/config/server_config_provider.dart';
import 'package:omm/features/oh_my_media/lists/list_detail_page.dart';
import 'package:omm/features/oh_my_media/lists/list_model.dart';
import 'package:omm/features/oh_my_media/lists/lists_repository.dart';
import 'package:omm/features/oh_my_media/movies/movies_providers.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

void main() {
  test('可以从合集移除已不存在详情的影片 ID', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = ListsRepository(await SharedPreferences.getInstance());
    final listId = repository.loadAll().first.id;

    await repository.addMovie(listId, 404);
    expect(repository.loadAll().first.movieIds, contains(404));

    await repository.removeMovie(listId, 404);

    expect(repository.loadAll().first.movieIds, isNot(contains(404)));
  });

  testWidgets('详情加载失败时仍可长按移除合集中的影片记录', (tester) async {
    const listId = 'test_list';
    final list = FavoriteList(
      id: listId,
      name: '测试合集',
      hue: 240,
      movieIds: [404],
    );
    SharedPreferences.setMockInitialValues({
      'favorite_lists.v1': FavoriteList.encodeAll([list]),
      'favorite_lists.removed_builtin_v1': true,
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          movieDetailProvider(404).overrideWith((ref) async {
            throw StateError('movie deleted');
          }),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          locale: Locale('zh'),
          home: ListDetailPage(listId: listId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('加载失败'), findsOneWidget);
    await tester.longPress(find.text('加载失败'));
    await tester.pumpAndSettle();

    expect(find.text('确定从列表中移除这条失效影片记录吗？'), findsOneWidget);
    await tester.tap(find.text('移除'));
    await tester.pumpAndSettle();

    expect(find.text('加载失败'), findsNothing);
    expect(prefs.getString('favorite_lists.v1'), isNot(contains('404')));
  });
}
