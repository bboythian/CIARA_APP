import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'my_app.dart';
import 'package:flutter/cupertino.dart';
import 'package:ciara/services/background_service.dart';

class UserPreferencesScreen extends StatefulWidget {
  const UserPreferencesScreen({Key? key}) : super(key: key);

  @override
  _UserPreferencesScreenState createState() => _UserPreferencesScreenState();
}

class _UserPreferencesScreenState extends State<UserPreferencesScreen> {
  final Map<String, List<bool>> _selectedOptions = {
    'mascota': List.generate(2, (_) => false),
    'responsabilidadesEnCasa': List.generate(4, (_) => false),
    'horarioClases': List.generate(3, (_) => false),
    'espacioOrdenado': List.generate(4, (_) => false),
    'actividadesAireLibre': List.generate(15, (_) => false),
    'actividadesEnCasa': List.generate(15, (_) => false),
    'motivacion': List.generate(4, (_) => false),
  };

  final Map<String, String> _preferences = {};
  String? _errorMessage;

  bool get _isFormComplete {
    // Verifica si se han seleccionado exactamente 3 opciones para 'actividadesAireLibre' y 'actividadesEnCasa'
    bool isActividadesAireLibreComplete =
        _selectedOptions['actividadesAireLibre']!.where((e) => e).length == 3;
    bool isActividadesEnCasaComplete =
        _selectedOptions['actividadesEnCasa']!.where((e) => e).length == 3;

    // La validación general de las demás preguntas se mantiene igual
    return isActividadesAireLibreComplete &&
        isActividadesEnCasaComplete &&
        _preferences.length == _selectedOptions.length;
  }

  void _updatePreference(String question, int index, List<String> options) {
    setState(() {
      _selectedOptions[question] =
          List.generate(options.length, (i) => i == index);
      _preferences[question] = options[index];
    });
  }

  void _updateMultipleSelections(
      String question, int index, List<String> options) {
    setState(() {
      List<bool> selected = _selectedOptions[question]!;

      if (selected[index]) {
        // Si ya está seleccionado, lo deseleccionamos
        selected[index] = false;
      } else {
        // Si no está seleccionado, verificamos que no se exceda el límite de 3
        if (selected.where((e) => e).length < 3) {
          selected[index] = true;
        }
      }

      // Guardamos las opciones seleccionadas en la preferencia
      _preferences[question] = options
          .asMap()
          .entries
          .where((entry) => selected[entry.key])
          .map((entry) => entry.value)
          .join(', '); // Guarda las 3 opciones seleccionadas
    });
  }

  Future<void> _submitPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool('hasCompletedPreferences', true);

