import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'my_app.dart'; // Asegúrate de importar el archivo adecuado

class UserPreferencesScreen extends StatefulWidget {
  const UserPreferencesScreen({Key? key}) : super(key: key);

  @override
  _UserPreferencesScreenState createState() => _UserPreferencesScreenState();
}

class _UserPreferencesScreenState extends State<UserPreferencesScreen> {
  final Map<String, List<bool>> _selectedOptions = {
    'peliculas': List.generate(6, (_) => false),
    'musica': List.generate(7, (_) => false),
    'series': List.generate(6, (_) => false),
    'libros': List.generate(6, (index) => false),
    'formatoLectura': List.generate(3, (_) => false),
    'actividades': List.generate(6, (_) => false),
    'frecuenciaActividades': List.generate(6, (_) => false),
    'actividadesInteriores': List.generate(6, (_) => false),
    'tiempoInteriores': List.generate(4, (_) => false),
    'destinosViaje': List.generate(6, (_) => false),
    'actividadesViaje': List.generate(6, (_) => false),
    'gadgets': List.generate(6, (_) => false),
    'aplicaciones': List.generate(7, (_) => false),
    'comida': List.generate(6, (_) => false),
    'frecuenciaComida': List.generate(6, (_) => false),
    'deportes': List.generate(6, (_) => false),
    'frecuenciaDeportes': List.generate(6, (_) => false),
  };

  final Map<String, String> _preferences = {};

  bool get _isFormComplete {
    return _preferences.length ==
        _selectedOptions
            .length; // Cambia este valor según el número de preguntas
  }

  void _updatePreference(String question, int index, List<String> options) {
    setState(() {
      _selectedOptions[question] =
          List.generate(options.length, (i) => i == index);
      _preferences[question] = options[index];
    });
  }

  Future<void> _submitPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool('hasCompletedPreferences', true);

