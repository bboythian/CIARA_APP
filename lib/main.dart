import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/welcome_screen.dart';
import 'screens/user_preferences_screen.dart';
import 'screens/my_app.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:workmanager/workmanager.dart';
import 'dart:isolate';
import 'dart:ui';
import 'services/background_service.dart';

const String isolateName = 'isolate';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar el WorkManager y el Android Alarm Manager
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
  await AndroidAlarmManager.initialize();

  // Mostrar la pantalla de carga inmediatamente
  runApp(MyAppInitializer());

  // Inicializar el Isolate para tareas de fondo
  initializeIsolate();
}

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    await BackgroundService.checkUsage(); // Monitorea el uso del teléfono
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

  // Inicializar zonas horarias
  tz.initializeTimeZones();

  // Inicializar servicios no críticos
  initializeNonCriticalServices();

  return {
    'storedEmail': storedEmail,
    'hasCompletedPreferences': hasCompletedPreferences,
  };
}

// Inicializar dependencias no críticas en segundo plano
Future<void> initializeNonCriticalServices() async {
  await BackgroundService.registerUsageMonitoringTask();
  // await AndroidAlarmManager.periodic(
  //   const Duration(minutes: 15), // Monitorear cada 15 minutos
  //   0,
  //   BackgroundService.checkUsage, // Monitorear uso de pantalla
  //   exact: true,
  //   wakeup: true,
  // );
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

// Inicializa el isolate para tareas de fondo
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
