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
