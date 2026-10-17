import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:suga/providers/power_interruption_provider.dart';
import 'package:suga/models/area.dart';
import 'package:suga/services/area_service.dart';
import 'dart:ui';

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
                      icon: const Icon(
                        Icons.notifications_none_rounded,
                        color: Color(0xFFFFBF00),
                        size: 23,
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

              Consumer<PowerInterruptionProvider>(
                builder: (context, provider, child) {
                  final areaId = provider.selectedAreaId;

                  // No selected area yet.
                  if (areaId == null) {
                    return const SizedBox.shrink();
                  }

                  final hasPower = provider.hasPowerInArea(areaId);

                  
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Lightbulb and glow
                        SizedBox(
                          width: double.infinity,
                          height: 240,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Transform.translate(
                                offset: const Offset(0, -20),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    if (hasPower)
                                      ImageFiltered(
                                        imageFilter: ImageFilter.blur(
                                          sigmaX: 65,
                                          sigmaY: 65,
                                        ),
                                        child: Container(
                                          width: 340,
                                          height: 340,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: const Color(0xFFFFBF00)
                                                .withValues(alpha: 0.35),
                                          ),
                                        ),
                                      ),
                                    SvgPicture.asset(
                                      hasPower
                                          ? 'assets/images/bulb_on.svg'
                                          : 'assets/images/bulb_off.svg',
                                      width: 300,
                                      height: 300,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Status text below the bulb
                        const SizedBox(height: 0),

                        Text(
                          hasPower
                              ? 'No Outage Reported'
                              : 'Power Outage In Your Area',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Time details
                        if (hasPower)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.access_time,
                                color: Colors.white70,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'As of ${DateTime.now().toLocal().toString().substring(0, 16)}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          )
                        else
                          Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.access_time,
                                    color: Colors.white70,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Since [outage start time]',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Est. restoration: [estimated time]',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 24),

              // Weather card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF111720),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFF292F38),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    // Weather icon
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF292315),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0x80FFBF00),
                        ),
                      ),
                      child: const Icon(
                        Icons.cloud_outlined,
                        color: Color(0xFFFFBF00),
                        size: 26,
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Weather details
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '28°C · Cloudy',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.water_drop_outlined,
                                color: Color(0xFF9CA3AF),
                                size: 14,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Rain: 0 mm',
                                style: TextStyle(
                                  color: Color(0xFF9CA3AF),
                                  fontSize: 12,
                                ),
                              ),
                              SizedBox(width: 12),
                              Icon(
                                Icons.location_on_outlined,
                                color: Color(0xFF9CA3AF),
                                size: 14,
                              ),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Iloilo City',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Color(0xFF9CA3AF),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 28),

              
              // Upcoming advisories
              Consumer<PowerInterruptionProvider>(
                builder: (context, provider, child) {
                  final now = DateTime.now();

                  // Only show future advisories for the selected area.
                  final upcomingAdvisories = provider.interruptions.where((
                    advisory,
                  ) {
                    final dateTime = DateTime.tryParse(
                      '${advisory.date}T${advisory.startTime}',
                    );

                    final status = advisory.status.toLowerCase();

                    return dateTime != null &&
                        dateTime.isAfter(now) &&
                        status != 'cancelled' &&
                        status != 'completed' &&
                        status != 'active';
                  }).toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Upcoming header
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_month_outlined,
                            color: Color(0xFFFFBF00),
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'UPCOMING',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${upcomingAdvisories.length} advisories',
                            style: const TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Empty state
                      if (upcomingAdvisories.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF111720),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: const Color(0xFF292F38),
                            ),
                          ),
                          child: const Text(
                            'No upcoming advisories for your area.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 13,
                            ),
                          ),
                        ),

                      // Advisory cards
                      ...upcomingAdvisories.map((advisory) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF111720),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: const Color(0xFF292F38),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Advisory title and date/time
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      advisory.title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.access_time,
                                          color: Color(0xFFFFD45C),
                                          size: 15,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            '${advisory.date} · ${advisory.startTime}',
                                            style: const TextStyle(
                                              color: Color(0xFFFFD45C),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 8),

                              // View details button
                              TextButton(
                                onPressed: () {
                                  Navigator.pushNamed(
                                    context,
                                    '/brownout_details',
                                    arguments: advisory,
                                  );
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFFFFBF00),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 10,
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'View Details',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(width: 3),
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 16,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  );
                },
              ),



            ],
          ),
        ),
      ),
    );
  }
}
