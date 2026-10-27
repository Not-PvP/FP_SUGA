import 'package:intl/intl.dart';
import 'package:suga/models/power_interruption.dart';

// Display helpers for advisories. The API sends dates as "YYYY-MM-DD" and
// times as "HH:MM" (24-hour).

// "14:30" -> 870 minutes after midnight. Null if it is not a time.
int? minutesOf(String? time) {
  if (time == null) return null;
  final parts = time.trim().split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null || hour > 24 || minute > 59) return null;
  return hour * 60 + minute;
}

// "14:30" -> "2:30 PM". Text that is not a time is returned unchanged.
String formatClock(String? time) {
  final minutes = minutesOf(time);
  if (minutes == null) return time ?? '';
  return DateFormat('h:mm a').format(DateTime(2000, 1, 1, minutes ~/ 60, minutes % 60));
}

// "8:00 AM – 12:00 PM"
String formatTimeRange(PowerInterruption item) =>
    '${formatClock(item.startTime)} – ${formatClock(item.endTime)}';

// Length of the brownout in minutes. An end time earlier than the start means
// it runs past midnight.
int? durationMinutes(PowerInterruption item) {
  final start = minutesOf(item.startTime);
  final end = minutesOf(item.endTime);
  if (start == null || end == null) return null;
  final length = end - start;
  return length > 0 ? length : length + 24 * 60;
}

// 240 -> "4 hrs", 90 -> "1 hr 30 min", 45 -> "45 min"
String formatDuration(int minutes) {
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  final hourText = '$hours hr${hours == 1 ? '' : 's'}';
  if (hours == 0) return '$rest min';
  if (rest == 0) return hourText;
  return '$hourText $rest min';
}

// "Today", "Tomorrow", "Yesterday", or "Sat, Oct 25".
String formatDay(DateTime day, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final diff = DateTime(day.year, day.month, day.day)
      .difference(DateTime(today.year, today.month, today.day))
      .inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';
  return DateFormat('EEE, MMM d').format(day);
}

// "Saturday, October 25, 2026"
String formatLongDate(DateTime day) => DateFormat('EEEE, MMMM d, y').format(day);

// "In 2 hrs" -> "in 2 hrs", so it reads inside a sentence.
String lowerFirst(String text) =>
    text.isEmpty ? text : text[0].toLowerCase() + text.substring(1);
