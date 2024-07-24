import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/welcome_screen.dart';
import 'screens/user_preferences_screen.dart';
import 'screens/my_app.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones(); // Inicializa las zonas horarias
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? storedEmail = prefs.getString('email');
  bool? hasCompletedPreferences = prefs.getBool('hasCompletedPreferences');
  await AndroidAlarmManager.initialize();
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
}
