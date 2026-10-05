import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omm/core/platform/app_theme.dart';
import 'package:omm/l10n/generated/app_localizations.dart';
import 'package:omm/shared/filter_chip.dart';
import 'package:omm/shared/header_action_button.dart';
import 'package:omm/shared/media_list_layout.dart';
import 'package:omm/shared/page_header.dart';

/// 验证「标题 → 工具栏 → 列表」的视觉间距节奏：标题文字垂直居中在
/// 48px 标题行内产生的下方空隙由 PageHeader 光学补偿，保证标题到
/// 工具栏的视觉间距与工具栏到列表首项的视觉间距一致（同为 12），
/// 且在放大字体下依然成立。
void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('标题/工具栏/列表视觉间距在 ${scale}x 字体下一致', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  PageHeader(
                    eyebrow: 'DB ONLINE',
                    bottomPadding: PageHeader.toolbarTopGap,
                    title: Text('排行榜', style: AppText.pageTitle(context)),
                    trailing: HeaderActionButton(
                      icon: Icons.settings,
                      tooltip: '设置',
                      onPressed: () {},
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: PageHeader.aboveListGap,
                    ),
                    child: SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        children: [
                          CompactFilterButton(
                            label: '日榜',
                            active: false,
                            onTap: () {},
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: CustomScrollView(
                      slivers: [
                        SliverPadding(
                          padding: MediaListLayout.contentPadding,
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (_, __) => Container(
                                key: const ValueKey('card'),
                                height: 120,
                                color: Colors.red,
                              ),
                              childCount: 5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final title = tester.getRect(find.text('排行榜'));
      final chip = tester.getRect(
        find
            .descendant(
              of: find.byType(CompactFilterButton),
              matching: find.byType(Container),
            )
            .first,
      );
      final card = tester.getRect(find.byKey(const ValueKey('card')).first);
      final titleToToolbar = chip.top - title.bottom;
      final toolbarToList = card.top - chip.bottom;
      expect(
        (titleToToolbar - toolbarToList).abs(),
        lessThan(1),
        reason: '标题→工具栏=$titleToToolbar 工具栏→列表=$toolbarToList',
      );
      expect(titleToToolbar, closeTo(PageHeader.toolbarTopGap, 1.5));
      expect(
        toolbarToList,
        closeTo(PageHeader.aboveListGap + MediaListLayout.contentTopInset, 0.5),
      );
    });
  }
}
