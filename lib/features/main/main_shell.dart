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
