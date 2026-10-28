import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:suga/models/area.dart';
import 'package:suga/models/power_interruption.dart';
import 'package:suga/providers/power_interruption_provider.dart';
import 'package:suga/services/area_service.dart';
import 'package:suga/theme/app_theme.dart';
import 'package:suga/utils/advisory_time.dart';
import 'package:suga/utils/format.dart';
import 'package:suga/widgets/power_status_widget.dart';
import 'package:suga/widgets/ui.dart';
import 'package:suga/widgets/weather_card.dart';
import 'package:suga/widgets/upcoming_advisories_widget.dart';

// One area: its power status, feeders and upcoming brownouts.
// Pops with true when the user sets it as their home area.
class AreaDetailsScreen extends StatefulWidget {
  const AreaDetailsScreen({super.key, this.service});

  final AreaService? service;

  @override
  State<AreaDetailsScreen> createState() => _AreaDetailsScreenState();
}

class _AreaDetailsScreenState extends State<AreaDetailsScreen> {
  late final AreaService _service = widget.service ?? AreaService();
  int? _id;
  Future<Area>? _area;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Receives the area id from the Areas screen.
    _id ??= ModalRoute.of(context)!.settings.arguments as int;
    _area ??= _service.fetchArea(_id!);
  }

  void _retry() {
    setState(() {
      _area = _service.fetchArea(_id!);
    });
  }

  void _setAsHome(Area area) {
    context.read<PowerInterruptionProvider>().setAreaFilter(area.id);
    Navigator.pop(context, true);
  }

  void _toggleSaved(Area area, bool saved) {
    context.read<PowerInterruptionProvider>().toggleSavedArea(area.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? 'Removed ${area.name} from saved areas'
              : 'Saved ${area.name}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Area>(
      future: _area,
      builder: (context, snapshot) {
        final area = snapshot.data;
        return Scaffold(
          appBar: AppBar(title: const Text('Area Details')),
          body: _buildBody(context, snapshot),
        );
      },
    );
  }

  // Takes the FutureBuilder's context, so context.watch runs during that build.
  Widget _buildSaveButton(BuildContext context, Area area) {
    final provider = context.watch<PowerInterruptionProvider>();
    final isHome = provider.selectedAreaId == area.id;
    final saved = provider.savedAreaIds.contains(area.id);
    return IconButton(
      onPressed: isHome ? null : () => _toggleSaved(area, saved),
      tooltip: isHome
          ? 'Your home area is always saved'
          : saved
          ? 'Remove from saved areas'
          : 'Save area',
      icon: Icon(
        saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
        color: isHome ? AppColors.textMuted : AppColors.amber,
      ),
    );
  }

  Widget _buildBody(BuildContext context, AsyncSnapshot<Area> snapshot) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.hasError) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ErrorPanel(
            what: 'this area',
            error: snapshot.error!,
            onRetry: _retry,
          ),
        ],
      );
    }

    final area = snapshot.data!;
    final isHome =
        context.watch<PowerInterruptionProvider>().selectedAreaId == area.id;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(area.name, style: AppText.screenTitle),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    area.city,
                    style: AppText.body.copyWith(
                      color: AppColors.amber,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _buildSaveButton(context, area),
          ],
        ),
        const SizedBox(height: 8),

        PowerStatusWidget(areaId: area.id, bulbSize: 150),
        const SizedBox(height: 24),
        WeatherCard(
          latitude: area.latitude,
          longitude: area.longitude,
          locationName: area.name,
        ),
        const SizedBox(height: 32),
        const SectionLabel('Feeders'),
        if (area.feeders.isEmpty)
          const Text('No feeders listed for this area.', style: AppText.muted)
        else
          SugaCard(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                for (var i = 0; i < area.feeders.length; i++) ...[
                  if (i > 0) const Divider(),
                  _FeederRow(area: area, feeder: area.feeders[i]),
                ],
              ],
            ),
          ),
        const SizedBox(height: 32),
        UpcomingAdvisoriesWidget(
          areaIds: {area.id},
          emptyMessage: 'No brownouts are scheduled in ${area.name}.',
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: isHome
              ? OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.home_rounded, size: 20),
                  label: const Text('This is your home area'),
                )
              : ElevatedButton.icon(
                  onPressed: () => _setAsHome(area),
                  icon: const Icon(Icons.home_outlined, size: 20),
                  label: const Text('Set as home area'),
                ),
        ),
      ],
    );
  }
}

// A feeder and whether it is affected by a brownout now or soon.
class _FeederRow extends StatelessWidget {
  const _FeederRow({required this.area, required this.feeder});

  final Area area;
  final Feeder feeder;

  // An advisory without feeders listed affects the whole area.
  bool _affects(PowerInterruption item) =>
      (item.feederIds.isEmpty && item.feeders.isEmpty) ||
      item.feederIds.contains(feeder.id) ||
      item.feeders.contains(feeder.name);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PowerInterruptionProvider>();
    Widget? pill;
    if (provider.hasLoaded) {
      final outage = provider.currentOutage(area.id);
      final next = UpcomingAdvisoriesWidget.upcoming(
        provider.interruptionsForArea(area.id),
      ).where(_affects).firstOrNull;
      final nextStart = next == null ? null : advisoryStart(next);
      if (outage != null && _affects(outage)) {
        pill = const StatusPill(label: 'Brownout now', color: AppColors.outage);
      } else if (nextStart != null) {
        pill = StatusPill(
          label: 'Brownout ${lowerFirst(timeUntil(nextStart, DateTime.now()))}',
          color: AppColors.amber,
        );
      } else {
        pill = const StatusPill(label: 'Power on', color: AppColors.powerOn);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(child: Text(feeder.name, style: AppText.cardTitle)),
          if (pill != null) ...[
            const SizedBox(width: 8),
            Flexible(child: pill),
          ],
        ],
      ),
    );
  }
}
