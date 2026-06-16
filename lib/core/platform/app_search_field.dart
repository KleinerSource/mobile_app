import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'platform_utils.dart';

class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    required this.controller,
    this.placeholder = '搜索',
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String placeholder;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    if (isCupertino(context)) {
      return CupertinoSearchTextField(
        controller: controller,
        placeholder: placeholder,
        onSubmitted: onSubmitted,
      );
    }
    return SearchBar(
      controller: controller,
      hintText: placeholder,
      leading: const Icon(Icons.search),
      onSubmitted: onSubmitted,
    );
  }
}
