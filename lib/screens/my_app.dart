import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:usage_stats/usage_stats.dart';
import 'dart:async';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:device_apps/device_apps.dart';
import 'package:url_launcher/url_launcher.dart';

class MyApp extends StatefulWidget {
  final String email;
  MyApp({required this.email});

  @override
  _MyAppState createState() => _MyAppState();

  static Future<void> callback() async {
    tz.initializeTimeZones();
  }
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
  static late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  @override
  void initState() {
    super.initState();
    configureLocalNotificationPlugin();
    tz.initializeTimeZones();
    _getMostActiveHour(currentDate);
    initUsage(currentDate);
    getCedula();

    Timer.periodic(Duration(minutes: 5), (Timer timer) {
      initUsage(currentDate);
    });
    // _scheduleDailyAlarm();
  }

  void configureLocalNotificationPlugin() {
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const androidInitializationSettings =
        AndroidInitializationSettings('ic_notificacion0');
    const initializationSettings =
        InitializationSettings(android: androidInitializationSettings);
    flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _refresh() async {
    print("Función _refresh ejecutada");
    await initUsage(currentDate);

    final location = tz.getLocation('America/Guayaquil');
    final currentTZDate = tz.TZDateTime.now(location);
    String formattedDate =
        DateFormat('yyyy-MM-dd / HH:mm').format(currentTZDate);

    String mostHour = _mostActiveHour;

    usageInfoList.sort((a, b) => _convertTimeToMinutes(b.totalTimeInForeground)
        .compareTo(_convertTimeToMinutes(a.totalTimeInForeground)));
    List<UsageInfo> firstFiveUsageInfo = usageInfoList.take(5).toList();

    List<Map<String, dynamic>> dataToSend =
        await Future.wait(firstFiveUsageInfo.map((info) async {
      return {
        'packageName': await getAppNameFromPackageName(info.packageName!),
        'totalTimeInForeground':
            _convertTimeToMinutes(info.totalTimeInForeground),
      };
    }).toList());
    print('Fecha actual: $formattedDate');
    print('Mayor consumo en la hora: $mostHour');
    print('Datos de uso: $dataToSend');
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
      List<EventUsageInfo> events =
          await UsageStats.queryEvents(startDate, endDate);
      int totalTimeAfterFiltering =
          0; // Variable para almacenar el tiempo total después de la filtración

      if (events.isEmpty) {
        print(
            'No se encontraron eventos de uso en el rango de tiempo especificado.');
      } else {
        for (var event in events) {
          DateTime eventTime =
              DateTime.fromMillisecondsSinceEpoch(int.parse(event.timeStamp!));
        }
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
        'com.sec.android.app.launcher',
        // 'com.example.ciara',
        // 'com.android.settings',
        'com.transsion.XOSLauncher', //infinix
        'com.miui.home', //readmi
        'com.mi.android.globallauncher' // POCO
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

          usageInfoList.add(
            UsageInfo(
              packageName: app,
              totalTimeInForeground: '$hours h $minutes m $seconds s',
            ),
          );
          // Sumar al tiempo total después de la filtración
          totalTimeAfterFiltering += totalTimeInMilliseconds;
        }
      }
      // Convertir el tiempo total a minutos después de la filtración
      int totalMinutesAfterFiltering =
          (totalTimeAfterFiltering / 60000).floor();

      print("Tiempo total de uso : $totalMinutesAfterFiltering minutos");

      print('********** Aplicaciones uso diario **********');
      for (var usageInfo in usageInfoList) {
        print(usageInfo.packageName);
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
        "channelId", "Local Notification",
        importance: Importance.high);
    var generalNotificationDetails =
        NotificationDetails(android: androidDetails);

    flutterLocalNotificationsPlugin.show(
        0, "CIARA", message, generalNotificationDetails);
  }

