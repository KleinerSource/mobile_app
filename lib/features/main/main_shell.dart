import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/platform/platform.dart';
import '../favorites/favorites_page.dart';
import '../movies/movies_page.dart';
import '../settings/settings_page.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context) {
    final cupertino = isCupertino(context);
    return AppTabsShell(
      tabs: [
        AppTabItem(
          icon: cupertino ? CupertinoIcons.film : Icons.movie_outlined,
          label: '影片',
          body: const MoviesPage(),
        ),
        AppTabItem(
          icon: cupertino ? CupertinoIcons.star : Icons.star_outline,
          label: '收藏',
          body: const FavoritesPage(),
        ),
        AppTabItem(
          icon: cupertino ? CupertinoIcons.settings : Icons.settings_outlined,
          label: '设置',
          body: const SettingsPage(),
        ),
      ],
    );
  }
}
