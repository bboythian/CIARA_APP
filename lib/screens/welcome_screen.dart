// ignore_for_file: sort_child_properties_last

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/gestures.dart';
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
                      'Al usar CIARA, aceptas cumplir con estos términos y condiciones. El uso indebido o violación de estos términos puede resultar en la suspensión o cancelación de tu cuenta.',
                      style: TextStyle(
                        fontFamily: 'FFMetaProText3',
                        color: Color(0xFF002856),
                      ),
                      textAlign: TextAlign.justify,
                    ),
                    const SizedBox(height: 15),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '1. Uso de la App',
                        style: TextStyle(
                          fontFamily: 'FFMetaProText3',
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF002856),
                        ),
                      ),
                    ),
                    const Text(
                      'CIARA está diseñada para promover la salud, el bienestar y la mejora del rendimiento académico mediante recomendaciones personalizadas basadas en tus preferencias.',
                      style: TextStyle(
                        fontFamily: 'FFMetaProText3',
                        color: Color(0xFF002856),
                      ),
                      textAlign: TextAlign.justify,
                    ),
                    const SizedBox(height: 15),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '2. Privacidad de los Datos',
                        style: TextStyle(
                          fontFamily: 'FFMetaProText3',
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF002856),
                        ),
                      ),
                    ),
                    RichText(
                      textAlign: TextAlign.justify,
                      text: TextSpan(
                        style: const TextStyle(
                          fontFamily: 'FFMetaProText3',
                          color: Color(0xFF002856),
                          fontSize: 15.3,
                        ),
                        children: [
                          const TextSpan(
                            text:
                                'Respetamos tu privacidad. Los datos que proporcionas son utilizados únicamente para personalizar las recomendaciones y para fines investigativos, no se compartirán con terceros sin tu consentimiento. Consulta nuestra ',
                          ),
                          TextSpan(
                            text: 'Política de Privacidad',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration
                                  .underline, // Subrayado para indicar que es un enlace
                              color: Color(0xFF002856), // Color del enlace
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                _showPrivacyPolicyDialog(context);
                              },
                          ),
                          const TextSpan(
                            text: ' para más detalles.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '3. Modificaciones en el Servicio',
                        style: TextStyle(
                          fontFamily: 'FFMetaProText3',
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF002856),
                        ),
                      ),
                    ),
                    const Text(
                      'Nos reservamos el derecho de modificar, suspender o descontinuar temporal o permanentemente cualquier parte de la app sin previo aviso.',
                      style: TextStyle(
                        fontFamily: 'FFMetaProText3',
                        color: Color(0xFF002856),
                      ),
                      textAlign: TextAlign.justify,
                    ),
                    const SizedBox(height: 15),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '4. Propiedad Intelectual',
                        style: TextStyle(
                          fontFamily: 'FFMetaProText3',
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF002856),
                        ),
                      ),
                    ),
                    RichText(
                      textAlign: TextAlign.justify,
                      text: const TextSpan(
                        style: TextStyle(
                          fontFamily: 'FFMetaProText3',
                          color: Color(0xFF002856),
                          fontSize: 15.3,
                        ),
                        children: [
                          TextSpan(
                            text:
                                'Todo el contenido y la tecnología de CIARA son propiedad del proyecto',
                          ),
                          TextSpan(
                            text:
                                '“Evaluación del impacto de las ciberadicciones en el rendimiento académico, salud y bienestar de los estudiantes universitarios de la ciudad de Cuenca”.',
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '5. Limitación de Responsabilidad',
                        style: TextStyle(
                          fontFamily: 'FFMetaProText3',
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF002856),
                        ),
                      ),
                    ),
                    const Text(
                      'CIARA ofrece recomendaciones para disminuir el uso de pantallas, esta versión corresponde a la fase de prueba. No nos responsabilizamos por la precisión de las recomendaciones, usted es libre de decidir la ejecución de las recomendaciones.',
                      style: TextStyle(
                        fontFamily: 'FFMetaProText3',
                        color: Color(0xFF002856),
                      ),
                      textAlign: TextAlign.justify,
                    ),
                    const SizedBox(height: 15),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '6. Suspensión de Cuenta',
                        style: TextStyle(
                          fontFamily: 'FFMetaProText3',
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF002856),
                        ),
                      ),
                    ),
                    const Text(
                      'Nos reservamos el derecho de suspender o cancelar tu cuenta si detectamos violaciones a estos términos, uso indebido o cualquier actividad ilegal.',
                      style: TextStyle(
                        fontFamily: 'FFMetaProText3',
                        color: Color(0xFF002856),
                      ),
                      textAlign: TextAlign.justify,
                    ),
                    const SizedBox(height: 15),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '7. Soporte y contacto',
                        style: TextStyle(
                          fontFamily: 'FFMetaProText3',
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF002856),
                        ),
                      ),
                    ),
                    const Text(
                      'Si tienes dudas o consultas sobre estos términos, puedes contactarnos a través del soporte de CIARA.',
                      style: TextStyle(
                        fontFamily: 'FFMetaProText3',
                        color: Color(0xFF002856),
                      ),
                      textAlign: TextAlign.justify,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Checkbox(
                          value: _isAccepted,
                          activeColor: Color(0xFF002856),
                          onChanged: (bool? value) {
                            setState(() {
                              _isAccepted = value ?? false;
                            });
                          },
                        ),
                        const Text(
                          'Aceptar términos y condiciones',
                          style: TextStyle(
                            fontFamily: 'FFMetaProText3',
                            color: Color(0xFF002856),
                          ),
                        ),
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

  void _showPrivacyPolicyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            'Política de Privacidad',
            style: TextStyle(
              fontFamily: 'FFMetaProText3',
              fontWeight: FontWeight.bold,
              color: Color(0xFF002856),
            ),
          ),
          content: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '1. Introducción',
                  style: TextStyle(
                    fontFamily: 'FFMetaProText3',
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF002856),
                  ),
                ),
                Text(
                  'La presente Política de Privacidad describe cómo recopilamos, utilizamos y protegemos tu información personal al utilizar nuestra app. Al usar CIARA, aceptas esta política.',
                  style: TextStyle(
                    fontFamily: 'FFMetaProText3',
                    color: Color(0xFF002856),
                  ),
                  textAlign: TextAlign.justify,
                ),
                SizedBox(height: 10), // Espacio entre párrafos
                Text(
                  '2. Información que Recopilamos',
                  style: TextStyle(
                    fontFamily: 'FFMetaProText3',
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF002856),
                  ),
                ),
                Text(
                  'Recopilamos la siguiente información:',
                  style: TextStyle(
                    fontFamily: 'FFMetaProText3',
                    color: Color(0xFF002856),
                  ),
                  textAlign: TextAlign.justify,
                ),
                Text(
                  '- Datos Personales: Dirección de correo electrónico (para la validación de participación en esta etapa).\n'
                  '- Datos de Uso: Información sobre cómo interactúas con tus aplicaciones, incluyendo preferencias y tiempo de uso.',
                  style: TextStyle(
                    fontFamily: 'FFMetaProText3',
                    color: Color(0xFF002856),
                  ),
                  textAlign: TextAlign.justify,
                ),
                SizedBox(height: 10), // Espacio entre párrafos
                Text(
                  '3. Uso de la Información',
                  style: TextStyle(
                    fontFamily: 'FFMetaProText3',
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF002856),
                  ),
                ),
                Text(
                  'Utilizamos la información recopilada para:',
                  style: TextStyle(
                    fontFamily: 'FFMetaProText3',
                    color: Color(0xFF002856),
                  ),
                  textAlign: TextAlign.justify,
                ),
                Text(
                  '- Proporcionar y mejorar nuestras recomendaciones personalizadas. \n'
                  '- Ejecutar la investigación sobre la efectividad de CIARA para combatir y/o prevenir la ciberadicción.',
                  style: TextStyle(
                    fontFamily: 'FFMetaProText3',
                    color: Color(0xFF002856),
                  ),
                  textAlign: TextAlign.justify,
                ),
                SizedBox(height: 10), // Espacio entre párrafos
                Text(
                  '4. Protección de la Información',
                  style: TextStyle(
                    fontFamily: 'FFMetaProText3',
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF002856),
                  ),
                ),
                Text(
                  'Tomamos medidas de seguridad para proteger tu información personal contra el acceso no autorizado, alteración, divulgación o destrucción. Únicamente los miembros del equipo tienen acceso a la información.',
                  style: TextStyle(
                    fontFamily: 'FFMetaProText3',
                    color: Color(0xFF002856),
                  ),
                  textAlign: TextAlign.justify,
                ),
                SizedBox(height: 10), // Espacio entre párrafos
                Text(
                  '5. Compartir Información',
                  style: TextStyle(
                    fontFamily: 'FFMetaProText3',
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF002856),
                  ),
                ),
                Text(
                  'No vendemos ni compartimos tu información personal con terceros, excepto en los siguientes casos:\n '
                  '- Para cumplir con la ley o responder a solicitudes legales.\n'
                  '- Con tu consentimiento explícito.',
                  style: TextStyle(
                    fontFamily: 'FFMetaProText3',
                    color: Color(0xFF002856),
                  ),
                  textAlign: TextAlign.justify,
                ),
                SizedBox(height: 10), // Espacio entre párrafos
                Text(
                  '6. Retención de Datos',
                  style: TextStyle(
                    fontFamily: 'FFMetaProText3',
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF002856),
                  ),
                ),
                Text(
                  'Retendremos su información personal sólo durante el tiempo necesario para cumplir con los propósitos establecidos en esta política, o según lo requiera la ley.',
                  style: TextStyle(
                    fontFamily: 'FFMetaProText3',
                    color: Color(0xFF002856),
                  ),
                  textAlign: TextAlign.justify,
                ),
                SizedBox(height: 10), // Espacio entre párrafos
                Text(
                  '7. Derechos del Usuario',
                  style: TextStyle(
                    fontFamily: 'FFMetaProText3',
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF002856),
                  ),
                ),
                Text(
                  'Tienes el derecho de:\n '
                  '- Acceder a tu información personal.\n'
                  '- Solicitar la corrección de datos inexactos.\n'
                  '- Eliminar tu cuenta y la información asociada.\n',
                  style: TextStyle(
                    fontFamily: 'FFMetaProText3',
                    color: Color(0xFF002856),
                  ),
                  textAlign: TextAlign.justify,
                ),
                SizedBox(height: 10), // Espacio entre párrafos
                Text(
                  '8. Cambios en la Política de Privacidad',
                  style: TextStyle(
                    fontFamily: 'FFMetaProText3',
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF002856),
                  ),
                ),
                Text(
                  'Podemos actualizar esta Política de Privacidad en cualquier momento. Notificaremos a los usuarios sobre cambios significativos a través de la app o por correo electrónico.',
                  style: TextStyle(
                    fontFamily: 'FFMetaProText3',
                    color: Color(0xFF002856),
                  ),
                  textAlign: TextAlign.justify,
                ),
                SizedBox(height: 10), // Espacio entre párrafos
                Text(
                  '9. Soporte y Contacto',
                  style: TextStyle(
                    fontFamily: 'FFMetaProText3',
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF002856),
                  ),
                ),
                Text(
                  'Si tienes preguntas o inquietudes sobre esta política, puedes contactarnos a través del soporte en CIARA.',
                  style: TextStyle(
                    fontFamily: 'FFMetaProText3',
                    color: Color(0xFF002856),
                  ),
                  textAlign: TextAlign.justify,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text(
                'Volver',
                style: TextStyle(
                  fontFamily: 'FFMetaProText2',
                  fontSize: 15,
                  color: Colors.white, // Color del texto
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF002856), // Color de fondo
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 8.0), // Ajuste del padding
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  //Muestra el panel inicial
  void _showWelcomeModal(BuildContext context) {
    Future.delayed(const Duration(milliseconds: 600), () {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF002856),
        builder: (BuildContext context) {
          return FractionallySizedBox(
            heightFactor: 0.80,
            child: Container(
              padding: const EdgeInsets.all(50.0),
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
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Stack(
              children: [
                AlertDialog(
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
                          color: Color(0xFF002856),
                          fontFamily: 'FFMetaProText3',
                          fontSize: 16,
                        ),
                        keyboardType: TextInputType.emailAddress,
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
                              color: Color(0xFFA51008),
                            ),
                          ),
                          focusedBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Color(0xFFA51008),
                            ),
                          ),
                          errorText: errorMessage.isEmpty ? null : errorMessage,
                        ),
                      ),
                    ],
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: isLoading
                          ? null
                          : () {
                              Navigator.of(context).pop();
                            },
                      style: ElevatedButton.styleFrom(
                        primary: Colors.white,
                        onPrimary: Color(0xFF002856),
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
                      onPressed: isLoading
                          ? null
                          : () async {
                              String email = _emailController.text;
                              if (email.isEmpty ||
                                  !RegExp(r'^[^@]+@[^@]+\.[^@]+')
                                      .hasMatch(email)) {
                                setState(() {
                                  errorMessage =
                                      'Por favor ingrese un correo válido';
                                });
                                return;
                              }

                              setState(() {
                                isLoading = true;
                              });

                              try {
                                var url = Uri.parse(
                                    'https://ingsoftware.ucuenca.edu.ec/validar-email');
                                var response = await http.post(
                                  url,
                                  headers: {"Content-Type": "application/json"},
                                  body: json.encode({'email': email}),
                                );

                                if (response.statusCode == 200) {
                                  var responseBody = json.decode(response.body);
                                  if (responseBody['exists'] == true) {
                                    SharedPreferences prefs =
                                        await SharedPreferences.getInstance();
                                    prefs.setString('email', email);
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            UserPreferencesScreen(),
                                      ),
                                    );
                                  } else {
                                    setState(() {
                                      errorMessage =
                                          'Correo existente en otro proceso';
                                    });
                                  }
                                } else {
                                  setState(() {
                                    errorMessage =
                                        'Correo no registrado para el proyecto';
                                  });
                                }
                              } catch (e) {
                                setState(() {
                                  errorMessage = 'Error en la conexión';
                                });
                              } finally {
                                setState(() {
                                  isLoading = false;
                                });
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        primary: const Color(0xFF002856),
                        onPrimary: Colors.white,
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
                            'Cargando...',
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
                  )
              ],
            );
          },
        );
      },
    );
  }
}
