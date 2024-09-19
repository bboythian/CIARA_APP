import 'package:ciara/services/usage_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:usage_stats/usage_stats.dart';
import 'package:http/http.dart' as http;
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:convert';
import 'package:intl/intl.dart';
// import 'package:device_apps/device_apps.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:workmanager/workmanager.dart';
import 'package:usage_stats/usage_stats.dart';

// Este es el nombre de la tarea de WorkManager
const String dailyAlarmTask = "dailyAlarmTask";

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    await BackgroundService.scheduleDailyAlarms();
    return Future.value(true);
  });
}

class BackgroundService {
  static FlutterLocalNotificationsPlugin? flutterLocalNotificationsPlugin;
  static late String email;

  static Future<void> initialize() async {
    if (flutterLocalNotificationsPlugin == null) {
      flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      const androidInitializationSettings = AndroidInitializationSettings(
          'ic_notificacion'); // Ajusta el ícono según tu configuración

      const initializationSettings =
          InitializationSettings(android: androidInitializationSettings);

      await flutterLocalNotificationsPlugin!.initialize(initializationSettings);
      tz.initializeTimeZones();
    }
  }

  static Future<void> scheduleDailyAlarms() async {
    await initialize();
    await UsageService.getEmail();

    final location = tz.getLocation('America/Guayaquil');
    final now = tz.TZDateTime.now(location);

    // Programar la alarma diaria a las 23:50
    final dailyReportTime =
        tz.TZDateTime(location, now.year, now.month, now.day, 23, 50);
    final nextDailyReportTime = dailyReportTime.isBefore(now)
        ? dailyReportTime.add(Duration(days: 1))
        : dailyReportTime;

    // Programar la alarma diaria
    await AndroidAlarmManager.oneShotAt(
      nextDailyReportTime,
      0,
      callback,
      exact: true,
      wakeup: true,
      allowWhileIdle:
          true, // Asegura que la alarma se active incluso en suspensión
    );

    print('Alarma programada para: $nextDailyReportTime - User: $email ');
  }

  static Future<void> callback() async {
    await initialize();
    await UsageService.getEmail();

    DateTime currentDate = DateTime.now();
    final location = tz.getLocation('America/Guayaquil');
    final currentTZDate = tz.TZDateTime.now(location);
    String formattedDate =
        DateFormat('yyyy-MM-dd / HH:mm').format(currentTZDate);

    String mostHour = await UsageService.getMostActiveHour(currentDate);

    // Inicializar datos de uso
    List<UsageInfo> usageInfoList = await initUsage(currentDate);
    List<Map<String, dynamic>> dataToSend =
        await _prepareUsageData(usageInfoList);

    // Verificar la conexión a internet
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.none) {
      // Sin conexión a internet, guardar datos y programar reintento a las 10 AM
      print('Sin conexión a internet. Guardando datos localmente...');
      await saveDataLocally(formattedDate, mostHour, dataToSend);
      await _scheduleRetryAlarm(); // Reintento a las 10 AM
      return; // Salir del callback si no hay conexión
    }

    try {
      var url = Uri.parse('https://ingsoftware.ucuenca.edu.ec/enviar-datos');
      var response = await http.post(
        url,
        body: {
          'email': email,
          'fecha': formattedDate,
          'mayorConsumo': mostHour,
          'usageData': jsonEncode(dataToSend),
        },
      );

      if (response.statusCode == 200) {
        _showNotification("Reporte diario enviado exitosamente!");
        print('Reporte enviado exitosamente.');
      } else {
        throw Exception('Error al enviar el reporte.');
      }
    } catch (error) {
      print('Error al enviar el reporte: $error');
      await saveDataLocally(formattedDate, mostHour, dataToSend);
      await _scheduleRetryAlarm(); // Programar reintento si falla
      // Programar la siguiente alarma diaria
      await scheduleNextDailyAlarm();
      return;
    }

