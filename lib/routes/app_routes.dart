import 'package:flutter/material.dart';
import 'package:suga/screens/home_screen.dart';
import 'package:suga/screens/settings_screen.dart';

class AppRoutes {
  static const String home = '/';
  static const String settings = '/settings';

  static Map<String, WidgetBuilder> get routes => {
    home: (_) => const HomeScreen(),
    settings: (_) => const SettingsScreen(),
  };
}
