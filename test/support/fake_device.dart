import 'package:suga/services/notification_service.dart';

// Records what would be sent to the phone instead of showing anything.
class FakeDevice implements DeviceNotifications {
  FakeDevice({this.permission = NotificationPermission.granted, this.grantOnRequest = true});

  NotificationPermission permission;
  bool grantOnRequest;
  int permissionRequests = 0;
  int settingsOpened = 0;
  final scheduled = <({int id, String title, DateTime when})>[];
  final shown = <String>[];

  @override
  set onTap(void Function(String payload)? handler) {}

  @override
  Future<void> init() async {}

  @override
  Future<NotificationPermission> checkPermission() async => permission;

  @override
  Future<NotificationPermission> requestPermission() async {
    permissionRequests++;
    if (grantOnRequest) permission = NotificationPermission.granted;
    return permission;
  }

  @override
  Future<void> openSystemSettings() async {
    settingsOpened++;
  }

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    required String payload,
  }) async =>
      scheduled.add((id: id, title: title, when: when));

  @override
  Future<void> show({required int id, required String title, required String body, required String payload}) async =>
      shown.add(title);

  @override
  Future<void> cancelScheduled() async => scheduled.clear();
}