    // Programar la siguiente alarma diaria
    await scheduleNextDailyAlarm();
  }

  static Future<void> scheduleNextDailyAlarm() async {
    final location = tz.getLocation('America/Guayaquil');
    final now = tz.TZDateTime.now(location);

    // Configurar la próxima alarma para el día siguiente a las 23:50
    final nextReportTime =
        tz.TZDateTime(location, now.year, now.month, now.day, 23, 50)
            .add(Duration(days: 1));

    try {
      await AndroidAlarmManager.oneShotAt(
        nextReportTime,
        0, // ID de la alarma
        callback, // Método que se ejecutará
        exact: true,
        wakeup: true,
        allowWhileIdle: true, // Asegura que la alarma funcione en segundo plano
      );
      print('Próxima alarma programada para: $nextReportTime');
    } catch (error) {
      print('Error al programar la siguiente alarma: $error');
    }
  }

  static Future<void> _scheduleRetryAlarm() async {
    final location = tz.getLocation('America/Guayaquil');
    final now = tz.TZDateTime.now(location);
    final retryTime =
        tz.TZDateTime(location, now.year, now.month, now.day, 10, 0)
            .add(Duration(days: 1));

    await AndroidAlarmManager.oneShotAt(
      retryTime,
      1,
      trySendFailedData,
      exact: true,
      wakeup: true,
      allowWhileIdle: true, // Asegura que la alarma funcione en segundo plano
    );
    print('Error detectado, reprogramando la alarma para: $retryTime');
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
            'email': email,
            'fecha': failedDate,
            'mayorConsumo': failedHour,
            'usageData': failedData,
          },
        );

        if (response.statusCode == 200) {
          await _clearFailedData();
          print('Datos fallidos enviados exitosamente.');
        } else {
          throw Exception('Error al enviar datos fallidos.');
        }
      } catch (error) {
        print('Error al enviar datos fallidos: $error');
        await _scheduleRetryAlarm(); // Reintentar nuevamente si falla
      }
    }
  }

  static Future<void> saveDataLocally(
      String date, String hour, List<Map<String, dynamic>> data) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('failedDate', date);
    await prefs.setString('failedHour', hour);
    await prefs.setString('failedData', jsonEncode(data));
  }

  static Future<void> _clearFailedData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('failedDate');
    await prefs.remove('failedHour');
    await prefs.remove('failedData');
  }

  static Future<List<Map<String, dynamic>>> _prepareUsageData(
      List<UsageInfo> usageInfoList) async {
    List<UsageInfo> sortedUsageInfo = usageInfoList
      ..sort((a, b) => _convertTimeToMinutes(b.totalTimeInForeground!)
          .compareTo(_convertTimeToMinutes(a.totalTimeInForeground!)));
    List<UsageInfo> topUsageInfo = sortedUsageInfo.take(5).toList();

    return await Future.wait(topUsageInfo.map((info) async {
      return {
        'packageName':
            await UsageService.getAppNameFromPackageName(info.packageName!),
        'totalTimeInForeground':
            _convertTimeToMinutes(info.totalTimeInForeground!),
      };
    }).toList());
  }

  static Future<void> _showNotification(String message) async {
    if (flutterLocalNotificationsPlugin == null) {
      await initialize();
    }

    await flutterLocalNotificationsPlugin!.show(
      0,
      "CIARA",
      message,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          "channelId",
          "Local Notification",
          "Descripción de la notificación",
          importance: Importance.high,
        ),
      ),
    );
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

      List<String> excludedPackages = [
        'com.oppo.launcher',
        'com.sec.android.app.launcher',
        'com.example.ciara',
        'com.android.settings'
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

  static Future<void> initializeWorkManager() async {
    Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
  }

  static Future<void> registerDailyTask() async {
    Workmanager().registerPeriodicTask(
      "1",
      dailyAlarmTask,
      frequency: Duration(hours: 24),
      initialDelay: Duration(minutes: 1),
      existingWorkPolicy:
          ExistingWorkPolicy.keep, // Mantener la tarea existente
    );
  }

// ALERTAS DIARIAS
  static Future<void> checkUsage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Obtener el tiempo total de uso de las apps
    int totalUsageTime = await UsageService.getTotalUsageToday();

    // Verificar si ya se han enviado las notificaciones hoy
    // Verificar si ya se han enviado las notificaciones hoy
    bool hasNotified4Hours = prefs.getBool('hasNotified4Hours') ?? false;
    bool hasNotified6Hours = prefs.getBool('hasNotified6Hours') ?? false;
    bool hasNotified8Hours = prefs.getBool('hasNotified8Hours') ?? false;

    print("Tiempo de uso detectado: ${totalUsageTime ~/ (60 * 1000)} minutos");

    // Revisar si ha alcanzado las 4 horas y aún no se ha enviado la notificación
    // if (totalUsageTime >= 4 * 60 * 60 * 1000 && !hasNotified4Hours) {
    if (totalUsageTime >= 5 * 60 * 1000 && !hasNotified4Hours) {
      // Enviar notificación de 4 horas
      await sendNotification("Has alcanzado 4 horas de uso de pantalla.");
      prefs.setBool('hasNotified4Hours', true);
    }

    // Revisar si ha alcanzado las 6 horas y aún no se ha enviado la notificación
    // if (totalUsageTime >= 6 * 60 * 60 * 1000 && !hasNotified6Hours) {
    if (totalUsageTime >= 10 * 60 * 1000 && !hasNotified6Hours) {
      // Enviar notificación de 6 horas
      await sendNotification("Has alcanzado 6 horas de uso de pantalla.");
      prefs.setBool('hasNotified6Hours', true);
    }

    // Revisar si ha alcanzado las 9 horas y aún no se ha enviado la notificación
    // if (totalUsageTime >= 8 * 60 * 60 * 1000 && !hasNotified8Hours) {
    if (totalUsageTime >= 15 * 60 * 1000 && !hasNotified8Hours) {
      // Enviar notificación de 9 horas
      await sendNotification("Has alcanzado 8 horas de uso de pantalla.");
      prefs.setBool('hasNotified8Hours', true);
    }

    // Reiniciar el estado cada día
    DateTime lastReset = DateTime.parse(
        prefs.getString('lastReset') ?? DateTime.now().toIso8601String());
    if (DateTime.now().difference(lastReset).inDays >= 1) {
      prefs.setBool('hasNotified4Hours', false);
      prefs.setBool('hasNotified6Hours', false);
      prefs.setBool('hasNotified8Hours', false);
      prefs.setString('lastReset', DateTime.now().toIso8601String());
    }

    // Mostrar el tiempo de uso en consola cada vez que se chequea
    print(
        "Tiempo de uso total de pantalla: ${totalUsageTime ~/ 1000} segundos");
  }

  static Future<void> sendNotification(String message) async {
    if (flutterLocalNotificationsPlugin == null) {
      await initialize();
    }

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'your_channel_id',
      'Uso del Teléfono',
      'Notificaciones por tiempo de uso del dispositivo',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin!.show(
      0,
      'Tiempo de Uso de Pantalla',
      message,
      platformChannelSpecifics,
      payload: 'item x',
    );
  }

  static Future<void> registerUsageMonitoringTask() async {
    Workmanager().registerPeriodicTask(
      "checkUsageTask",
      "checkDailyUsage",
      frequency: Duration(minutes: 15),
      initialDelay: Duration(minutes: 1),
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );
  }
}