    // Enviar las preferencias al servidor
    try {
      var url =
          Uri.parse('https://ingsoftware.ucuenca.edu.ec/enviar-preferencias');
      // var url = Uri.parse('http://10.24.161.24:8081/enviar-preferencias');
      // Obtener la fecha actual y formatearla
      DateTime now = DateTime.now();
      String formattedDate = DateFormat('MMM').format(now).toUpperCase() +
          DateFormat('yy').format(now);
      //print('PERIODO: $formattedDate');
      var response = await http.post(
        url,
        body: {
          'email': prefs.getString('email'),
          'periodo': formattedDate,
          'mascota': _preferences['mascota'],
          'responsabilidadesEnCasa': _preferences['responsabilidadesEnCasa'],
          'horarioClases': _preferences['horarioClases'],
          'espacioOrdenado': _preferences['espacioOrdenado'],
          'actividadesAireLibre': _preferences['actividadesAireLibre'],
          'actividadesEnCasa': _preferences['actividadesEnCasa'],
          'motivacion': _preferences['motivacion'],
        },
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      // Asegúrate de inicializar el servicio antes de programar alarmas
      await BackgroundService.initialize();
      await BackgroundService.scheduleDailyAlarms();
    } catch (error) {
      print('Error al enviar las preferencias: $error');
    }

    // Navegar a la aplicación principal
    // ignore: use_build_context_synchronously
    // Navigator.pushReplacement(
    //   context,
    //   MaterialPageRoute(
    //       builder: (context) => MyApp(email: prefs.getString('email')!)),
    // );
    // Navegar a la aplicación principal y bloquear volver a la pantalla de preferencias
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (context) => MyApp(email: prefs.getString('email')!)),
    );
  }

  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        return false; // Bloquear el botón de retroceso
      },
      child: Stack(
        children: [
          Scaffold(
            //Se crea el contenido de la vista de preferencias
            appBar: AppBar(
              title: const Text(
                'Perfil de Usuario',
                style: TextStyle(
                  fontFamily: 'FFMetaProText2',
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              backgroundColor: Color(0xFF002856),
              iconTheme: const IconThemeData(
                color: Colors.white,
              ),
            ),
            body: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Selecciona según corresponda:',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    const Text('1. ¿Tienes mascotas que vivan con usted?'),
                    _buildToggleButtons('mascota', ['Si', 'No']),
                    const SizedBox(height: 20),
                    const Text(
                        '2. ¿Cómo manejas tus responsabilidades en casa?'),
                    _buildToggleButtons('responsabilidadesEnCasa', [
                      'Cumplo con todas',
                      'Solo cuando me lo piden',
                      'Rara vez las cumplo',
                      'No tengo responsabilidades'
                    ]),
                    const SizedBox(height: 10),
                    const Text(
                        '3. Seleccione su jornada de clases más habitual.'),
                    _buildToggleButtons('horarioClases',
                        ['Matutino', 'Vespertino', 'Nocturno']),
                    const SizedBox(height: 10),
                    const Text(
                        '4. ¿Cómo describirías el estado de tu espacio personal en general?'),
                    _buildToggleButtons('espacioOrdenado', [
                      'Siempre ordenado',
                      'Generalmente ordenado',
                      'A veces desordenado, pero lo arreglo',
                      'A menudo desordenado'
                    ]),
                    const SizedBox(height: 10),
                    const Text(
                        '5. Selecciona 3 actividades FUERA DE CASA que más disfrute.'),
                    _buildMultipleChoiceToggleButtons('actividadesAireLibre', [
                      'Practicar algún deporte o actividad física',
                      'Salir a caminar',
                      'Salir a comer',
                      'Ir al cine',
                      'Salir de compras o al centro comercial',
                      'Socializar con amigos o pareja',
                      'Acampar',
                      'Salir de fiesta',
                      'Visitar lugares nuevos',
                      'Hacer senderismo o excursiones fuera de la ciudad',
                      'Participar en actividades culturales',
                      'Fotografiar entornos y elementos diversos',
                      'Realizar voluntariado',
                      'Visitar museos o exposiciones',
                      'Asistir a seminarios/cursos'
                    ]),
                    const SizedBox(height: 10),
                    const Text(
                        '6. Selecciona 3 actividades EN CASA que más disfrute SIN USAR TECNOLOGÍA'),
                    _buildMultipleChoiceToggleButtons('actividadesEnCasa', [
                      'Leer',
                      'Tocar algún instrumento',
                      'Hacer manualidades',
                      'Socializar con familia o amigos',
                      'Cocinar',
                      'Rutinas de belleza o cuidado personal',
                      'Juegos de mesa o rompecabezas',
                      'Practicar meditación o yoga',
                      'Hacer ejercicio en casa',
                      'Escritura creativa',
                      'Pintar o dibujar',
                      'Hacer costura o tejer',
                      'Organizar o limpiar',
                      'Jardinería',
                      'Pasar tiempo con tu mascota',
                    ]),
                    const SizedBox(height: 10),
                    const Text('7. ¿Cuál es tu expectativa al usar CIARA?'),
                    _buildToggleButtons('motivacion', [
                      'Mejorar mi bienestar físico y mental',
                      'Aumentar mi productividad en estudios',
                      'Fortalecer mis relaciones personales',
                      'Encontrar nuevas formas de entretenimiento'
                    ]),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _isFormComplete
                          ? () async {
                              setState(() {
                                isLoading = true; // Mostrar indicador de carga
                              });

                              await _submitPreferences(); // Ejecutar el método que ya tarda 2 segundos

                              setState(() {
                                isLoading =
                                    false; // Ocultar indicador de carga cuando termine
                              });
                            }
                          : null,
                      style: ButtonStyle(
                        backgroundColor:
                            MaterialStateProperty.resolveWith<Color>(
                          (Set<MaterialState> states) {
                            if (states.contains(MaterialState.disabled)) {
                              return Colors
                                  .grey; // Color cuando el botón está deshabilitado
                            }
                            return const Color(
                                0xFF002856); // Color cuando el botón está habilitado
                          },
                        ),
                        foregroundColor:
                            MaterialStateProperty.resolveWith<Color>(
                          (Set<MaterialState> states) {
                            if (states.contains(MaterialState.disabled)) {
                              return Colors
                                  .black; // Color del texto cuando está deshabilitado
                            }
                            return Colors
                                .white; // Color del texto cuando está habilitado
                          },
                        ),
                      ),
                      child: const Text(
                        'Generar Perfil de Usuario',
                        style: TextStyle(
                          fontFamily: 'FFMetaProText2',
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isLoading)
            Container(
              color: Colors.black.withOpacity(0.5), // Fondo opaco
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: CircularProgressIndicator(
                        color: Colors.white, // Color del indicador
                        strokeWidth: 8, // Grosor del indicador
                      ),
                    ),
                    SizedBox(height: 14),
                    Text(
                      'Generando perfil de Usuario...',
                      style: TextStyle(
                        fontSize: 18,
                        fontFamily: 'FFMetaProText2',
                        color: Colors.white, // Color del texto
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildToggleButtons(String question, List<String> options) {
    return Wrap(
      spacing: 8.0,
      children: List.generate(options.length, (index) {
        return Theme(
          data: Theme.of(context).copyWith(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: Colors.transparent, // Hace el check transparente
                  onPrimary: Colors
                      .transparent, // Asegura que el check sea transparente
                ),
          ),
          child: ChoiceChip(
            label: Text(
              options[index],
              style: TextStyle(
                color: _selectedOptions[question]![index]
                    ? Colors.black // Color del texto cuando está seleccionado
                    : const Color(
                        0xFF002856), // Color del texto cuando no está seleccionado
              ),
            ),
            selectedColor: Color(0xFFE0E0E0), //
            backgroundColor: Colors.white, //background color
            selected: _selectedOptions[question]![index],
            onSelected: (selected) {
              setState(() {
                _updatePreference(question, index, options);
              });
            },
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
              side: BorderSide(
                color: _selectedOptions[question]![index]
                    ? const Color.fromARGB(
                        0, 220, 14, 14) // Sin borde cuando está seleccionado
                    : const Color(
                        0xFF606880), // Color del borde cuando no está seleccionado
                width: 1.0, // Ancho del borde
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildMultipleChoiceToggleButtons(
      String question, List<String> options) {
    return Wrap(
      spacing: 8.0,
      children: List.generate(options.length, (index) {
        return Theme(
          data: Theme.of(context).copyWith(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: ChoiceChip(
            label: Text(
              options[index],
              style: TextStyle(
                color: _selectedOptions[question]![index]
                    ? Colors.black
                    : const Color(0xFF002856),
              ),
            ),
            selectedColor: Color(0xFFE0E0E0),
            backgroundColor: Colors.white,
            selected: _selectedOptions[question]![index],
            onSelected: (selected) {
              setState(() {
                _updateMultipleSelections(question, index, options);
              });
            },
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
              side: BorderSide(
                color: _selectedOptions[question]![index]
                    ? const Color.fromARGB(0, 220, 14, 14)
                    : const Color(0xFF606880),
                width: 1.0,
              ),
            ),
          ),
        );
      }),
    );
  }
}
