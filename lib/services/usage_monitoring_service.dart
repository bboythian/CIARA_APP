import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ciara/services/usage_service.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class UsageMonitoringService {
  static FlutterLocalNotificationsPlugin? flutterLocalNotificationsPlugin;
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

  // Inicializa el servicio en primer plano con una notificación persistente
  // static Future<void> startForegroundService() async {
  //   if (flutterLocalNotificationsPlugin == null) {
  //     flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  //     const androidInitializationSettings = AndroidInitializationSettings(
  //         'ic_notificacion'); // Icono personalizado
  //     const initializationSettings =
  //         InitializationSettings(android: androidInitializationSettings);

  //     await flutterLocalNotificationsPlugin!.initialize(initializationSettings);
  //   }

  //   // Mostrar una notificación persistente
  //   const androidPlatformChannelSpecifics = AndroidNotificationDetails(
  //     'usage_monitoring_channel',
  //     'Monitoreo de Uso',
  //     channelDescription: 'Servicio de monitoreo de uso de aplicaciones',
  //     importance: Importance.max,
  //     priority: Priority.high,
  //     ongoing: true, // Hace la notificación persistente
  //   );

  //   const platformChannelSpecifics =
  //       NotificationDetails(android: androidPlatformChannelSpecifics);

  //   await flutterLocalNotificationsPlugin!.show(
  //     0,
  //     'Monitoreo Activo',
  //     'El monitoreo del uso de aplicaciones está en ejecución',
  //     platformChannelSpecifics,
  //   );
  // }
  static Future<void> startForegroundService() async {
    if (flutterLocalNotificationsPlugin == null) {
      flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      const androidInitializationSettings =
          AndroidInitializationSettings('ic_notificacion');
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

  // Iniciar el servicio en primer plano y ejecutar checkUsage cada 15 minutos
  // static void startService() {
  //   startForegroundService();

  //   // Usar AndroidAlarmManager para ejecutar cada 15 minutos
  //   AndroidAlarmManager.periodic(const Duration(minutes: 15), 0, checkUsage,
  //       wakeup: true, allowWhileIdle: true);
  // }

  // Este método reemplaza al uso de AndroidAlarmManager
  // Iniciar el servicio en primer plano, el checkUsage se ejecuta con WorkManager
  static void startService() {
    startForegroundService();
  }

  static const int alert1 = 60;
  static const int alert2 = 90;
  static const int alert3 = 120;

  // Método que ejecuta la tarea de monitoreo de uso
  static Future<void> checkUsage() async {
    tz.initializeTimeZones(); // Inicializar las zonas horarias
    // Implementar la lógica de checkUsage
    print('Ejecutando checkUsage...');
    // Aquí colocar la lógica de monitoreo de uso
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
    final location = tz.getLocation('America/Guayaquil');
    final now = tz.TZDateTime.now(location);
    print('*Hora del check:* $now');
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
