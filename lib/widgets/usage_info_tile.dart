import 'package:flutter/material.dart';
import '../models/usage_info.dart';
import '../services/app_service.dart';

class UsageInfoTile extends StatelessWidget {
  final UsageInfo appInfo;

  UsageInfoTile({required this.appInfo});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      // leading: FutureBuilder(
      //   future: AppService.getAppIcon(appInfo.packageName),
      //   builder: (context, snapshot) {
      //     if (snapshot.connectionState == ConnectionState.waiting) {
      //       return CircularProgressIndicator();
      //     } else if (snapshot.hasData) {
      //       return Image.memory(snapshot.data!);
      //     } else {
      //       return Icon(Icons.error);
      //     }
      //   },
      // ),
      // title: FutureBuilder(
      //   future: AppService.getAppName(appInfo.packageName),
      //   builder: (context, snapshot) {
      //     if (snapshot.connectionState == ConnectionState.waiting) {
      //       return Text('Loading...');
      //     } else if (snapshot.hasData) {
      //       return Text(snapshot.data!);
      //     } else {
      //       return Text('Unknown');
      //     }
      //   },
      // ),
      subtitle: Text('Tiempo de uso: ${appInfo.totalTimeInForeground}'),
    );
  }
}
