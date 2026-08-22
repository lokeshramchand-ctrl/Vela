import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Thin wrapper around flutter_local_notifications for the one notification
/// this app fires: "your statement finished processing", triggered from the
/// Analysing screen's live job-poll stream while the app process is alive
/// (foreground or backgrounded) - there is no push/server-triggered path.
class LocalNotificationsService {
  LocalNotificationsService._();
  static final LocalNotificationsService instance = LocalNotificationsService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _plugin.initialize(const InitializationSettings(android: androidSettings, iOS: iosSettings));
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final iosImpl = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) return await androidImpl.requestNotificationsPermission() ?? false;
    if (iosImpl != null) return await iosImpl.requestPermissions(alert: true, badge: true, sound: true) ?? false;
    return true;
  }

  Future<void> showJobDone({required String title, required String body}) async {
    const androidDetails = AndroidNotificationDetails(
      'job_status',
      'Statement processing',
      channelDescription: "Notifies when a statement finishes analysing",
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails, iOS: DarwinNotificationDetails());
    await _plugin.show(0, title, body, details);
  }
}
