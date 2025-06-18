import 'package:ciara/services/usage_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:usage_stats/usage_stats.dart';
import 'package:http/http.dart' as http;
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:workmanager/workmanager.dart' as workManager;
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:workmanager/workmanager.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:ciara/services/usage_monitoring_service.dart';

// Este es el nombre de la tarea de WorkManager
const String dailyAlarmTask = "dailyAlarmTask";

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // Aquí llamamos a la función checkUsage del servicio en primer plano
    await UsageMonitoringService.checkUsage();
    print("Tarea ejecutada: $task");
    return Future.value(true); // Indicar que la tarea se completó
  });
}

//verificar conectividad
void initializeConnectivityListener() {
  Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
    if (result != ConnectivityResult.none) {
      BackgroundService.trySendFailedData();
    }
  });
}

class BackgroundService {
  static FlutterLocalNotificationsPlugin? flutterLocalNotificationsPlugin;
  static late String email;

  static Future<void> initialize() async {
    if (flutterLocalNotificationsPlugin == null) {
      flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      const androidInitializationSettings =
          AndroidInitializationSettings('ic_notificacion0');

      const initializationSettings =
          InitializationSettings(android: androidInitializationSettings);

      await flutterLocalNotificationsPlugin!.initialize(initializationSettings);
      tz.initializeTimeZones();
    }
  }

  static Future<void> scheduleDailyAlarms() async {
    try {
      await initialize();
      // await startForegroundService(); // Iniciar el servicio en primer plano

      // SharedPreferences prefs = await SharedPreferences.getInstance();
      // email = prefs.getString('email') ?? '**';

      final location = tz.local;
      final now = tz.TZDateTime.now(location);

      // Programar la alarma para las 12:15
      var dailyReportTime =
          tz.TZDateTime(location, now.year, now.month, now.day, 23, 50);
      if (dailyReportTime.isBefore(now)) {
        dailyReportTime = dailyReportTime.add(const Duration(days: 1));
      }

      // Programar la tarea usando AndroidAlarmManager
      await AndroidAlarmManager.oneShotAt(
        dailyReportTime, // Hora exacta
        1, // ID único para la alarma
        callback, // Función a ejecutar
        exact: true, // Asegurarse de que sea exacto
        wakeup: true, // Despertar el dispositivo si es necesario
        allowWhileIdle: true, // Ejecutar incluso en modo inactivo
      );
      print('*HORA ACTUAL* $now');
      print(
          '** TASK ** Tarea diaria programada correctamente para: $dailyReportTime');
    } catch (e) {
      print('Error al programar la alarma diaria: $e');
    }
  }

