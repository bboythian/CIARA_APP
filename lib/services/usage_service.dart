import 'package:permission_handler/permission_handler.dart';
import 'package:usage_stats/usage_stats.dart';
import 'package:device_apps/device_apps.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> requestPermissions() async {
  if (await Permission.storage.request().isGranted) {
    print('Storage permission granted');
  } else {
    print('Storage permission denied');
  }
}

Future<List<EventUsageInfo>> initUsage(DateTime date) async {
  bool? isGranted = await UsageStats.checkUsagePermission();
  if (!isGranted!) {
    await UsageStats.grantUsagePermission();
  }
  DateTime startDate = DateTime(date.year, date.month, date.day, 0, 0, 0, 0, 1);
  DateTime endDate =
      DateTime(date.year, date.month, date.day, 23, 59, 59, 999, 999);
  return await UsageStats.queryEvents(startDate, endDate);
}

class UsageService {
  static late String email;
  static Future<int> getTotalUsageToday() async {
    DateTime now = DateTime.now();
    DateTime startOfDay =
        DateTime(now.year, now.month, now.day); // Inicio del día a las 00:00

    // Consultar las estadísticas de uso desde el inicio del día hasta ahora
    List<UsageInfo> usageStats =
        await UsageStats.queryUsageStats(startOfDay, now);

    int totalTimeInForeground = 0;

    // Sumar el tiempo en primer plano de cada aplicación
    for (var info in usageStats) {
      if (info.totalTimeInForeground != null) {
        totalTimeInForeground += int.tryParse(info.totalTimeInForeground!) ?? 0;
      }
    }

    return totalTimeInForeground; // Tiempo total de uso en milisegundos
  }

  static Future<String> getMostActiveHour(DateTime date) async {
    try {
      DateTime endDate = DateTime(date.year, date.month, date.day, 23, 59, 59);
      DateTime startDate = DateTime(date.year, date.month, date.day, 0, 0, 0);

      // Obtener las estadísticas de uso del día
      List<UsageInfo> usageStats =
          await UsageStats.queryUsageStats(startDate, endDate);

      // Map para almacenar el uso por hora
      Map<int, int> usageByHour = {};

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
        }
      }

      // Encontrar la hora con mayor uso
      int maxUsageHour = usageByHour.keys.first;
      for (var hour in usageByHour.keys) {
        if (usageByHour[hour]! > usageByHour[maxUsageHour]!) {
          maxUsageHour = hour;
        }
      }

      return '$maxUsageHour:00';
    } catch (e) {
      print('Error al obtener la hora de mayor uso: $e');
      return 'Error';
    }
  }

  static Future<String> getAppNameFromPackageName(String packageName) async {
    try {
      Application? app = await DeviceApps.getApp(packageName);
      return app?.appName ?? packageName;
    } catch (e) {
      return packageName;
    }
  }

  static Future<void> getEmail() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    email = prefs.getString('email') ?? '**';
  }
}
