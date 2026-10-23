import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:suga/utils/advisory_time.dart';
import 'package:timezone/timezone.dart' as tz;

enum NotificationPermission { unknown, granted, denied, unsupported }

// Phone notifications (the ones in the status bar). An interface, so tests and
// platforms without notifications can use a version that does nothing.
abstract class DeviceNotifications {
  // Called with the payload (the advisory id) when the user taps a notification.
  set onTap(void Function(String payload)? handler);

  Future<void> init();
  Future<NotificationPermission> checkPermission();
  Future<NotificationPermission> requestPermission();
  Future<void> openSystemSettings();
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    required String payload,
  });
  Future<void> show({required int id, required String title, required String body, required String payload});

  // Cancels reminders that have not fired yet. Notifications already shown stay.
  Future<void> cancelScheduled();
}

// flutter_local_notifications on Android and iOS. Elsewhere (web, desktop) it reports
// NotificationPermission.unsupported and does nothing, and the in-app list still works.
class NotificationService implements DeviceNotifications {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  void Function(String payload)? _onTap;
  bool _ready = false;
  String? _launchPayload;

  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'brownout_alerts',
      'Brownout alerts',
      channelDescription: 'Reminders before scheduled brownouts and power restored alerts',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_stat_suga',
    ),
    iOS: DarwinNotificationDetails(),
  );

  @override
  set onTap(void Function(String payload)? handler) {
    _onTap = handler;
    // The app was opened by tapping a notification before anyone was listening.
    final pending = _launchPayload;
    if (handler != null && pending != null) {
      _launchPayload = null;
      handler(pending);
    }
  }

  @override
  Future<void> init() async {
    if (_ready || !isSupported) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_suga'),
        // Ask on iOS only when the user turns notifications on, not at launch.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null) _onTap?.call(payload);
      },
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final payload = launch?.notificationResponse?.payload;
    if (launch?.didNotificationLaunchApp == true && payload != null) {
      if (_onTap != null) {
        _onTap!(payload);
      } else {
        _launchPayload = payload;
      }
    }
    _ready = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  IOSFlutterLocalNotificationsPlugin? get _ios =>
      _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

  @override
  Future<NotificationPermission> checkPermission() async {
    if (!isSupported) return NotificationPermission.unsupported;
    try {
      await init();
      final enabled = defaultTargetPlatform == TargetPlatform.android
          ? await _android?.areNotificationsEnabled()
          : (await _ios?.checkPermissions())?.isEnabled;
      if (enabled == null) return NotificationPermission.unknown;
      return enabled ? NotificationPermission.granted : NotificationPermission.denied;
    } catch (_) {
      return NotificationPermission.unknown;
    }
  }

  // Shows the system "Allow notifications?" prompt (Android 13+ and iOS).
  @override
  Future<NotificationPermission> requestPermission() async {
    if (!isSupported) return NotificationPermission.unsupported;
    try {
      await init();
      final granted = defaultTargetPlatform == TargetPlatform.android
          ? await _android?.requestNotificationsPermission()
          : await _ios?.requestPermissions(alert: true, badge: true, sound: true);
      if (granted == null) return checkPermission();
      return granted ? NotificationPermission.granted : NotificationPermission.denied;
    } catch (_) {
      return NotificationPermission.unknown;
    }
  }

  // For when the user said no before: Android and iOS stop showing the prompt,
  // so the only way back is the app's page in system settings.
  @override
  Future<void> openSystemSettings() async {
    if (!isSupported) return;
    try {
      await _plugin.openAppNotificationSettings();
    } catch (_) {
      // Nothing else to try; the banner keeps explaining what to do.
    }
  }

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    required String payload,
  }) async {
    if (!isSupported) return;
    await init();
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(when, manila),
      notificationDetails: _details,
      // Inexact: may arrive a few minutes late, but needs no exact-alarm permission.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  @override
  Future<void> show({required int id, required String title, required String body, required String payload}) async {
    if (!isSupported) return;
    await init();
    await _plugin.show(id: id, title: title, body: body, notificationDetails: _details, payload: payload);
  }

  @override
  Future<void> cancelScheduled() async {
    if (!isSupported) return;
    await init();
    await _plugin.cancelAllPendingNotifications();
  }
}
