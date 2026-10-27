import 'package:flutter/material.dart';
import 'package:suga/theme/app_theme.dart';

// A 24-hour bar with the brownout window shaded, so people can see at a glance
// how much of the day it takes ("can I still charge before 8?").
class DayStrip extends StatelessWidget {
  const DayStrip({
    super.key,
    required this.startMinutes,
    required this.endMinutes,
    this.color = AppColors.amber,
    this.nowMinutes,
  });

  static const _day = 24 * 60;

  final int startMinutes;
  final int endMinutes;
  final Color color;

  // Draws a "now" marker. Pass it only when the brownout is today.
  final int? nowMinutes;

  @override
  Widget build(BuildContext context) {
    // A window that runs past midnight is shaded to the end of this day.
    final end = endMinutes > startMinutes ? endMinutes : _day;

    return ExcludeSemantics(
      child: Column(
        children: [
          SizedBox(
            height: 8,
            child: LayoutBuilder(
              builder: (context, box) {
                final width = box.maxWidth;
                final left = startMinutes / _day * width;
                final right = end / _day * width;
                final now = nowMinutes;
                return Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.line,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                    ),
                    Positioned(
                      left: left,
                      width: (right - left).clamp(4, width),
                      top: 0,
                      bottom: 0,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                    ),
                    if (now != null)
                      Positioned(
                        left: (now / _day * width - 1).clamp(0, width - 2),
                        width: 2,
                        top: 0,
                        bottom: 0,
                        child: const ColoredBox(color: AppColors.text),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('12 AM', style: AppText.small),
              Text('6 AM', style: AppText.small),
              Text('12 PM', style: AppText.small),
              Text('6 PM', style: AppText.small),
              Text('12 AM', style: AppText.small),
            ],
          ),
        ],
      ),
    );
  }
}
