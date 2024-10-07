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
import 'dart:typed_data';

import 'package:ciara/services/usage_monitoring_service.dart';

// Este es el nombre de la tarea de WorkManager
const String dailyAlarmTask = "dailyAlarmTask";

// void callbackDispatcher() {
//   print("callbackDispatcher ejecutado");
//   Workmanager().executeTask((task, inputData) async {
//     await BackgroundService.scheduleDailyAlarms();
//     print("Tarea ejecutada: $task");
//     return Future.value(true);
//   });
// }
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // Aquí llamamos a la función checkUsage del servicio en primer plano
    await UsageMonitoringService.checkUsage();
    return Future.value(true); // Indicar que la tarea se completó
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
    try {
      await initialize();
      // await startForegroundService(); // Iniciar el servicio en primer plano

      SharedPreferences prefs = await SharedPreferences.getInstance();
      email = prefs.getString('email') ?? '**';

      final location = tz.getLocation('America/Guayaquil');
      final now = tz.TZDateTime.now(location);

      // Programar la alarma diaria a la hora deseada (e.g., 23:50)
      var dailyReportTime =
          tz.TZDateTime(location, now.year, now.month, now.day, 10, 25);
      if (dailyReportTime.isBefore(now)) {
        dailyReportTime = dailyReportTime.add(Duration(
            days:
                1)); // Asegurar que se programe para el día siguiente si ya ha pasado
      }

      await AndroidAlarmManager.oneShotAt(
        dailyReportTime, // La hora exacta
        0, // ID único para la alarma
        callback, // Función a ejecutar
        exact: true,
        wakeup: true,
        allowWhileIdle: true,
      );
      print('*HORA ACTUAL* $now');
      print(
          '** TASK ** Tarea diaria programada correctamente para: $dailyReportTime');
    } catch (e) {
      print('Error al programar la alarma diaria: $e');
    }
  }

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
      await _scheduleRetryAlarm(); // Reintento a las 11 AM
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

      // if (response.statusCode == 200) {
      //   _showNotification("Reporte diario enviado exitosamente!");
      //   print('Reporte enviado exitosamente.');
      //   await _clearFailedData(); // Limpiar datos si se envían correctamente
      // } else {
      //   throw Exception('Error al enviar el reporte.');
      // }
      print('Response status: ${response.statusCode}');
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
      // Programar la alarma para el siguiente día a la misma hora
      // Programar la alarma para el día siguiente a la hora especificada
      await scheduleNextDailyAlarm(); // Ajusta la hora y minuto según lo que necesites
    } catch (error) {
      print('Error al enviar el reporte: $error');
      await saveDataLocally(formattedDate, mostHour, dataToSend);
      await _scheduleRetryAlarm(); // Programar reintento si falla
      // Programar la siguiente alarma diaria
      await scheduleNextDailyAlarm();
      return;
    }
  }

  static Future<void> scheduleNextDailyAlarm() async {
    final location = tz.getLocation('America/Guayaquil');
    final now = tz.TZDateTime.now(location);

    // Configurar la próxima alarma para el día siguiente a las 23:50
    final nextReportTime =
        tz.TZDateTime(location, now.year, now.month, now.day, 23, 50) //HORAF
            .add(Duration(days: 1));

    try {
      await AndroidAlarmManager.oneShotAt(
        nextReportTime,
        1,
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

  static Future<void> _scheduleRetryAlarm() async {
    // Reintento a las 10 AM
    final location = tz.getLocation('America/Guayaquil');
    final now = tz.TZDateTime.now(location);
    final retryTime =
        tz.TZDateTime(location, now.year, now.month, now.day, 10, 30) //HORAF
            .add(Duration(days: 1));
    // Programar el reintento para las 10:00 AM del día siguiente si no hay conexión
    // final retryTime =
    //     tz.TZDateTime(location, now.year, now.month, now.day, 11, 0)
    //         .add(Duration(days: now.hour >= 10 ? 1 : 0));

    try {
      await AndroidAlarmManager.oneShotAt(
        retryTime,
        1,
        callback,
        exact: true,
        wakeup: true,
      );
      // await Workmanager().registerOneOffTask(
      //   "retryAlarmTask",
      //   dailyAlarmTask,
      //   initialDelay: retryTime.difference(DateTime.now()),
      //   constraints: Constraints(
      //     networkType:
      //         workManager.NetworkType.connected, // Requiere conexión a internet
      //   ),
      // );
      print('Reintento programado para: $retryTime');
    } catch (e) {
      print('Error al programar el reintento: $e');
    }
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

// ALERTAS DIARIAS

  static const int alert1 = 80;
  static const int alert2 = 100;
  static const int alert3 = 120;

  static Future<void> checkUsage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Obtener el email desde SharedPreferences
    String? email = prefs.getString('email');
    if (email == null) {
      print('Email no encontrado en SharedPreferences.');
      return; // Si no hay email guardado, no se ejecuta el resto del proceso
    }

    // Obtener el tiempo total de uso de las apps
    int totalUsageTime = await UsageService.getTotalUsageToday() ~/ (60 * 1000);

    // Verificar si ya se han enviado las notificaciones hoy
    bool hasNotified4Hours = prefs.getBool('hasNotified4Hours') ?? false;
    bool hasNotified6Hours = prefs.getBool('hasNotified6Hours') ?? false;
    bool hasNotified8Hours = prefs.getBool('hasNotified8Hours') ?? false;

    // Revisar si ha alcanzado las 4 horas y aún no se ha enviado la notificación
    if (totalUsageTime >= alert1 && !hasNotified4Hours) {
      //4 horas =240
      //minutos
      await sendNotificationWithServerData(
          "¿Qué tal si tomas un descanso y pruebas esta actividad relajante:",
          email,
          totalUsageTime);
      prefs.setBool('hasNotified4Hours', true);
      print("**ALERT**: Alerta 4 Horas solicitada");
    }

    // Revisar si ha alcanzado las 6 horas y aún no se ha enviado la notificación
    if (totalUsageTime >= alert2 && !hasNotified6Hours) {
      //6 horas = 360
      await sendNotificationWithServerData(
          " ¡Prueba esta alternativa!", email, totalUsageTime);
      prefs.setBool('hasNotified6Hours', true);
      print("**ALERT**: Alerta 6 Horas solicitada");
    }

    // Revisar si ha alcanzado las 8 horas y aún no se ha enviado la notificación
    if (totalUsageTime >= alert3 && !hasNotified8Hours) {
      //9 horas = 480
      await sendNotificationWithServerData(
          "Es importante desconectarse un poco. Aquí tienes una idea para recargar energías:",
          email,
          totalUsageTime);
      prefs.setBool('hasNotified8Hours', true);
      print("**ALERT**: Alerta 8 Horas solicitada");
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
        "**checkUsage**: Tiempo de uso total de pantalla: ${totalUsageTime} minutos");
  }

  static Future<void> sendNotificationWithServerData(
      String message, String email, int totalUsageTimeInMinutes) async {
    if (flutterLocalNotificationsPlugin == null) {
      await initialize();
    }

    try {
      // Realizar la solicitud POST al servidor
      var url =
          Uri.parse('https://ingsoftware.ucuenca.edu.ec/generar-consulta');
      var response = await http.post(
        url,
        body: {
          'email': email, // Aquí enviamos el email
        },
      );

      // Verificar si la respuesta es correcta
      if (response.statusCode == 200) {
        // Obtener el texto devuelto por el servidor
        String serverMessage = response.body;

        // Obtener el progreso y el color basado en el tiempo de uso
        int progress = _getProgress(totalUsageTimeInMinutes);
        Color progressColor = _getProgressColor(totalUsageTimeInMinutes);

        // Título dinámico basado en el uso
        String dynamicTitle =
            _getDynamicTitle(totalUsageTimeInMinutes, message);

        // Mostrar notificación con el mensaje del servidor
        AndroidNotificationDetails androidPlatformChannelSpecifics =
            AndroidNotificationDetails(
          'your_channel_id',
          'Uso del Teléfono',
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'ticker',
          styleInformation: BigTextStyleInformation(serverMessage),
          enableLights: true,
          ledColor: progressColor, // Cambiar el color del LED según el tiempo
          ledOnMs: 1000,
          ledOffMs: 500,
          showProgress: true,
          maxProgress: 100, // El progreso máximo será 100%
          progress: progress, // El progreso actual
          color: progressColor, // Cambiar el color de la notificación
        );

        NotificationDetails platformChannelSpecifics =
            NotificationDetails(android: androidPlatformChannelSpecifics);

        await flutterLocalNotificationsPlugin!.show(
          0,
          dynamicTitle, // Mostrar el título dinámico
          serverMessage, // El mensaje será el texto devuelto por el servidor
          platformChannelSpecifics,
          payload: 'item x',
        );
      } else {
        throw Exception(
            'Error al conectarse al servidor para generar consulta de actividad.');
      }
    } catch (error) {
      print('Error en la solicitud POST: $error (generando consulta)');
      // Manejar error en la solicitud, puedes enviar una notificación de error si es necesario
    }
  }

  // Función para generar el título dinámico
  static String _getDynamicTitle(int totalUsageTimeInMinutes, String message) {
    if (totalUsageTimeInMinutes < alert2) {
      return "¡Llevas 4 horas con tu teléfono!";
    } else if (totalUsageTimeInMinutes < alert3) {
      return "Has alcanzado 6 horas de uso.";
    } else {
      return "Has alcanzado el límite diario con 8 horas de uso.";
    }
  }

  static int _getProgress(int totalUsageTimeInMinutes) {
    const int maxUsageMinutes = alert3;
    return (totalUsageTimeInMinutes / maxUsageMinutes * 100).toInt();
  }

  static Color _getProgressColor(int totalUsageTimeInMinutes) {
    if (totalUsageTimeInMinutes < alert2) {
      return Colors.green;
    } else if (totalUsageTimeInMinutes < alert3) {
      return Colors.yellow;
    } else {
      return Colors.red;
    }
  }

  static Future<void> registerUsageMonitoringTask() async {
    // Workmanager().registerPeriodicTask(
    //   "checkUsageTask",
    //   "checkDailyUsage",
    //   frequency: Duration(minutes: 15),
    //   initialDelay: Duration(minutes: 1),
    //   // existingWorkPolicy: ExistingWorkPolicy.keep,
    //   constraints: Constraints(
    //     networkType: workManager.NetworkType.not_required,
    //   ),
    // );
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
