import 'package:flutter/material.dart';
import 'package:suga/models/power_interruption.dart';
import 'package:suga/routes/app_routes.dart';
import 'package:suga/theme/app_theme.dart';
import 'package:suga/utils/advisory_time.dart';
import 'package:suga/utils/format.dart';
import 'package:suga/widgets/day_strip.dart';
import 'package:suga/widgets/status_badge.dart';
import 'package:suga/widgets/ui.dart';

// One brownout advisory in a list. The whole card opens its details.
// Used on Home, Area Details and Scheduled Brownouts.
class AdvisoryCard extends StatelessWidget {
  const AdvisoryCard({
    super.key,
    required this.advisory,
    this.showDay = true,
    this.showStatus = false,
  });

  final PowerInterruption advisory;

  // False when the list is already grouped under a date heading.
  final bool showDay;

  // True in the admin "All advisories" list, where statuses differ.
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final status = advisory.status.toLowerCase();
    final accent = status == 'ongoing' ? AppColors.outage : AppColors.amber;
    final start = advisoryStart(advisory);
    final day = DateTime.tryParse(advisory.date);
    final startMinutes = minutesOf(advisory.startTime);
    final endMinutes = minutesOf(advisory.endTime);
    final length = durationMinutes(advisory);
    final countdown = status == 'scheduled' && start != null && start.isAfter(now)
        ? timeUntil(start, now)
        : null;

    final when = [
      if (showDay && day != null) formatDay(day, now: now),
      formatTimeRange(advisory),
      if (length != null) formatDuration(length),
    ].join(' · ');

    return SugaCard(
      onTap: () => Navigator.pushNamed(
        context,
        AppRoutes.brownoutDetails,
        arguments: advisory,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  advisory.title.isEmpty ? 'Power interruption' : advisory.title,
                  style: AppText.cardTitle,
                ),
              ),
              if (showStatus) ...[
                const SizedBox(width: 8),
                StatusBadge(status: advisory.status),
              ] else if (countdown != null) ...[
                const SizedBox(width: 8),
                _Countdown(countdown),
              ],
            ],
          ),
          if (advisory.affectedAreas.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              advisory.affectedAreas.join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.muted,
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 16, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  when,
                  style: TextStyle(
                    fontFamily: AppText.font,
                    color: accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (startMinutes != null && endMinutes != null) ...[
            const SizedBox(height: 12),
            DayStrip(
              startMinutes: startMinutes,
              endMinutes: endMinutes,
              color: accent,
              nowMinutes: day != null && DateUtils.isSameDay(day, now)
                  ? now.hour * 60 + now.minute
                  : null,
            ),
          ],
          if (advisory.feeders.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final feeder in advisory.feeders) FeederChip(feeder)],
            ),
          ],
        ],
      ),
    );
  }
}

class _Countdown extends StatelessWidget {
  const _Countdown(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.amberSoft,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: AppText.font,
          color: AppColors.amber,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
