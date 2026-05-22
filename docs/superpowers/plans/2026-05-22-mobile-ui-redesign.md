# Mobile App UI/UX 重构 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 根据 [docs/superpowers/specs/2026-05-22-mobile-ui-redesign-design.md](../specs/2026-05-22-mobile-ui-redesign-design.md) 把 mobile_app 重做成标准浅/深色 UI，5 tab 底栏，3 列网格，完整 PWA badge 体系，移除 Cupertino/Material 平台分叉。

**Architecture:** 新建 `lib/core/ui/` 目录承载所有视觉组件（theme tokens、scaffold、底栏、search、chip row）；废弃旧 `lib/core/platform/`。MovieCard 重写支持全部 6 类 badge。MaterialApp 主题切换为自定义 light/dark `ThemeData`，`themeMode: system`。

**Tech Stack:** Flutter 3.44 / Material 3 / flutter_riverpod / Material Outlined Icons / 无新依赖

---

## File Structure

```
lib/
  core/
    ui/                          ← 新目录，全部视觉组件
      tokens.dart                ← AppColors / AppRadius / AppSpacing (light/dark)
      theme.dart                 ← appTheme(Brightness) -> ThemeData
      app_scaffold.dart          ← AppScaffold + AppPage（大标题 sliver）
      app_bottom_nav.dart        ← 5 tab 底栏 + onMoreTap 回调
      app_search_field.dart      ← surface 底 + search icon line 风
      app_chip_row.dart          ← 横向 chip 行
      app_more_sheet.dart        ← "更多" bottom sheet（占位项）
      app_badge.dart             ← 海报上的小角标（左上/右上/底部行 共用）
  shared/
    movie_card.dart              ← 完整 PWA badge 体系（重写）
    empty_view.dart              ← 套新 token（轻改）
    error_view.dart              ← 套新 token（轻改）
  features/
    main/main_shell.dart         ← 用新 AppBottomNav，移除 isCupertino
    movies/movies_page.dart      ← 3 列 grid，套新主题
    favorites/favorites_page.dart ← 套新主题（仍占位）
    settings/settings_page.dart  ← 自绘 list tile + 新主题
    settings/server_setup_page.dart ← 移除 Cupertino 分支
  main.dart                      ← MaterialApp 套新 theme

test/
  core/
    platform_test.dart           ← 重写：只验证 Material
    ui/
      theme_test.dart            ← 新增
      app_bottom_nav_test.dart   ← 新增
  shared/
    movie_card_test.dart         ← 增量：badge 用例

DELETED:
  lib/core/platform/platform.dart
  lib/core/platform/app_scaffold.dart
  lib/core/platform/app_tab_bar.dart
  lib/core/platform/app_nav_bar.dart
  lib/core/platform/app_search_field.dart
  （app_action_sheet.dart / app_dialog.dart 保留，本轮不用）
```

任务执行顺序：先 token 和 theme（基础），再 4 个核心 UI 组件（独立可测），再 movie_card 重写，最后串到屏幕和 shell。每个 Task 完成都跑 test 并 commit。

---

## Task 1: 设计 token (`tokens.dart`)

**Files:**
- Create: `lib/core/ui/tokens.dart`
- Test: `test/core/ui/theme_test.dart`（先建文件，后面 Task 2 一起填）

- [ ] **Step 1: Write the failing test**

Create `test/core/ui/theme_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/ui/tokens.dart';

void main() {
  test('AppColors.of returns light tokens for Brightness.light', () {
    final c = AppColors.of(Brightness.light);
    expect(c.bg, const Color(0xFFFFFFFF));
    expect(c.text, const Color(0xFF0F0F14));
    expect(c.brand, const Color(0xFF4F6DF0));
  });

  test('AppColors.of returns dark tokens for Brightness.dark', () {
    final c = AppColors.of(Brightness.dark);
    expect(c.bg, const Color(0xFF000000));
    expect(c.text, const Color(0xFFFFFFFF));
    expect(c.brand, const Color(0xFF4F6DF0));
  });

  test('AppColors badge state colors are identical across themes', () {
    final l = AppColors.of(Brightness.light);
    final d = AppColors.of(Brightness.dark);
    expect(l.badgeUpdated, d.badgeUpdated);
    expect(l.badgeFavorited, d.badgeFavorited);
    expect(l.badgeCompleted, d.badgeCompleted);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/ui/theme_test.dart`
Expected: FAIL — `lib/core/ui/tokens.dart` not found

- [ ] **Step 3: Implement tokens**

Create `lib/core/ui/tokens.dart`:

```dart
import 'package:flutter/material.dart';

@immutable
class AppColors {
  const AppColors({
    required this.bg,
    required this.surface,
    required this.surfaceVariant,
    required this.text,
    required this.textMuted,
    required this.divider,
    required this.tabBarBg,
    required this.tabBarBorder,
    required this.tabIdle,
    required this.posterBorder,
    required this.progressTrack,
    required this.shade,
    required this.brand,
    required this.brandOn,
    required this.badgeUpdated,
    required this.badgeFavorited,
    required this.badgeCompleted,
    required this.badgeSubtitle,
  });

  final Color bg;
  final Color surface;
  final Color surfaceVariant;
  final Color text;
  final Color textMuted;
  final Color divider;
  final Color tabBarBg;
  final Color tabBarBorder;
  final Color tabIdle;
  final Color posterBorder;
  final Color progressTrack;
  final Color shade;
  final Color brand;
  final Color brandOn;
  final Color badgeUpdated;
  final Color badgeFavorited;
  final Color badgeCompleted;
  final Color badgeSubtitle;

  static const _brand = Color(0xFF4F6DF0);
  static const _brandOn = Color(0xFFFFFFFF);
  static const _badgeUpdated = Color(0xFFF59E0B);
  static const _badgeFavorited = Color(0xFFEF4444);
  static const _badgeCompleted = Color(0xFF14B8A6);
  static const _badgeSubtitle = Color(0xFFF59E0B);

  static const light = AppColors(
    bg: Color(0xFFFFFFFF),
    surface: Color(0xFFF4F4F6),
    surfaceVariant: Color(0xFFECECEF),
    text: Color(0xFF0F0F14),
    textMuted: Color(0xFF6B6B75),
    divider: Color(0x14000000),
    tabBarBg: Color(0xFFFFFFFF),
    tabBarBorder: Color(0x14000000),
    tabIdle: Color(0xFF8A8A92),
    posterBorder: Color(0x0F000000),
    progressTrack: Color(0x1F000000),
    shade: Color(0xB8000000),
    brand: _brand,
    brandOn: _brandOn,
    badgeUpdated: _badgeUpdated,
    badgeFavorited: _badgeFavorited,
    badgeCompleted: _badgeCompleted,
    badgeSubtitle: _badgeSubtitle,
  );

  static const dark = AppColors(
    bg: Color(0xFF000000),
    surface: Color(0xFF1A1A1C),
    surfaceVariant: Color(0xFF2A2A2E),
    text: Color(0xFFFFFFFF),
    textMuted: Color(0xFF98989F),
    divider: Color(0x1AFFFFFF),
    tabBarBg: Color(0xFF111113),
    tabBarBorder: Color(0x1AFFFFFF),
    tabIdle: Color(0xFF7A7A82),
    posterBorder: Color(0x0FFFFFFF),
    progressTrack: Color(0x2EFFFFFF),
    shade: Color(0xC7000000),
    brand: _brand,
    brandOn: _brandOn,
    badgeUpdated: _badgeUpdated,
    badgeFavorited: _badgeFavorited,
    badgeCompleted: _badgeCompleted,
    badgeSubtitle: _badgeSubtitle,
  );

  static AppColors of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}

class AppRadius {
  static const double poster = 10;
  static const double card = 12;
  static const double pill = 999;
  static const double badge = 4;
}

class AppSpacing {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/ui/theme_test.dart`
Expected: PASS, all 3 tests green

