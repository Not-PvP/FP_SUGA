import 'package:suga/models/power_interruption.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

// Advisory dates and times are Philippine time, whatever time zone the phone is set to.
tz.Location? _manila;

tz.Location get manila {
  final location = _manila;
  if (location != null) return location;
  tz_data.initializeTimeZones();
  return _manila = tz.getLocation('Asia/Manila');
}

tz.TZDateTime? _at(String date, String time) {
  final day = DateTime.tryParse(date);
  final parts = time.split(':');
  if (day == null || parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  return tz.TZDateTime(manila, day.year, day.month, day.day, hour, minute);
}

// When the brownout starts and ends. Null if the advisory has a bad date or time.
tz.TZDateTime? advisoryStart(PowerInterruption item) => _at(item.date, item.startTime);
tz.TZDateTime? advisoryEnd(PowerInterruption item) => _at(item.date, item.endTime);

// "In 30 mins", "In 2 hrs", "Tomorrow", "In 3 days", or "Started".
String timeUntil(DateTime start, DateTime now) {
  final left = start.difference(now);
  if (left.isNegative || left == Duration.zero) return 'Started';
  if (left.inMinutes < 60) {
    final minutes = left.inMinutes < 1 ? 1 : left.inMinutes;
    return 'In $minutes min${minutes == 1 ? '' : 's'}';
  }
  if (left.inHours < 24) {
    final hours = left.inHours;
    return 'In $hours hr${hours == 1 ? '' : 's'}';
  }
  final days = (left.inHours / 24).round();
  return days <= 1 ? 'Tomorrow' : 'In $days days';
}
