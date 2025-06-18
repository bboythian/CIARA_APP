import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ciara/services/usage_service.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:usage_stats/usage_stats.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'dart:convert';
import 'package:intl/intl.dart';

class UsageMonitoringService {
  static const int maxRetries = 3;
  static FlutterLocalNotificationsPlugin? flutterLocalNotificationsPlugin;
  static String email = '**';

  static Future<void> initialize() async {
    if (flutterLocalNotificationsPlugin == null) {
      flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      const androidInitializationSettings = AndroidInitializationSettings(
          'ic_notificacion0'); // Ajusta el ícono según tu configuración

      const initializationSettings =
          InitializationSettings(android: androidInitializationSettings);

      await flutterLocalNotificationsPlugin!.initialize(initializationSettings);
      tz.initializeTimeZones();
    }
  }

  static Future<void> startForegroundService() async {
    if (flutterLocalNotificationsPlugin == null) {
      flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      const androidInitializationSettings =
          AndroidInitializationSettings('ic_notificacion0');
      const initializationSettings =
          InitializationSettings(android: androidInitializationSettings);

      await flutterLocalNotificationsPlugin!.initialize(initializationSettings);
    }

    const androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'usage_monitoring_channel',
      'Monitoreo de Uso',
      channelDescription: 'Monitoreo de uso en segundo plano',
      importance: Importance.max,
      priority: Priority.high,
      ongoing: true, // Hace la notificación persistente
      autoCancel: false, // Impide que se cancele al interactuar
    );

    const platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin!.show(
      0,
      'Monitoreo Activo',
      'El monitoreo de uso de aplicaciones está en ejecución',
      platformChannelSpecifics,
    );
  }

  // Este método reemplaza al uso de AndroidAlarmManager
  // Iniciar el servicio en primer plano, el checkUsage se ejecuta con WorkManager
  static void startService() {
    startForegroundService();
  }

  static Future<void> validateNotification() async {
    if (flutterLocalNotificationsPlugin == null) {
      await initialize();
    }

    // Verificar si la notificación sigue activa
    await flutterLocalNotificationsPlugin!
        .getActiveNotifications()
        .then((notifications) {
      if (notifications.isEmpty) {
        startForegroundService(); // Reinicia la notificación si no está activa
      }
    }).catchError((error) {
      print('Error al validar la notificación: $error');
    });
  }

  static const int alert1 = 240; //4horas
  static const int alert2 = 360; // 6 horas
  static const int alert3 = 480; // 8 horas

  // Método que ejecuta la tarea de monitoreo de uso
  static Future<void> checkUsage() async {
    try {
      tz.initializeTimeZones(); // Inicializar las zonas horarias
      await validateNotification();

      // Verificar y reiniciar alertas diariamente
      await resetDailyNotifications();

      final location = tz.getLocation('America/Guayaquil');
      final now = tz.TZDateTime.now(location);
      // Verificar si la hora está dentro del rango 23:30 a 23:50
      if (isWithinReportTime(now)) {
        await logReportTime(); // Llamar a la función de reporte
      }

      // Implementar la lógica de checkUsage
      print('***************************************************');
      SharedPreferences prefs = await SharedPreferences.getInstance();

      // Obtener el email desde SharedPreferences
      String? email = prefs.getString('email');
      if (email == null) {
        print('Email no encontrado en SharedPreferences.');
        return; // Si no hay email guardado, no se ejecuta el resto del proceso
      }

      // Obtener el tiempo total de uso de las apps
      int totalUsageTime =
          await UsageService.getTotalUsageToday() ~/ (60 * 1000);

      // Procesar alertas de manera independiente
      await _processAlerts(prefs, totalUsageTime, email);

      // Reiniciar el estado diariamente si es necesario
      await _resetDailyStateIfNeeded(prefs);

      print(
          '*** CheckUsage ejecutado: $now ***: Tiempo de uso total de pantalla: ${totalUsageTime} minutos');
    } catch (e) {
      print('Error en checkUsage: $e');
    }
  }

  static Future<void> _processAlerts(
      SharedPreferences prefs, int totalUsageTime, String email) async {
    try {
      // Verificar si ya se han enviado las notificaciones hoy
      bool hasNotified4Hours = prefs.getBool('hasNotified4Hours') ?? false;
      bool hasNotified6Hours = prefs.getBool('hasNotified6Hours') ?? false;
      bool hasNotified8Hours = prefs.getBool('hasNotified8Hours') ?? false;

      // Alerta 4 horas
      if (totalUsageTime >= alert1 && !hasNotified4Hours) {
        await sendNotificationWithServerData(
            "¿Qué tal si tomas un descanso y pruebas esta actividad relajante?",
            email,
            totalUsageTime);
        prefs.setBool('hasNotified4Hours', true);
        print("**ALERTA**: Alerta 4 Horas enviada");
      }

      // Alerta 6 horas
      if (totalUsageTime >= alert2 && !hasNotified6Hours) {
        await sendNotificationWithServerData(
            "¡Prueba esta alternativa!", email, totalUsageTime);
        prefs.setBool('hasNotified6Hours', true);
        print("**ALERTA**: Alerta 6 Horas enviada");
      }

      // Alerta 8 horas
      if (totalUsageTime >= alert3 && !hasNotified8Hours) {
        await sendNotificationWithServerData(
            "Es importante desconectarse un poco. Aquí tienes una idea para recargar energías:",
            email,
            totalUsageTime);
        prefs.setBool('hasNotified8Hours', true);
        print("**ALERTA**: Alerta 8 Horas enviada");
      }
    } catch (e) {
      print('Error procesando alertas: $e');
    }
  }

  static Future<void> _resetDailyStateIfNeeded(SharedPreferences prefs) async {
    try {
      DateTime lastReset = DateTime.parse(
          prefs.getString('lastReset') ?? DateTime.now().toIso8601String());
      if (DateTime.now().difference(lastReset).inDays >= 1) {
        prefs.setBool('hasNotified4Hours', false);
        prefs.setBool('hasNotified6Hours', false);
        prefs.setBool('hasNotified8Hours', false);
        prefs.setString('lastReset', DateTime.now().toIso8601String());
        print("Estados de notificaciones reiniciados para un nuevo día.");
      }
    } catch (e) {
      print('Error al reiniciar el estado diario: $e');
    }
  }

