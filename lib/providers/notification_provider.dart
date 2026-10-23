import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suga/models/app_notification.dart';
import 'package:suga/models/power_interruption.dart';
import 'package:suga/providers/power_interruption_provider.dart';
import 'package:suga/services/notification_service.dart';
import 'package:suga/utils/advisory_time.dart';

export 'package:suga/services/notification_service.dart' show NotificationPermission;

// Notification state for the whole app:
// - the in-app list on the Notifications screen, with read/unread
// - the user's notification settings (on/off, how early, power restored alerts)
// - phone reminders scheduled before each brownout in the followed areas
// main.dart feeds it the advisories and saved areas from PowerInterruptionProvider.
class NotificationProvider extends ChangeNotifier {
  NotificationProvider({DeviceNotifications? device, DateTime Function()? now})
      : _device = device ?? NotificationService(),
        _now = now ?? DateTime.now;

  // Choices for "Alert me before" in Settings, in minutes.
  static const leadTimeOptions = [10, 60, 120, 720, 1440];
  static const _maxScheduled = 50;
  static const _maxReadKeys = 300;

  static const _kPushEnabled = 'notifications.pushEnabled';
  static const _kLeadMinutes = 'notifications.leadMinutes';
  static const _kRestoredAlerts = 'notifications.restoredAlerts';
  static const _kRead = 'notifications.read';
  static const _kReminders = 'notifications.reminders';
  static const _kAsked = 'notifications.askedPermission';
  static const _kAreas = 'notifications.areaIds';

  final DeviceNotifications _device;
  final DateTime Function() _now;

  SharedPreferences? _prefs;
  bool _loaded = false;
  bool _pushEnabled = true;
  int _leadMinutes = 120;
  bool _restoredAlerts = true;
  bool _askedPermission = false;
  Set<String> _readKeys = {};
  Set<String> _reminderIds = {};
  NotificationPermission _permission = NotificationPermission.unknown;

  List<PowerInterruption> _advisories = const [];
  Set<int> _areaIds = const {};
  // Saved areas are not kept between launches yet, so remember the last
  // followed areas here. Otherwise every restart would cancel the reminders.
  Set<int> _storedAreaIds = const {};
  bool _advisoriesLoaded = false;
  String? _loadError;
  Map<String, String>? _lastStatuses;
  List<AppNotification> _items = const [];

  Timer? _rescheduleTimer;
  Timer? _clock;
  bool _disposed = false;

  bool get isLoaded => _loaded;
  bool get pushEnabled => _pushEnabled;
  int get leadMinutes => _leadMinutes;
  Duration get leadTime => Duration(minutes: _leadMinutes);
  bool get restoredAlerts => _restoredAlerts;
  NotificationPermission get permission => _permission;

  // The followed areas: saved areas plus the main area.
  Set<int> get areaIds => _areaIds;
  bool get hasFollowedAreas => _areaIds.isNotEmpty || _reminderIds.isNotEmpty;

  // Mirrors PowerInterruptionProvider, for the screen's loading and error states.
  bool get advisoriesLoaded => _advisoriesLoaded;
  String? get loadError => _loadError;

  // Newest first, from the last 7 days.
  List<AppNotification> get notifications => _items;
  bool isUnread(AppNotification item) => !_readKeys.contains(item.key);
  int get unreadCount => _items.where(isUnread).length;

  // Phone alerts are wanted but the system is blocking them.
  bool get isBlocked => _pushEnabled && _permission == NotificationPermission.denied;

  static String leadTimeLabel(int minutes) {
    if (minutes < 60) return '$minutes minutes';
    final hours = minutes ~/ 60;
    return '$hours hour${hours == 1 ? '' : 's'}';
  }

