import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:suga/models/power_interruption.dart';
import 'package:suga/providers/auth_provider.dart';
import 'package:suga/providers/notification_provider.dart';
import 'package:suga/providers/power_interruption_provider.dart';
import 'package:suga/theme/app_theme.dart';
import 'package:suga/utils/advisory_time.dart';
import 'package:suga/utils/format.dart';
import 'package:suga/widgets/admin_advisory_actions.dart';
import 'package:suga/widgets/day_strip.dart';
import 'package:suga/widgets/status_badge.dart';
import 'package:suga/widgets/ui.dart';

class BrownoutDetailsScreen extends StatelessWidget {
  const BrownoutDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final passed = ModalRoute.of(context)?.settings.arguments as PowerInterruption;
    // Use the provider's copy, so a change made by an admin shows right away.
    final brownout = context.watch<PowerInterruptionProvider>().findById(passed.id) ?? passed;
    final isAdmin = context.watch<AuthProvider>().isSignedIn;
    final notifications = context.watch<NotificationProvider>();

    final now = DateTime.now();
    final status = brownout.status.toLowerCase();
    final start = advisoryStart(brownout);
    // Reminders are only for brownouts that are still coming up.
    final canRemind = status == 'scheduled' && start != null && start.isAfter(now);
    final hasReminder = notifications.hasReminder(brownout);
    final lead = NotificationProvider.leadTimeLabel(notifications.leadMinutes);

    final day = DateTime.tryParse(brownout.date);
    final startMinutes = minutesOf(brownout.startTime);
    final endMinutes = minutesOf(brownout.endTime);
    final length = durationMinutes(brownout);
    final accent = status == 'ongoing' ? AppColors.outage : AppColors.amber;
    final restoration = brownout.estimatedRestorationTime?.trim() ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Brownout details')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Row(
            children: [
              StatusBadge(status: brownout.status),
              if (canRemind) ...[
                const SizedBox(width: 10),
                Text(
                  'Starts ${lowerFirst(timeUntil(start, now))}',
                  style: AppText.small.copyWith(color: AppColors.amber, fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Semantics(
            header: true,
            child: Text(
              brownout.title.isEmpty ? 'Power interruption' : brownout.title,
              style: AppText.screenTitle,
            ),
          ),
          if (brownout.affectedAreas.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(brownout.affectedAreas.join(' · '), style: AppText.body),
          ],
          const SizedBox(height: 20),

          // When
          SugaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(day != null ? formatLongDate(day) : brownout.date, style: AppText.label),
                const SizedBox(height: 6),
                Text(
                  formatTimeRange(brownout),
                  style: AppText.headline.copyWith(fontSize: 22, color: accent),
                ),
                if (length != null) ...[
                  const SizedBox(height: 4),
                  Text('${formatDuration(length)} without power', style: AppText.muted),
                ],
                if (startMinutes != null && endMinutes != null) ...[
                  const SizedBox(height: 16),
                  DayStrip(
                    startMinutes: startMinutes,
                    endMinutes: endMinutes,
                    color: accent,
                    nowMinutes: day != null && DateUtils.isSameDay(day, now)
                        ? now.hour * 60 + now.minute
                        : null,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // What and why
          SugaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Affected feeders', style: AppText.label),
                const SizedBox(height: 8),
                if (brownout.feeders.isEmpty)
                  const Text('Whole area', style: AppText.body)
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [for (final feeder in brownout.feeders) FeederChip(feeder)],
                  ),
                const _Gap(),
                _Info('Reason', brownout.reason),
                const _Gap(),
                _Info('Details', brownout.description),
                const _Gap(),
                _Info(
                  'Expected restoration',
                  restoration.isEmpty ? '' : formatClock(restoration),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Reminder
          if (!canRemind)
            const Text(
              'Reminders are only available before a scheduled brownout starts.',
              textAlign: TextAlign.center,
              style: AppText.small,
            )
          else if (hasReminder)
            SugaCard(
              color: AppColors.amberSoft,
              borderColor: AppColors.amber.withValues(alpha: 0.35),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active_rounded, color: AppColors.amber),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Reminder set. We'll notify you $lead before it starts.",
                      style: AppText.body.copyWith(color: AppColors.text),
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final willFire = await notifications.remindMe(brownout);
                  messenger.showSnackBar(SnackBar(
                    content: Text(willFire
                        ? "Reminder set for $lead before it starts"
                        : 'Saved to your alerts. Allow notifications to get a phone reminder.'),
                  ));
                },
                icon: const Icon(Icons.notifications_active_outlined, size: 20),
                label: Text('Remind me $lead before'),
              ),
            ),

          // Only signed-in admins see these.
          if (isAdmin) ...[
            const SizedBox(height: 16),
            AdminAdvisoryActions(advisory: brownout),
          ],
        ],
      ),
    );
  }
}

class _Gap extends StatelessWidget {
  const _Gap();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Divider(),
      );
}

class _Info extends StatelessWidget {
  const _Info(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.label),
        const SizedBox(height: 6),
        Text(value.trim().isEmpty ? 'Not specified' : value, style: AppText.body),
      ],
    );
  }
}
