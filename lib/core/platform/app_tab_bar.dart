import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'platform.dart';

class AppTabItem {
  const AppTabItem({required this.icon, required this.label, required this.body});
  final IconData icon;
  final String label;
  final Widget body;
}

class AppTabsShell extends StatefulWidget {
  const AppTabsShell({super.key, required this.tabs});
  final List<AppTabItem> tabs;

  @override
  State<AppTabsShell> createState() => _AppTabsShellState();
}

class _AppTabsShellState extends State<AppTabsShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    if (isCupertino(context)) {
      return CupertinoTabScaffold(
        tabBar: CupertinoTabBar(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          items: widget.tabs
              .map((t) => BottomNavigationBarItem(
                    icon: Icon(t.icon),
                    label: t.label,
                  ))
              .toList(),
        ),
        tabBuilder: (ctx, i) => CupertinoTabView(builder: (_) => widget.tabs[i].body),
      );
    }
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: widget.tabs.map((t) => t.body).toList(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: widget.tabs
            .map((t) => NavigationDestination(icon: Icon(t.icon), label: t.label))
            .toList(),
      ),
    );
  }
}
