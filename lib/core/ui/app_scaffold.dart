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
