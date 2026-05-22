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
