
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:suga/providers/power_interruption_provider.dart';

class UpcomingAdvisoriesWidget extends StatelessWidget {
  const UpcomingAdvisoriesWidget({
    super.key,
    this.areaId,
  });

  final int? areaId;

  @override
  Widget build(BuildContext context) {
    return Consumer<PowerInterruptionProvider>(
      builder: (context, provider, child) {
        final now = DateTime.now();

        final areaAdvisories = areaId != null
            ? provider.interruptionsForArea(areaId!)
            : provider.interruptions;

        final upcomingAdvisories = areaAdvisories.where((advisory) {
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
                  'No upcoming advisories for this area.',
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
    );
  }
}
