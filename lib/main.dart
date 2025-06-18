import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/welcome_screen.dart';
import 'screens/user_preferences_screen.dart';
import 'screens/my_app.dart';
import 'package:workmanager/workmanager.dart';
import 'dart:ui';
import 'services/background_service.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:ciara/services/usage_monitoring_service.dart';

// Método para manejar optimización de batería
Future<void> checkBatteryOptimizationStatus() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool? isBatteryOptimizationDisabled =
      prefs.getBool('batteryOptimizationDisabled');

  if (isBatteryOptimizationDisabled == null || !isBatteryOptimizationDisabled) {
    openBatteryOptimizationSettings();
  }
}

Future<void> openBatteryOptimizationSettings() async {
  final intent = AndroidIntent(
    action: 'android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
  );

  try {
    bool? canResolve = await intent.canResolveActivity();
    if (canResolve == true) {
      await intent.launch();
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('batteryOptimizationDisabled', true);
    } else {
      print('No se pudo abrir la configuración de optimización de batería.');
    }
  } catch (e) {
    print('Error al abrir la configuración de optimización de batería: $e');
  }
}

// TAREA B: Método que será llamado por WorkManager cada 15 minutos
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await UsageMonitoringService
          .checkUsage(); // Ejecuta la tarea de monitoreo de uso
      return Future.value(true);
    } catch (e) {
      print("Error en la tarea de WorkManager: $e");
      return Future.value(false);
    }
  });
}

void main() async {
  // Asegurarse de que Flutter esté inicializado antes de cualquier operación
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar el WorkManager
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

  // Inicializar AndroidAlarmManager
  // await AndroidAlarmManager.initialize();

  // BackgroundService.scheduleDailyAlarms();

  // Registrar una tarea periódica con WorkManager cada 15 minutos
  Workmanager().registerPeriodicTask(
    "checkUsageTask",
    "checkDailyUsage",
    frequency: Duration(minutes: 15),
    initialDelay: Duration(minutes: 1), // Ajusta si deseas un retraso inicial
    existingWorkPolicy: ExistingWorkPolicy.keep, // Mantener tareas previas
    constraints: Constraints(
      networkType: NetworkType.connected, // Requiere conexión a Internet
      requiresBatteryNotLow: false, // Se puede ejecutar con batería baja
      requiresCharging: false, // No necesita estar cargando
      requiresDeviceIdle:
          false, // Puede ejecutarse mientras el dispositivo está en uso
    ),
  );

  // Verificar y desactivar optimización de batería si es necesario
  await checkBatteryOptimizationStatus();

  // Iniciar servicio en primer plano
  await UsageMonitoringService.startForegroundService();

  // Mostrar la pantalla de carga inmediatamente
  runApp(MyAppInitializer());

  // Inicializar el Isolate para tareas en segundo plano
  // initializeIsolate();
}

// Pantalla de carga que se muestra al iniciar la aplicación
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

// Esta clase inicializa la aplicación y muestra la pantalla de carga
class MyAppInitializer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: FutureBuilder(
        future: initializeApp(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return LoadingScreen(); // Mostrar pantalla de carga mientras se inicializan las dependencias
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

// Inicializar las dependencias críticas para el inicio de la aplicación
Future<Map<String, dynamic>> initializeApp() async {
  // Inicializar SharedPreferences
  SharedPreferences prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (e) {
    // Manejo del error
    print("Error al inicializar SharedPreferences: $e");
    rethrow; // Propagar el error o mostrar una pantalla de error
  }

  String? storedEmail = prefs.getString('email');
  bool? hasCompletedPreferences = prefs.getBool('hasCompletedPreferences');

  // Inicializar servicios no críticos en segundo plano
  // await initializeNonCriticalServices();

  return {
    'storedEmail': storedEmail,
    'hasCompletedPreferences': hasCompletedPreferences,
  };
}

// Inicializar servicios no críticos
Future<void> initializeNonCriticalServices() async {
  try {
    // await BackgroundService.registerUsageMonitoringTask();
  } catch (e) {
    print("Error al inicializar servicios no críticos: $e");
  }
}

// Determina qué pantalla mostrar después de la inicialización
class MyAppWithLoading extends StatelessWidget {
  final String? storedEmail;
  final bool? hasCompletedPreferences;

  MyAppWithLoading({this.storedEmail, this.hasCompletedPreferences});

  @override
  Widget build(BuildContext context) {
    Widget homeScreen;

    if (storedEmail == null) {
      homeScreen =
          WelcomeScreen(); // Pantalla de bienvenida si no se ha iniciado sesión
    } else if (hasCompletedPreferences == true) {
      homeScreen = MyApp(
          email:
              storedEmail!); // Pantalla principal si el usuario ya configuró preferencias
    } else {
      homeScreen =
          UserPreferencesScreen(); // Pantalla de configuración de preferencias si no ha terminado
    }

    return homeScreen;
  }
}
