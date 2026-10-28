import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:suga/models/power_interruption.dart';
import 'package:suga/providers/power_interruption_provider.dart';
import 'package:suga/theme/app_theme.dart';
import 'package:suga/utils/advisory_time.dart';
import 'package:suga/utils/format.dart';
import 'package:suga/widgets/advisory_card.dart';
import 'package:suga/widgets/ui.dart';

// The list of brownouts that have not started yet, soonest first.
// Used on Home, Area Details and Scheduled Brownouts.
class UpcomingAdvisoriesWidget extends StatelessWidget {
  const UpcomingAdvisoriesWidget({
    super.key,
    this.areaIds,
    this.title = 'Upcoming brownouts',
    this.showHeader = true,
    this.groupByDate = false,
    this.limit,
    this.onSeeAll,
    this.emptyMessage,
  });

  // Only advisories that affect one of these areas. Null shows every area.
  final Set<int>? areaIds;
  final String title;
  final bool showHeader;
  final bool groupByDate;

  // Show at most this many, with a "See all" button for the rest.
  final int? limit;
  final VoidCallback? onSeeAll;
  final String? emptyMessage;

  // Scheduled advisories that start after now. Cancelled, restored and ongoing
  // ones are left out.
  static List<PowerInterruption> upcoming(
    Iterable<PowerInterruption> items, {
    Set<int>? areaIds,
    DateTime? now,
  }) {
    final time = now ?? DateTime.now();
    return items.where((item) {
      final status = item.status.toLowerCase();
      if (status == 'cancelled' || status == 'restored' || status == 'ongoing') {
        return false;
      }
      if (areaIds != null && !item.areaIds.any(areaIds.contains)) return false;
      final start = advisoryStart(item);
      return start != null && start.isAfter(time);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PowerInterruptionProvider>(
      builder: (context, provider, _) {
        final items = upcoming(provider.allInterruptions, areaIds: areaIds);
        final shown = limit == null ? items : items.take(limit!).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeader)
              SectionLabel(
                title,
                trailing: items.isEmpty
                    ? null
                    : Text('${items.length} scheduled', style: AppText.small),
              ),
            if (items.isEmpty)
              _buildEmpty(provider)
            else if (groupByDate)
              ..._buildGrouped(shown)
            else
              for (final item in shown)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AdvisoryCard(advisory: item),
                ),
            if (onSeeAll != null && items.length > shown.length)
              Center(
                child: TextButton(
                  onPressed: onSeeAll,
                  child: Text('See all ${items.length} brownouts'),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildEmpty(PowerInterruptionProvider provider) {
    if (!provider.hasLoaded) {
      // Loading for the first time. Errors are shown by the screen.
      if (provider.error != null) return const SizedBox.shrink();
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return StatePanel(
      icon: Icons.event_available_outlined,
      iconColor: AppColors.powerOn,
      title: 'No brownouts scheduled',
      message: emptyMessage ?? 'New advisories from MORE Power will show up here.',
    );
  }

  List<Widget> _buildGrouped(List<PowerInterruption> items) {
    final now = DateTime.now();
    final widgets = <Widget>[];
    String? currentDate;
    for (final item in items) {
      if (item.date != currentDate) {
        currentDate = item.date;
        final day = DateTime.tryParse(item.date);
        widgets.add(Padding(
          padding: EdgeInsets.only(top: widgets.isEmpty ? 4 : 16, bottom: 10),
          child: Row(
            children: [
              Text(
                day == null ? item.date : _relativeDay(day, now),
                style: AppText.label.copyWith(color: AppColors.text, fontSize: 14),
              ),
              const Spacer(),
              if (day != null)
                Text(DateFormat('MMMM d').format(day), style: AppText.small),
            ],
          ),
        ));
      }
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AdvisoryCard(advisory: item, showDay: false),
      ));
    }
    return widgets;
  }

  // "Today", "Tomorrow", or the weekday name.
  static String _relativeDay(DateTime day, DateTime now) {
    final label = formatDay(day, now: now);
    return label == 'Today' || label == 'Tomorrow' ? label : DateFormat('EEEE').format(day);
  }
}
