import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:suga/models/area.dart';
import 'package:suga/providers/notification_provider.dart';
import 'package:suga/providers/power_interruption_provider.dart';
import 'package:suga/routes/app_routes.dart';
import 'package:suga/services/area_service.dart';
import 'package:suga/theme/app_theme.dart';
import 'package:suga/widgets/power_status_widget.dart';
import 'package:suga/widgets/ui.dart';
import 'package:suga/widgets/upcoming_advisories_widget.dart';

// Home tab: the power status of the home area and its next brownouts.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onNavigateToAreas, this.onNavigateToScheduled});

  final VoidCallback? onNavigateToAreas;
  final VoidCallback? onNavigateToScheduled;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _areaService = AreaService();

  // Fetched once and reused, so the area name does not flash "Loading" on every rebuild.
  Future<List<Area>>? _areas;
  Future<List<Area>> get _areasFuture => _areas ??= _areaService.fetchAreas();

  @override
  void initState() {
    super.initState();
    // Load after the first frame, because notifyListeners() must not run during a build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<PowerInterruptionProvider>();
      if (!provider.hasLoaded && !provider.isLoading) provider.loadInterruptions();
    });
  }

  void _openAreas() {
    final open = widget.onNavigateToAreas;
    if (open != null) {
      open();
    } else {
      Navigator.pushNamed(context, AppRoutes.areas);
    }
  }

  Future<void> _refresh() async {
    setState(() => _areas = null);
    await context.read<PowerInterruptionProvider>().loadInterruptions();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PowerInterruptionProvider>();
    final areaId = provider.selectedAreaId;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _buildTopBar(),
              const SizedBox(height: 12),
              if (!provider.areasRestored)
                const SizedBox(height: 320, child: Center(child: CircularProgressIndicator()))
              else if (areaId == null)
                _ChooseAreaHero(onChoose: _openAreas)
              else ...[
                _AreaBar(areas: _areasFuture, areaId: areaId, onChange: _openAreas),
                const SizedBox(height: 8),
                const PowerStatusWidget(),
                const SizedBox(height: 32),
                UpcomingAdvisoriesWidget(
                  areaIds: {areaId},
                  limit: 3,
                  onSeeAll: widget.onNavigateToScheduled,
                  emptyMessage: "We'll list brownouts for your area here as soon as they're announced.",
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        const Semantics(
          header: true,
          child: Text(
            'SUGA',
            style: TextStyle(
              fontFamily: AppText.font,
              color: AppColors.amber,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ),
        const Spacer(),
        Consumer<NotificationProvider>(
          builder: (context, notifications, _) {
            final unread = notifications.unreadCount;
            return IconButton(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.notifications),
              tooltip: unread > 0 ? 'Notifications, $unread unread' : 'Notifications',
              style: IconButton.styleFrom(
                side: const BorderSide(color: AppColors.line),
              ),
              icon: Badge(
                isLabelVisible: unread > 0,
                label: Text('$unread'),
                backgroundColor: AppColors.outage,
                textColor: AppColors.ink,
                child: const Icon(Icons.notifications_none_rounded, color: AppColors.amber),
              ),
            );
          },
        ),
      ],
    );
  }
}

// The home area's name, with a button to pick another one.
class _AreaBar extends StatelessWidget {
  const _AreaBar({required this.areas, required this.areaId, required this.onChange});

  final Future<List<Area>> areas;
  final int areaId;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return SugaCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      child: Row(
        children: [
          const IconTile(Icons.location_on_outlined, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: FutureBuilder<List<Area>>(
              future: areas,
              builder: (context, snapshot) {
                final matches = snapshot.data?.where((area) => area.id == areaId);
                final area = matches == null || matches.isEmpty ? null : matches.first;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Your area', style: AppText.small),
                    const SizedBox(height: 2),
                    Text(
                      area == null
                          ? (snapshot.hasError ? 'Saved area' : 'Loading…')
                          : '${area.name}, ${area.city}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.cardTitle,
                    ),
                  ],
                );
              },
            ),
          ),
          TextButton(onPressed: onChange, child: const Text('Change')),
        ],
      ),
    );
  }
}

// First run: no area picked yet.
class _ChooseAreaHero extends StatelessWidget {
  const _ChooseAreaHero({required this.onChoose});

  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          SizedBox(
            height: 170,
            child: OverflowBox(
              maxWidth: 220,
              maxHeight: 220,
              child: SvgPicture.asset(
                'assets/images/bulb_off.svg',
                width: 220,
                height: 220,
                semanticsLabel: 'Light bulb',
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Pick your area', textAlign: TextAlign.center, style: AppText.headline),
          const SizedBox(height: 10),
          const Text(
            'SUGA shows whether your area has power and reminds you before scheduled brownouts.',
            textAlign: TextAlign.center,
            style: AppText.body,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onChoose,
              icon: const Icon(Icons.location_on_outlined),
              label: const Text('Choose area'),
            ),
          ),
        ],
      ),
    );
  }
}
