import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:suga/models/power_interruption.dart';
import 'package:intl/intl.dart';
import 'package:suga/providers/auth_provider.dart';
import 'package:suga/providers/notification_provider.dart';
import 'package:suga/providers/power_interruption_provider.dart';
import 'package:suga/utils/advisory_time.dart';
import 'package:suga/widgets/admin_advisory_actions.dart';
import 'package:suga/widgets/weather_card.dart';
import 'package:suga/routes/app_routes.dart';
import 'package:suga/models/area.dart';
import 'package:suga/services/area_service.dart';

class BrownoutDetailsScreen extends StatelessWidget {
  const BrownoutDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final passed =
        ModalRoute.of(context)?.settings.arguments as PowerInterruption;
    // Use the provider's copy, so a change made by an admin shows right away.
    final brownout =
        context.watch<PowerInterruptionProvider>().findById(passed.id) ??
        passed;
    final isAdmin = context.watch<AuthProvider>().isSignedIn;
    final notifications = context.watch<NotificationProvider>();
    final hasReminder = notifications.hasReminder(brownout);
    // Reminders are only for brownouts that are still coming up.
    final start = advisoryStart(brownout);
    final canRemind =
        brownout.status.toLowerCase() == 'scheduled' &&
        start != null &&
        start.isAfter(DateTime.now());
    final status = brownout.status.toLowerCase();
    final statusColor = switch (status) {
      'scheduled' => const Color(0xFFFBBF24),
      'restored' => const Color(0xFF34D399),
      'cancelled' || 'canceled' => const Color(0xFFF87171),
      _ => const Color(0xFF64748B),
    };

    Widget buildInfoSection(String label, String value) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value.trim().isEmpty ? 'Not specified' : value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      );
    }

    String formatDuration(String start, String end) {
      try {
        final startParts = start.split(':').map(int.parse).toList();
        final endParts = end.split(':').map(int.parse).toList();

        final startMinutes = startParts[0] * 60 + startParts[1];
        var endMinutes = endParts[0] * 60 + endParts[1];

        if (endMinutes < startMinutes) {
          endMinutes += 24 * 60;
        }

        final totalMinutes = endMinutes - startMinutes;
        final hours = totalMinutes ~/ 60;
        final minutes = totalMinutes % 60;

        if (hours == 0) {
          return '$minutes ${minutes == 1 ? 'minute' : 'minutes'}';
        }

        if (minutes == 0) {
          return '$hours ${hours == 1 ? 'hour' : 'hours'}';
        }

        return '$hours ${hours == 1 ? 'hour' : 'hours'} '
            '$minutes ${minutes == 1 ? 'minute' : 'minutes'}';
      } catch (_) {
        return 'Not specified';
      }
    }

    String formatTime(String time) {
      try {
        final parsed = DateFormat('HH:mm').parseStrict(time);
        return DateFormat('h:mm a').format(parsed);
      } catch (_) {
        return time;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF070A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF070A0F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Brownout Details',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        brownout.title,
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
                        DateFormat(
                          'MMMM, d, yyyy',
                        ).format(DateTime.parse(brownout.date)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFFFBF00),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                if (isAdmin)
                  InkWell(
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.brownoutForm,
                        arguments: brownout,
                      );
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFBF00).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(
                            0xFFFFBF00,
                          ).withValues(alpha: 0.35),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.edit_outlined,
                            size: 14,
                            color: Color(0xFFFFBF00),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Edit',
                            style: TextStyle(
                              color: Color(0xFFFFBF00),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      brownout.status[0].toUpperCase() +
                          brownout.status.substring(1).toLowerCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 24),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF111720),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF292F38), width: 1),
              ),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Areas
                  buildInfoSection('Areas', brownout.affectedAreas.join(', ')),
                  const SizedBox(height: 20),

                  // Feeders
                  const Text(
                    'Affected Feeders',
                    style: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: brownout.feeders.map((feeder) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
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
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Time and Duration
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: buildInfoSection(
                          'Time',
                          '${formatTime(brownout.startTime)} – ${formatTime(brownout.endTime)}',
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: buildInfoSection(
                          'Duration',
                          formatDuration(brownout.startTime, brownout.endTime),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Reason
                  buildInfoSection('Reason', brownout.reason),
                  const SizedBox(height: 20),

                  // Advisory Details
                  buildInfoSection('Advisory Details', brownout.description),
                  const SizedBox(height: 20),

                  // Estimated Restoration
                  buildInfoSection(
                    'Estimated Restoration',
                    brownout.estimatedRestorationTime == null ||
                            brownout.estimatedRestorationTime!.trim().isEmpty
                        ? 'Not specified'
                        : formatTime(brownout.estimatedRestorationTime!),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Weather at the affected area when the brownout starts.
            _AdvisoryWeather(
              areaNames: brownout.affectedAreas,
              start: start,
            ),

            const SizedBox(height: 16),

            // Notify Before Interruption: schedules a phone reminder for this advisory.
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: !canRemind
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final willFire = await notifications.remindMe(brownout);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              willFire
                                  ? "We'll remind you ${NotificationProvider.leadTimeLabel(notifications.leadMinutes)} before it starts."
                                  : 'Saved to your alerts. Allow notifications to get a phone reminder.',
                            ),
                          ),
                        );
                      },
                icon: Icon(
                  hasReminder
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_active_outlined,
                  size: 20,
                ),
                label: Text(
                  !canRemind
                      ? 'No Reminder for This Advisory'
                      : hasReminder
                      ? 'Reminder Set · ${NotificationProvider.leadTimeLabel(notifications.leadMinutes)} Before'
                      : 'Notify Me Before Interruption',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFBF00),
                  foregroundColor: const Color(0xFF070A0F),
                  disabledBackgroundColor: const Color(0xFF1F2937),
                  disabledForegroundColor: const Color(0xFF9CA3AF),
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

            // Only signed-in admins see these.
            if (isAdmin) ...[
              const SizedBox(height: 16),
              AdminAdvisoryActions(advisory: brownout),
            ],
          ],
        ),
      ),
    );
  }
}

