import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(settings);
    _initialized = true;
  }

  static Future<void> requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> sendGridDownAlert() async {
    await init();
    const androidDetails = AndroidNotificationDetails(
      'grid_alerts',
      'Grid Outage Alerts',
      channelDescription: 'Alerts when grid power goes down',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );
    const details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      1,
      '⚡ Grid Power Lost',
      'Wire power is 0W. Grid appears to be down.',
      details,
    );
  }

  static Future<void> sendGridRestoredAlert() async {
    await init();
    const androidDetails = AndroidNotificationDetails(
      'grid_alerts',
      'Grid Outage Alerts',
      channelDescription: 'Alerts when grid power is restored',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      2,
      '✅ Grid Power Restored',
      'Wire power is back. Grid is online.',
      details,
    );
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
