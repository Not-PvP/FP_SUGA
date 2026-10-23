import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:suga/providers/notification_provider.dart';
import 'package:suga/providers/power_interruption_provider.dart';
import 'package:suga/models/area.dart';
import 'package:suga/services/area_service.dart';
import 'package:suga/widgets/power_status_widget.dart';
import 'package:suga/widgets/weather_card.dart';
import 'package:suga/widgets/upcoming_advisories_widget.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    this.onNavigateToAreas,
  });

  final VoidCallback? onNavigateToAreas;

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;

    final greeting = hour < 12
        ? 'Good morning!'
        : hour < 18
        ? 'Good afternoon!'
        : 'Good evening!';

    return Scaffold(
      backgroundColor: const Color(0xFF070A0F),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  // SUGA and greeting
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SUGA',
                        style: TextStyle(
                          color: Color(0xFFFFBF00),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      Text(
                        greeting,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Notification button on the right
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFFBF00),
                        width: 1.3,
                      ),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        Navigator.pushNamed(context, '/notifications');
                      },
                      tooltip: 'Notifications',
                      // The number of unread alerts, when there are any.
                      icon: Consumer<NotificationProvider>(
                        builder: (context, notifications, _) => Badge(
                          isLabelVisible: notifications.unreadCount > 0,
                          label: Text('${notifications.unreadCount}'),
                          backgroundColor: const Color(0xFFF87171),
                          child: const Icon(
                            Icons.notifications_none_rounded,
                            color: Color(0xFFFFBF00),
                            size: 23,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Your Area label
              const Text(
                'YOUR AREA',
                style: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 14),

              // Area card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF111720),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF292F38), width: 1),
                ),
                child: Row(
                  children: [
                    // Location icon
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF292315),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFFFBF00).withValues(alpha: 0.5),
                        ),
                      ),
                      child: const Icon(
                        Icons.location_on_outlined,
                        color: Color(0xFFFFBF00),
                        size: 26,
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Location and feeder
                    Expanded(
                      child: Consumer<PowerInterruptionProvider>(
                        builder: (context, provider, child) {
                          final selectedAreaId = provider.selectedAreaId;

                          if (selectedAreaId == null) {
                            return const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'No area selected',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Tap Change to select your area',
                                  style: TextStyle(
                                    color: Color(0xFF9CA3AF),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            );
                          }

                          return FutureBuilder<List<Area>>(
                            future: AreaService().fetchAreas(),
                            builder: (context, snapshot) {
                              final areas = snapshot.data;

                              if (areas == null) {
                                return const Text(
                                  'Loading area...',
                                  style: TextStyle(color: Color(0xFF9CA3AF)),
                                );
                              }

                              final selectedArea = areas.where(
                                (area) => area.id == selectedAreaId,
                              );

                              if (selectedArea.isEmpty) {
                                return const Text(
                                  'Area not found',
                                  style: TextStyle(color: Colors.white),
                                );
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    selectedArea.first.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    selectedArea.first.city,
                                    style: const TextStyle(
                                      color: Color(0xFF9CA3AF),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Change area button
                    OutlinedButton(
                      onPressed: () {
                        if (onNavigateToAreas != null) {
                          onNavigateToAreas!();
                        } else {
                          Navigator.pushNamed(context, '/areas');
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFD1D5DB),
                        side: const BorderSide(color: Color(0xFF45413A)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      child: const Text(
                        'Change →',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              const PowerStatusWidget(),
              
              const SizedBox(height: 24),

              const WeatherCard(),
              
              const SizedBox(height: 28),

              UpcomingAdvisoriesWidget(
                areaId: context.watch<PowerInterruptionProvider>().selectedAreaId,
              )

            ],
          ),
        ),
      ),
    );
  }
}
