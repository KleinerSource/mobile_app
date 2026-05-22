import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui/app_bottom_nav.dart';
import '../../core/ui/app_more_sheet.dart';
import '../dashboard/dashboard_page.dart';
import '../favorites/favorites_page.dart';
import '../movies/movies_page.dart';
import '../settings/settings_page.dart';
import 'main_shell_providers.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key});

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
  Widget build(BuildContext context, WidgetRef ref) {
    final tabIndex = ref.watch(mainShellTabIndexProvider);
    final pageIdx = _pageIndexMap[tabIndex] ?? 0;
    return Scaffold(
      body: IndexedStack(index: pageIdx, children: _pages),
      bottomNavigationBar: AppBottomNav(
        currentIndex: tabIndex,
        onTap: (i) => ref.read(mainShellTabIndexProvider.notifier).state = i,
        onMoreTap: () => showAppMoreSheet(context),
      ),
    );
  }
}
