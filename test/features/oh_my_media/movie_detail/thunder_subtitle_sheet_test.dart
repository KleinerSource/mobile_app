import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/models/movie.dart';
import 'package:omm/core/models/preview.dart';
import 'package:omm/core/models/subtitle_search.dart';
import 'package:omm/core/sources/common/source_exception.dart';
import 'package:omm/core/sources/media/media_models.dart' as source_models;
import 'package:omm/core/sources/media/media_source.dart';
import 'package:omm/core/sources/media/omm_media_operations_source.dart';
import 'package:omm/features/oh_my_media/movie_detail/thunder_subtitle_sheet.dart';
import 'package:omm/features/oh_my_media/movies/media_repository.dart';
import 'package:omm/features/oh_my_media/movies/movies_providers.dart';
import 'package:omm/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('同名字幕下载失败时确认覆盖并重试', (tester) async {
    final operations = _FakeOperations();
    final repository = MediaRepository(
      catalog: _FakeCatalog(),
      details: _FakeDetails(),
      operations: operations,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mediaRepositoryProvider.overrideWithValue(repository),
          movieDetailProvider(
            1,
          ).overrideWith((ref) async => const MovieDetail(id: 1)),
        ],
        child: MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          locale: const Locale('zh'),
          theme: ThemeData(brightness: Brightness.dark),
          home: const Scaffold(body: ThunderSubtitleSheet(movieId: 1)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('下载'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('字幕已存在'), findsOneWidget);
    expect(find.text('同名字幕文件已存在，是否覆盖？'), findsOneWidget);

    await tester.tap(find.text('覆盖'));
    await tester.pumpAndSettle();

    expect(operations.overwriteValues, [false, true]);
  });
}

class _FakeCatalog implements CatalogSource {
  @override
  Future<source_models.MediaPage<source_models.MediaSummary>> listMovies(
    source_models.MediaQuery query,
  ) async {
    return source_models.MediaPage(
      items: const <source_models.MediaSummary>[],
      page: 1,
      limit: query.limit,
      total: 0,
      hasMore: false,
    );
  }

  @override
  Future<source_models.MediaPage<source_models.MediaSummary>> searchMovies(
    source_models.MediaQuery query,
  ) => listMovies(query);
}

class _FakeDetails implements MovieDetailSource {
  @override
  Future<source_models.MediaDetails> getMovie(
    source_models.MediaRef ref,
  ) async {
    return source_models.MediaDetails(
      summary: source_models.MediaSummary(ref: ref, title: '测试影片'),
      payload: const MovieDetail(id: 1),
    );
  }
}

class _FakeOperations implements OmmMediaOperationsSource {
  final List<bool> overwriteValues = [];

  @override
  Future<({String keyword, List<SubtitleSearchItem> items})> searchSubtitles(
    source_models.MediaRef movie,
  ) async {
    return (
      keyword: 'TEST-001',
      items: const [
        SubtitleSearchItem(
          name: '测试字幕',
          url: 'https://example.test/subtitle.srt',
          ext: 'srt',
        ),
      ],
    );
  }

  @override
  Future<void> downloadSubtitle(
    source_models.MediaRef movie, {
    required String url,
    required String ext,
    bool overwrite = false,
  }) async {
    overwriteValues.add(overwrite);
    if (!overwrite) {
      throw const SourceException('同名字幕文件已存在');
    }
  }

  @override
  Future<PreviewStartResult> generatePreview(
    source_models.MediaRef movie, {
    bool overwrite = false,
  }) => throw UnimplementedError();

  @override
  Future<PreviewStatus> previewStatus(
    source_models.MediaRef movie, {
    String? taskId,
  }) => throw UnimplementedError();

  @override
  Future<PreviewTask> previewTask(String taskId) => throw UnimplementedError();

  @override
  Future<void> cancelPreviewTask(String taskId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(invocation.memberName.toString());
  }
}
