import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:suga/models/power_interruption.dart';
import 'package:intl/intl.dart';
import 'package:suga/providers/auth_provider.dart';
import 'package:suga/providers/power_interruption_provider.dart';
import 'package:suga/widgets/admin_advisory_actions.dart';
import 'package:suga/widgets/weather_card.dart';

class BrownoutDetailsScreen extends StatelessWidget {
  const BrownoutDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final passed =
        ModalRoute.of(context)?.settings.arguments as PowerInterruption;
    // Use the provider's copy, so a change made by an admin shows right away.
    final brownout =
        context.watch<PowerInterruptionProvider>().findById(passed.id) ?? passed;
    final isAdmin = context.watch<AuthProvider>().isSignedIn;
    final status = brownout.status.toLowerCase();
    final statusColor = switch (status) {
      'scheduled' => const Color(0xFFFBBF24),
      'restored' => const Color(0xFF34D399),
      'cancelled' || 'canceled' => const Color(0xFFF87171),
      _ => const Color(0xFF64748B),
    };

    Widget _buildInfoSection(String label, String value) {
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

    String _formatDuration(String start, String end) {
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

    String _formatTime(String time) {
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
              crossAxisAlignment: CrossAxisAlignment.start,
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
                  _buildInfoSection('Areas', brownout.affectedAreas.join(', ')),
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
                        child: _buildInfoSection(
                          'Time',
                          '${_formatTime(brownout.startTime)} – ${_formatTime(brownout.endTime)}',
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: _buildInfoSection(
                          'Duration',
                          _formatDuration(brownout.startTime, brownout.endTime),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Reason
                  _buildInfoSection('Reason', brownout.reason),
                  const SizedBox(height: 20),

                  // Advisory Details
                  _buildInfoSection('Advisory Details', brownout.description),
                  const SizedBox(height: 20),

                  // Estimated Restoration
                  _buildInfoSection(
                    'Estimated Restoration',
                    brownout.estimatedRestorationTime == null ||
                            brownout.estimatedRestorationTime!.trim().isEmpty
                        ? 'Not specified'
                        : _formatTime(brownout.estimatedRestorationTime!),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Weather Card
            const WeatherCard(),

            const SizedBox(height: 16),

            // Notify Before Interruption
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // TODO: Connect to notification scheduling.
                },
                icon: const Icon(Icons.notifications_active_outlined, size: 20),
                label: const Text('Notify Me Before Interruption'),
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
