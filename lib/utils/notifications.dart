import 'package:flutter_local_notifications/flutter_local_notifications.dart';

FlutterLocalNotificationsPlugin configureLocalNotificationPlugin() {
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  const androidInitializationSettings =
      AndroidInitializationSettings('ic_notificacion');
  const initializationSettings =
      InitializationSettings(android: androidInitializationSettings);
  flutterLocalNotificationsPlugin.initialize(initializationSettings);
  return flutterLocalNotificationsPlugin;
}
