import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:suga/models/area.dart';
import 'package:suga/providers/auth_provider.dart';
import 'package:suga/providers/notification_provider.dart';
import 'package:suga/providers/power_interruption_provider.dart';
import 'package:suga/routes/app_routes.dart';
import 'package:suga/services/area_service.dart';
import 'package:suga/theme/app_theme.dart';
import 'package:suga/widgets/ui.dart';
import 'package:url_launcher/url_launcher.dart';

// Settings tab: saved areas, alert preferences, admin sign-in and app info.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.onNavigateToAreas});

  final VoidCallback? onNavigateToAreas;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _areaService = AreaService();
  late Future<List<Area>> _areasFuture = _areaService.fetchAreas();

  void _retryAreas() => setState(() => _areasFuture = _areaService.fetchAreas());

  void _browseAreas() {
    final open = widget.onNavigateToAreas;
    if (open != null) {
      open();
    } else {
      Navigator.pushNamed(context, AppRoutes.areas);
    }
  }

  Future<void> _openGitHub() async {
    final messenger = ScaffoldMessenger.of(context);
    final opened = await launchUrl(Uri.https('github.com', '/Not-PvP/FP_SUGA'))
        .catchError((_) => false);
    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't open GitHub. Visit github.com/Not-PvP/FP_SUGA.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Navigator.canPop(context) ? AppBar() : null,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            const ScreenHeader(
              title: 'Settings',
              subtitle: 'Your areas, alerts, and app info.',
              padding: EdgeInsets.fromLTRB(0, 20, 0, 20),
            ),
            const SectionLabel('Saved areas'),
            _buildSavedAreas(),
            const SizedBox(height: 32),
            const SectionLabel('Alerts'),
            _buildAlerts(),
            const SizedBox(height: 32),
            const SectionLabel('Admin'),
            _buildAdmin(),
            const SizedBox(height: 32),
            const SectionLabel('About'),
            _buildAbout(),
          ],
        ),
      ),
    );
  }

  // Saved areas -------------------------------------------------------------

  Widget _buildSavedAreas() {
    return FutureBuilder<List<Area>>(
      future: _areasFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return ErrorPanel(
            what: 'your areas',
            error: snapshot.error!,
            onRetry: _retryAreas,
          );
        }

        final provider = context.watch<PowerInterruptionProvider>();
        final homeId = provider.selectedAreaId;
        final saved = snapshot.data!
            .where((area) => provider.savedAreaIds.contains(area.id))
            .toList()
          ..sort((a, b) => a.id == homeId ? -1 : (b.id == homeId ? 1 : 0));

        return Column(
          children: [
            for (final area in saved) ...[
              _SavedAreaTile(area: area, isHome: area.id == homeId),
              const SizedBox(height: 10),
            ],
            _AddAreaTile(firstArea: saved.isEmpty, onTap: _browseAreas),
          ],
        );
      },
    );
  }

  // Alerts ------------------------------------------------------------------

  Widget _buildAlerts() {
    return Consumer<NotificationProvider>(
      builder: (context, notifications, _) {
        final pushEnabled = notifications.pushEnabled;
        return SugaCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: [
              _toggle(
                title: 'Phone alerts',
                subtitle: 'Reminders and updates for your saved areas',
                value: pushEnabled,
                onChanged: notifications.setPushEnabled,
              ),
              const Divider(),
              Opacity(
                opacity: pushEnabled ? 1 : 0.45,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Remind me before', style: AppText.cardTitle),
                            SizedBox(height: 2),
                            Text('Each scheduled brownout', style: AppText.small),
                          ],
                        ),
                      ),
                      DropdownButton<int>(
                        value: notifications.leadMinutes,
                        underline: const SizedBox.shrink(),
                        dropdownColor: AppColors.surfaceRaised,
                        borderRadius: BorderRadius.circular(12),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.amber),
                        style: AppText.body.copyWith(color: AppColors.text),
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
                                if (value != null) notifications.setLeadMinutes(value);
                              },
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(),
              _toggle(
                title: 'Power restored',
                subtitle: 'Tell me when electricity comes back',
                value: notifications.restoredAlerts,
                onChanged: pushEnabled ? notifications.setRestoredAlerts : null,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _toggle({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Opacity(
      opacity: onChanged == null ? 0.45 : 1,
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title, style: AppText.cardTitle),
        subtitle: Text(subtitle, style: AppText.small),
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  // Admin -------------------------------------------------------------------

  Widget _buildAdmin() {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final admin = auth.admin;
        final signedIn = admin != null;
        return SugaCard(
          borderColor: signedIn ? AppColors.amber.withValues(alpha: 0.5) : AppColors.line,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconTile(
                    signedIn ? Icons.verified_user_outlined : Icons.admin_panel_settings_outlined,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(signedIn ? 'Signed in as admin' : 'Admin sign-in', style: AppText.cardTitle),
                        const SizedBox(height: 2),
                        Text(
                          signedIn ? admin.email : 'For SUGA staff who post advisories',
                          style: AppText.small,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (signedIn) ...[
                const SizedBox(height: 12),
                const Text(
                  'Admin tools appear on Scheduled brownouts and on each advisory.',
                  style: AppText.muted,
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: signedIn
                    ? OutlinedButton.icon(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          await context.read<AuthProvider>().logout();
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Signed out. Admin tools are hidden.')),
                          );
                        },
                        icon: const Icon(Icons.logout_rounded, size: 18),
                        label: const Text('Sign out'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.outage,
                          side: BorderSide(color: AppColors.outage.withValues(alpha: 0.5)),
                        ),
                      )
                    : OutlinedButton.icon(
                        onPressed: () => Navigator.pushNamed(context, AppRoutes.adminLogin),
                        icon: const Icon(Icons.login_rounded, size: 18),
                        label: const Text('Sign in as admin'),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  // About -------------------------------------------------------------------

  Widget _buildAbout() {
    return SugaCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Column(
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'SUGA',
                style: TextStyle(
                  fontFamily: AppText.font,
                  color: AppColors.amber,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 3),
                  child: Text('Brownout alerts for Iloilo', style: AppText.muted),
                ),
              ),
              Text('Version 1.0.0', style: AppText.small),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const _AboutRow(
            icon: Icons.verified_outlined,
            label: 'Data',
            value: 'Advisories are entered by SUGA admins from official MORE Power announcements.',
          ),
          const _AboutRow(icon: Icons.groups_outlined, label: 'Made by', value: 'Florencio and Olmo'),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            onTap: _openGitHub,
            leading: const Icon(Icons.code_rounded, color: AppColors.amber),
            title: const Text('Source code on GitHub', style: AppText.cardTitle),
            trailing: const Icon(Icons.open_in_new_rounded, color: AppColors.textMuted, size: 18),
          ),
        ],
      ),
    );
  }
}

class _SavedAreaTile extends StatelessWidget {
  const _SavedAreaTile({required this.area, required this.isHome});

  final Area area;
  final bool isHome;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<PowerInterruptionProvider>();
    return SugaCard(
      borderColor: isHome ? AppColors.amber.withValues(alpha: 0.5) : AppColors.line,
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      child: Row(
        children: [
          IconTile(
            isHome ? Icons.home_rounded : Icons.location_on_outlined,
            color: isHome ? AppColors.amber : AppColors.textMuted,
            background: isHome ? AppColors.amberSoft : AppColors.chip,
            size: 40,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(area.name, style: AppText.cardTitle),
                const SizedBox(height: 2),
                Text(isHome ? '${area.city} · Home area' : area.city, style: AppText.small),
              ],
            ),
          ),
          if (isHome)
            const SizedBox(width: 12)
          else
            PopupMenuButton<String>(
              tooltip: 'Options for ${area.name}',
              icon: const Icon(Icons.more_vert_rounded, color: AppColors.textMuted),
              onSelected: (action) {
                if (action == 'home') {
                  provider.setMainArea(area.id);
                } else {
                  provider.removeSavedArea(area.id);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'home', child: Text('Set as home area')),
                PopupMenuItem(
                  value: 'remove',
                  child: Text('Remove', style: TextStyle(color: AppColors.outage)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _AddAreaTile extends StatelessWidget {
  const _AddAreaTile({required this.firstArea, required this.onTap});

  final bool firstArea;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: CustomPaint(
        painter: const _DashedBorderPainter(color: AppColors.lineStrong, radius: AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                firstArea ? Icons.location_searching_rounded : Icons.add_location_alt_outlined,
                color: AppColors.amber,
              ),
              const SizedBox(width: 10),
              Text(
                firstArea ? 'Choose your first area' : 'Add another area',
                style: AppText.cardTitle.copyWith(color: AppColors.amber),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.amber, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppText.small),
                const SizedBox(height: 2),
                Text(value, style: AppText.body.copyWith(color: AppColors.text)),
              ],
            ),
          ),
        ],
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
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
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
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
