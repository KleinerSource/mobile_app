import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'platform_utils.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({super.key, required this.body, this.backgroundColor});

  final Widget body;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    if (isCupertino(context)) {
      return CupertinoPageScaffold(
        backgroundColor: backgroundColor,
        child: SafeArea(child: body),
      );
    }
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(child: body),
    );
  }
}
