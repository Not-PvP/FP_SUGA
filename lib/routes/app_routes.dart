import 'package:flutter/material.dart';

import 'package:suga/screens/settings_screen.dart';

import 'package:suga/screens/areas_screen.dart';
import 'package:suga/screens/area_details_screen.dart';
import 'package:suga/screens/scheduled_brownouts_screen.dart';
import 'package:suga/screens/brownout_details_screen.dart';
import 'package:suga/screens/notifications_screen.dart';
import 'package:suga/screens/main_screen.dart';
import 'package:suga/screens/admin_login_screen.dart';

class AppRoutes {
  static const String home = '/';
  static const String settings = '/settings';

  static const String areas = '/areas';
  static const String areaDetails = '/area_details';
  static const String scheduledBrownouts = '/brownouts';
  static const String brownoutDetails = '/brownout_details';
  static const String notifications = '/notifications';

  // After signing in, admins use the normal screens, which then show admin buttons.
  static const String adminLogin = '/admin/login';

  static Map<String, WidgetBuilder> get routes => {
    home: (_) => const MainScreen(),
    settings: (_) => const SettingsScreen(),
    areas: (_) => const AreasScreen(),
    areaDetails: (_) => const AreaDetailsScreen(),
    scheduledBrownouts: (_) => const ScheduledBrownoutsScreen(),
    brownoutDetails: (_) => const BrownoutDetailsScreen(),
    notifications: (_) => const NotificationsScreen(),
    adminLogin: (_) => const AdminLoginScreen(),
  };
}
