import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'user_preferences_screen.dart'; // Asegúrate de importar el archivo adecuado

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final TextEditingController _emailController = TextEditingController();

  bool _isAccepted = false;
  bool _isModalShown = false;

  @override
  Widget build(BuildContext context) {
    if (!_isModalShown) {
      WidgetsBinding.instance!.addPostFrameCallback((_) {
        _showWelcomeModal(context);
      });
      _isModalShown = true;
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Términos y Condiciones',
          style: TextStyle(
            fontFamily: 'FFMetaProText2',
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Color(0xFF002856),
      ),
      body: Padding(
        padding: EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const Text(
                      'Estos términos y condiciones describen las reglas y regulaciones para el uso de nuestra aplicación. '
                      'Al acceder a esta aplicación, asumimos que acepta estos términos y condiciones en su totalidad. '
                      'No continúe utilizando la aplicación si no acepta todos los términos y condiciones establecidos en esta página. '
                      'El siguiente lenguaje se aplica a estos términos y condiciones, política de privacidad y aviso de responsabilidad: '
                      'Cliente, usted y su se refiere a usted, la persona que accede a esta aplicación y acepta los términos y condiciones de la Compañía.',
                      style: TextStyle(
                        fontFamily: 'FFMetaProText3',
                        color: Color(0xFF002856),
                      ),
                      textAlign: TextAlign.justify,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Checkbox(
                          value: _isAccepted,
                          onChanged: (bool? value) {
                            setState(() {
                              _isAccepted = value ?? false;
                            });
                          },
                        ),
                        const Text('Aceptar términos y condiciones'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isAccepted
                  ? () {
                      _showEmailDialog(context);
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                primary: Color(0xFF002856), // Color de fondo
                onPrimary: Colors.white, // Color del texto
              ),
              child: const Text(
                'Ingresar',
                style: TextStyle(
                  fontFamily: 'FFMetaProText2',
                  fontSize: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  //Muestra el panel inicial
  void _showWelcomeModal(BuildContext context) {
    Future.delayed(Duration(milliseconds: 600), () {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF002856),
        builder: (BuildContext context) {
          return FractionallySizedBox(
            heightFactor: 0.80,
            child: Container(
              padding: EdgeInsets.all(50.0),
              // color: Color(0xFF002856),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/icono.png',
                    height: 200,
                  ),
                  // const SizedBox(height: 25.0),
                  const Text(
                    'Bienvenid@ a CIARA',
                    style: TextStyle(
                      fontSize: 26.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'FFMetaProText2',
                    ),
                  ),
                  const SizedBox(height: 25.0),
                  const Text(
                    'Esta aplicación reúne tu información del uso diario de tu teléfono celular.\n \nPuedes revisar parámetros de uso, alertas y sugerencias',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'FFMetaProText3',
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 40.0),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Continuar',
                      style: TextStyle(
                        fontFamily: 'FFMetaProText2',
                        fontSize: 20,
                        color: Color(0xFF002856),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    });
  }

  void _showEmailDialog(BuildContext context) {
    String errorMessage = '';
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: const Text(
                'Ingresar correo electrónico',
                style: TextStyle(
                  fontFamily: 'FFMetaProText2',
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF002856),
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _emailController,
                    style: const TextStyle(
                      color: Color(0xFF002856), // Color del texto del input
                      fontFamily: 'FFMetaProText3',
                      fontSize: 16,
                    ),
                    keyboardType: TextInputType.emailAddress,
                    // inputFormatters: [
                    //   FilteringTextInputFormatter.digitsOnly,
                    // ],
                    cursorColor: Color(0xFF002856),
                    decoration: InputDecoration(
                      labelText: 'Correo electrónico*',
                      labelStyle: const TextStyle(
                        color: Color(0xFF002856),
                        fontFamily: 'FFMetaProText3',
                        fontSize: 16,
                      ),
                      enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: Color(
                              0xFFA51008), // Color de la línea inferior cuando no está enfocado
                        ),
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: Color(
                              0xFFA51008), // Color de la línea inferior cuando está enfocado
                        ),
                      ),
                      errorText: errorMessage.isEmpty ? null : errorMessage,
                    ),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    primary: Colors.white, // Color de fondo
                    onPrimary: Color(0xFF002856), // Color del texto
                  ),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(
                      fontFamily: 'FFMetaProText2',
                      fontSize: 20,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    String email = _emailController.text;
                    if (email.isEmpty ||
                        !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
                      setState(() {
                        errorMessage = 'Por favor ingrese un correo válido';
                      });
                      return;
                    }
                    print('Enviando solicitud al servidor...');
                    print('Correo electrónico: $email');
                    // Validar correo en el servidor
                    // var url = Uri.parse(
                    //     'https://ingsoftware.ucuenca.edu.ec/validar-email');
                    var url =
                        Uri.parse('http://10.24.160.183:8081/validar-email');
                    var response = await http.post(
                      url,
                      headers: {"Content-Type": "application/json"},
                      body: json.encode({'email': email}),
                    );

                    if (response.statusCode == 200) {
                      var responseBody = json.decode(response.body);
                      print('Respuesta del servidor:');
                      print(responseBody);
                      if (responseBody['exists'] == true) {
                        // Guardar correo y navegar a la siguiente pantalla
                        SharedPreferences prefs =
                            await SharedPreferences.getInstance();
                        prefs.setString('email', email);
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UserPreferencesScreen(),
                          ),
                        );
                      } else {
                        setState(() {
                          errorMessage = 'Correo no registrado';
                        });
                      }
                    } else {
                      setState(() {
                        errorMessage = 'Correo no registrado para el proyecto';
                      });
                      print('Error en la solicitud: ${response.statusCode}');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    primary: Color(0xFF002856), // Color de fondo
                    onPrimary: Colors.white, // Color del texto
                  ),
                  child: const Text(
                    'Guardar',
                    style: TextStyle(
                      fontFamily: 'FFMetaProText2',
                      fontSize: 20,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
