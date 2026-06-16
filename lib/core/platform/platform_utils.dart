import 'package:flutter/material.dart';

bool isCupertino(BuildContext context) =>
    Theme.of(context).platform == TargetPlatform.iOS;
