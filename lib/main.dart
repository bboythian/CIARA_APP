import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/welcome_screen.dart';
import 'screens/user_preferences_screen.dart';
import 'screens/my_app.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'dart:isolate';
import 'dart:ui';
import 'services/background_service.dart';

const String isolateName = 'isolate';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? storedEmail = prefs.getString('email');
  bool? hasCompletedPreferences = prefs.getBool('hasCompletedPreferences');
  tz.initializeTimeZones(); // Inicializar la base de datos de zonas horarias
  await AndroidAlarmManager.initialize();

  // Registrar el callback
  initializeIsolate();

  runApp(MaterialApp(
    home: storedEmail == null
        ? WelcomeScreen()
        : (hasCompletedPreferences == true
            ? MyApp(email: storedEmail)
            : UserPreferencesScreen()),
    theme: ThemeData(
      primarySwatch: Colors.blue,
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: Color(0xFF002856),
        selectionColor: Color(0xFF002856),
        selectionHandleColor: Color(0xFF002856),
      ),
    ),
  ));

  // Programa la alarma diaria a las 23:59
  //await BackgroundService.scheduleDailyAlarms();
}

// Registrar el puerto de envío
void initializeIsolate() {
  final ReceivePort port = ReceivePort();
  IsolateNameServer.registerPortWithName(port.sendPort, isolateName);
  port.listen((dynamic data) {
    print("Isolate received: $data");
  });
}
