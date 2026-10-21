import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:suga/providers/power_interruption_provider.dart';
import 'package:suga/routes/app_routes.dart';
import 'package:intl/intl.dart';

class UpcomingAdvisoriesWidget extends StatelessWidget {
  const UpcomingAdvisoriesWidget({
    super.key,
    this.areaId,
    this.showHeader = true,
    this.groupByDate = false,
  });

  final int? areaId;
  final bool showHeader;
  final bool groupByDate;

  @override
  Widget build(BuildContext context) {
    return Consumer<PowerInterruptionProvider>(
      builder: (context, provider, child) {
        final hasSelectedArea =
            areaId != null || provider.selectedAreaId != null;

        final now = DateTime.now();

        final areaAdvisories = areaId != null
            ? provider.interruptionsForArea(areaId!)
            : provider.allInterruptions;

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

        final groupedAdvisories = <String, List<dynamic>>{};

        for (final advisory in upcomingAdvisories) {
          groupedAdvisories.putIfAbsent(advisory.date, () => []).add(advisory);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Upcoming header
            if (showHeader) ...[
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
            ],

            if (showHeader) const SizedBox(height: 14),

            // Empty state
            // Empty state
            if (!hasSelectedArea && !groupByDate)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF111720),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF292F38)),
                ),
                child: const Text(
                  'Select an area to view upcoming brownouts.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                ),
              )
            else if (upcomingAdvisories.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF111720),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF292F38)),
                ),
                child: const Text(
                  'No upcoming brownouts scheduled.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                ),
              ),

            // Advisory cards
            if (groupByDate) ...[
              ...groupedAdvisories.entries.expand<Widget>(
                (entry) => <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12, top: 8),
                    child: Text(
                      DateFormat(
                        'MMMM d, y',
                      ).format(DateTime.parse(entry.key)).toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  ...entry.value.map<Widget>(
                    (advisory) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111720),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFF292F38),
                          width: 1,
                        ),
                      ),
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
                                  '${DateFormat('h:mm a').format(DateFormat('HH:mm').parse(advisory.startTime))} – ${DateFormat('h:mm a').format(DateFormat('HH:mm').parse(advisory.endTime))}',
                                  style: const TextStyle(
                                    color: Color(0xFFFFD45C),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (advisory.feeders.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            const Text(
                              'AFFECTED FEEDERS',
                              style: TextStyle(
                                color: Color(0xFF9CA3AF),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: advisory.feeders.map<Widget>((feeder) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1F2937),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(
                                        0xFF374151,
                                      ).withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Text(
                                    feeder,
                                    style: const TextStyle(
                                      color: Color(0xFFD1D5DB),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                          const SizedBox(height: 16),
                          const Divider(color: Color(0xFF292F38), height: 1),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.brownoutDetails,
                                  arguments: advisory,
                                );
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFFFFBF00),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                                  SizedBox(width: 4),
                                  Icon(Icons.arrow_forward, size: 14),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (hasSelectedArea)
              ...upcomingAdvisories.map((advisory) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111720),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFF292F38),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
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
                                        '${DateFormat('MMM d, y').format(DateTime.parse(advisory.date))} · ${DateFormat('h:mm a').format(DateFormat('HH:mm').parse(advisory.startTime))} – ${DateFormat('h:mm a').format(DateFormat('HH:mm').parse(advisory.endTime))}',
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
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Color(0xFF292F38), height: 1),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              AppRoutes.brownoutDetails,
                              arguments: advisory,
                            );
                          },
                          style: TextButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            foregroundColor: const Color(0xFFFFBF00),
                            overlayColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                              Icon(Icons.arrow_forward_rounded, size: 14),
                            ],
                          ),
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