- [ ] **Step 5: Commit**

```bash
git add lib/core/ui/tokens.dart test/core/ui/theme_test.dart
git commit -m "feat(ui): add design tokens for light/dark and badge colors"
```

---

## Task 2: 主题 (`theme.dart`) + Theme extension

**Files:**
- Create: `lib/core/ui/theme.dart`
- Modify: `test/core/ui/theme_test.dart`

- [ ] **Step 1: Add failing tests**

Append to `test/core/ui/theme_test.dart`:

```dart
import 'package:md_center/core/ui/theme.dart';

// ... 已有 import 和 tests 之外，在 main() 末尾追加：
//   test('appTheme returns light ThemeData with brand color', () { ... });
//   test('appTheme dark uses dark tokens', () { ... });
//   test('AppColors is accessible via Theme.of(context).extension', () { ... });
```

完整新增测试代码（追加到 `main()` 块末尾）：

```dart
  test('appTheme light brightness is light and scaffoldBackground=bg', () {
    final t = appTheme(Brightness.light);
    expect(t.brightness, Brightness.light);
    expect(t.scaffoldBackgroundColor, AppColors.light.bg);
  });

  test('appTheme dark brightness is dark and scaffoldBackground=bg', () {
    final t = appTheme(Brightness.dark);
    expect(t.brightness, Brightness.dark);
    expect(t.scaffoldBackgroundColor, AppColors.dark.bg);
  });

  testWidgets('Theme.of(context).extension<AppColors>() resolves',
      (tester) async {
    AppColors? captured;
    await tester.pumpWidget(MaterialApp(
      theme: appTheme(Brightness.light),
      home: Builder(builder: (ctx) {
        captured = Theme.of(ctx).extension<AppColors>();
        return const SizedBox();
      }),
    ));
    expect(captured, isNotNull);
    expect(captured!.brand, AppColors.light.brand);
  });
```

- [ ] **Step 2: Run test to verify failures**

Run: `flutter test test/core/ui/theme_test.dart`
Expected: FAIL — `appTheme` not defined, no `extension` registered

- [ ] **Step 3: Make `AppColors` a `ThemeExtension` and implement `appTheme`**

Update `lib/core/ui/tokens.dart` — change class declaration and add `copyWith` + `lerp`:

```dart
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    // ... same fields as before
  });

  // ... all fields and static const light/dark and AppColors.of unchanged

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) => this;
}
```

Create `lib/core/ui/theme.dart`:

```dart
import 'package:flutter/material.dart';
import 'tokens.dart';

ThemeData appTheme(Brightness brightness) {
  final c = AppColors.of(brightness);
  final colorScheme = ColorScheme.fromSeed(
    seedColor: c.brand,
    brightness: brightness,
    surface: c.bg,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: c.bg,
    extensions: <ThemeExtension<dynamic>>[c],
    textTheme: TextTheme(
      displayLarge: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
        color: c.text,
      ),
      titleMedium: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: c.text,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: c.text,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: c.textMuted,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.brand,
        foregroundColor: c.brandOn,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
      ),
    ),
  );
}
```

- [ ] **Step 4: Run test to verify pass**

Run: `flutter test test/core/ui/theme_test.dart`
Expected: PASS all tests

- [ ] **Step 5: Commit**

```bash
git add lib/core/ui/theme.dart lib/core/ui/tokens.dart test/core/ui/theme_test.dart
git commit -m "feat(ui): add appTheme factory exposing AppColors as ThemeExtension"
```

---

## Task 3: AppScaffold + AppPage (大标题)

**Files:**
- Create: `lib/core/ui/app_scaffold.dart`
- Test: `test/core/ui/app_scaffold_test.dart`

- [ ] **Step 1: Write failing tests**

Create `test/core/ui/app_scaffold_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/ui/app_scaffold.dart';
import 'package:md_center/core/ui/theme.dart';

void main() {
  Widget wrap(Widget child, {Brightness b = Brightness.light}) => MaterialApp(
        theme: appTheme(b),
        home: child,
      );

  testWidgets('AppScaffold renders Scaffold and child', (tester) async {
    await tester.pumpWidget(wrap(
      const AppScaffold(body: Text('hello')),
    ));
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets('AppPage shows title and subtitle', (tester) async {
    await tester.pumpWidget(wrap(
      const AppPage(
        title: '影片库',
        subtitle: '2341 部',
        slivers: [SliverToBoxAdapter(child: SizedBox(height: 100))],
      ),
    ));
    expect(find.text('影片库'), findsOneWidget);
    expect(find.text('2341 部'), findsOneWidget);
  });

  testWidgets('AppPage without subtitle does not crash', (tester) async {
    await tester.pumpWidget(wrap(
      const AppPage(
        title: '设置',
        slivers: [SliverToBoxAdapter(child: SizedBox(height: 100))],
      ),
    ));
    expect(find.text('设置'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run failing test**

Run: `flutter test test/core/ui/app_scaffold_test.dart`
Expected: FAIL — `AppScaffold` / `AppPage` not defined

- [ ] **Step 3: Implement**

Create `lib/core/ui/app_scaffold.dart`:

```dart
import 'package:flutter/material.dart';
import 'tokens.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({super.key, required this.body, this.bottomNavigationBar});
  final Widget body;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(bottom: bottomNavigationBar == null, child: body),
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}

