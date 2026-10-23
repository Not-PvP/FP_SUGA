import 'package:flutter/material.dart';
import 'package:suga/screens/home_screen.dart';
import 'package:suga/screens/areas_screen.dart';
import 'package:suga/screens/scheduled_brownouts_screen.dart';
import 'package:suga/screens/settings_screen.dart';
import 'package:suga/theme/app_theme.dart';

// The four tabs and the bottom navigation bar.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  static const _home = 0;
  static const _areas = 1;
  static const _scheduled = 2;

  int _selectedIndex = _home;

  late final List<Widget> _screens = [
    HomeScreen(
      onNavigateToAreas: () => _selectTab(_areas),
      onNavigateToScheduled: () => _selectTab(_scheduled),
    ),
    // After "Set as home area", go back to Home to show that area's status.
    AreasScreen(onAreaSelected: () => _selectTab(_home)),
    const ScheduledBrownoutsScreen(),
    SettingsScreen(onNavigateToAreas: () => _selectTab(_areas)),
  ];

  void _selectTab(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Row(
              children: [
                _buildNavItem(0, 'Home', Icons.home_outlined, Icons.home_rounded),
                _buildNavItem(1, 'Areas', Icons.map_outlined, Icons.map_rounded),
                _buildNavItem(2, 'Scheduled', Icons.calendar_month_outlined, Icons.calendar_month_rounded),
                _buildNavItem(3, 'Settings', Icons.settings_outlined, Icons.settings_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, String label, IconData icon, IconData activeIcon) {
    final isSelected = _selectedIndex == index;
    final color = isSelected ? AppColors.amber : AppColors.textMuted;

    return Expanded(
      child: Semantics(
        selected: isSelected,
        button: true,
        label: '$label tab',
        excludeSemantics: true,
        child: InkWell(
          onTap: () => _selectTab(index),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(isSelected ? activeIcon : icon, size: 24, color: color),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: AppText.font,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
