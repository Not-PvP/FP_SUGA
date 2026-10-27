import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:suga/models/power_interruption.dart';
import 'package:suga/providers/auth_provider.dart';
import 'package:suga/providers/power_interruption_provider.dart';
import 'package:suga/widgets/advisory_card.dart';
import 'package:suga/widgets/ui.dart';
import 'package:suga/widgets/upcoming_advisories_widget.dart';

enum _Scope { myAreas, allAreas }

// Scheduled tab: every upcoming brownout, grouped by day.
class ScheduledBrownoutsScreen extends StatefulWidget {
  const ScheduledBrownoutsScreen({super.key});

  @override
  State<ScheduledBrownoutsScreen> createState() => _ScheduledBrownoutsScreenState();
}

class _ScheduledBrownoutsScreenState extends State<ScheduledBrownoutsScreen> {
  // Users with saved areas see only those first; they can switch to every area.
  _Scope _scope = _Scope.myAreas;

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

  Widget _buildAllAdvisories(List<PowerInterruption> items) {
    if (items.isEmpty) {
      return const StatePanel(icon: Icons.inbox_outlined, title: 'No advisories yet');
    }
    // Newest first, so today's and ongoing advisories are at the top.
    return Column(
      children: [
        for (final item in items.reversed)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AdvisoryCard(advisory: item, showStatus: true),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PowerInterruptionProvider>();
    final items = provider.allInterruptions;
    final isAdmin = context.watch<AuthProvider>().isSignedIn;
    final showAll = isAdmin && _showAll;
    final followed = {...provider.savedAreaIds, ?provider.selectedAreaId};
    final canFilter = followed.isNotEmpty && !showAll;
    final onlyMine = canFilter && _scope == _Scope.myAreas;

    final Widget body;
    if (items.isEmpty && (provider.isLoading || !provider.hasLoaded) && provider.error == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (items.isEmpty && provider.error != null) {
      body = ListView(
        padding: const EdgeInsets.all(20),
        children: [
          StatePanel(
            icon: Icons.cloud_off_rounded,
            title: "Couldn't load brownouts",
            message: provider.error!,
            actionLabel: 'Retry',
            onAction: provider.loadInterruptions,
          ),
        ],
      );
    } else {
      body = RefreshIndicator(
        onRefresh: provider.loadInterruptions,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            showAll
                ? _buildAllAdvisories(items)
                : UpcomingAdvisoriesWidget(
                    areaIds: onlyMine ? followed : null,
                    showHeader: false,
                    groupByDate: true,
                    emptyMessage: onlyMine
                        ? 'Nothing scheduled in your saved areas. Switch to All areas to see the rest of the city.'
                        : null,
                  ),
          ],
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ScreenHeader(
              title: 'Scheduled brownouts',
              subtitle: 'Upcoming power interruptions, soonest first.',
            ),
            if (canFilter)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: SegmentedTabs<_Scope>(
                  options: const [(_Scope.myAreas, 'My areas'), (_Scope.allAreas, 'All areas')],
                  value: _scope,
                  onChanged: (scope) => setState(() => _scope = scope),
                ),
              ),
            // Only signed-in admins see this switch.
            if (isAdmin)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: SegmentedTabs<bool>(
                  options: const [(false, 'Upcoming'), (true, 'All advisories')],
                  value: _showAll,
                  onChanged: (all) => setState(() => _showAll = all),
                ),
              ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}
