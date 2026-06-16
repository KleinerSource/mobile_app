import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'platform_utils.dart';

/// 用法：
///   CustomScrollView(slivers: [AppLargeNavBar(title: '影片'), ...])
class AppLargeNavBar extends StatelessWidget {
  const AppLargeNavBar({super.key, required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    if (isCupertino(context)) {
      return CupertinoSliverNavigationBar(
        largeTitle: Text(title),
        trailing: trailing,
      );
    }
    return SliverAppBar.large(
      title: Text(title),
      actions: trailing == null ? null : [trailing!],
      pinned: true,
    );
  }
}
