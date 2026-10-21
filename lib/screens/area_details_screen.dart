import 'package:flutter/material.dart';
import 'package:suga/models/area.dart';
import 'package:suga/services/area_service.dart';
import 'package:provider/provider.dart';
import 'package:suga/providers/power_interruption_provider.dart';
import 'package:suga/widgets/power_status_widget.dart';
import 'package:suga/widgets/weather_card.dart';
import 'package:suga/widgets/upcoming_advisories_widget.dart';

class AreaDetailsScreen extends StatefulWidget {
  const AreaDetailsScreen({super.key, this.service});

  final AreaService? service;

  @override
  State<AreaDetailsScreen> createState() => _AreaDetailsScreenState();
}

class _AreaDetailsScreenState extends State<AreaDetailsScreen> {
  late final AreaService _service = widget.service ?? AreaService();
  Future<Area>? _area;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Receives the area id from the Areas screen.
    final id = ModalRoute.of(context)!.settings.arguments as int;
    _area ??= _service.fetchArea(id);
  }

  void _setAsMyArea(Area area) {
    context.read<PowerInterruptionProvider>().setAreaFilter(area.id);
    Navigator.pop(context);
  }

  void _toggleFavorite(Area area) {
    context.read<PowerInterruptionProvider>().toggleSavedArea(area.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070A0F),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        forceMaterialTransparency: true,
        toolbarHeight: 90,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: FutureBuilder<Area>(
          future: _area,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox.shrink();
            }

            final area = snapshot.data!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  area.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  area.city,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFFFBF00),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            );
          },
        ),

        actions: [
          FutureBuilder<Area>(
            future: _area,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox.shrink();
              }

              final provider = context.watch<PowerInterruptionProvider>();
final isFavorite = provider.savedAreaIds.contains(
  snapshot.data!.id,
);

              return IconButton(
                onPressed: () => _toggleFavorite(snapshot.data!),
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: Color(0xFFFFBF00),
                  size: 26,
                ),
                tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<Area>(
        future: _area,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }
          final area = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 110, 16, 16),
            children: [
              PowerStatusWidget(areaId: area.id),

              const SizedBox(height: 24),

              const WeatherCard(),

              const SizedBox(height: 24),

              const Text(
                'FEEDER STATUS',
                style: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 12),

              if (area.feeders.isEmpty)
                const Text(
                  'No feeders listed for this area.',
                  style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                ),

              for (final feeder in area.feeders)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111720),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF292F38)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF4ADE80),
                          shape: BoxShape.circle,
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Text(
                          feeder.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF14271E),
                          border: Border.all(color: const Color(0xFF347653)),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Text(
                          'Operational',
                          style: TextStyle(
                            color: Color(0xFF86EFAC),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              UpcomingAdvisoriesWidget(areaId: area.id),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _setAsMyArea(area),
                  icon: const Icon(Icons.location_on_outlined, size: 20),
                  label: const Text('Set as My Area'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFBF00),
                    foregroundColor: const Color(0xFF070A0F),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