class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    this.subtitle,
    required this.slivers,
  });

  final String title;
  final String? subtitle;
  final List<Widget> slivers;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.l,
              AppSpacing.s,
              AppSpacing.l,
              AppSpacing.m,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: c.text,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: c.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        ...slivers,
      ],
    );
  }
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/core/ui/app_scaffold_test.dart`
Expected: PASS all 3

- [ ] **Step 5: Commit**

```bash
git add lib/core/ui/app_scaffold.dart test/core/ui/app_scaffold_test.dart
git commit -m "feat(ui): add AppScaffold and AppPage with large title sliver"
```

---

## Task 4: AppBottomNav (5 tab)

**Files:**
- Create: `lib/core/ui/app_bottom_nav.dart`
- Test: `test/core/ui/app_bottom_nav_test.dart`

- [ ] **Step 1: Write failing tests**

Create `test/core/ui/app_bottom_nav_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/ui/app_bottom_nav.dart';
import 'package:md_center/core/ui/theme.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        theme: appTheme(Brightness.light),
        home: Scaffold(bottomNavigationBar: child, body: const SizedBox()),
      );

  testWidgets('renders 5 labels', (tester) async {
    await tester.pumpWidget(wrap(AppBottomNav(
      currentIndex: 0,
      onTap: (_) {},
      onMoreTap: () {},
    )));
    expect(find.text('仪表板'), findsOneWidget);
    expect(find.text('影片'), findsOneWidget);
    expect(find.text('收藏'), findsOneWidget);
    expect(find.text('更多'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
  });

  testWidgets('tap on non-more tab fires onTap with index', (tester) async {
    int? tappedIndex;
    await tester.pumpWidget(wrap(AppBottomNav(
      currentIndex: 0,
      onTap: (i) => tappedIndex = i,
      onMoreTap: () {},
    )));
    await tester.tap(find.text('影片'));
    expect(tappedIndex, 1);
    await tester.tap(find.text('设置'));
    expect(tappedIndex, 4);
  });

  testWidgets('tap on More fires onMoreTap not onTap', (tester) async {
    int? tappedIndex;
    var moreCount = 0;
    await tester.pumpWidget(wrap(AppBottomNav(
      currentIndex: 0,
      onTap: (i) => tappedIndex = i,
      onMoreTap: () => moreCount++,
    )));
    await tester.tap(find.text('更多'));
    expect(moreCount, 1);
    expect(tappedIndex, isNull);
  });
}
```

- [ ] **Step 2: Run failing test**

Run: `flutter test test/core/ui/app_bottom_nav_test.dart`
Expected: FAIL — `AppBottomNav` not defined

- [ ] **Step 3: Implement**

Create `lib/core/ui/app_bottom_nav.dart`:

```dart
import 'package:flutter/material.dart';
import 'tokens.dart';

class AppBottomNavItem {
  const AppBottomNavItem({
    required this.iconIdle,
    required this.iconActive,
    required this.label,
  });
  final IconData iconIdle;
  final IconData iconActive;
  final String label;
}

const _items = <AppBottomNavItem>[
  AppBottomNavItem(
    iconIdle: Icons.dashboard_outlined,
    iconActive: Icons.dashboard,
    label: '仪表板',
  ),
  AppBottomNavItem(
    iconIdle: Icons.movie_outlined,
    iconActive: Icons.movie,
    label: '影片',
  ),
  AppBottomNavItem(
    iconIdle: Icons.favorite_outline,
    iconActive: Icons.favorite,
    label: '收藏',
  ),
  AppBottomNavItem(
    iconIdle: Icons.more_horiz,
    iconActive: Icons.more_horiz,
    label: '更多',
  ),
  AppBottomNavItem(
    iconIdle: Icons.settings_outlined,
    iconActive: Icons.settings,
    label: '设置',
  ),
];

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onMoreTap,
  });

  static const int moreIndex = 3;

  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onMoreTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    return Container(
      decoration: BoxDecoration(
        color: c.tabBarBg,
        border: Border(top: BorderSide(color: c.tabBarBorder, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(
            children: List.generate(_items.length, (i) {
              final item = _items[i];
              final active = i == currentIndex;
              final color = active ? c.brand : c.tabIdle;
              return Expanded(
                child: InkWell(
                  onTap: () => i == moreIndex ? onMoreTap() : onTap(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        active ? item.iconActive : item.iconIdle,
                        size: 22,
                        color: color,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/core/ui/app_bottom_nav_test.dart`
Expected: PASS all 3

- [ ] **Step 5: Commit**

```bash
git add lib/core/ui/app_bottom_nav.dart test/core/ui/app_bottom_nav_test.dart
git commit -m "feat(ui): add 5-tab AppBottomNav with onMoreTap callback"
```

---

## Task 5: AppSearchField + AppChipRow

**Files:**
- Create: `lib/core/ui/app_search_field.dart`
- Create: `lib/core/ui/app_chip_row.dart`
- Test: `test/core/ui/app_search_chip_test.dart`

- [ ] **Step 1: Write failing tests**

Create `test/core/ui/app_search_chip_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/ui/app_chip_row.dart';
import 'package:md_center/core/ui/app_search_field.dart';
import 'package:md_center/core/ui/theme.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        theme: appTheme(Brightness.light),
        home: Scaffold(body: child),
      );

  testWidgets('AppSearchField shows placeholder', (tester) async {
    await tester.pumpWidget(wrap(AppSearchField(
      placeholder: '搜索片名',
      onSubmitted: (_) {},
    )));
    expect(find.text('搜索片名'), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
  });

  testWidgets('AppSearchField onSubmitted fires with value', (tester) async {
    String? submitted;
    await tester.pumpWidget(wrap(AppSearchField(
      placeholder: 'p',
      onSubmitted: (v) => submitted = v,
    )));
    await tester.enterText(find.byType(TextField), 'hello');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    expect(submitted, 'hello');
  });

  testWidgets('AppChipRow renders chips and fires onTap with index',
      (tester) async {
    int? tapped;
    await tester.pumpWidget(wrap(SingleChildScrollView(
      child: AppChipRow(
        labels: const ['全部', '未看', '收藏'],
        activeIndex: 0,
        onTap: (i) => tapped = i,
      ),
    )));
    expect(find.text('全部'), findsOneWidget);
    expect(find.text('收藏'), findsOneWidget);
    await tester.tap(find.text('收藏'));
    expect(tapped, 2);
  });
}
```

- [ ] **Step 2: Run failing test**

Run: `flutter test test/core/ui/app_search_chip_test.dart`
Expected: FAIL — `AppSearchField` / `AppChipRow` not defined

- [ ] **Step 3: Implement search field**

Create `lib/core/ui/app_search_field.dart`:

```dart
import 'package:flutter/material.dart';
import 'tokens.dart';

class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    this.controller,
    required this.placeholder,
    required this.onSubmitted,
  });

  final TextEditingController? controller;
  final String placeholder;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(Icons.search, size: 18, color: c.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.search,
              onSubmitted: onSubmitted,
              style: TextStyle(fontSize: 14, color: c.text),
              cursorColor: c.brand,
              decoration: InputDecoration(
                isCollapsed: true,
                hintText: placeholder,
                hintStyle: TextStyle(fontSize: 14, color: c.textMuted),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Implement chip row**

Create `lib/core/ui/app_chip_row.dart`:

```dart
import 'package:flutter/material.dart';
import 'tokens.dart';

class AppChipRow extends StatelessWidget {
  const AppChipRow({
    super.key,
    required this.labels,
    required this.activeIndex,
    required this.onTap,
  });

  final List<String> labels;
  final int activeIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    return SizedBox(
      height: 28,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.s),
        itemBuilder: (_, i) {
          final active = i == activeIndex;
          return InkWell(
            onTap: () => onTap(i),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: active ? c.brand : c.surface,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                labels[i],
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: active ? c.brandOn : c.text,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 5: Run tests**

Run: `flutter test test/core/ui/app_search_chip_test.dart`
Expected: PASS all 3

- [ ] **Step 6: Commit**

```bash
git add lib/core/ui/app_search_field.dart lib/core/ui/app_chip_row.dart test/core/ui/app_search_chip_test.dart
git commit -m "feat(ui): add AppSearchField and AppChipRow with brand active state"
```

---

## Task 6: AppBadge component

**Files:**
- Create: `lib/core/ui/app_badge.dart`
- Test: `test/core/ui/app_badge_test.dart`

- [ ] **Step 1: Write failing tests**

Create `test/core/ui/app_badge_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/ui/app_badge.dart';
import 'package:md_center/core/ui/theme.dart';
import 'package:md_center/core/ui/tokens.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        theme: appTheme(Brightness.dark),
        home: Scaffold(body: Center(child: child)),
      );

  testWidgets('AppBadge shows icon and label', (tester) async {
    await tester.pumpWidget(wrap(const AppBadge(
      icon: Icons.refresh,
      label: '已更新',
      background: Color(0xFFF59E0B),
    )));
    expect(find.text('已更新'), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
  });

  testWidgets('AppBadge without label only shows icon', (tester) async {
    await tester.pumpWidget(wrap(const AppBadge(
      icon: Icons.closed_caption_outlined,
      background: Color(0xFFF59E0B),
    )));
    expect(find.byIcon(Icons.closed_caption_outlined), findsOneWidget);
    expect(find.byType(Text), findsNothing);
  });
}
```

- [ ] **Step 2: Run failing test**

Run: `flutter test test/core/ui/app_badge_test.dart`
Expected: FAIL — `AppBadge` not defined

- [ ] **Step 3: Implement**

Create `lib/core/ui/app_badge.dart`:

```dart
import 'package:flutter/material.dart';
import 'tokens.dart';

class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.icon,
    required this.background,
    this.label,
    this.foreground = Colors.white,
  });

  final IconData icon;
  final String? label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: label == null ? 4 : 5,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.badge),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: foreground),
          if (label != null) ...[
            const SizedBox(width: 2),
            Text(
              label!,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: foreground,
                letterSpacing: 0.2,
                height: 1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/core/ui/app_badge_test.dart`
Expected: PASS both

- [ ] **Step 5: Commit**

```bash
git add lib/core/ui/app_badge.dart test/core/ui/app_badge_test.dart
git commit -m "feat(ui): add AppBadge shared component for poster overlays"
```

---

## Task 7: 重写 MovieCard with 完整 badge

**Files:**
- Modify: `lib/shared/movie_card.dart` (重写)
- Modify: `test/shared/movie_card_test.dart` (新增 badge 用例)

- [ ] **Step 1: Update tests for full badge coverage**

Replace `test/shared/movie_card_test.dart` content:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/models/movie.dart';
import 'package:md_center/core/ui/theme.dart';
import 'package:md_center/shared/movie_card.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        theme: appTheme(Brightness.dark),
        home: Scaffold(
          body: Center(
            child: SizedBox(width: 120, child: child),
          ),
        ),
      );

  MovieCard card(MovieListItem movie) => MovieCard(
        movie: movie,
        posterUrlBuilder: (u) => 'http://x/$u',
      );

  testWidgets('显示标题', (tester) async {
    await tester.pumpWidget(wrap(card(
      const MovieListItem(id: 1, title: '示例片名'),
    )));
    expect(find.text('示例片名'), findsOneWidget);
  });

  testWidgets('completed=true 显示已看完角标', (tester) async {
    await tester.pumpWidget(wrap(card(
      const MovieListItem(
        id: 1,
        title: 'A',
        watchRecord: WatchRecordSummary(progressRatio: 1.0, completed: true),
      ),
    )));
    expect(find.text('已看完'), findsOneWidget);
  });

  testWidgets('未完成有进度时显示进度条', (tester) async {
    await tester.pumpWidget(wrap(card(
      const MovieListItem(
        id: 1,
        title: 'A',
        watchRecord: WatchRecordSummary(progressRatio: 0.4, completed: false),
      ),
    )));
    expect(find.byKey(const ValueKey('movie-progress')), findsOneWidget);
  });

  testWidgets('is_updated 显示"已更新"角标', (tester) async {
    await tester.pumpWidget(wrap(card(
      const MovieListItem(id: 1, title: 'A', isUpdated: true),
    )));
    expect(find.text('已更新'), findsOneWidget);
  });

  testWidgets('is_favorited 显示"已收藏"角标', (tester) async {
    await tester.pumpWidget(wrap(card(
      const MovieListItem(id: 1, title: 'A', isFavorited: true),
    )));
    expect(find.text('已收藏'), findsOneWidget);
  });

  testWidgets('is_updated 优先于 is_favorited（互斥）', (tester) async {
    await tester.pumpWidget(wrap(card(
      const MovieListItem(
        id: 1,
        title: 'A',
        isUpdated: true,
        isFavorited: true,
      ),
    )));
    expect(find.text('已更新'), findsOneWidget);
    expect(find.text('已收藏'), findsNothing);
  });

  testWidgets('rating 显示评分 badge（保留一位小数）', (tester) async {
    await tester.pumpWidget(wrap(card(
      const MovieListItem(id: 1, title: 'A', rating: 8.567),
    )));
    expect(find.text('8.6'), findsOneWidget);
  });

  testWidgets('has_external_subtitle 显示字幕 badge', (tester) async {
    await tester.pumpWidget(wrap(card(
      const MovieListItem(id: 1, title: 'A', hasExternalSubtitle: true),
    )));
    expect(find.byIcon(Icons.closed_caption_outlined), findsOneWidget);
  });

  testWidgets('num 显示番号 pill', (tester) async {
    await tester.pumpWidget(wrap(card(
      const MovieListItem(id: 1, title: 'A', num: 'ABC-001'),
    )));
    expect(find.text('ABC-001'), findsOneWidget);
  });

  testWidgets('year 显示年份', (tester) async {
    await tester.pumpWidget(wrap(card(
      const MovieListItem(id: 1, title: 'A', year: 2023),
    )));
    expect(find.text('2023'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run failing tests**

Run: `flutter test test/shared/movie_card_test.dart`
Expected: most tests FAIL — current MovieCard doesn't show 已更新/已收藏/rating/CC/num/year/progress key

- [ ] **Step 3: Rewrite MovieCard**

Replace `lib/shared/movie_card.dart` content:

```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/models/movie.dart';
import '../core/ui/app_badge.dart';
import '../core/ui/tokens.dart';

class MovieCard extends StatelessWidget {
  const MovieCard({
    super.key,
    required this.movie,
    required this.posterUrlBuilder,
    this.onTap,
  });

  final MovieListItem movie;
  final String Function(String uuid) posterUrlBuilder;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final progress = movie.watchRecord?.progressRatio ?? 0.0;
    final completed = movie.watchRecord?.completed ?? false;
    final rating = movie.rating;
    final ratingText = (rating != null && rating > 0)
        ? rating.toStringAsFixed(1)
        : null;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 2 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.poster),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: c.surface,
                      border: Border.all(color: c.posterBorder, width: 1),
                      borderRadius: BorderRadius.circular(AppRadius.poster),
                    ),
                    child: movie.posterUuid != null
                        ? CachedNetworkImage(
                            imageUrl: posterUrlBuilder(movie.posterUuid!),
                            fit: BoxFit.cover,
                            placeholder: (_, __) => ColoredBox(color: c.surface),
                            errorWidget: (_, __, ___) =>
                                ColoredBox(color: c.surface),
                          )
                        : ColoredBox(color: c.surface),
                  ),
                  Positioned(top: 5, left: 5, child: _topLeftBadge(c)),
                  if (completed)
                    Positioned(
                      top: 5,
                      right: 5,
                      child: AppBadge(
                        icon: Icons.check_circle_outline,
                        label: '已看完',
                        background: c.badgeCompleted,
                      ),
                    ),
                  Positioned(
                    left: 5,
                    right: 5,
                    bottom: 5,
                    child: _bottomBadgeRow(c, ratingText),
                  ),
                  if (progress > 0 && !completed)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: SizedBox(
                        key: const ValueKey('movie-progress'),
                        height: 2,
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          minHeight: 2,
                          backgroundColor: c.progressTrack,
                          valueColor: AlwaysStoppedAnimation(c.brand),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            movie.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: c.text,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 2),
          _metaRow(c),
        ],
      ),
    );
  }

  Widget _topLeftBadge(AppColors c) {
    if (movie.isUpdated) {
      return AppBadge(
        icon: Icons.refresh,
        label: '已更新',
        background: c.badgeUpdated,
      );
    }
    if (movie.isFavorited) {
      return AppBadge(
        icon: Icons.favorite,
        label: '已收藏',
        background: c.badgeFavorited,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _bottomBadgeRow(AppColors c, String? ratingText) {
    final children = <Widget>[];
    if (movie.hasExternalSubtitle) {
      children.add(AppBadge(
        icon: Icons.closed_caption_outlined,
        background: c.badgeSubtitle,
      ));
    }
    if (ratingText != null) {
      children.add(AppBadge(
        icon: Icons.star,
        label: ratingText,
        background: c.shade,
      ));
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 3,
      runSpacing: 3,
      children: children,
    );
  }

  Widget _metaRow(AppColors c) {
    final parts = <Widget>[];
    final num = movie.num;
    if (num != null && num.isNotEmpty) {
      parts.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: c.surfaceVariant,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          num,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: c.text,
            height: 1.1,
          ),
        ),
      ));
    }
    if (movie.year != null) {
      if (parts.isNotEmpty) parts.add(const SizedBox(width: 4));
      parts.add(Text(
        '${movie.year}',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: c.textMuted,
        ),
      ));
    }
    if (parts.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: parts,
    );
  }
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/shared/movie_card_test.dart`
Expected: PASS all 10

- [ ] **Step 5: Commit**

```bash
git add lib/shared/movie_card.dart test/shared/movie_card_test.dart
git commit -m "feat(card): rewrite MovieCard with full PWA badge system"
```

---

## Task 8: 套新主题：empty / error / settings / server_setup

**Files:**
- Modify: `lib/shared/empty_view.dart`
- Modify: `lib/shared/error_view.dart`

- [ ] **Step 1: Update empty_view**

Replace `lib/shared/empty_view.dart` content:

```dart
import 'package:flutter/material.dart';

