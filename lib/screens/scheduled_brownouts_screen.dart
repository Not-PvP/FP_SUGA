import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:suga/models/power_interruption.dart';
import 'package:suga/providers/auth_provider.dart';
import 'package:suga/providers/power_interruption_provider.dart';
import 'package:suga/routes/app_routes.dart';
import 'package:suga/widgets/status_badge.dart';
import 'package:suga/widgets/upcoming_advisories_widget.dart';

class ScheduledBrownoutsScreen extends StatefulWidget {
  const ScheduledBrownoutsScreen({super.key});

  @override
  State<ScheduledBrownoutsScreen> createState() =>
      _ScheduledBrownoutsScreenState();
}

class _ScheduledBrownoutsScreenState extends State<ScheduledBrownoutsScreen> {
  // Admin only: also list ongoing, restored, cancelled and past advisories,
  // so they can be opened and updated.
  bool _showAll = false;

  @override
  void initState() {
    super.initState();
    // Load after the first frame, because notifyListeners() must not run during a build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<PowerInterruptionProvider>();
      if (!provider.hasLoaded) provider.loadInterruptions();
    });
  }

  Widget _buildAdminToggle() {
    Widget option(String label, bool all) {
      final selected = _showAll == all;
      return Expanded(
        child: InkWell(
          onTap: () => setState(() => _showAll = all),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF292315) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? const Color(0xFFFFBF00).withValues(alpha: 0.5)
                    : Colors.transparent,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? const Color(0xFFFFBF00) : const Color(0xFF9CA3AF),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFF111720),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF292F38)),
        ),
        child: Row(
          children: [
            option('Upcoming', false),
            const SizedBox(width: 4),
            option('All advisories', true),
          ],
        ),
      ),
    );
  }

  Widget _buildAllAdvisories(List<PowerInterruption> items) {
    if (items.isEmpty) {
      return const Text(
        'No advisories yet.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
      );
    }
    // Newest first, so today's and ongoing advisories are at the top.
    final sorted = items.reversed.toList();
    return Column(
      children: [
        for (final item in sorted)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: const Color(0xFF111720),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.brownoutDetails,
                  arguments: item,
                ),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF292F38)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _formatWhen(item),
                              style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusBadge(status: item.status),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  static String _formatWhen(PowerInterruption item) {
    try {
      final date = DateFormat('MMM d, y').format(DateTime.parse(item.date));
      final start = DateFormat('h:mm a').format(DateFormat('HH:mm').parse(item.startTime));
      final end = DateFormat('h:mm a').format(DateFormat('HH:mm').parse(item.endTime));
      return '$date · $start – $end';
    } catch (_) {
      return '${item.date} · ${item.startTime} – ${item.endTime}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PowerInterruptionProvider>();
    final items = provider.allInterruptions;
    final isAdmin = context.watch<AuthProvider>().isSignedIn;
    final showAll = isAdmin && _showAll;

    final Widget body;
    if (items.isEmpty &&
        (provider.isLoading || !provider.hasLoaded) &&
        provider.error == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (items.isEmpty && provider.error != null) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(provider.error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: provider.loadInterruptions,
              child: const Text('Retry'),
            ),
          ],
        ),
      );

    } else {
      body = RefreshIndicator(
        onRefresh: provider.loadInterruptions,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          children: [
            showAll
                ? _buildAllAdvisories(items)
                : const UpcomingAdvisoriesWidget(showHeader: false, groupByDate: true),
          ],
        ),
      );
    }

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
                    'Scheduled Brownouts',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Stay informed about upcoming power interruptions.',
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                  ),
                ],
              ),
            ),

            // Only signed-in admins see this switch.
            if (isAdmin) _buildAdminToggle(),

            // Existing loading, error, or brownout list
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}
