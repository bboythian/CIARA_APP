import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:usage_stats/usage_stats.dart';
import 'package:http/http.dart' as http;
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:device_apps/device_apps.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackgroundService {
  static late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
  static late String email;

  static Future<void> initialize() async {
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const androidInitializationSettings =
        AndroidInitializationSettings('ic_notificacion');
    const initializationSettings =
        InitializationSettings(android: androidInitializationSettings);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    tz.initializeTimeZones();
  }

  static Future<void> getCedula() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    email = prefs.getString('email') ?? '**';
  }

  // static Future<void> scheduleDailyAlarm() async {
  //   await initialize();
  //   await getCedula();

  //   final location = tz.getLocation('America/Guayaquil');
  //   final now = tz.TZDateTime.now(location);

  //   // Calcular la próxima vez que será las 23:59
  //   final scheduledTime =
  //       tz.TZDateTime(location, now.year, now.month, now.day, 12, 32);
  //   if (scheduledTime.isBefore(now)) {
  //     // Si la hora programada ya pasó hoy, programa para mañana
  //     scheduledTime.add(Duration(days: 1));
  //   }

  //   await AndroidAlarmManager.periodic(
  //     const Duration(days: 1),
  //     0,
  //     callback, // Callback debe ser estático
  //     startAt: scheduledTime,
  //     exact: true,
  //     wakeup: true,
  //   );
  //   print('*** User:  $email');
  //   print(
  //       'Alarma diaria programada para las 23:59 PM a partir de: $scheduledTime *****');
  // }
  static Future<void> scheduleDailyAlarms() async {
    await initialize();
    await getCedula();

    final location = tz.getLocation('America/Guayaquil');
    final now = tz.TZDateTime.now(location);

    // Programar la alarma diaria a las 23:59
    final dailyReportTime =
        tz.TZDateTime(location, now.year, now.month, now.day, 23, 55);
    if (dailyReportTime.isBefore(now)) {
      dailyReportTime.add(Duration(days: 1));
    }

    await AndroidAlarmManager.periodic(
      const Duration(days: 1),
      0,
      callback, // Callback debe ser estático
      startAt: dailyReportTime,
      exact: true,
      wakeup: true,
    );

    // Programar la alarma diaria a las 10:00 AM
    final retryTime =
        tz.TZDateTime(location, now.year, now.month, now.day, 10, 0);
    if (retryTime.isBefore(now)) {
      retryTime.add(Duration(days: 1));
    }

    await AndroidAlarmManager.periodic(
      const Duration(days: 1),
      1,
      trySendFailedData, // Callback debe ser estático
      startAt: retryTime,
      exact: true,
      wakeup: true,
    );
    print(
        ' *** User:  $email : Alarmas diarias programadas para las 23:59 PM y 12:00 AM (caso perdida) $dailyReportTime');
  }

  static Future<void> callback() async {
    await initialize();
    await getCedula();

    DateTime currentDate = DateTime.now();
    final location = tz.getLocation('America/Guayaquil');
    final currentTZDate = tz.TZDateTime.now(location);
    String formattedDate =
        DateFormat('yyyy-MM-dd / HH:mm').format(currentTZDate);

    String mostHour = "9 am";

    // Inicializa los datos de uso
    List<UsageInfo> usageInfoList = await initUsage(currentDate);
    usageInfoList.sort((a, b) => _convertTimeToMinutes(b.totalTimeInForeground!)
        .compareTo(_convertTimeToMinutes(a.totalTimeInForeground!)));
    List<UsageInfo> firstFiveUsageInfo = usageInfoList.take(5).toList();

    List<Map<String, dynamic>> dataToSend =
        await Future.wait(firstFiveUsageInfo.map((info) async {
      return {
        'packageName': await getAppNameFromPackageName(info.packageName!),
        'totalTimeInForeground':
            _convertTimeToMinutes(info.totalTimeInForeground!),
      };
    }).toList());

    print('Fecha actual: $formattedDate');
    print('Mayor consumo en la hora: $mostHour');
    print('Datos de uso: $dataToSend');

    try {
      var url = Uri.parse('https://ingsoftware.ucuenca.edu.ec/enviar-datos');
      // var url = Uri.parse('http://10.24.161.24:8081/enviar-datos');
      var response = await http.post(
        url,
        body: {
          'email': email,
          'fecha': formattedDate,
          'mayorConsumo': mostHour,
          'usageData': jsonEncode(dataToSend),
        },
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      flutterLocalNotificationsPlugin.show(
        0,
        "CIARA",
        "Reporte diario enviado exitosamente!",
        const NotificationDetails(
          android: AndroidNotificationDetails(
            "channelId",
            "Local Notification",
            "This is the description of the Notification, you can write anything",
            importance: Importance.high,
          ),
        ),
      );
    } catch (error) {
      print('Error al enviar los datos user( $email ): $error');
      await saveDataLocally(formattedDate, mostHour, dataToSend);
    }
  }

  static Future<void> saveDataLocally(
      String date, String hour, List<Map<String, dynamic>> data) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('failedDate', date);
    await prefs.setString('failedHour', hour);
    await prefs.setString('failedData', jsonEncode(data));
  }

  static Future<void> trySendFailedData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? failedDate = prefs.getString('failedDate');
    String? failedHour = prefs.getString('failedHour');
    String? failedData = prefs.getString('failedData');

    if (failedDate != null && failedHour != null && failedData != null) {
      try {
        var url = Uri.parse('https://ingsoftware.ucuenca.edu.ec/enviar-datos');
        var response = await http.post(
          url,
          body: {
            'email': email, // Usar el correo electrónico obtenido
            'fecha': failedDate,
            'mayorConsumo': failedHour,
            'usageData': failedData,
          },
        );

        print('Response status: ${response.statusCode}');
        print('Response body: ${response.body}');

        if (response.statusCode == 200) {
          // Limpiar datos fallidos después de un envío exitoso
          await prefs.remove('failedDate');
          await prefs.remove('failedHour');
          await prefs.remove('failedData');
        }
      } catch (error) {
        print('Error al enviar los datos fallidos: $error');
      }
    }
  }

  static Future<List<UsageInfo>> initUsage(DateTime date) async {
    List<UsageInfo> usageInfoList = [];
    try {
      bool? isGranted = await UsageStats.checkUsagePermission();
      if (!isGranted!) {
        await UsageStats.grantUsagePermission();
      }
      DateTime startDate =
          DateTime(date.year, date.month, date.day, 0, 0, 0, 0, 1);
      DateTime endDate =
          DateTime(date.year, date.month, date.day, 23, 59, 59, 999, 999);
      List<EventUsageInfo> events =
          await UsageStats.queryEvents(startDate, endDate);

      if (events.isEmpty) {
        print(
            'No se encontraron eventos de uso en el rango de tiempo especificado.');
      }

      Map<String, int> usageByApp = {};
      Map<String, int> foregroundTimes = {};

      for (var event in events) {
        DateTime eventTime =
            DateTime.fromMillisecondsSinceEpoch(int.parse(event.timeStamp!));
        String packageName = event.packageName ?? 'Unknown';

        if (event.eventType == "1") {
          foregroundTimes[packageName] = eventTime.millisecondsSinceEpoch;
        } else if (event.eventType == "2") {
          if (foregroundTimes.containsKey(packageName)) {
            int foregroundTime = eventTime.millisecondsSinceEpoch -
                foregroundTimes[packageName]!;
            usageByApp[packageName] =
                (usageByApp[packageName] ?? 0) + foregroundTime;
            foregroundTimes.remove(packageName);
          }
        }
      }

      foregroundTimes.forEach((packageName, timestamp) {
        print(
            'WARNING: Foreground event without a corresponding background event for $packageName');
      });

      // int totalTimeInMilliseconds =
      //     usageByApp.values.fold(0, (sum, element) => sum + element);
      // int totalMinutes = (totalTimeInMilliseconds / 60000).floor();

      // print("Tiempo total de uso: $totalMinutes minutos");

      List<String> excludedPackages = [
        'com.oppo.launcher',
        'otro.paquete1',
        'otro.paquete2'
      ];

      for (var app in usageByApp.keys) {
        int totalTimeInMilliseconds = usageByApp[app]!;

        if (!excludedPackages.contains(app) &&
            totalTimeInMilliseconds >= 60000) {
          int seconds = (totalTimeInMilliseconds / 1000).floor();
          int minutes = (seconds / 60).floor();
          int hours = (minutes / 60).floor();
          minutes = minutes % 60;
          seconds = seconds % 60;

          usageInfoList.add(
            UsageInfo(
              packageName: app,
              totalTimeInForeground: '$hours h $minutes m $seconds s',
            ),
          );
        }
      }
    } catch (err) {
      print("Error: $err");
    }
    return usageInfoList;
  }

  static Future<String> getAppNameFromPackageName(String packageName) async {
    try {
      Application? app = await DeviceApps.getApp(packageName);
      return app?.appName ?? packageName;
    } catch (e) {
      return packageName;
    }
  }

  static int _convertTimeToMinutes(String? time) {
    if (time == null || time.isEmpty) return 0;

    int hours = 0;
    int minutes = 0;
    int seconds = 0;

    RegExp regExp = RegExp(r'(\d+)\s?h\s?(\d+)\s?m\s?(\d+)\s?s');
    Match? match = regExp.firstMatch(time);

    if (match != null) {
      hours = int.tryParse(match.group(1)!) ?? 0;
      minutes = int.tryParse(match.group(2)!) ?? 0;
      seconds = int.tryParse(match.group(3)!) ?? 0;
    }

    return (hours * 60) + minutes + (seconds ~/ 60);
  }
}