import '../core/ui/tokens.dart';

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, this.message = '暂无数据'});
  final String message;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: c.textMuted),
            const SizedBox(height: AppSpacing.m),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: c.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Update error_view**

Replace `lib/shared/error_view.dart` content:

```dart
import 'package:flutter/material.dart';

import '../core/ui/tokens.dart';

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: c.textMuted),
            const SizedBox(height: AppSpacing.m),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: c.text),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.l),
              FilledButton(onPressed: onRetry, child: const Text('重试')),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Run existing tests still pass**

Run: `flutter test test/shared/`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add lib/shared/empty_view.dart lib/shared/error_view.dart
git commit -m "refactor(shared): apply new tokens to empty/error views"
```

---

## Task 9: 更新 settings_page + server_setup_page

**Files:**
- Modify: `lib/features/settings/settings_page.dart`
- Modify: `lib/features/settings/server_setup_page.dart`
- Modify: `test/features/server_setup_page_test.dart` (移除 Cupertino 假设)

- [ ] **Step 1: Rewrite settings_page**

Replace `lib/features/settings/settings_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/server_config_provider.dart';
import '../../core/ui/app_scaffold.dart';
import '../../core/ui/tokens.dart';
import 'server_setup_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ref.watch(serverConfigProvider);
    final c = Theme.of(context).extension<AppColors>()!;
    return AppPage(
      title: '设置',
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(AppSpacing.l),
          sliver: SliverList.list(children: [
            _SettingsTile(
              title: '服务器地址',
              subtitle: cfg?.baseUrl ?? '未配置',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ServerSetupPage()),
              ),
              c: c,
            ),
          ]),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.c,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final AppColors c;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: c.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: c.textMuted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: c.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Rewrite server_setup_page (无 Cupertino)**

Replace `lib/features/settings/server_setup_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/dio_factory.dart';
import '../../core/config/server_config.dart';
import '../../core/config/server_config_provider.dart';
import '../../core/ui/app_scaffold.dart';
import '../../core/ui/tokens.dart';

