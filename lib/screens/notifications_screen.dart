import 'package:flutter/material.dart';
import '../widgets/app_drawer.dart';

class NotificationsScreen extends StatefulWidget {
  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notificaciones'),
      ),
      drawer: AppDrawer(),
      body: Center(
        child: Column(
          children: [
            // Widgets específicos para configuración de notificaciones
          ],
        ),
      ),
    );
  }
}