  @pragma('vm:entry-point')
  static Future<void> callback() async {
    await initialize();
    print('Ejecutando callback a la hora programada');

    SharedPreferences prefs = await SharedPreferences.getInstance();
    email = prefs.getString('email') ?? '**';

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
      // await _scheduleRetryAlarm(); // Reintento a las 11 AM
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
      print('Response status callback: ${response.statusCode}');
      print('Response body: ${response.body}');
      flutterLocalNotificationsPlugin!.show(
        0,
        "CIARA",
        "Reporte diario enviado exitosamente!",
        const NotificationDetails(
          android: AndroidNotificationDetails(
            "channelId",
            "Local Notification",
            importance: Importance.high,
          ),
        ),
      );
    } catch (error) {
      print('Error al enviar el reporte diario: $error');
      return;
    }
  }

  @pragma('vm:entry-point')
  static Future<void> scheduleNextDailyAlarm() async {
    final location = tz.getLocation('America/Guayaquil');
    final now = tz.TZDateTime.now(location);

    // Configurar la próxima alarma para el día siguiente a las 23:50
    final nextReportTime =
        tz.TZDateTime(location, now.year, now.month, now.day, 23, 50) //HORAF
            .add(const Duration(days: 1));

    try {
      await AndroidAlarmManager.oneShotAt(
        nextReportTime,
        2,
        callback,
        exact: true,
        wakeup: true,
        allowWhileIdle: true,
      );
      print('Próxima alarma programada para: $nextReportTime');
    } catch (error) {
      print('Error al programar la siguiente alarma: $error');
    }
  }

  @pragma('vm:entry-point')
  static Future<void> _scheduleRetryAlarm() async {
    // Reintento a las 10 AM
    final location = tz.getLocation('America/Guayaquil');
    final now = tz.TZDateTime.now(location);
    final retryTime =
        tz.TZDateTime(location, now.year, now.month, now.day, 20, 00) //HORAF
            .add(const Duration(days: 1));

    try {
      await AndroidAlarmManager.oneShotAt(
        retryTime,
        3,
        callback,
        exact: true,
        wakeup: true,
      );

      print('Reintento programado para: $retryTime');
    } catch (e) {
      print('Error al programar el reintento: $e');
    }
  }

  @pragma('vm:entry-point')
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
          await _clearFailedData(); // Limpiar los datos si se envía exitosamente
          print('Reporte anterior enviado exitosamente.');
        } else {
          throw Exception('Error al enviar datos fallidos.');
        }
        await scheduleDailyAlarms();
      } catch (error) {
        print('Error al enviar datos fallidos: $error');
        // Si el reintento falla, reprográmalo para otro intento a las 10 AM del siguiente día
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

  // static Future<void> _showNotification(String message) async {
  //   if (flutterLocalNotificationsPlugin == null) {
  //     await initialize();
  //   }
  //   await flutterLocalNotificationsPlugin!.show(
  //     0,
  //     "CIARA",
  //     message,
  //     const NotificationDetails(
  //       android: AndroidNotificationDetails(
  //         "channelId",
  //         "Local Notification",
  //         "Descripción de la notificación",
  //         importance: Importance.high,
  //       ),
  //     ),
  //   );
  // }
  static Future<void> _showNotification(String message) async {
    if (flutterLocalNotificationsPlugin == null) {
      await initialize();
    }

    AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'your_channel_id',
      'Local Notification',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      // Elimina la referencia a PendingIntent
    );

    NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin!.show(
      0,
      "CIARA",
      message,
      platformChannelSpecifics,
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

      // Inicializar el vector de tiempos para cada rango
      List<int> timeByRanges = List.filled(8, 0); // Inicializa con 8 ceros.

      for (var event in events) {
        DateTime eventTime =
            DateTime.fromMillisecondsSinceEpoch(int.parse(event.timeStamp!));
        String packageName = event.packageName ?? 'Unknown';
        // Procesar eventos de inicio y fin de uso
        if (event.eventType == "1") {
          foregroundTimes[packageName] = eventTime.millisecondsSinceEpoch;
        } else if (event.eventType == "2") {
          if (foregroundTimes.containsKey(packageName)) {
            int startTime = foregroundTimes[packageName]!;
            int endTime = eventTime.millisecondsSinceEpoch;
            int foregroundTime = endTime - startTime;

            usageByApp[packageName] =
                (usageByApp[packageName] ?? 0) + foregroundTime;

            // Calcular tiempo en cada rango horario
            int startHour = DateTime.fromMillisecondsSinceEpoch(startTime).hour;
            int endHour = DateTime.fromMillisecondsSinceEpoch(endTime).hour;

            for (int i = startHour; i <= endHour; i++) {
              int rangeIndex = _getRangeIndex(i);
              timeByRanges[rangeIndex] +=
                  foregroundTime ~/ 60000; // Convertir a minutos.
            }

            foregroundTimes.remove(packageName);
          }
        }
      }

      List<String> excludedPackages = [
        'com.oppo.launcher',
        'com.sec.android.app.launcher',
        // 'com.example.ciara',
        // 'com.android.settings',
        'com.transsion.XOSLauncher', //infinix
        'com.miui.home', //readmi
        'com.mi.android.globallauncher' // POCO
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
      // Agregar el vector de tiempos como un elemento adicional
      usageInfoList.add(
        UsageInfo(
          packageName: "AllRegistration",
          totalTimeInForeground: timeByRanges.toString(),
        ),
      );
    } catch (err) {
      print("Error: $err");
    }
    return usageInfoList;
  }

  // Función auxiliar para determinar el índice del rango basado en la hora
  static int _getRangeIndex(int hour) {
    if (hour >= 0 && hour <= 2) return 0;
    if (hour >= 3 && hour <= 5) return 1;
    if (hour >= 6 && hour <= 8) return 2;
    if (hour >= 9 && hour <= 11) return 3;
    if (hour >= 12 && hour <= 14) return 4;
    if (hour >= 15 && hour <= 17) return 5;
    if (hour >= 18 && hour <= 20) return 6;
    if (hour >= 21 && hour <= 23) return 7;
    return -1; // Caso no válido.
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
    Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
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

//TAREA B: CheckUsage
  static Future<void> registerUsageMonitoringTask() async {
    Workmanager().registerPeriodicTask(
      "checkUsageTask",
      "checkDailyUsage",
      frequency: Duration(minutes: 15),
      constraints: Constraints(
        networkType:
            workManager.NetworkType.not_required, // No requiere internet
        requiresBatteryNotLow: false, // Ejecutar incluso con batería baja
        requiresCharging: false, // No requiere estar cargando
      ),
    );
  }
}