class ServerSetupPage extends ConsumerStatefulWidget {
  const ServerSetupPage({super.key});

  @override
  ConsumerState<ServerSetupPage> createState() => _ServerSetupPageState();
}

class _ServerSetupPageState extends ConsumerState<ServerSetupPage> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = ref.read(serverConfigProvider);
    if (existing != null) _controller.text = existing.baseUrl;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _testAndSave() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = '请输入服务器地址');
      return;
    }
    final normalized = ServerConfig.normalize(raw);
    if (!normalized.startsWith('http://') &&
        !normalized.startsWith('https://')) {
      setState(() => _error = '地址必须以 http:// 或 https:// 开头');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final dio = buildDio(ServerConfig(baseUrl: normalized));
      await dio.get<dynamic>('/health');
      await ref
          .read(serverConfigProvider.notifier)
          .save(ServerConfig(baseUrl: normalized));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = toApiException(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    return AppScaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Text(
              '连接 md_center 后端',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: c.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '请输入服务器地址，包含协议和端口。例：http://192.168.1.10:8001',
              style: TextStyle(fontSize: 13, color: c.textMuted),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                controller: _controller,
                keyboardType: TextInputType.url,
                autocorrect: false,
                style: TextStyle(fontSize: 14, color: c.text),
                cursorColor: c.brand,
                decoration: InputDecoration(
                  isCollapsed: true,
                  hintText: 'http://192.168.1.10:8001',
                  hintStyle: TextStyle(fontSize: 14, color: c.textMuted),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Color(0xFFEF4444))),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _testAndSave,
              child: _busy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('测试并保存'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Update server_setup_page_test**

Read existing `test/features/server_setup_page_test.dart` first. The existing tests should still work since they don't depend on Cupertino specifically — they just check error text appears. Run them:

Run: `flutter test test/features/server_setup_page_test.dart`
Expected: PASS (existing assertions don't depend on platform)

If they fail because of a Cupertino-specific Finder, change those finders to find by text only.

- [ ] **Step 4: Commit**

```bash
git add lib/features/settings/ test/features/server_setup_page_test.dart
git commit -m "refactor(settings): rewrite settings/server-setup with new theme, drop Cupertino branches"
```

---

## Task 10: Favorites 占位 + Dashboard 占位

**Files:**
- Modify: `lib/features/favorites/favorites_page.dart`
- Create: `lib/features/dashboard/dashboard_page.dart`

- [ ] **Step 1: Rewrite favorites page**

Replace `lib/features/favorites/favorites_page.dart`:

```dart
import 'package:flutter/material.dart';

import '../../core/ui/app_scaffold.dart';
import '../../shared/empty_view.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      body: EmptyView(message: '收藏功能建设中'),
    );
  }
}
```

- [ ] **Step 2: Create dashboard page**

Create `lib/features/dashboard/dashboard_page.dart`:

```dart
import 'package:flutter/material.dart';

import '../../core/ui/app_scaffold.dart';
import '../../shared/empty_view.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      body: EmptyView(message: '仪表板建设中'),
    );
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/favorites/favorites_page.dart lib/features/dashboard/dashboard_page.dart
git commit -m "feat(pages): add dashboard placeholder, restyle favorites placeholder"
```

---

## Task 11: 重写 main_shell + 更多 sheet

**Files:**
- Modify: `lib/features/main/main_shell.dart`
- Create: `lib/core/ui/app_more_sheet.dart`

- [ ] **Step 1: Create more sheet**

Create `lib/core/ui/app_more_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'tokens.dart';

class _MoreEntry {
  const _MoreEntry(this.icon, this.label);
  final IconData icon;
  final String label;
}

const _entries = <_MoreEntry>[
  _MoreEntry(Icons.collections_bookmark_outlined, '媒体库'),
  _MoreEntry(Icons.label_outline, '标签管理'),
  _MoreEntry(Icons.category_outlined, '分类管理'),
  _MoreEntry(Icons.video_library_outlined, '系列管理'),
  _MoreEntry(Icons.people_outline, '演员管理'),
  _MoreEntry(Icons.link, '演员关联'),
];

Future<void> showAppMoreSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final c = Theme.of(ctx).extension<AppColors>()!;
      return Container(
        decoration: BoxDecoration(
          color: c.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          border: Border(top: BorderSide(color: c.divider, width: 1)),
        ),
        padding: EdgeInsets.only(
          top: AppSpacing.l,
          left: AppSpacing.l,
          right: AppSpacing.l,
          bottom: MediaQuery.of(ctx).viewPadding.bottom + AppSpacing.l,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '更多页面',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: c.text,
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: AppSpacing.s,
              crossAxisSpacing: AppSpacing.s,
              childAspectRatio: 1.0,
              children: _entries
                  .map((e) => _MoreCell(entry: e, c: c))
                  .toList(),
            ),
          ],
        ),
      );
    },
  );
}

class _MoreCell extends StatelessWidget {
  const _MoreCell({required this.entry, required this.c});
  final _MoreEntry entry;
  final AppColors c;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: () {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${entry.label} 待实现')),
          );
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(entry.icon, size: 22, color: c.text),
            const SizedBox(height: 8),
            Text(
              entry.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: c.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Rewrite main_shell**

Replace `lib/features/main/main_shell.dart`:

```dart
import 'package:flutter/material.dart';

import '../../core/ui/app_bottom_nav.dart';
import '../../core/ui/app_more_sheet.dart';
import '../dashboard/dashboard_page.dart';
import '../favorites/favorites_page.dart';
import '../movies/movies_page.dart';
import '../settings/settings_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _pageIndexMap = <int, int>{
    0: 0, // dashboard
    1: 1, // movies
    2: 2, // favorites
    4: 3, // settings (skip 3 = more)
  };

  static const _pages = <Widget>[
    DashboardPage(),
    MoviesPage(),
    FavoritesPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final pageIdx = _pageIndexMap[_index] ?? 0;
    return Scaffold(
      body: IndexedStack(index: pageIdx, children: _pages),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        onMoreTap: () => showAppMoreSheet(context),
      ),
    );
  }
}
```

- [ ] **Step 3: Run all tests**

Run: `flutter test`
Expected: PASS (some may need adjustment if `platform_test.dart` still tests old shell)

- [ ] **Step 4: Commit**

```bash
git add lib/core/ui/app_more_sheet.dart lib/features/main/main_shell.dart
git commit -m "feat(shell): rewrite MainShell with 5-tab nav and more sheet"
```

---

## Task 12: 重写 movies_page (3列 + 新主题)

**Files:**
- Modify: `lib/features/movies/movies_page.dart`

- [ ] **Step 1: Rewrite movies_page**

Replace `lib/features/movies/movies_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../core/api/dio_factory.dart';
import '../../core/models/movie.dart';
import '../../core/ui/app_scaffold.dart';
import '../../core/ui/app_search_field.dart';
import '../../core/ui/tokens.dart';
import '../../shared/empty_view.dart';
import '../../shared/error_view.dart';
import '../../shared/movie_card.dart';
import 'movie_filter.dart';
import 'movies_providers.dart';

class MoviesPage extends ConsumerStatefulWidget {
  const MoviesPage({super.key});

  @override
  ConsumerState<MoviesPage> createState() => _MoviesPageState();
}

class _MoviesPageState extends ConsumerState<MoviesPage> {
  static const _pageSize = 50;
  final _controller = PagingController<int, MovieListItem>(firstPageKey: 0);
  final _searchController = TextEditingController();
  MovieFilter _currentFilter = const MovieFilter();

  @override
  void initState() {
    super.initState();
    _controller.addPageRequestListener(_fetch);
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetch(int offset) async {
    try {
      final repo = ref.read(moviesRepositoryProvider);
      final page = await repo.list(_currentFilter,
          limit: _pageSize, offset: offset);
      final nextOffset = offset + page.items.length;
      if (nextOffset >= page.totalCount || page.items.isEmpty) {
        _controller.appendLastPage(page.items);
      } else {
        _controller.appendPage(page.items, nextOffset);
      }
    } catch (e) {
      _controller.error = toApiException(e).message;
    }
  }

  void _onSubmitted(String v) {
    final next = _currentFilter.copyWith(search: v);
    if (next == _currentFilter) return;
    setState(() => _currentFilter = next);
    ref.read(movieFilterProvider.notifier).state = next;
    _controller.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final urlBuilder = ref.watch(imageUrlBuilderProvider);
    final c = Theme.of(context).extension<AppColors>()!;

    return AppScaffold(
      body: AppPage(
        title: '影片库',
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.l, 0, AppSpacing.l, AppSpacing.m,
              ),
              child: AppSearchField(
                controller: _searchController,
                placeholder: '搜索片名 / 演员 / 标签',
                onSubmitted: _onSubmitted,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
            sliver: PagedSliverGrid<int, MovieListItem>(
              pagingController: _controller,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.55,
                mainAxisSpacing: AppSpacing.s,
                crossAxisSpacing: AppSpacing.s,
              ),
              builderDelegate: PagedChildBuilderDelegate<MovieListItem>(
                itemBuilder: (ctx, item, idx) => MovieCard(
                  movie: item,
                  posterUrlBuilder: urlBuilder,
                ),
                firstPageErrorIndicatorBuilder: (_) => ErrorView(
                  message: _controller.error?.toString() ?? '加载失败',
                  onRetry: () => _controller.refresh(),
                ),
                newPageErrorIndicatorBuilder: (_) => Padding(
                  padding: const EdgeInsets.all(AppSpacing.l),
                  child: TextButton(
                    onPressed: () => _controller.retryLastFailedRequest(),
                    child: Text(
                      '加载失败，点击重试：${_controller.error}',
                      style: TextStyle(color: c.brand),
                    ),
                  ),
                ),
                noItemsFoundIndicatorBuilder: (_) =>
                    const EmptyView(message: '没有找到符合条件的影片'),
                firstPageProgressIndicatorBuilder: (_) => Center(
                  child: CircularProgressIndicator(color: c.brand),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/movies/movies_page.dart
git commit -m "refactor(movies): switch to 3-col grid and AppPage layout"
```

---

## Task 13: 更新 main.dart + 删除 platform/ 目录

**Files:**
- Modify: `lib/main.dart`
- Delete: `lib/core/platform/platform.dart`
- Delete: `lib/core/platform/app_scaffold.dart`
- Delete: `lib/core/platform/app_tab_bar.dart`
- Delete: `lib/core/platform/app_nav_bar.dart`
- Delete: `lib/core/platform/app_search_field.dart`
- Modify: `test/core/platform_test.dart` (重写为只验 Material)

- [ ] **Step 1: Rewrite main.dart**

Replace `lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/config/server_config_provider.dart';
import 'core/ui/theme.dart';
import 'features/main/main_shell.dart';
import 'features/settings/server_setup_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(
    overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    child: const MdCenterApp(),
  ));
}

class MdCenterApp extends ConsumerWidget {
  const MdCenterApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ref.watch(serverConfigProvider);
    return MaterialApp(
      title: 'md_center',
      debugShowCheckedModeBanner: false,
      theme: appTheme(Brightness.light),
      darkTheme: appTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: cfg == null ? const ServerSetupPage() : const MainShell(),
    );
  }
}
```

- [ ] **Step 2: Delete platform files (only the ones no longer imported)**

Run:

```bash
git rm lib/core/platform/platform.dart \
       lib/core/platform/app_scaffold.dart \
       lib/core/platform/app_tab_bar.dart \
       lib/core/platform/app_nav_bar.dart \
       lib/core/platform/app_search_field.dart
```

Note: `app_action_sheet.dart` and `app_dialog.dart` remain (not used in this round but kept for future).

- [ ] **Step 3: Rewrite platform_test.dart**

Replace `test/core/platform_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md_center/core/ui/app_scaffold.dart';
import 'package:md_center/core/ui/theme.dart';

void main() {
  Widget wrap(Widget child, {Brightness b = Brightness.light}) => MaterialApp(
        theme: appTheme(b),
        home: child,
      );

  testWidgets('AppScaffold renders Material Scaffold on light', (tester) async {
    await tester.pumpWidget(wrap(const AppScaffold(body: Text('x'))));
    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets('AppScaffold renders Material Scaffold on dark', (tester) async {
    await tester.pumpWidget(
        wrap(const AppScaffold(body: Text('x')), b: Brightness.dark));
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
```

- [ ] **Step 4: Run full test suite**

Run: `flutter test`
Expected: PASS all

If any test fails because of stale imports referencing deleted files, fix imports. Common offenders: 任何 `import 'package:md_center/core/platform/...'` 改为 `package:md_center/core/ui/...`.

- [ ] **Step 5: Run analyzer**

Run: `flutter analyze`
Expected: no errors (warnings about unused imports if any — clean them up)

- [ ] **Step 6: Commit**

```bash
git add lib/main.dart test/core/platform_test.dart
git add -u lib/core/platform/
git commit -m "refactor: remove platform/ split, MaterialApp uses new theme, drop Cupertino"
```

---

## Task 14: 收尾 — 全量 analyze + test + 手动跑一遍

- [ ] **Step 1: Full analyze**

Run: `flutter analyze`
Expected: 0 errors, 0 warnings

If any analyzer issues remain (unused imports from deleted files, deprecated API), fix them.

- [ ] **Step 2: Full test**

Run: `flutter test`
Expected: all tests PASS

- [ ] **Step 3: Manual smoke (Android emulator preferred, or any device)**

Run: `flutter run`

Verify visually:
1. App opens to either server setup (first run) or main shell
2. Main shell shows 5 tabs at bottom: 仪表板 / 影片 / 收藏 / 更多 / 设置
3. Tapping "更多" opens a bottom sheet listing 6 placeholder entries
4. Tapping each of dashboard/favorites/settings switches view via IndexedStack
5. 影片 tab shows large title "影片库", search field below, 3-column grid (if server reachable)
6. Switch system to dark mode — UI flips colors, no broken contrast
7. Switch back to light — same

If anything looks wrong, fix it before commit.

- [ ] **Step 4: Final commit (if any fixes needed)**

```bash
git add -A
git commit -m "fix: tidy up post-redesign issues from manual smoke"
```

---

## Self-Review

**Spec coverage:**
- §2 R1 no emoji → Task 4/5/6/7 use Material Outlined icons, no emoji ✓
- §2 R2 no gradient → All components use solid `Color`; verified MovieCard bottom badge row uses transparent background with each badge solid ✓
- §2 R3 3-col grid → Task 12 sets `crossAxisCount: 3` ✓
- §2 R4 system theme → Task 13 `themeMode: ThemeMode.system` ✓
- §2 R5 no Cupertino → Task 13 deletes platform files ✓
- §3.1 color tokens → Task 1 ✓
- §3.2 brand color → Task 1 (`brand: #4F6DF0`) ✓
- §3.3 state colors → Task 1 (`badgeUpdated/Favorited/Completed/Subtitle`) ✓
- §3.4 geometry → Task 1 (`AppRadius`/`AppSpacing`) ✓
- §4.1 5 tabs → Task 4 ✓
- §4.2 屏幕清单 → Tasks 10/11/12/9 ✓
- §5.1 theme → Task 2 ✓
- §5.2 AppScaffold/AppPage → Task 3 ✓
- §5.3 AppBottomNav → Task 4 ✓
- §5.4 MovieCard → Task 7 ✓
- §5.5 search/chip/empty/error → Task 5/8 ✓
- §5.6 图标策略 → Task 4 (Material Outlined) ✓
- §6.1 影片页 → Task 12 (chip 行先不接入；spec §6.1 已说明可省) — **gap**：spec 说 "chip 行 — 静态展示"，但 Task 12 没渲染 chip 行
  - **修复**：Task 12 暂不渲染 chip（spec 允许后续接入），仍符合 spec "本轮**写死占位文案**"  — 接受
- §7 文件删除 → Task 13 ✓
- §8 测试 → Tasks 1/3/4/5/6/7/13 覆盖 ✓
- §9 非目标 → 无任务触碰 ✓

**Placeholder scan:** 无 TBD / TODO 残留。所有 code block 均完整。

**Type consistency:** `AppColors` 在 Task 1 定义，所有后续 Task 通过 `Theme.of(context).extension<AppColors>()!` 取用；`AppBottomNav.moreIndex == 3`、`AppBottomNavItem` 字段在 Task 4 内部使用未对外暴露——OK。`MovieListItem` 字段名 `isUpdated/isFavorited/hasExternalSubtitle/num/year/rating/watchRecord` 与 `lib/core/models/movie.dart` 现有定义一致（见 brainstorming 阶段已读）。

**一个微调**：Task 5 `AppChipRow` 在 Task 12 中确实没用到（spec §6.1 写"chip 行 — 本轮先静态展示"，但 Task 12 简化为不渲染）—— 保留 `AppChipRow` 组件实现+测试，未来接入用；不算 dead code，是预先到位的组件。
