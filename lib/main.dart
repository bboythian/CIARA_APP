import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/welcome_screen.dart';
import 'screens/user_preferences_screen.dart';
import 'screens/my_app.dart';
import 'package:workmanager/workmanager.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'dart:isolate';
import 'dart:ui';
import 'services/background_service.dart';
import 'services/usage_monitoring_service.dart';
import 'package:permission_handler/permission_handler.dart';

const String isolateName = 'isolate';

void main() async {
  // Asegurarse de que Flutter esté inicializado antes de cualquier otra operación
  WidgetsFlutterBinding.ensureInitialized();

  // Solicitar permiso para ignorar la optimización de batería
  // if (await Permission.ignoreBatteryOptimizations.isDenied) {
  //   await openAppSettings(); // Abre la configuración de la app para que el usuario permita ignorar optimizaciones
  // }

  // if (await Permission.scheduleExactAlarm.isDenied) {
  //   await openAppSettings(); // Abre la configuración de la app para que el usuario conceda el permiso
  // }
  // Inicializa AndroidAlarmManager
  await AndroidAlarmManager.initialize();
  // Programa la alarma diaria
  // Iniciar el servicio en primer plano
  UsageMonitoringService.startService();

  if (await Permission.ignoreBatteryOptimizations.isDenied) {
    await openAppSettings(); // Abrir configuración para que el usuario permita ignorar optimizaciones
  }

  await BackgroundService
      .scheduleDailyAlarms(); // Llama al método que programa la tarea diaria

  // Inicializar el WorkManager y el Android Alarm Manager
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

  // Iniciar la tarea periódica cada 15 minutos con WorkManager
  Workmanager().registerPeriodicTask(
    "checkUsageTask", // Nombre único de la tarea
    "checkDailyUsage", // Nombre de la tarea que ejecutará el método checkUsage
    frequency: Duration(minutes: 15), // Intervalo de 15 minutos
    initialDelay: Duration(minutes: 1), // Delay inicial antes de comenzar
    existingWorkPolicy: ExistingWorkPolicy.keep, // Evita sobrescribir tareas
    constraints: Constraints(
      networkType: NetworkType.not_required, // Ejecutar incluso sin internet
      requiresBatteryNotLow: false, // Ejecutar incluso con batería baja
    ),
  );

  // Mostrar la pantalla de carga inmediatamente
  runApp(MyAppInitializer());

  // Inicializar el Isolate para tareas en segundo plano después de que la app esté completamente cargada
  // initializeIsolate();
}

// @pragma('vm:entry-point')
// void callbackDispatcher() {
//   Workmanager().executeTask((task, inputData) async {
//     try {
//       await BackgroundService.checkUsage();
//       return Future.value(true); // Marca la tarea como completada
//     } catch (e) {
//       print("Error en la tarea de WorkManager: $e");
//       return Future.value(false); // Marca la tarea como fallida
//     }
//   });
// }
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    await UsageMonitoringService.checkUsage();
    return Future.value(true);
  });
}

// Pantalla de carga que se muestra inmediatamente al iniciar la aplicación
class LoadingScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            color: Colors.black.withOpacity(0.5), // Fondo opaco
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      color: Colors.white, // Color del indicador
                      strokeWidth: 8, // Grosor del indicador
                    ),
                  ),
                  SizedBox(height: 14),
                  Text(
                    'Cargando...',
                    style: TextStyle(
                      fontSize: 18,
                      fontFamily: 'FFMetaProText2',
                      color: Colors.white, // Color del texto
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Esta clase muestra la pantalla de carga mientras las dependencias principales se inicializan
class MyAppInitializer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: FutureBuilder(
        future: initializeApp(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return LoadingScreen();
          } else if (snapshot.hasError) {
            return Scaffold(
              body: Center(child: Text('Error al cargar la aplicación')),
            );
          } else {
            final Map<String, dynamic> data =
                snapshot.data as Map<String, dynamic>;
            return MyAppWithLoading(
              storedEmail: data['storedEmail'],
              hasCompletedPreferences: data['hasCompletedPreferences'],
            );
          }
        },
      ),
      theme: ThemeData(
        primarySwatch: Colors.blue,
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Color(0xFF002856),
          selectionColor: Color(0xFF002856),
          selectionHandleColor: Color(0xFF002856),
        ),
      ),
    );
  }
}

// Inicializar las dependencias críticas para el inicio
Future<Map<String, dynamic>> initializeApp() async {
  final stopwatch = Stopwatch()..start();

  // Inicializar SharedPreferences
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? storedEmail = prefs.getString('email');
  bool? hasCompletedPreferences = prefs.getBool('hasCompletedPreferences');

  // Inicializar servicios no críticos
  await initializeNonCriticalServices();

  return {
    'storedEmail': storedEmail,
    'hasCompletedPreferences': hasCompletedPreferences,
  };
}

// Inicializar dependencias no críticas en segundo plano
Future<void> initializeNonCriticalServices() async {
  try {
    await BackgroundService.registerUsageMonitoringTask();
  } catch (e) {
    print("Error al inicializar servicios no críticos: $e");
  }
}

// Determinar qué pantalla mostrar después de la inicialización
class MyAppWithLoading extends StatelessWidget {
  final String? storedEmail;
  final bool? hasCompletedPreferences;

  MyAppWithLoading({this.storedEmail, this.hasCompletedPreferences});

  @override
  Widget build(BuildContext context) {
    Widget homeScreen;

    if (storedEmail == null) {
      homeScreen = WelcomeScreen();
    } else if (hasCompletedPreferences == true) {
      homeScreen = MyApp(email: storedEmail!);
    } else {
      homeScreen = UserPreferencesScreen();
    }

    return homeScreen;
  }
}

// Inicializar el Isolate para tareas de fondo
void initializeIsolate() {
  final ReceivePort port = ReceivePort();
  final isRegistered = IsolateNameServer.lookupPortByName(isolateName);

  if (isRegistered == null) {
    IsolateNameServer.registerPortWithName(port.sendPort, isolateName);
  }

  port.listen((dynamic data) {
    debugPrint("Isolate received: $data");
  });
}