  // Reads the saved settings and the system permission. Call once at startup.
  Future<void> load() async {
    try {
      final prefs = _prefs = await SharedPreferences.getInstance();
      _pushEnabled = prefs.getBool(_kPushEnabled) ?? true;
      final lead = prefs.getInt(_kLeadMinutes) ?? 120;
      _leadMinutes = leadTimeOptions.contains(lead) ? lead : 120;
      _restoredAlerts = prefs.getBool(_kRestoredAlerts) ?? true;
      _askedPermission = prefs.getBool(_kAsked) ?? false;
      _readKeys = (prefs.getStringList(_kRead) ?? const []).toSet();
      _reminderIds = (prefs.getStringList(_kReminders) ?? const []).toSet();
      _storedAreaIds = (prefs.getStringList(_kAreas) ?? const []).map(int.tryParse).nonNulls.toSet();
      if (_areaIds.isEmpty) _areaIds = _storedAreaIds;
    } catch (_) {
      // Settings could not be read: keep the defaults.
    }
    await _device.init();
    _permission = await _device.checkPermission();
    _loaded = true;
    _rebuild();
    _notify();
    unawaited(reschedule());
    _maybeAskPermission();

    // Once a minute, so "In 30 mins" counts down and reminders appear on time.
    _clock?.cancel();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      _rebuild();
      _notify();
    });
  }

  // Called by the ChangeNotifierProxyProvider in main.dart whenever the
  // advisories or the saved areas change.
  void updateFrom(PowerInterruptionProvider source) {
    _advisories = source.allInterruptions.toList();
    final followed = {...source.savedAreaIds, ?source.selectedAreaId};
    _areaIds = followed.isEmpty ? _storedAreaIds : followed;
    if (followed.isNotEmpty && !setEquals(followed, _storedAreaIds)) {
      _storedAreaIds = followed;
      unawaited(_prefs?.setStringList(_kAreas, [for (final id in followed) '$id']));
    }
    _advisoriesLoaded = source.hasLoaded;
    _loadError = source.error;

    if (source.hasLoaded) _alertRestored();
    _rebuild();
    // Not during the build that called us: notify and reschedule right after it.
    scheduleMicrotask(_notify);
    _rescheduleTimer?.cancel();
    _rescheduleTimer = Timer(const Duration(milliseconds: 400), () => unawaited(reschedule()));
    _maybeAskPermission();
  }

  void markRead(AppNotification item) {
    if (!_readKeys.add(item.key)) return;
    _saveReadKeys();
    _notify();
  }

  void markAllRead() {
    final before = _readKeys.length;
    _readKeys.addAll(_items.map((item) => item.key));
    if (_readKeys.length == before) return;
    _saveReadKeys();
    _notify();
  }

  Future<void> setPushEnabled(bool enabled) async {
    _pushEnabled = enabled;
    _notify();
    await _prefs?.setBool(_kPushEnabled, enabled);
    if (enabled && _permission != NotificationPermission.granted) {
      await _request();
    }
    await reschedule();
  }

  Future<void> setLeadMinutes(int minutes) async {
    if (!leadTimeOptions.contains(minutes) || minutes == _leadMinutes) return;
    _leadMinutes = minutes;
    _rebuild();
    _notify();
    await _prefs?.setInt(_kLeadMinutes, minutes);
    await reschedule();
  }

  Future<void> setRestoredAlerts(bool enabled) async {
    _restoredAlerts = enabled;
    _rebuild();
    _notify();
    await _prefs?.setBool(_kRestoredAlerts, enabled);
  }

  // For the "Turn on" button: ask again, or open system settings if the user said no
  // before (the system no longer shows the prompt then).
  Future<void> enableNotifications() async {
    if (!_pushEnabled) {
      await setPushEnabled(true);
      if (_permission == NotificationPermission.granted) return;
    }
    if (_permission != NotificationPermission.granted) await _request();
    if (_permission == NotificationPermission.denied) await _device.openSystemSettings();
  }

  // Call when the app comes back to the foreground: the user may have changed
  // the permission in system settings.
  Future<void> refreshPermission() async {
    final current = await _device.checkPermission();
    if (current == _permission) return;
    _permission = current;
    _notify();
    await reschedule();
  }

  // "Notify Me Before Interruption" on an advisory outside the followed areas.
  bool hasReminder(PowerInterruption item) =>
      _reminderIds.contains(item.id) || item.areaIds.any(_areaIds.contains);

  // Returns true when a phone reminder will fire.
  Future<bool> remindMe(PowerInterruption item) async {
    if (_reminderIds.add(item.id)) {
      await _prefs?.setStringList(_kReminders, _reminderIds.toList());
    }
    if (!_pushEnabled) {
      await setPushEnabled(true);
    } else if (_permission != NotificationPermission.granted) {
      await _request();
    }
    _rebuild();
    _notify();
    await reschedule();
    return _permission == NotificationPermission.granted;
  }

  // Replaces every scheduled phone reminder with the current ones: one for each
  // scheduled brownout in a followed area, fired [leadTime] before it starts.
  Future<void> reschedule() async {
    if (!_loaded || _disposed) return;
    try {
      await _device.cancelScheduled();
      if (!_pushEnabled || _permission != NotificationPermission.granted) return;

      final now = _now();
      var count = 0;
      for (final item in _advisories) {
        if (count >= _maxScheduled) break;
        if (item.status.toLowerCase() != 'scheduled' || !hasReminder(item)) continue;
        final id = int.tryParse(item.id);
        final start = advisoryStart(item);
        if (id == null || start == null) continue;
        final when = start.subtract(leadTime);
        // Already inside the window: it is on the in-app list instead.
        if (!when.isAfter(now)) continue;

        await _device.schedule(
          id: id,
          title: 'Brownout in ${leadTimeLabel(_leadMinutes)}',
          body: _reminderBody(item),
          when: when,
          payload: item.id,
        );
        count++;
      }
    } catch (e) {
      debugPrint('Could not schedule brownout reminders: $e');
    }
  }

  // Shows a phone notification when a followed advisory changes to restored
  // while the app is open. Not on the first load, so old advisories stay quiet.
  void _alertRestored() {
    final previous = _lastStatuses;
    _lastStatuses = {for (final item in _advisories) item.id: item.status.toLowerCase()};
    if (previous == null) return;
    if (!_pushEnabled || !_restoredAlerts || _permission != NotificationPermission.granted) return;

    for (final item in _advisories) {
      final before = previous[item.id];
      final id = int.tryParse(item.id);
      if (id == null || before == null || before == 'restored') continue;
      if (item.status.toLowerCase() != 'restored' || !hasReminder(item)) continue;
      unawaited(_device.show(
        id: 1000000 + id,
        title: 'Power restored',
        body: '${item.affectedAreas.join(', ')}: power is back on.',
        payload: item.id,
      ).catchError((Object e) => debugPrint('Could not show notification: $e')));
    }
  }

  String _reminderBody(PowerInterruption item) {
    final areas = item.affectedAreas.map((a) => a.split(',').first.trim()).join(', ');
    String time(String hhmm) {
      final parts = hhmm.split(':');
      final hour = int.tryParse(parts.first) ?? 0;
      final minute = parts.length > 1 ? parts[1] : '00';
      final h12 = hour % 12 == 0 ? 12 : hour % 12;
      return '$h12:$minute ${hour < 12 ? 'AM' : 'PM'}';
    }

    return '$areas: ${time(item.startTime)} – ${time(item.endTime)}. ${item.title}';
  }

  Future<void> _request() async {
    _askedPermission = true;
    await _prefs?.setBool(_kAsked, true);
    _permission = await _device.requestPermission();
    _notify();
  }

  // Asks for permission the first time the user follows an area, which is when
  // alerts start to matter. Only once: after that, the banner offers to turn them on.
  void _maybeAskPermission() {
    if (!_loaded || _askedPermission || !_pushEnabled || !hasFollowedAreas) return;
    if (_permission == NotificationPermission.granted || _permission == NotificationPermission.unsupported) return;
    _askedPermission = true;
    unawaited(_request().then((_) => reschedule()));
  }

  void _rebuild() {
    _items = NotificationBuilder.build(
      advisories: _advisories,
      areaIds: _areaIds,
      advisoryIds: _reminderIds,
      now: _now(),
      leadTime: leadTime,
      includeRestored: _restoredAlerts,
    );
  }

  void _saveReadKeys() {
    // Keep only keys still on the list, plus the newest others, so this stays small.
    final current = _items.map((item) => item.key).toSet();
    if (_readKeys.length > _maxReadKeys) {
      // Sets keep insertion order, so the last ones are the newest.
      final others = _readKeys.difference(current).toList();
      final keep = (_maxReadKeys - current.length).clamp(0, others.length);
      _readKeys = {..._readKeys.intersection(current), ...others.sublist(others.length - keep)};
    }
    unawaited(_prefs?.setStringList(_kRead, _readKeys.toList()));
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _rescheduleTimer?.cancel();
    _clock?.cancel();
    super.dispose();
  }
}