  Future<void> getCedula() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      email = prefs.getString('email') ?? '**';
    });
  }

  Future<void> _getMostActiveHour(DateTime date) async {
    try {
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
        _mostActiveHour = '$maxUsageHour:00';
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

  String _formatTime(int minutes) {
    if (minutes < 60) {
      return '$minutes min';
    } else {
      int hours = minutes ~/ 60;
      int remainingMinutes = minutes % 60;
      return '$hours h $remainingMinutes min';
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
    initUsage(currentDate);
    _getMostActiveHour(currentDate);
  }

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
        child: Column(
          // padding: EdgeInsets.zero,
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
                  const SizedBox(width: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Usuario: ${email.split('@')[0]}',
                        style: const TextStyle(
                          fontFamily: 'FFMetaProText1',
                          color: Colors.white,
                          fontSize: 16,
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
                      .add(const EdgeInsets.only(left: 2.0, right: 90.0)),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Color(0xFFA51008),
                        width: 3.0,
                      ),
                    ),
                  ),
                  child: const Text(
                    'Actividad en apps',
                    style: TextStyle(
                      fontFamily: 'FFMetaProText4',
                      fontSize: 16,
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
                      .add(const EdgeInsets.only(left: 2.0, right: 60.0)),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Color(0xFFA51008),
                        width: 3.0,
                      ),
                    ),
                  ),
                  child: const Text(
                    'Información del CIARA',
                    style: TextStyle(
                      fontFamily: 'FFMetaProText4',
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              onTap: () {
                _onTabTapped(2);
              },
            ),
            const SizedBox(height: 8),
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
                    'Soporte y contacto',
                    style: TextStyle(
                      fontFamily: 'FFMetaProText4',
                      fontSize: 16,
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
                      .add(const EdgeInsets.only(left: 2.0, right: 60.0)),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Color(0xFFA51008),
                        width: 3.0,
                      ),
                    ),
                  ),
                  child: const Text(
                    'Términos y Privacidad',
                    style: TextStyle(
                      fontFamily: 'FFMetaProText4',
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              onTap: () {
                _onTabTapped(3);
              },
            ),

            Spacer(), // Añadir un Spacer para empujar el contenido hacia arriba
            Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.only(bottom: 8),
              child: const Text(
                'UCUENCA',
                style: TextStyle(
                  fontFamily: 'FFMetaProTitle',
                  color: Color(0xFF6F6F6F),
                  fontSize: 25,
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
      case 3:
        return _buildTerminosPrivacidad();
      default:
        return _buildHome();
    }
  }

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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Soporte y Contacto',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'FFMetaProTitle',
              color: Color(0xFF002856),
            ),
          ),
          const SizedBox(height: 20),
          _buildContactCard(
            icon: Icons.phone,
            title: 'Teléfono de Soporte',
            content: '+593 98 772 1834\n+593 96 841 5004',
            actionText: 'Llamar o WhatsApp',
            onTap: () => _launchPhone('+593987721834'),
          ),
          const SizedBox(height: 16),
          _buildContactCard(
            icon: Icons.email,
            title: 'Correo Electrónico',
            content: 'proyecto.ciberadiccion@ucuenca.edu.ec',
            actionText: 'Enviar correo',
            onTap: () => _launchEmail('proyecto.ciberadiccion@ucuenca.edu.ec'),
          ),
          const SizedBox(height: 16),
          _buildContactCard(
            icon: Icons.public,
            title: 'Más Información',
            content: 'https://ingsoftware.ucuenca.edu.ec/',
            actionText: 'Visitar sitio web',
            onTap: () => _launchURL('https://ingsoftware.ucuenca.edu.ec/'),
          ),
          const SizedBox(height: 16),
          const Text(
            'Horario de Atención:',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'FFMetaProText4',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Lunes a Viernes: 08:30 - 13:00',
            style: TextStyle(
              fontSize: 16,
              fontFamily: 'FFMetaProText1',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String content,
    required String actionText,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Color(0xFFA51008)),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'FFMetaProText4',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: const TextStyle(
                fontSize: 16,
                fontFamily: 'FFMetaProText1',
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF002856),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  actionText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'FFMetaProText1',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

// Funciones para lanzar aplicaciones externas
  Future<void> _launchPhone(String phone) async {
    final url = 'https://wa.me/$phone';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      throw 'No se pudo abrir WhatsApp';
    }
  }

  Future<void> _launchEmail(String email) async {
    final url = 'mailto:$email';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      throw 'No se pudo abrir el cliente de correo';
    }
  }

  Future<void> _launchURL(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      throw 'No se pudo abrir la URL $url';
    }
  }

  Widget _buildTerminosPrivacidad() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Términos y Condiciones',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'FFMetaProTitle',
              color: Color(0xFF002856),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Al usar CIARA, aceptas cumplir con estos términos y condiciones. El uso indebido o violación de estos términos puede resultar en la suspensión o cancelación de tu cuenta.',
            style: TextStyle(
              fontSize: 16,
              fontFamily: 'FFMetaProText1',
            ),
          ),
          const SizedBox(height: 24),

          // Sección 1
          _buildTerminoItem(
            icon: Icons.apps,
            title: '1. Uso de la App',
            content:
                'CIARA está diseñada para promover la salud, el bienestar y la mejora del rendimiento académico mediante recomendaciones personalizadas basadas en tus preferencias.',
          ),

          // Sección 2
          _buildTerminoItem(
            icon: Icons.security,
            title: '2. Privacidad de los Datos',
            content:
                'Respetamos tu privacidad. Los datos que proporcionas son utilizados únicamente para personalizar las recomendaciones y para fines investigativos, no se compartirán con terceros sin tu consentimiento.',
          ),

          // Sección 3
          _buildTerminoItem(
            icon: Icons.update,
            title: '3. Modificaciones en el Servicio',
            content:
                'Nos reservamos el derecho de modificar, suspender o descontinuar temporal o permanentemente cualquier parte de la app sin previo aviso.',
          ),

          // Sección 4
          _buildTerminoItem(
            icon: Icons.copyright,
            title: '4. Propiedad Intelectual',
            content:
                '“Evaluación del impacto de las ciberadicciones en el rendimiento académico, salud y bienestar de los estudiantes universitarios de la ciudad de Cuenca”. Todo el contenido y la tecnología de CIARA son propiedad del proyecto.',
          ),

          // Sección 5
          _buildTerminoItem(
            icon: Icons.warning,
            title: '5. Limitación de Responsabilidad',
            content:
                'CIARA ofrece recomendaciones para disminuir el uso de pantallas, esta versión corresponde a la fase de prueba. No nos responsabilizamos por la precisión de las recomendaciones, usted es libre de decidir la ejecución de las recomendaciones.',
          ),

          // Sección 6
          _buildTerminoItem(
            icon: Icons.block,
            title: '6. Suspensión de Cuenta',
            content:
                'Nos reservamos el derecho de suspender o cancelar tu cuenta si detectamos violaciones a estos términos, uso indebido o cualquier actividad ilegal.',
          ),

          // Sección 7
          _buildTerminoItem(
            icon: Icons.help,
            title: '7. Soporte y contacto',
            content:
                'Si tienes dudas o consultas sobre estos términos, puedes contactarnos a través del soporte de CIARA.',
          ),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 20),

          // Acuerdo final
          const Text(
            'Al continuar usando CIARA, aceptas estos términos y condiciones en su totalidad.',
            style: TextStyle(
              fontSize: 16,
              fontStyle: FontStyle.italic,
              fontFamily: 'FFMetaProText1',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTerminoItem({
    required IconData icon,
    required String title,
    required String content,
    bool hasButton = false,
    String buttonText = '',
    VoidCallback? onButtonPressed,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Color(0xFF002856)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'FFMetaProText4',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: const TextStyle(
                fontSize: 16,
                fontFamily: 'FFMetaProText1',
              ),
            ),
            if (hasButton && onButtonPressed != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: onButtonPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFA51008),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    buttonText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'FFMetaProText1',
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAjustes() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: CircleAvatar(
              radius: 60,
              backgroundImage: AssetImage('assets/images/icono.png'),
            ),
          ),
          const SizedBox(height: 20),
          const Center(
            child: Text(
              'CIARA',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                fontFamily: 'FFMetaProTitle',
                color: Color(0xFF002856),
              ),
            ),
          ),
          const Center(
            child: Text(
              'Cyber-Adicction Intervention And Recovery Assistance',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontFamily: 'FFMetaProText1',
              ),
            ),
          ),
          const SizedBox(height: 30),
          _buildInfoItem(
            title: 'Versión',
            content: '1.0.0',
          ),
          _buildInfoItem(
            title: 'Desarrollado por',
            content:
                'Grupo de Investigación de Ingeniería del Software - Universidad de Cuenca',
          ),
          _buildInfoItem(
            title: 'Año de lanzamiento',
            content: '2025',
          ),
          const SizedBox(height: 20),
          const Text(
            'Descripción:',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'FFMetaProText4',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'CIARA es una aplicación diseñada para ayudar a los estudiantes a monitorear '
            'y gestionar su tiempo de uso de aplicaciones, con el objetivo de mejorar '
            'su productividad y rendimiento académico.',
            style: TextStyle(
              fontSize: 16,
              fontFamily: 'FFMetaProText1',
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Características principales:',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'FFMetaProText4',
            ),
          ),
          const SizedBox(height: 8),
          _buildFeatureItem('Monitoreo de tiempo en aplicaciones'),
          _buildFeatureItem('Estadísticas de uso diario'),
          _buildFeatureItem('Identificación de horas de mayor uso'),
          _buildFeatureItem('Recomendaciones personalizadas'),
        ],
      ),
    );
  }

  Widget _buildInfoItem({required String title, required String content}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title: ',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'FFMetaProText4',
            ),
          ),
          Expanded(
            child: Text(
              content,
              style: const TextStyle(
                fontSize: 16,
                fontFamily: 'FFMetaProText1',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String feature) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle,
              color: Color.fromARGB(255, 54, 216, 13), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              feature,
              style: const TextStyle(
                fontSize: 16,
                fontFamily: 'FFMetaProText1',
              ),
            ),
          ),
        ],
      ),
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

  static Future<String> getAppNameFromPackageName(String packageName) async {
    try {
      Application? app = await DeviceApps.getApp(packageName);
      return app?.appName ?? packageName;
    } catch (e) {
      return packageName;
    }
  }

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

  Future<List<String>> getAppNames(List<UsageInfo> usageInfoList) async {
    List<String> appNames = [];
    for (var appInfo in usageInfoList) {
      String appName = await getAppNameFromPackageName(appInfo.packageName!);
      appNames.add(appName);
    }
    return appNames;
  }

  Future<Application?> getApplicationWithIcon(String packageName) async {
    try {
      Application? app = await DeviceApps.getApp(packageName, true);
      return app;
    } catch (e) {
      return null;
    }
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
          return Container(
            width: 35,
            height: 35,
            child: Image.asset('assets/images/icono.png'),
          );
        } else {
          Application? app = snapshot.data;
          if (app is ApplicationWithIcon) {
            return Container(
              width: 35,
              height: 35,
              child: Image.memory(app.icon),
            );
          } else {
            return Container(
              width: 35,
              height: 35,
              child: Image.asset('assets/images/icono.png'),
            );
          }
        }
      },
    );
  }
}