// The forecast for the area a brownout affects.
//
// It is its own StatefulWidget so the area list is requested once. The screen
// above rebuilds whenever the advisories, the session or the notifications
// change (the notification clock alone ticks every minute), and a FutureBuilder
// that creates its future inside build() would call the API again each time.
class _AdvisoryWeather extends StatefulWidget {
  const _AdvisoryWeather({required this.areaNames, required this.start});

  final List<String> areaNames;
  final DateTime? start;

  @override
  State<_AdvisoryWeather> createState() => _AdvisoryWeatherState();
}

class _AdvisoryWeatherState extends State<_AdvisoryWeather> {
  late final Future<List<Area>> _areas = AreaService().fetchAreas();

  static const _muted = TextStyle(color: Color(0xFF9CA3AF));

  @override
  Widget build(BuildContext context) {
    final start = widget.start;
    return FutureBuilder<List<Area>>(
      future: _areas,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Unable to load weather for this area.', style: _muted);
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFFFBF00)),
          );
        }

        if (!snapshot.hasData) {
          return const Text('Weather area information is unavailable.', style: _muted);
        }

        if (start == null) {
          return const Text(
            'Weather unavailable: scheduled start time could not be determined.',
            style: _muted,
          );
        }

        // Use the first affected area that matches an area from the API.
        final names = widget.areaNames.map((name) => name.trim().toLowerCase()).toSet();
        final matching = snapshot.data!.where(
          (area) => names.contains(area.name.trim().toLowerCase()),
        );

        if (matching.isEmpty) {
          return Text(
            'Weather unavailable: no matching area found for ${widget.areaNames.join(', ')}.',
            style: _muted,
          );
        }

        final area = matching.first;
        return WeatherCard(
          latitude: area.latitude,
          longitude: area.longitude,
          locationName: area.name,
          forecastDateTime: start,
        );
      },
    );
  }
}