    // Enviar las preferencias al servidor
    try {
      //var url = Uri.parse('https://ingsoftware.ucuenca.edu.ec/enviar-preferencias');
      var url = Uri.parse('http://10.24.160.183:8081/enviar-preferencias');
      // Obtener la fecha actual y formatearla
      DateTime now = DateTime.now();
      String formattedDate = DateFormat('MMM').format(now).toUpperCase() +
          DateFormat('yy').format(now);

      var response = await http.post(
        url,
        body: {
          'email': prefs.getString('email'),
          'periodo': formattedDate, // Nuevo campo añadido
          'peliculas': _preferences['peliculas'],
          'musica': _preferences['musica'],
          'series': _preferences['series'],
          'libros': _preferences['libros'],
          'formatoLectura': _preferences['formatoLectura'],
          'actividadesAlAireLibre': _preferences['actividades'],
          'frecuenciaActividadesAlAireLibre':
              _preferences['frecuenciaActividades'],
          'actividadesEnInteriores': _preferences['actividadesInteriores'],
          'tiempoActividadesEnInteriores': _preferences['tiempoInteriores'],
          'destinosDeViaje': _preferences['destinosViaje'],
          'actividadesEnViaje': _preferences['actividadesViaje'],
          'gadgets': _preferences['gadgets'],
          'aplicaciones': _preferences['aplicaciones'],
          'tipoComida': _preferences['comida'],
          'frecuenciaComerFuera': _preferences['frecuenciaComida'],
          'deportes': _preferences['deportes'],
          'frecuenciaEjercicio': _preferences['frecuenciaDeportes'],
        },
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
    } catch (error) {
      print('Error al enviar las preferencias: $error');
    }

    // Navegar a la aplicación principal
    // ignore: use_build_context_synchronously
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (context) => MyApp(email: prefs.getString('email')!)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //Se crea el contenido de la vista de preferencias
      appBar: AppBar(
        title: const Text('Gustos y Preferencias'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '1. Entretenimiento',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text('1.1. ¿Qué tipo de películas prefieres?'),
              _buildToggleButtons('peliculas', [
                'Acción',
                'Comedia',
                'Drama',
                'Ciencia ficción',
                'Terror',
                'Documentales'
              ]),
              const SizedBox(height: 20),
              const Text('1.2. ¿Cuál es tu género musical favorito?'),
              _buildToggleButtons('musica', [
                'Pop',
                'Rock',
                'Reggaeton',
                'Clásica',
                'Electrónica',
                'Hip-hop/Rap',
                'Otro',
              ]),
              const SizedBox(height: 20),
              const Text('1.3. ¿Qué tipo de series te gustan más?'),
              _buildToggleButtons('series', [
                'Policíacas',
                'Comedias',
                'Drama',
                'Ciencia ficción',
                'Fantasía',
                'Documentales'
              ]),
              const SizedBox(height: 20),
              const Text(
                '2. Lectura',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text('2.1. ¿Qué tipo de libros prefieres leer?'),
              _buildToggleButtons('libros', [
                'Novelas',
                'Biografías',
                'Ciencia ficción',
                'No ficción',
                'Autoayuda',
                'Fantasía'
              ]),
              const SizedBox(height: 20),
              const Text('2.2. ¿Qué formato de lectura prefieres?'),
              _buildToggleButtons('formatoLectura', [
                'Libros impresos',
                'Libros electrónicos (eBooks)',
                'Audiolibros'
              ]),
              const SizedBox(height: 20),
              const Text(
                '3. Actividades al aire libre',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text('3.1. ¿Qué actividades al aire libre disfrutas más?'),
              _buildToggleButtons('actividades', [
                'Senderismo',
                'Ciclismo',
                'Camping',
                'Running',
                'Deportes acuáticos',
                'Pasear en la ciudad'
              ]),
              const SizedBox(height: 20),
              const Text(
                  '3.2. ¿Con qué frecuencia realizas actividades al aire libre?'),
              _buildToggleButtons('frecuenciaActividades', [
                'Diariamente',
                'Varias veces a la semana',
                'Una vez a la semana',
                'Un par de veces al mes',
                'Rara vez',
                'Nunca'
              ]),
              const SizedBox(height: 20),
              const Text(
                '4. Actividades en interiores',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                  '4.1. ¿Qué tipo de actividades en interiores prefieres?'),
              _buildToggleButtons('actividadesInteriores', [
                'Cocinar',
                'Manualidades/DIY',
                'Juegos de mesa',
                'Videojuegos',
                'Yoga/meditación',
                'Lectura'
              ]),
              const SizedBox(height: 20),
              const Text(
                  '4.2. ¿Cuánto tiempo dedicas a actividades en interiores en una semana?'),
              _buildToggleButtons('tiempoInteriores', [
                'Menos de 5 horas',
                'Entre 5 y 10 horas',
                'Entre 10 y 15 horas',
                'Más de 15 horas'
              ]),
              const SizedBox(height: 20),
              const Text(
                '5. Viajes y exploración',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text('5.1. ¿Qué tipo de destinos prefieres para viajar?'),
              _buildToggleButtons('destinosViaje', [
                'Playas',
                'Montañas',
                'Ciudades históricas',
                'Parques naturales',
                'Ciudades modernas',
                'Destinos culturales'
              ]),
              const SizedBox(height: 20),
              const Text(
                  '5.2. ¿Qué tipo de actividades disfrutas más durante tus viajes?'),
              _buildToggleButtons('actividadesViaje', [
                'Turismo gastronómico',
                'Visitas culturales (museos, monumentos)',
                'Actividades deportivas',
                'Compras',
                'Relajación (spa, playa)',
                'Aventuras (excursiones, deportes extremos)'
              ]),
              const SizedBox(height: 20),
              const Text(
                '6. Tecnologías y dispositivos',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text('6.1. ¿Qué tipo de gadgets usas con más frecuencia?'),
              _buildToggleButtons('gadgets', [
                'Teléfonos inteligentes',
                'Tablets',
                'Computadoras portátiles',
                'Consolas de videojuegos',
                'Relojes inteligentes',
                'Auriculares inalámbricos'
              ]),
              const SizedBox(height: 20),
              const Text('6.2. ¿Qué aplicaciones utilizas con más frecuencia?'),
              _buildToggleButtons('aplicaciones', [
                'Redes sociales',
                'Aplicaciones de mensajería',
                'Aplicaciones de streaming (música/películas)',
                'Aplicaciones de productividad (calendarios, notas)',
                'Aplicaciones de fitness y salud',
                'Aplicaciones de noticias',
                'Aplicaciones de juegos'
              ]),
              const SizedBox(height: 20),
              const Text(
                '7. Gastronomía',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text('7.1. ¿Cuál es tu tipo de comida favorita?'),
              _buildToggleButtons('comida', [
                'Italiana',
                'Mexicana',
                'Japonesa',
                'India',
                'Mediterránea',
                'Americana'
              ]),
              const SizedBox(height: 20),
              const Text('7.2. ¿Con qué frecuencia comes fuera de casa?'),
              _buildToggleButtons('frecuenciaComida', [
                'Diariamente',
                'Varias veces a la semana',
                'Una vez a la semana',
                'Varias veces al mes',
                'Rara vez',
                'Nunca'
              ]),
              const SizedBox(height: 20),
              const Text(
                '8. Deportes y fitness',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text('8.1. ¿Qué deportes practicas regularmente?'),
              _buildToggleButtons('deportes', [
                'Fútbol',
                'Baloncesto',
                'Natación',
                'Ciclismo',
                'Running',
                'Ninguno'
              ]),
              const SizedBox(height: 20),
              const Text('8.2. ¿Con qué frecuencia haces ejercicio?'),
              _buildToggleButtons('frecuenciaDeportes', [
                'Diariamente',
                'Varias veces a la semana',
                'Una vez a la semana',
                'Varias veces al mes',
                'Rara vez',
                'Nunca'
              ]),
              //here
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isFormComplete ? _submitPreferences : null,
                child: const Text('Generar Perfil de Usuario'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleButtons(String question, List<String> options) {
    return Wrap(
      spacing: 8.0,
      children: List.generate(options.length, (index) {
        return ChoiceChip(
          label: Text(options[index]),
          selected: _selectedOptions[question]![index],
          onSelected: (selected) {
            _updatePreference(question, index, options);
          },
        );
      }),
    );
  }
}
