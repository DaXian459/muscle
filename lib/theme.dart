import 'package:flutter/material.dart';

/// 主色调：偏运动感的青绿色。
const Color kSeedColor = Color(0xFF0E9F6E);

ThemeData buildAppTheme() => ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: kSeedColor),
    );
