import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:suga/models/area.dart';
import 'package:suga/providers/power_interruption_provider.dart';
import 'package:suga/routes/app_routes.dart';
import 'package:suga/services/area_service.dart';
import 'package:suga/theme/app_theme.dart';
import 'package:suga/utils/advisory_time.dart';
import 'package:suga/utils/format.dart';
import 'package:suga/widgets/ui.dart';

// Areas tab: search every area and see which ones have power right now.
class AreasScreen extends StatefulWidget {
  const AreasScreen({super.key, this.service, this.onAreaSelected});

  final AreaService? service;

  // Called after the user sets a new home area, e.g. to switch back to Home.
  final VoidCallback? onAreaSelected;

  @override
  State<AreasScreen> createState() => _AreasScreenState();
}

class _AreasScreenState extends State<AreasScreen> {
  late final AreaService _service = widget.service ?? AreaService();
  late Future<List<Area>> _areas = _service.fetchAreas();
  final TextEditingController _searchController = TextEditingController();
  String _search = '';
  Timer? _searchDebounce;

  void _searchAreas(String value) {
    // Rebuild right away so the clear button appears while typing.
    setState(() => _search = value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _areas = _service.fetchAreas(search: _search));
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {
      _search = '';
      _areas = _service.fetchAreas();
    });
  }

  void _load() {
    setState(() => _areas = _service.fetchAreas(search: _search));
  }

  // Area Details returns true when the user tapped "Set as home area".
  Future<void> _open(Area area) async {
    // Not pushNamed<bool>: the routes in AppRoutes are untyped, so a typed push fails at runtime.
    final setAsHome = await Navigator.pushNamed(
      context,
      AppRoutes.areaDetails,
      arguments: area.id,
    );
    if (!mounted || setAsHome != true) return;
    final onSelected = widget.onAreaSelected;
    if (onSelected != null) {
      onSelected();
    } else if (Navigator.canPop(context)) {
      // Opened as its own page (e.g. from Notifications): go back there.
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Navigator.canPop(context) ? AppBar() : null,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ScreenHeader(
              title: 'Areas',
              subtitle: 'Find your area to see its power status and upcoming brownouts.',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: TextField(
                controller: _searchController,
                style: AppText.body.copyWith(color: AppColors.text),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _search.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          tooltip: 'Clear search',
                          onPressed: _clearSearch,
                        ),
                  hintText: 'Search areas, like Jaro or Molo',
                ),
                textInputAction: TextInputAction.search,
                onChanged: _searchAreas,
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Area>>(
                future: _areas,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        StatePanel(
                          icon: Icons.cloud_off_rounded,
                          title: "Couldn't load areas",
                          message: '${snapshot.error}',
                          actionLabel: 'Retry',
                          onAction: _load,
                        ),
                      ],
                    );
                  }
                  final areas = snapshot.data!;
                  if (areas.isEmpty) {
                    final searching = _search.trim().isNotEmpty;
                    return ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        StatePanel(
                          icon: Icons.location_off_outlined,
                          title: searching ? 'No areas match "${_search.trim()}"' : 'No areas yet',
                          message: searching
                              ? 'Check the spelling or try a nearby area.'
                              : 'Areas added by SUGA admins will appear here.',
                        ),
                      ],
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    itemCount: areas.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _AreaTile(
                      area: areas[i],
                      onTap: () => _open(areas[i]),
                    ),
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

class _AreaTile extends StatelessWidget {
  const _AreaTile({required this.area, required this.onTap});

  final Area area;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PowerInterruptionProvider>();
    final loaded = provider.hasLoaded;
    final outage = loaded ? provider.currentOutage(area.id) : null;
    final next = loaded && outage == null ? provider.nextOutage(area.id) : null;
    final isHome = provider.selectedAreaId == area.id;
    final isSaved = provider.savedAreaIds.contains(area.id);

    Widget? pill;
    if (outage != null) {
      pill = StatusPill(
        label: 'Brownout now · since ${formatClock(outage.startTime)}',
        color: AppColors.outage,
      );
    } else if (next != null) {
      final start = advisoryStart(next);
      final soon = start != null && start.difference(DateTime.now()).inHours < 24;
      pill = soon
          ? StatusPill(
              label: 'Power on · brownout ${lowerFirst(timeUntil(start, DateTime.now()))}',
              color: AppColors.amber,
            )
          : const StatusPill(label: 'Power on', color: AppColors.powerOn);
    } else if (loaded) {
      pill = const StatusPill(label: 'Power on', color: AppColors.powerOn);
    }

    return SugaCard(
      onTap: onTap,
      color: outage != null ? AppColors.outageSoft : AppColors.surface,
      borderColor: outage != null ? AppColors.outage.withValues(alpha: 0.45) : AppColors.line,
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(area.name, style: AppText.cardTitle)),
                    if (isHome) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.home_rounded, size: 16, color: AppColors.amber, semanticLabel: 'Home area'),
                    ] else if (isSaved) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.bookmark_rounded, size: 16, color: AppColors.textMuted, semanticLabel: 'Saved'),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(area.city, style: AppText.muted),
                if (pill != null) ...[const SizedBox(height: 10), pill],
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
