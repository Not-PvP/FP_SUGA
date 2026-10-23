import 'package:flutter/material.dart';
import 'package:suga/models/area.dart';
import 'package:suga/services/area_service.dart';
import 'package:provider/provider.dart';
import 'package:suga/providers/power_interruption_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:suga/providers/auth_provider.dart';
import 'package:suga/providers/notification_provider.dart';
import 'package:suga/routes/app_routes.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.onNavigateToAreas});

  final VoidCallback? onNavigateToAreas;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Future<List<Area>> _areasFuture;
  // Push, lead time and power restored settings live in NotificationProvider,
  // so they are saved and used to schedule reminders.
  bool _weatherAlerts = false;

  Widget _buildNotificationsSection() {

    const cardColor = Color(0xFF111720);
    const borderColor = Color(0xFF292F38);
    const secondaryText = Color(0xFF9CA3AF);

    Widget settingDivider() => const Divider(color: borderColor, height: 1);

    // Rebuilds when a notification setting changes.
    return Consumer<NotificationProvider>(
      builder: (context, notifications, _) {
        final pushEnabled = notifications.pushEnabled;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(0, 12, 0, 12),
              child: Text(
                'NOTIFICATIONS',
                style: TextStyle(
                  color: secondaryText,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
            ),

            Container(
              margin: const EdgeInsets.fromLTRB(0, 0, 0, 24),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  // Master push notification toggle
                  _buildAlertToggle(
                    title: 'Push Notifications',
                    subtitle: 'Still receive alerts from SUGA',
                    value: pushEnabled,
                    enabled: true,
                    onChanged: notifications.setPushEnabled,
                  ),
                  settingDivider(),

                  // Alert reminder timing
                  Opacity(
                    opacity: pushEnabled ? 1 : 0.45,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Alert me before',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Upcoming scheduled brownouts',
                                  style: TextStyle(
                                    color: Color(0xFF9CA3AF),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF070A0F),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF292F38)),
                            ),
                            child: DropdownButton<int>(
                              value: notifications.leadMinutes,
                              isDense: false,
                              underline: const SizedBox.shrink(),
                              dropdownColor: const Color(0xFF111720),
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Color(0xFFFFBF00),
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              items: [
                                for (final minutes in NotificationProvider.leadTimeOptions)
                                  DropdownMenuItem(
                                    value: minutes,
                                    child: Text(NotificationProvider.leadTimeLabel(minutes)),
                                  ),
                              ],
                              onChanged: !pushEnabled
                                  ? null
                                  : (value) {
                                      if (value == null) return;
                                      notifications.setLeadMinutes(value);
                                    },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  settingDivider(),

                  // Power restoration alerts
                  _buildAlertToggle(
                    title: 'Power Restored Alerts',
                    subtitle: 'Know when electricity returns',
                    value: notifications.restoredAlerts,
                    enabled: pushEnabled,
                    onChanged: notifications.setRestoredAlerts,
                  ),

                  settingDivider(),

                  // Weather alerts
                  _buildAlertToggle(
                    title: 'Weather Alerts',
                    subtitle: 'Get notified about severe weather',
                    value: _weatherAlerts,
                    enabled: pushEnabled,
                    onChanged: (value) {
                      setState(() {
                        _weatherAlerts = value;
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAdminSection() {
    const amber = Color(0xFFFFBF00);
    const danger = Color(0xFFF87171);
    const cardColor = Color(0xFF111720);
    const borderColor = Color(0xFF292F38);
    const secondaryText = Color(0xFF9CA3AF);

    // Rebuilds when the admin signs in or out, or the session expires.
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final admin = auth.admin;
        final signedIn = admin != null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(0, 12, 0, 12),
              child: Text(
                'ADMIN',
                style: TextStyle(
                  color: secondaryText,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: signedIn ? amber.withValues(alpha: 0.5) : borderColor,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF292315),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          signedIn
                              ? Icons.verified_user_outlined
                              : Icons.admin_panel_settings_outlined,
                          color: amber,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              signedIn ? 'Signed in as admin' : 'Admin Login',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              signedIn
                                  ? admin.email
                                  : 'Manage advisories and feeder information',
                              style: const TextStyle(
                                color: secondaryText,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (signedIn) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Admin tools are shown on Scheduled Brownouts and on each advisory.',
                      style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: signedIn
                        ? OutlinedButton.icon(
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              await context.read<AuthProvider>().logout();
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Signed out. Admin tools are hidden.'),
                                ),
                              );
                            },
                            icon: const Icon(Icons.logout_rounded, size: 18),
                            label: const Text('Sign Out'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: danger,
                              side: BorderSide(color: danger.withValues(alpha: 0.5)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        : ElevatedButton.icon(
                            onPressed: () =>
                                Navigator.pushNamed(context, AppRoutes.adminLogin),
                            icon: const Icon(Icons.login_rounded, size: 18),
                            label: const Text('Open Admin Portal'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: amber,
                              foregroundColor: const Color(0xFF070A0F),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAboutSection() {
    const amber = Color(0xFFFFBF00);
    const cardColor = Color(0xFF111720);
    const borderColor = Color(0xFF292F38);
    const secondaryText = Color(0xFF9CA3AF);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(0, 12, 0, 12),
          child: Text(
            'ABOUT',
            style: TextStyle(
              color: secondaryText,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SUGA',
                          style: TextStyle(
                            color: amber,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Brownout Tracker',
                          style: TextStyle(color: secondaryText, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF292315),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: amber.withValues(alpha: 0.4)),
                    ),
                    child: const Text(
                      'v1.0.0',
                      style: TextStyle(
                        color: amber,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(color: borderColor, height: 1),
              const SizedBox(height: 16),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.verified_outlined, color: amber, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DATA',
                          style: TextStyle(
                            color: secondaryText,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'Verified by official advisories',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.code_rounded, color: amber, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MADE BY',
                          style: TextStyle(
                            color: secondaryText,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'Florencio and Olmo',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(color: borderColor, height: 1),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final uri = Uri.https('github.com', '/Not-PvP/FP_SUGA');

                  try {
                    final opened = await launchUrl(
                      uri,
                      mode: LaunchMode.platformDefault,
                    );

                    if (!opened && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Unable to open GitHub. Please try again.',
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Could not open GitHub: $e')),
                      );
                    }
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.code_rounded, color: amber, size: 22),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'GitHub Repository',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'View the SUGA source code',
                              style: TextStyle(
                                color: Color(0xFF9CA3AF),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.open_in_new_rounded,
                        color: secondaryText,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAlertToggle({
    required String title,
    required String subtitle,
    required bool value,
    required bool enabled,
    required ValueChanged<bool> onChanged,
  }) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              activeTrackColor: const Color(0xFFFFBF00),
              inactiveTrackColor: const Color(0xFF374151),
              onChanged: enabled ? onChanged : null,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _areasFuture = AreaService().fetchAreas();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070A0F),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Settings',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Customize your SUGA Experience.',
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                  ),
                ],
              ),
            ),

            // Saved areas
            Expanded(
              child: FutureBuilder<List<Area>>(
                future: _areasFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFFFBF00),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return const Center(
                      child: Text(
                        'Unable to load saved areas.',
                        style: TextStyle(color: Color(0xFF9CA3AF)),
                      ),
                    );
                  }

                  final areas = snapshot.data ?? [];
                  final savedAreaIds = context
                      .watch<PowerInterruptionProvider>()
                      .savedAreaIds;

                  final savedAreas = areas
                      .where((area) => savedAreaIds.contains(area.id))
                      .toList();

                  final mainAreaId = context
                      .read<PowerInterruptionProvider>()
                      .selectedAreaId;

                  savedAreas.sort((a, b) {
                    if (a.id == mainAreaId) return -1;
                    if (b.id == mainAreaId) return 1;
                    return 0;
                  });

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    itemCount: savedAreas.length + 5,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return const Padding(
                          padding: EdgeInsets.only(bottom: 2),
                          child: Text(
                            'MY AREAS',
                            style: TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.5,
                            ),
                          ),
                        );
                      }

                      final areaIndex = index - 1;

                      if (areaIndex == savedAreas.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 4),
                          child: InkWell(
                            onTap: widget.onNavigateToAreas,
                            borderRadius: BorderRadius.circular(18),
                            child: CustomPaint(
                              painter: const _DashedBorderPainter(
                                color: Color(0xFF4B5563),
                                radius: 18,
                              ),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 20,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0C1118),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      savedAreas.isEmpty
                                          ? Icons.location_searching_rounded
                                          : Icons.add_location_alt_outlined,
                                      color: const Color(0xFFFFBF00),
                                      size: 26,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      savedAreas.isEmpty
                                          ? 'No saved areas yet'
                                          : 'Add another area',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      savedAreas.isEmpty
                                          ? 'Browse locations to get started'
                                          : 'Browse and save more locations',
                                      style: TextStyle(
                                        color: Color(0xFF9CA3AF),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }

                      if (areaIndex == savedAreas.length + 1) {
                        return _buildNotificationsSection();
                      }

                      if (areaIndex == savedAreas.length + 2) {
                        return _buildAdminSection();
                      }

                      if (areaIndex == savedAreas.length + 3) {
                        return _buildAboutSection();
                      }

                      final area = savedAreas[areaIndex];

                      final provider = context
                          .watch<PowerInterruptionProvider>();
                      final isMain = provider.selectedAreaId == area.id;

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111720),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isMain
                                ? const Color(0xFFFFBF00).withValues(alpha: 0.5)
                                : const Color(0xFF292F38),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: isMain
                                        ? const Color(0xFF292315)
                                        : const Color(0xFF1A2029),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isMain
                                          ? const Color(
                                              0xFFFFBF00,
                                            ).withValues(alpha: 0.5)
                                          : const Color(0xFF374151),
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.location_on_outlined,
                                    color: isMain
                                        ? const Color(0xFFFFBF00)
                                        : const Color(0xFF9CA3AF),
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        area.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        area.city,
                                        style: const TextStyle(
                                          color: Color(0xFF9CA3AF),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                if (isMain)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF292315),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: const Color(
                                          0xFFFFBF00,
                                        ).withValues(alpha: 0.4),
                                      ),
                                    ),
                                    child: const Text(
                                      'MAIN',
                                      style: TextStyle(
                                        color: Color(0xFFFFBF00),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  )
                                else ...[
                                  const SizedBox(width: 4),
                                  InkWell(
                                    onTap: () {
                                      context
                                          .read<PowerInterruptionProvider>()
                                          .setMainArea(area.id);
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1F2937),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: const Color(
                                            0xFF374151,
                                          ).withValues(alpha: 0.4),
                                        ),
                                      ),
                                      child: const Text(
                                        'Set as main',
                                        style: TextStyle(
                                          color: Color(0xFFD1D5DB),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),

                                  SizedBox(width: 4),

                                  TextButton(
                                    onPressed: () {
                                      context
                                          .read<PowerInterruptionProvider>()
                                          .removeSavedArea(area.id);
                                    },
                                    style: TextButton.styleFrom(
                                      foregroundColor: const Color(0xFFF87171),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text(
                                      'Remove',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),

                            const SizedBox(height: 14),
                            const Divider(color: Color(0xFF292F38), height: 1),
                            const SizedBox(height: 12),

                            Row(
                              children: [
                                const Icon(
                                  Icons.notifications_active_outlined,
                                  color: Color(0xFFFFBF00),
                                  size: 16,
                                ),
                                const SizedBox(width: 7),
                                const Expanded(
                                  child: Text(
                                    'Notifications enabled',
                                    style: TextStyle(
                                      color: Color(0xFFD1D5DB),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    //TODO
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFFFFBF00),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 4,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Customize',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(width: 4),
                                      Icon(Icons.arrow_forward, size: 14),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );

    for (final metric in path.computeMetrics()) {
      double distance = 0;

      while (distance < metric.length) {
        final end = (distance + 6).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += 10;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}