// Método para reiniciar las notificaciones diarias
  static Future<void> resetDailyNotifications() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Verificar si es un nuevo día
    String? lastResetDate = prefs.getString('lastReset');
    DateTime now = DateTime.now();
    DateTime lastReset = lastResetDate != null
        ? DateTime.parse(lastResetDate)
        : now.subtract(const Duration(days: 1));

    if (now.difference(lastReset).inDays >= 1) {
      // Reiniciar estados de notificaciones
      await prefs.setBool('hasNotified4Hours', false);
      await prefs.setBool('hasNotified6Hours', false);
      await prefs.setBool('hasNotified8Hours', false);
      await prefs.setString('lastReset', now.toIso8601String());
      print("Estados de notificaciones reiniciados para un nuevo día.");
    }
  }

  // Función que verifica si la hora actual está dentro del rango de reporte
  static bool isWithinReportTime(DateTime now) {
    DateTime startRange = DateTime(now.year, now.month, now.day, 23, 30);
    DateTime endRange = DateTime(now.year, now.month, now.day, 23, 55);

    return now.isAfter(startRange) && now.isBefore(endRange);
  }

  // Lógica adicional al detectar el horario de reporte
  static Future<void> logReportTime() async {
    print(
        '*** HORA de reporte diario detectado ***. Enviando reporte al servidor ... ');
    await callback(); // Llamar a la función callback
  }

  // Función para enviar el reporte al servidor con reintentos y manejo de errores
  @pragma('vm:entry-point')
  static Future<void> callback() async {
    await initialize();

    // Recuperar datos pendientes
    await sendPendingData();

    // Procesar y enviar el reporte actual
    int retryCount = 0;
    while (retryCount < maxRetries) {
      try {
        await sendReport();
        return; // Salir si el envío es exitoso
      } catch (error) {
        retryCount++;
        print('Error al enviar el reporte. Intento $retryCount: $error');
      }
    }

    // Si todos los intentos fallan, guardar localmente
    print('No se pudo enviar el reporte después de $maxRetries intentos.');
    await saveDataLocally(await prepareCurrentData());
  }

  // Envía el reporte actual al servidor
  static Future<void> sendReport() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    email = prefs.getString('email') ?? '**';

    DateTime currentDate = DateTime.now();
    final location = tz.getLocation('America/Guayaquil');
    final currentTZDate = tz.TZDateTime.now(location);
    String formattedDate =
        DateFormat('yyyy-MM-dd / HH:mm').format(currentTZDate);

    String mostHour = await UsageService.getMostActiveHour(currentDate);

    // Preparar datos actuales
    List<UsageInfo> usageInfoList = await initUsage(currentDate);
    List<Map<String, dynamic>> dataToSend =
        await _prepareUsageData(usageInfoList);

    // Verificar conexión a Internet
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.none) {
      throw Exception('Sin conexión a Internet');
    }

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

    if (response.statusCode != 200) {
      throw Exception(
          'Error en la respuesta del servidor: ${response.statusCode}');
    }

    print('Reporte enviado exitosamente.');
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
  }

  // Guardar datos localmente
  static Future<void> saveDataLocally(Map<String, dynamic> data) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> pendingReports =
        prefs.getStringList('pendingReports') ?? <String>[];
    pendingReports.add(jsonEncode(data));
    await prefs.setStringList('pendingReports', pendingReports);
    print('Datos guardados localmente para reenvío posterior.');
  }

  // Enviar datos pendientes almacenados localmente
  static Future<void> sendPendingData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> pendingReports =
        prefs.getStringList('pendingReports') ?? <String>[];

    if (pendingReports.isEmpty) {
      print('No hay datos pendientes para enviar.');
      return;
    }

    print('Enviando datos pendientes...');
    for (String report in pendingReports) {
      try {
        Map<String, dynamic> data = jsonDecode(report);
        var url = Uri.parse('https://ingsoftware.ucuenca.edu.ec/enviar-datos');
        var response = await http.post(
          url,
          body: data,
        );

        if (response.statusCode == 200) {
          print('Reporte pendiente enviado exitosamente.');
          pendingReports.remove(report);
        } else {
          throw Exception('Error al enviar reporte pendiente.');
        }
      } catch (error) {
        print('Error al enviar reporte pendiente: $error');
      }
    }

    await prefs.setStringList('pendingReports', pendingReports);
  }

  // Preparar datos actuales para guardar o enviar
  static Future<Map<String, dynamic>> prepareCurrentData() async {
    DateTime currentDate = DateTime.now();
    String formattedDate = DateFormat('yyyy-MM-dd / HH:mm').format(currentDate);
    String mostHour = await UsageService.getMostActiveHour(currentDate);

    List<UsageInfo> usageInfoList = await initUsage(currentDate);
    List<Map<String, dynamic>> dataToSend =
        await _prepareUsageData(usageInfoList);

    return {
      'email': email,
      'fecha': formattedDate,
      'mayorConsumo': UsageService.mayorConsumoVector.toString(),
      'usageData': jsonEncode(dataToSend),
    };
  }

  // Otros métodos auxiliares como initUsage, _prepareUsageData, saveDataLocally
  static Future<List<UsageInfo>> initUsage(DateTime date) async {
    List<UsageInfo> usageInfoList = [];
    List<int> mayorConsumo =
        List.filled(8, 0); // Vector inicializado con ceros.
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
              mayorConsumo[rangeIndex] +=
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
    } catch (err) {
      print("Error: $err");
    }
    // Retornar el vector mayorConsumo para ser usado en otra función
    UsageService.mayorConsumoVector =
        mayorConsumo; // Almacenar en un campo estático de la clase
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

  // deben ser definidos aquí según tu implementación actual

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

        // // Definir estilo de la notificación para expandirla
        // BigTextStyleInformation bigTextStyleInformation =
        //     BigTextStyleInformation(
        //   serverMessage, // Texto devuelto por el servidor
        //   contentTitle: dynamicTitle, // El título que se muestra
        //   summaryText:
        //       "Despliega para ver actividad:", // Texto resumido cuando está colapsada
        //   htmlFormatBigText: true, // Permitir formato HTML si es necesario
        //   htmlFormatContentTitle: true,
        //   htmlFormatSummaryText: true,
        // );

        // // Mostrar notificación con el mensaje del servidor
        // AndroidNotificationDetails androidPlatformChannelSpecifics =
        //     AndroidNotificationDetails(
        //   'your_channel_id',
        //   'Uso del Teléfono',
        //   channelDescription:
        //       'Notificaciones relacionadas con el uso del teléfono',
        //   importance: Importance.max,
        //   priority: Priority.high,
        //   ticker: 'ticker',
        //   styleInformation: bigTextStyleInformation,
        //   enableLights: true,
        //   ledColor: progressColor, // Cambiar el color del LED según el tiempo
        //   ledOnMs: 1000,
        //   ledOffMs: 500,
        //   showProgress: true,
        //   maxProgress: 100, // El progreso máximo será 100%
        //   progress: progress, // El progreso actual
        //   color: progressColor, // Cambiar el color de la notificación
        //   icon: '@drawable/ic_notification',
        //   visibility: NotificationVisibility
        //       .public, // Mostrar contenido en la pantalla de bloqueo
        //   autoCancel: true, // Se cancela cuando el usuario toca la notificación
        //   colorized:
        //       true, // Esta línea asegura que el color personalizado se use
        // );
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
}
