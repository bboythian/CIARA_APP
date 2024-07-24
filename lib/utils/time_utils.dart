class TimeUtils {
  static int _convertTimeToMinutes0(String time) {
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

  // static String formatTime(int minutes) {
  //   // Código para formatear el tiempo
  // }
}
