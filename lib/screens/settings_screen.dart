import 'package:flutter/material.dart';
import '../widgets/app_drawer.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ajustes'),
      ),
      drawer: AppDrawer(),
      body: Center(
        child: Text('Página de Ajustes'),
      ),
    );
  }
}
