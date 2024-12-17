import 'package:flutter/material.dart';
import 'package:ciara/services/background_service.dart';

class BootReceiver extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Inicializar alarmas nuevamente después del reinicio
    BackgroundService.scheduleDailyAlarms();
    return Container();
  }
}
