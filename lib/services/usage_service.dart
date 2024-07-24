import 'package:permission_handler/permission_handler.dart';
import 'package:usage_stats/usage_stats.dart';

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
