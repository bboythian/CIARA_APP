import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:usage_stats/usage_stats.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:device_apps/device_apps.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
// import 'utils/time_utils.dart';

class MyApp extends StatefulWidget {
  final String email;
  MyApp({required this.email});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String email = '';
  List<UsageInfo> usageInfoList = [];
  int _currentIndex = 0;
  bool notificationEnabled = false;
  bool alternativasEnabled = false;
  bool sugerenciasEnabled = false;
  DateTime currentDate = DateTime.now();
  late DateTime startDate;
  late DateTime endDate;

  String _mostActiveHour = '';
  List<Map<String, dynamic>> _usageData = [];
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  void configureLocalNotificationPlugin() {
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const androidInitializationSettings =
        AndroidInitializationSettings('ic_notificacion');
    const initializationSettings =
        InitializationSettings(android: androidInitializationSettings);
    flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  @override
  void initState() {
    super.initState();
    configureLocalNotificationPlugin();
    _getMostActiveHour(currentDate);
    //requestPermissions();
    initUsage(currentDate);
    getCedula();

    Timer.periodic(Duration(minutes: 5), (Timer timer) {
      initUsage(currentDate);
    });
    // Programar la tarea en segundo plano
    _scheduleAlarm();
  }

  Future<void> requestPermissions() async {
    if (await Permission.storage.request().isGranted) {
      print('Storage permission granted');
    } else {
      print('Storage permission denied');
    }
  }

  Future<void> initUsage(DateTime date) async {
    try {
      bool? isGranted = await UsageStats.checkUsagePermission();
      if (!isGranted!) {
        await UsageStats.grantUsagePermission();
      }
      DateTime startDate =
          DateTime(date.year, date.month, date.day, 0, 0, 0, 0, 1);
      DateTime endDate =
          DateTime(date.year, date.month, date.day, 23, 59, 59, 999, 999);
      // print('Hora init start: ${startDate.toIso8601String()}');
      // print('Hora init end: $endDate');
      List<EventUsageInfo> events =
          await UsageStats.queryEvents(startDate, endDate);

      if (events.isEmpty) {
        print(
            'No se encontraron eventos de uso en el rango de tiempo especificado.');
      } else {
        // print('Eventos obtenidos:');
        for (var event in events) {
          DateTime eventTime =
              DateTime.fromMillisecondsSinceEpoch(int.parse(event.timeStamp!));
          // print('App: ${event.packageName}, EventType: ${event.eventType}, TimeStamp: ${eventTime.toIso8601String()}');
        }
      }

      Map<String, int> usageByApp = {};
      Map<String, int> foregroundTimes = {};

      for (var event in events) {
        DateTime eventTime =
            DateTime.fromMillisecondsSinceEpoch(int.parse(event.timeStamp!));
        String packageName = event.packageName ?? 'Unknown';

        if (event.eventType == "1") {
          // MOVE_TO_FOREGROUND
          foregroundTimes[packageName] = eventTime.millisecondsSinceEpoch;
        } else if (event.eventType == "2") {
          // MOVE_TO_BACKGROUND
          if (foregroundTimes.containsKey(packageName)) {
            int foregroundTime = eventTime.millisecondsSinceEpoch -
                foregroundTimes[packageName]!;
            usageByApp[packageName] =
                (usageByApp[packageName] ?? 0) + foregroundTime;
            foregroundTimes.remove(packageName);
          } else {
            // print( 'WARNING: Background event without a corresponding foreground event for $packageName');
          }
        }
      }

      // Clear any remaining foregroundTimes entries as they have no matching background event
      foregroundTimes.forEach((packageName, timestamp) {
        print(
            'WARNING: Foreground event without a corresponding background event for $packageName');
      });

      int totalTimeInMilliseconds =
          usageByApp.values.fold(0, (sum, element) => sum + element);
      int totalMinutes = (totalTimeInMilliseconds / 60000).floor();

      print("Tiempo total de uso: $totalMinutes minutos");

      if (totalMinutes >= 87) {
        // 240 minutos = 4 horas
        _showNotification(
            "Haz consumido el teléfono celular por 4 horas, considera descansar");
      }
      // Lista de nombres de paquetes a excluir
      List<String> excludedPackages = [
        'com.oppo.launcher',
        'otro.paquete1',
        'otro.paquete2'
      ];

      List<UsageInfo> usageInfoList = [];

      for (var app in usageByApp.keys) {
        int totalTimeInMilliseconds = usageByApp[app]!;

        if (!excludedPackages.contains(app) &&
            totalTimeInMilliseconds >= 60000) {
          int seconds = (totalTimeInMilliseconds / 1000).floor();
          int minutes = (seconds / 60).floor();
          int hours = (minutes / 60).floor();
          minutes = minutes % 60;
          seconds = seconds % 60;

          print('App: $app');
          print('Total Time in Foreground: ${hours}h ${minutes}m ${seconds}s');

          usageInfoList.add(
            UsageInfo(
              packageName: app,
              totalTimeInForeground: '$hours h $minutes m $seconds s',
            ),
          );
        }
      }

      setState(() {
        this.usageInfoList = usageInfoList;
      });
    } catch (err) {
      print("Error: $err");
    }
  }

  void _showNotification(String message) {
    var androidDetails = const AndroidNotificationDetails(
        "channelId",
        "Local Notification",
        "This is the description of the Notification, you can write anything",
        importance: Importance.high);
    var generalNotificationDetails =
        NotificationDetails(android: androidDetails);

    flutterLocalNotificationsPlugin.show(
        0, "Alerta de uso excesivo", message, generalNotificationDetails);
  }

  void callback() {
    print('Callback iniciado');
    _refresh();
    print('Callback ejecutado');
  }

  Future<void> _refresh() async {
    print("Función _refresh ejecutada");
    await initUsage(currentDate); // Pasar la fecha actualizada a initUsage
    final location =
        tz.getLocation('America/Guayaquil'); // Ajusta a tu zona horaria
    final currentTZDate = tz.TZDateTime.now(location);
    String formattedDate =
        DateFormat('yyyy-MM-dd / HH:mm').format(currentTZDate);

    String mostHour = _mostActiveHour;
    // Ordena la lista por totalTimeInForeground de mayor a menor
    usageInfoList.sort((a, b) => _convertTimeToMinutes(b.totalTimeInForeground)
        .compareTo(_convertTimeToMinutes(a.totalTimeInForeground)));
    // Toma los primeros 5 elementos después de ordenar
    List<UsageInfo> firstFiveUsageInfo = usageInfoList.take(5).toList();

    List<Map<String, dynamic>> dataToSend =
        await Future.wait(firstFiveUsageInfo.map((info) async {
      return {
        'packageName': await getAppNameFromPackageName(info.packageName!),
        'totalTimeInForeground':
            _convertTimeToMinutes(info.totalTimeInForeground),
      };
    }).toList());

    // Imprimir las fechas con las que se envían los datos a la API
    print('Fecha actual: $formattedDate');
    print('Mayor consumo en la hora: $mostHour');
    print('Datos de uso: $dataToSend');

    try {
      var url = Uri.parse('http://10.24.160.183:8081/enviar-datos');
      var response = await http.post(
        url,
        body: {
          'email': widget.email,
          'fecha': formattedDate,
          'mayorConsumo': mostHour,
          'usageData': jsonEncode(dataToSend),
        },
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
    } catch (error) {
      print('Error al enviar los datos: $error');
    }

    _showNotification("Datos enviados al server");
  }

  // void _scheduleAlarm() async {
  //   // Programar el Alarm Manager para ejecutar cada día a una hora específica
  //   final int alarmID = 0;
  //   DateTime now = DateTime.now();
  //   // DateTime scheduledTime =
  //   //     DateTime(now.year, now.month, now.day, 15, 0); // 3:00 PM
  //   DateTime scheduledTime = now.add(Duration(minutes: 2));
  //   if (now.isAfter(scheduledTime)) {
  //     scheduledTime = scheduledTime.add(Duration(days: 1));
  //   }
  //   await AndroidAlarmManager.oneShotAt(
  //     scheduledTime,
  //     alarmID,
  //     callback,
  //     exact: true,
  //     wakeup: true,
  //   );
  //   print('Alarm programado para: $scheduledTime');
  // }
  void _scheduleAlarm() async {
    // Obtener la zona horaria de Ecuador
    final location = tz.getLocation('America/Guayaquil');

    // Obtener la hora actual en la zona horaria de Ecuador
    final now = tz.TZDateTime.now(location);

    // Programar la alarma para las 9:10 AM hora de Ecuador
    final scheduledTime =
        tz.TZDateTime(location, now.year, now.month, now.day, 9, 10);

    // Si la hora programada ya pasó hoy, programarla para mañana
    final nextScheduledTime = scheduledTime.isBefore(now)
        ? scheduledTime.add(Duration(days: 1))
        : scheduledTime;

    print('Alarm programado para: $nextScheduledTime');

    await AndroidAlarmManager.oneShotAt(
      nextScheduledTime,
      0,
      callback,
      exact: true,
      wakeup: true,
    );
  }

  int _convertTimeToMinutes(String? time) {
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

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    Navigator.pop(context);
  }

  void _updateDate(int days) {
    setState(() {
      currentDate = currentDate.add(Duration(days: days));
      print('Hora update1:  ${currentDate.toIso8601String()}');
      if (currentDate.isAfter(DateTime.now().toLocal())) {
        currentDate = DateTime.now().toLocal();
      } else if (currentDate
          .isBefore(DateTime.now().toLocal().subtract(Duration(days: 30)))) {
        currentDate = DateTime.now().toLocal().subtract(Duration(days: 30));
      }
      usageInfoList.clear();
    });
    print('Hora update2:  ${currentDate.toIso8601String()}');
    initUsage(currentDate); // Pasar la fecha actualizada a initUsage
    _getMostActiveHour(currentDate);
  }

  //Construye el widget inicial general, navbar, menu desplegable
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(color: Colors.white),
        title: const Text(
          "CIARA",
          style: TextStyle(color: Colors.white, fontFamily: 'FFMetaProText2'),
        ),
        backgroundColor: Color(0xFF002856),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _refresh();
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFF002856),
              ),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 40,
                    backgroundImage: AssetImage('assets/images/icono.png'),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'Bienvenid@ a CIARA',
                    style: TextStyle(
                      fontFamily: 'FFMetaProText1',
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Usuario: ${email.split('@')[0]}',
                        style: const TextStyle(
                          fontFamily: 'FFMetaProText1',
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ListTile(
              title: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 0.0)
                      .add(const EdgeInsets.only(left: 2.0, right: 80.0)),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Color(0xFFA51008),
                        width: 3.0,
                      ),
                    ),
                  ),
                  child: const Text(
                    'Estadísticas de uso',
                    style: TextStyle(
                      fontFamily: 'FFMetaProText4',
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              onTap: () {
                _onTabTapped(0);
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              title: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 0.0)
                      .add(const EdgeInsets.only(left: 2.0, right: 120.0)),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Color.fromRGBO(165, 16, 8, 1.0),
                        width: 3.0,
                      ),
                    ),
                  ),
                  child: const Text(
                    'Notificaciones',
                    style: TextStyle(
                      fontFamily: 'FFMetaProText4',
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              onTap: () {
                _onTabTapped(1);
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              title: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 0.0)
                      .add(const EdgeInsets.only(left: 2.0, right: 180.0)),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Color(0xFFA51008),
                        width: 3.0,
                      ),
                    ),
                  ),
                  child: const Text(
                    'Ajustes',
                    style: TextStyle(
                      fontFamily: 'FFMetaProText4',
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              onTap: () {
                _onTabTapped(2);
              },
            ),
            const SizedBox(height: 280),
            Container(
              alignment: Alignment.bottomCenter,
              padding: const EdgeInsets.only(bottom: 8),
              child: const Text(
                'UCUENCA',
                style: TextStyle(
                  fontFamily: 'FFMetaProTitle',
                  color: Color(0xFF6F6F6F),
                  fontSize: 50,
                ),
              ),
            ),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _buildHome();
      case 1:
        return _buildNotificaciones();
      case 2:
        return _buildAjustes();
      default:
        return _buildHome();
    }
  }

  //Construye la vista inicial o home
  Widget _buildHome() {
    usageInfoList.sort((a, b) =>
        _convertTimeToMinutes(b.totalTimeInForeground) -
        _convertTimeToMinutes(a.totalTimeInForeground));

    return RefreshIndicator(
      onRefresh: _refresh,
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 10),
            const Text('Fecha reporte:',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'FFMetaProTitle')),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    _updateDate(-1);
                  },
                ),
                Text(
                  '${currentDate.toLocal()}'.split(' ')[0],
                  style: const TextStyle(fontSize: 18),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () {
                    _updateDate(1);
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    const Text('Hora de mayor uso:',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'FFMetaProTitle')),
                    const SizedBox(width: 8),
                    Text(
                      _mostActiveHour,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                          fontFamily: 'FFMetaProText1'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.only(left: 16.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Gráfica del tiempo de uso:',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'FFMetaProTitle')),
              ),
            ),
            SingleChildScrollView(
              child: _buildPieChart(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificaciones() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const Text(
            'Configuración de notificaciones',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          _buildNotificacionesList(),
        ],
      ),
    );
  }

  Widget _buildNotificacionesList() {
    return Expanded(
      child: ListView(
        children: [
          _buildNotificacionItem("Notificaciones", notificationEnabled),
          _buildNotificacionItem("Límites", sugerenciasEnabled),
          _buildNotificacionItem("Alertas", alternativasEnabled),
        ],
      ),
    );
  }

  Widget _buildNotificacionItem(String itemName, bool itemEnabled) {
    return Dismissible(
      key: Key(itemName),
      onDismissed: (direction) {
        print("$itemName deslizado en dirección $direction");
      },
      background: Container(
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Card(
        child: ListTile(
          title: Text(itemName),
          trailing: Switch(
            value: itemEnabled,
            onChanged: (value) {
              setState(() {
                if (itemName == "Notificaciones") {
                  notificationEnabled = value;
                } else if (itemName == "Sugerencias") {
                  sugerenciasEnabled = value;
                } else if (itemName == "Alternativas") {
                  alternativasEnabled = value;
                }
              });
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAjustes() {
    return const Center(
      child: Text('Página de Ajustes'),
    );
  }

  Widget _buildPieChart() {
    int totalTime = 0;
    usageInfoList.forEach((info) {
      totalTime += _convertTimeToMinutes(info.totalTimeInForeground);
    });

    List<Color> colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.yellow,
      Colors.grey,
    ];

    return FutureBuilder<List<String>>(
      future: getAppNames(usageInfoList),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator();
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else {
          List<String> appNames = snapshot.data!;
          List<String> displayAppNames = [];
          List<int> appTimes = [];
          for (int i = 0; i < usageInfoList.length && i < 6; i++) {
            UsageInfo appInfo = usageInfoList[i];
            displayAppNames.add(appNames[i]);
            appTimes.add(_convertTimeToMinutes(appInfo.totalTimeInForeground));
          }

          if (usageInfoList.length > 6) {
            int otrosTime = 0;
            for (int i = 6; i < usageInfoList.length; i++) {
              otrosTime +=
                  _convertTimeToMinutes(usageInfoList[i].totalTimeInForeground);
            }
            displayAppNames.add("Otros");
            appTimes.add(otrosTime);
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  height: 250,
                  child: Stack(
                    children: [
                      SfCircularChart(
                        series: <CircularSeries>[
                          PieSeries<Map<String, Object>, String>(
                            dataSource: List.generate(
                                displayAppNames.length,
                                (index) => {
                                      'name': displayAppNames[index],
                                      'time': appTimes[index],
                                    }),
                            xValueMapper: (Map<String, Object> data, _) =>
                                data['name'] as String,
                            yValueMapper: (Map<String, Object> data, _) =>
                                data['time'] as int,
                            pointColorMapper: (Map<String, Object> data, _) {
                              int index = displayAppNames
                                      .indexOf(data['name'] as String) %
                                  colors.length;
                              return colors[index];
                            },
                            dataLabelMapper: (Map<String, Object> data, _) =>
                                data['name'] as String,
                            dataLabelSettings: const DataLabelSettings(
                              isVisible: true,
                              textStyle: TextStyle(fontSize: 14),
                              labelPosition: ChartDataLabelPosition.outside,
                            ),
                          ),
                        ],
                      ),
                      Center(
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(
                              color: Colors.grey,
                              width: 5.0,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '${_formatTime(totalTime)}',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Text(
                  'Top aplicaciones más utilizadas:',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'FFMetaProTitle'),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const ScrollPhysics(),
                  itemCount: usageInfoList.length,
                  itemBuilder: (context, index) {
                    return _buildListTile(usageInfoList[index]);
                  },
                ),
              ],
            ),
          );
        }
      },
    );
  }

  //Construle la lista de Aplicaciones mas utilizadas
  Widget _buildListTile(UsageInfo appInfo) {
    return FutureBuilder<String>(
      future: getAppNameFromPackageName(appInfo.packageName!),
      builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
        String appName = appInfo.packageName!;
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData) {
          appName = snapshot.data!;
        }
        return ListTile(
          leading: getAppIcon(appInfo.packageName!),
          title: Text(appName),
          subtitle: Text(
            'Tiempo de uso: ${_formatTime(_convertTimeToMinutes(appInfo.totalTimeInForeground))}',
          ),
        );
      },
    );
  }

  Widget getAppIcon(String packageName) {
    return FutureBuilder<Application?>(
      future: getApplicationWithIcon(packageName),
      builder: (BuildContext context, AsyncSnapshot<Application?> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: 35,
            height: 35,
            child: CircularProgressIndicator(),
          );
        } else if (snapshot.hasError || !snapshot.hasData) {
          print('Error o sin datos para el paquete: $packageName');
          return Container(
            width: 35,
            height: 35,
            child: Image.asset('assets/images/icono.png'), // Icono por defecto
          );
        } else {
          Application? app = snapshot.data;
          if (app is ApplicationWithIcon) {
            // print('Icono cargado para el paquete: ${app.appName}');
            return Container(
              width: 35,
              height: 35,
              child: Image.memory(app.icon),
            );
          } else {
            print('Sin icono para el paquete: ${app?.appName}');
            return Container(
              width: 35,
              height: 35,
              child:
                  Image.asset('assets/images/icono.png'), // Icono por defecto
            );
          }
        }
      },
    );
  }

  // Funcion obtiene la cedula registrada anteriormente
  Future<void> getCedula() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      email = prefs.getString('email') ?? '**';
    });
  }

  Future<List<String>> getAppNames(List<UsageInfo> usageInfoList) async {
    List<String> appNames = [];
    for (var appInfo in usageInfoList) {
      String appName = await getAppNameFromPackageName(appInfo.packageName!);
      appNames.add(appName);
    }
    return appNames;
  }

  //Función para obtener el icono de la aplicación
  Future<Application?> getApplicationWithIcon(String packageName) async {
    try {
      Application? app = await DeviceApps.getApp(packageName, true);
      return app;
    } catch (e) {
      print('Error al obtener la aplicación con icono: $e');
      return null;
    }
  }

  // Future<void> _showNotification() async {
  //   // Tiempo de uso actual en minutos
  //   int currentUsageMinutes = 20; // 4:30 horas
  //   // Tiempo máximo de uso permitido en minutos
  //   int maxUsageMinutes = 720; // 12 horas

  //   // Calcular el porcentaje de uso
  //   int usagePercentage =
  //       ((currentUsageMinutes / maxUsageMinutes) * 100).toInt();

  //   // Configurar la notificación con barra de progreso
  //   final AndroidNotificationDetails androidPlatformChannelSpecifics =
  //       AndroidNotificationDetails(
  //     'your channel id',
  //     'your channel name',
  //     'your channel description',
  //     importance: Importance.max,
  //     priority: Priority.high,
  //     icon: 'ic_notificacion',
  //     showProgress: true,
  //     maxProgress: maxUsageMinutes,
  //     progress: currentUsageMinutes,
  //     indeterminate: false, // Indicar que la barra de progreso es determinante
  //   );

  //   final NotificationDetails platformChannelSpecifics =
  //       NotificationDetails(android: androidPlatformChannelSpecifics);

  //   await flutterLocalNotificationsPlugin.show(
  //     0,
  //     'Alerta de tiempo de uso:',
  //     'Has usado aplicaciones por más de 4:30 horas. Uso: $usagePercentage%',
  //     platformChannelSpecifics,
  //     payload: 'item x',
  //   );
  // }

  //Función para obtener el nombre de la aplicación
  Future<String> getAppNameFromPackageName(String packageName) async {
    try {
      Application? app = await DeviceApps.getApp(packageName);
      return app?.appName ?? packageName;
    } catch (e) {
      print("Error al obtener la aplicación '$packageName': $e");
      return packageName;
    }
  }

  //Funcion que obtiene la hora de mayor uso
  Future<void> _getMostActiveHour(DateTime date) async {
    try {
      // Imprimir la fecha enviada al método
      print('Fecha consumo mayor enviada: $date');

      DateTime endDate = DateTime(date.year, date.month, date.day, 23, 59, 59);
      DateTime startDate = DateTime(date.year, date.month, date.day, 0, 0, 0);

      List<UsageInfo> usageStats =
          await UsageStats.queryUsageStats(startDate, endDate);

      Map<int, int> usageByHour = {};
      Map<String, int> usageByApp = {};

      for (var info in usageStats) {
        if (info.firstTimeStamp != null && info.lastTimeStamp != null) {
          DateTime beginTime = DateTime.fromMillisecondsSinceEpoch(
              int.parse(info.firstTimeStamp!));
          DateTime endTime = DateTime.fromMillisecondsSinceEpoch(
              int.parse(info.lastTimeStamp!));
          int hour = beginTime.hour;

          int usageDuration = endTime.difference(beginTime).inMinutes;

          if (usageByHour.containsKey(hour)) {
            usageByHour[hour] = usageByHour[hour]! + usageDuration;
          } else {
            usageByHour[hour] = usageDuration;
          }

          if (usageByApp.containsKey(info.packageName)) {
            usageByApp[info.packageName!] =
                usageByApp[info.packageName]! + usageDuration;
          } else {
            usageByApp[info.packageName!] = usageDuration;
          }
        }
      }

      int maxUsageHour = usageByHour.keys.first;
      for (var hour in usageByHour.keys) {
        if (usageByHour[hour]! > usageByHour[maxUsageHour]!) {
          maxUsageHour = hour;
        }
      }

      setState(() {
        _mostActiveHour = '$maxUsageHour:00 - ${maxUsageHour + 1}:00';
        _usageData = usageByApp.entries
            .map((entry) => {
                  'packageName': entry.key,
                  'usageDuration': entry.value,
                })
            .toList();
      });
    } catch (e) {
      print('Error al obtener los datos de uso: $e');
    }
  }

  //Formatear el tiempo en minutos, horas
  String _formatTime(int minutes) {
    if (minutes < 60) {
      return '$minutes min';
    } else {
      int hours = minutes ~/ 60;
      int remainingMinutes = minutes % 60;
      return '$hours h $remainingMinutes min';
    }
  }
}