import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'profile_screen.dart';
import 'email_verification_screen.dart';
import 'log_in_log_up/registro.dart';
import 'variables_globales.dart';
import 'sales_history_screen.dart';
import 'codigo_verificacion_screen.dart';
import 'options_modal.dart';

// ✅ COLORES GLOBALES (MISMO QUE PERFIL)
final Color _blueDarkColor = const Color(0xFF0055B8);
final Color _approvedCardBackground = const Color(0xFFE8F0FE);

// ✅ ESTILOS ESTANDARIZADOS PARA SNACKBARS (MISMO COLOR GRIS)
void mostrarSnackBar(BuildContext context, String mensaje) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        mensaje,
        style: const TextStyle(color: Colors.white),
      ),
      backgroundColor: Colors.grey[800], // Color gris oscuro
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  );
}

// ✅ REINICIAR LA APLICACIÓN NAVEGANDO AL MAIN
void _reiniciarAplicacion(BuildContext context) {
  print('🔄 Reiniciando aplicación desde DashboardScreen...');

  Navigator.pushNamedAndRemoveUntil(
    context,
    '/',
        (route) => false,
  );

  if (Navigator.canPop(context)) {
    Navigator.popUntil(context, (route) => route.isFirst);
  }
}

class RutUtils {
  static String formatRut(String rut) {
    String cleanRut = rut.replaceAll('.', '').replaceAll('-', '');

    if (cleanRut.length < 2) return rut;

    String numero = cleanRut.substring(0, cleanRut.length - 1);
    String dv = cleanRut.substring(cleanRut.length - 1);

    String formatted = '';
    for (int i = numero.length - 1, j = 0; i >= 0; i--, j++) {
      if (j > 0 && j % 3 == 0) {
        formatted = '.$formatted';
      }
      formatted = numero[i] + formatted;
    }

    return '$formatted-$dv'.toUpperCase();
  }

  static bool validateRut(String rut) {
    if (rut.isEmpty) return false;

    try {
      String cleanRut = rut.replaceAll('.', '').replaceAll('-', '').toUpperCase();

      // ✅ VALIDACIÓN: RUT DEBE TENER AL MENOS 8 DÍGITOS (sin contar el DV)
      if (cleanRut.length < 9) return false; // Mínimo 8 dígitos + 1 DV

      String numero = cleanRut.substring(0, cleanRut.length - 1);
      String dv = cleanRut.substring(cleanRut.length - 1);

      // ✅ VALIDACIÓN: EL NÚMERO DEBE TENER AL MENOS 8 DÍGITOS
      if (numero.length < 8) return false;

      if (int.tryParse(numero) == null) return false;

      String expectedDv = _calculateDv(numero);

      return dv == expectedDv;
    } catch (e) {
      return false;
    }
  }

  static String _calculateDv(String numero) {
    int suma = 0;
    int multiplicador = 2;

    for (int i = numero.length - 1; i >= 0; i--) {
      suma += int.parse(numero[i]) * multiplicador;
      multiplicador = multiplicador == 7 ? 2 : multiplicador + 1;
    }

    int resto = suma % 11;
    String dv = (11 - resto).toString();

    if (dv == '11') return '0';
    if (dv == '10') return 'K';
    return dv;
  }

  static Map<String, String> parseRut(String rut) {
    String cleanRut = rut.replaceAll('.', '').replaceAll('-', '').toUpperCase();
    if (cleanRut.length < 2) return {'numero': '', 'dv': ''};

    String numero = cleanRut.substring(0, cleanRut.length - 1);
    String dv = cleanRut.substring(cleanRut.length - 1);

    return {'numero': numero, 'dv': dv};
  }

  // ✅ NUEVO MÉTODO: OBTENER RUN DEL USUARIO DE FORMA CORRECTA
  static Map<String, String> parseRunFromUserData(Map<String, dynamic> userData) {
    try {
      final runComprador = userData['comprador']?['run_comprador']?.toString() ?? '';
      final dvComprador = userData['comprador']?['dv_comprador']?.toString() ?? '';

      if (runComprador.isNotEmpty && dvComprador.isNotEmpty) {
        return {'numero': runComprador, 'dv': dvComprador};
      }

      // Si no viene separado, intentar parsear de un campo combinado
      final runCompleto = userData['comprador']?['run_completo']?.toString() ?? '';
      if (runCompleto.isNotEmpty) {
        return parseRut(runCompleto);
      }

      return {'numero': '', 'dv': ''};
    } catch (e) {
      return {'numero': '', 'dv': ''};
    }
  }

  // ✅ AGREGAR ESTE MÉTODO QUE FALTA:
  static String formatCurrency(int amount) {
    if (amount == 0) return '\$0';

    String amountStr = amount.toString();
    String formatted = '';
    int count = 0;

    for (int i = amountStr.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        formatted = '.$formatted';
      }
      formatted = amountStr[i] + formatted;
      count++;
    }

    return '\$$formatted';
  }
}

class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const DashboardScreen({super.key, required this.userData});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  Map<String, dynamic> _currentUserData = {};
  bool _isLoading = false;
  String? _empresaSeleccionada;
  DateTime? _lastProfileTap;
  List<Map<String, dynamic>> _autorizadores = [];

  // ✅ NUEVO: PageController para navegación horizontal con gestos
  late PageController _pageController;

  // ✅ NUEVO: Controlador para bloquear PageView durante modales
  bool _isModalOpen = false;
  int _lastPageBeforeModal = 0;

  // ✅ ANIMATION CONTROLLER PARA LA ANIMACIÓN DE LA LÍNEA DE CRÉDITO
  late AnimationController _animationController;
  late Animation<double> _animation;
  double _animatedMontoDisponible = 0.0;
  double _animatedMontoUtilizado = 0.0;

  // ✅ NUEVO: Estado para mensaje de línea de crédito
  bool _mostrarMensajeLineaCredito = false;

  @override
  void initState() {
    super.initState();
    _currentUserData = widget.userData;
    _inicializarEmpresaSeleccionada();
    _verificarSesionActualizada();

    // ✅ INICIALIZAR PAGE CONTROLLER CON UNA SOLA INSTANCIA
    _pageController = PageController(initialPage: _currentIndex);

    // ✅ INICIALIZAR ANIMATION CONTROLLER
    _animationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );

    // Iniciar animación cuando se construye la pantalla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _iniciarAnimacion();
    });

    print('🎯 DashboardScreen iniciado con datos iniciales:');
    _printUserData();
  }

  // ✅ MÉTODO: INICIALIZAR EMPRESA SELECCIONADA
  void _inicializarEmpresaSeleccionada() {
    final empresas = _currentUserData['empresas'] ?? [];
    if (empresas.isNotEmpty) {
      final primeraEmpresa = empresas[0];
      _empresaSeleccionada = primeraEmpresa['token_empresa'];
    }
  }

  // ✅ MÉTODO: IMPRIMIR DATOS DEL USUARIO
  void _printUserData() {
    print('👤 DATOS USUARIO:');
    print('- Comprador: ${_currentUserData['comprador']?['alias_comprador']}');
    print('- Estado comprador: ${_currentUserData['comprador']?['estado_comprador']}');
    print('- Dispositivo actual: ${_currentUserData['dispositivo_actual'] != null}');
    print('- Sesión iniciada: ${_currentUserData['sesion_iniciada']}');
    print('- Empresa seleccionada: $_empresaSeleccionada');

    final runParseado = RutUtils.parseRunFromUserData(_currentUserData);
    print('- RUN comprador: ${runParseado['numero']}-${runParseado['dv']}');
  }

  // ✅ NUEVO MÉTODO: INICIAR ANIMACIÓN
  void _iniciarAnimacion() {
    _actualizarValoresAnimados();
    if (mounted) {
      _animationController.reset();
      _animationController.forward();
    }
  }

  // ✅ NUEVO MÉTODO: ACTUALIZAR VALORES ANIMADOS
  void _actualizarValoresAnimados() {
    final lineaCreditoData = _getLineaCreditoData();
    final int montoDisponible = lineaCreditoData['monto_disponible'] as int;
    final int montoUtilizado = lineaCreditoData['monto_utilizado'] as int;

    // Crear un Tween para cada valor
    final montoDisponibleTween = Tween<double>(
      begin: 0.0,
      end: montoDisponible.toDouble(),
    );

    final montoUtilizadoTween = Tween<double>(
      begin: 0.0,
      end: montoUtilizado.toDouble(),
    );

    // Escuchar la animación y actualizar los valores
    _animation.addListener(() {
      if (mounted) {
        setState(() {
          _animatedMontoDisponible = montoDisponibleTween.transform(_animation.value);
          _animatedMontoUtilizado = montoUtilizadoTween.transform(_animation.value);
        });
      }
    });
  }

  @override
  void dispose() {
    // ✅ DISPONER DEL PAGE CONTROLLER
    _pageController.dispose();

    // ✅ DISPONER DEL ANIMATION CONTROLLER
    _animationController.dispose();
    super.dispose();
  }

  // ✅ MÉTODO PARA RESETEAR ESTADO DE MODAL
  void _resetModalState() {
    if (mounted) {
      setState(() {
        _isModalOpen = false;
        _lastPageBeforeModal = _currentIndex;
      });
    }
  }

  // ✅ MÉTODO MEJORADO: VERIFICAR SESIÓN ACTUALIZADA
  Future<void> _verificarSesionActualizada() async {
    try {
      if (_currentIndex == 0) {
        setState(() {
          _isLoading = true;
        });
      }

      print('🔄 Verificando sesión actualizada...');

      // ✅ GUARDAR EMPRESA ACTUAL ANTES DE LA ACTUALIZACIÓN
      final empresaSeleccionadaActual = _empresaSeleccionada;

      // Obtener token FCM
      await Firebase.initializeApp();
      String? fcmToken = await FirebaseMessaging.instance.getToken();
      final String deviceToken = fcmToken ?? 'fcm_fallback_${DateTime.now().millisecondsSinceEpoch}';

      final response = await http.post(
        Uri.parse('${GlobalVariables.baseUrl}/SesionIniciada/api/v1/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'api-key': GlobalVariables.apiKey,
        },
        body: json.encode({
          "token_dispositivo": deviceToken,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final bool sesionIniciada = responseData['sesion_iniciada'] == true;

        // ✅ VERIFICAR SI LA SESIÓN HA EXPIRADO
        if (responseData['success'] == false && responseData['sesion_iniciada'] == false) {
          mostrarSnackBar(context, 'Sesión cerrada. Por favor, inicia sesión nuevamente.');
          _reiniciarAplicacion(context);
          return;
        }

        if (sesionIniciada) {
          print('✅ Sesión actualizada detectada, actualizando datos...');

          // ✅ ACTUALIZAR DATOS PERO MANTENER LA EMPRESA SELECCIONADA
          setState(() {
            _currentUserData = responseData;

            // ✅ VERIFICAR SI LA EMPRESA SELECCIONADA SIGUE EXISTIENDO EN LOS NUEVOS DATOS
            if (empresaSeleccionadaActual != null) {
              final empresasNuevas = responseData['empresas'] ?? [];
              final empresaExiste = empresasNuevas.any((empresa) => empresa['token_empresa'] == empresaSeleccionadaActual);

              if (empresaExiste) {
                // ✅ MANTENER LA MISMA EMPRESA SELECCIONADA
                _empresaSeleccionada = empresaSeleccionadaActual;
                print('✅ Empresa seleccionada mantenida: $_empresaSeleccionada');
              } else {
                // ✅ SI LA EMPRESA YA NO EXISTE, SELECCIONAR LA PRIMERA DISPONIBLE
                if (empresasNuevas.isNotEmpty) {
                  _empresaSeleccionada = empresasNuevas[0]['token_empresa'];
                  print('⚠️ Empresa anterior ya no existe. Nueva selección: $_empresaSeleccionada');
                } else {
                  _empresaSeleccionada = null;
                  print('⚠️ No hay empresas disponibles después del refresh');
                }
              }
            } else {
              // ✅ SI NO HABÍA EMPRESA SELECCIONADA, INICIALIZAR UNA
              _inicializarEmpresaSeleccionada();
            }

            // ✅ VERIFICAR SI DEBEMOS MOSTRAR EL MENSAJE DE LÍNEA DE CRÉDITO
            _verificarMostrarMensajeLineaCredito();
          });

          // ✅ ACTUALIZAR VALORES ANIMADOS Y REINICIAR ANIMACIÓN
          _actualizarValoresAnimados();
          _iniciarAnimacion();
        }
      } else if (response.statusCode == 401) {
        // ✅ SESIÓN EXPIRADA POR STATUS 401
        print('🔐 Sesión expirada (401 Unauthorized)');
        mostrarSnackBar(context, 'Sesión cerrada. Por favor, inicia sesión nuevamente.');
        _reiniciarAplicacion(context);
      }
    } catch (e) {
      print('❌ Error verificando sesión actualizada: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ✅ MÉTODO: VERIFICAR SI DEBEMOS MOSTRAR EL MENSAJE DE LÍNEA DE CRÉDITO
  void _verificarMostrarMensajeLineaCredito() {
    final lineaCreditoData = _getLineaCreditoData();
    final bool tieneLineaCredito = lineaCreditoData['tiene_linea_credito'] as bool;
    final bool relacionValida = _esRelacionValida();

    setState(() {
      _mostrarMensajeLineaCredito = !tieneLineaCredito && !relacionValida;
    });
  }

  // ✅ MÉTODO SIMPLIFICADO: PULL TO REFRESH
  Future<void> _onRefresh() async {
    print('🔄 Pull to refresh activado');

    try {
      await _verificarSesionActualizada();
    } catch (e) {
      print('❌ Error durante refresh: $e');
    }
  }

  // ✅ MÉTODO SIMPLIFICADO PARA MOSTRAR OPCIONES
  void _showOptionsMenu() {
    OptionsModal.show(
      context: context,
      userData: _currentUserData,
      empresaSeleccionada: _empresaSeleccionada,
      onCambiarEmpresa: _cambiarEmpresaConActualizacion,
      onAgregarEmpresa: _agregarNuevaEmpresa,
      onAsignarAutorizador: _asignarNuevoAutorizador,
      onMostrarAutorizadores: () {
        _resetModalState();
        _mostrarListaAutorizadores();
      },
      onReiniciarApp: () => _reiniciarAplicacion(context),
      onActualizarVista: () {
        // ✅ SOLO ACTUALIZAR EL ESTADO ACTUAL SIN RECARGAR TODO
        setState(() {
          // Forzar rebuild del estado actual
        });
      },
    ).then((_) {
      _resetModalState();
    });
  }

  // ✅ MÉTODO OPTIMIZADO: CAMBIAR EMPRESA CON ACTUALIZACIÓN DE VISTA
  void _cambiarEmpresaConActualizacion(String nuevaEmpresaToken) {
    print('🔄 Cambiando empresa con actualización de vista...');
    print('🎯 Nueva empresa seleccionada: $nuevaEmpresaToken');

    // Primero verificar si es una empresa diferente
    if (_empresaSeleccionada == nuevaEmpresaToken) {
      mostrarSnackBar(context, 'Ya tienes seleccionada esta empresa');
      return;
    }

    // Obtener nombre de la nueva empresa para mostrar en el mensaje
    String nombreNuevaEmpresa = 'Nueva empresa';
    final empresas = _currentUserData['empresas'] ?? [];
    for (var emp in empresas) {
      if (emp['token_empresa'] == nuevaEmpresaToken) {
        nombreNuevaEmpresa = emp['nombre_empresa']?.toString() ??
            'Empresa ${emp['rut_empresa']}-${emp['dv_rut_empresa']}';
        break;
      }
    }

    // Cambiar la empresa
    setState(() {
      _empresaSeleccionada = nuevaEmpresaToken;
    });

    mostrarSnackBar(context, 'Cambiando a: $nombreNuevaEmpresa');

    // ✅ ACTUALIZAR VALORES ANIMADOS Y REINICIAR ANIMACIÓN
    _actualizarValoresAnimados();
    _iniciarAnimacion();

    // ✅ VERIFICAR SI DEBEMOS MOSTRAR EL MENSAJE DE LÍNEA DE CRÉDITO
    _verificarMostrarMensajeLineaCredito();

    // ✅ LA VISTA DE COMPRAS SE RECARGARÁ AUTOMÁTICAMENTE
    // gracias al didUpdateWidget en SalesHistoryScreen
    print('✅ Empresa cambiada. SalesHistoryScreen se recargará automáticamente.');
  }

  // ✅ NUEVO MÉTODO: OBTENER EMPRESA SELECCIONADA
  Map<String, dynamic>? _getEmpresaSeleccionada() {
    if (_empresaSeleccionada == null) return null;

    final empresas = _currentUserData['empresas'] ?? [];
    for (var emp in empresas) {
      if (emp['token_empresa'] == _empresaSeleccionada) {
        return emp;
      }
    }
    return null;
  }

  // ✅ NUEVO MÉTODO: VERIFICAR SI LA RELACIÓN ES VÁLIDA
  bool _esRelacionValida() {
    final empresa = _getEmpresaSeleccionada();
    if (empresa == null || empresa.isEmpty) return false;

    final validezRelacion = empresa['validez_relacion']?.toString().toLowerCase() ?? '';
    return !validezRelacion.contains('no válida');
  }

  // ✅ MÉTODO ACTUALIZADO: CAMBIAR EMPRESA SIN REDIRIGIR (mantener por compatibilidad)
  void _cambiarEmpresaSinRedirigir(String nuevaEmpresaToken) {
    _cambiarEmpresaConActualizacion(nuevaEmpresaToken);
  }

  // ✅ MÉTODO ACTUALIZADO: AGREGAR NUEVA EMPRESA (API v2)
  Future<void> _agregarNuevaEmpresa(String rut, String tipoRelacion) async {
    print('🔄 Agregando nueva empresa con RUT: $rut');

    try {
      setState(() {
        _isLoading = true;
      });

      // Parsear RUT ingresado
      final rutParseado = RutUtils.parseRut(rut);
      final rutEmpresa = rutParseado['numero'] ?? '';
      final dvEmpresa = rutParseado['dv'] ?? '';

      if (rutEmpresa.isEmpty || dvEmpresa.isEmpty) {
        mostrarSnackBar(context, 'RUT inválido');
        return;
      }

      // ✅ VALIDACIÓN: VERIFICAR SI EL RUT YA EXISTE
      if (_rutEmpresaYaExiste(rutEmpresa, dvEmpresa)) {
        mostrarSnackBar(context, 'Esta empresa ya está registrada en tu cuenta');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final tokenComprador = _getTokenComprador();

      if (tokenComprador.isEmpty) {
        mostrarSnackBar(context, 'Error: No se pudo obtener el token del comprador');
        return;
      }

      // ✅ OBTENER TOKEN DEL DISPOSITIVO (FCM)
      String? deviceToken;
      try {
        await Firebase.initializeApp();
        deviceToken = await FirebaseMessaging.instance.getToken();

        if (deviceToken == null) {
          deviceToken = 'fcm_fallback_${DateTime.now().millisecondsSinceEpoch}';
        }
      } catch (e) {
        print('❌ Error obteniendo token FCM: $e');
        deviceToken = 'fcm_error_${DateTime.now().millisecondsSinceEpoch}';
      }

      print('🔄 Iniciando llamada a API AgregarEmpresaComprador (v2)...');
      print('📤 Request body:');
      print('  - token_comprador: $tokenComprador');
      print('  - rut_empresa: $rutEmpresa');
      print('  - dv_rut_empresa: $dvEmpresa');
      print('  - tipo_relacion: $tipoRelacion');
      print('  - token_dispositivo: $deviceToken');
      print('🌐 URL: ${GlobalVariables.baseUrl}/AgregarEmpresaComprador/api/v2/');

      final response = await http.post(
        Uri.parse('${GlobalVariables.baseUrl}/AgregarEmpresaComprador/api/v2/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'api-key': GlobalVariables.apiKey,
        },
        body: json.encode({
          "token_comprador": tokenComprador,
          "rut_empresa": rutEmpresa,
          "dv_rut_empresa": dvEmpresa,
          "tipo_relacion": tipoRelacion,
          "token_dispositivo": deviceToken,
        }),
      ).timeout(const Duration(seconds: 15));

      print('📥 Response recibido:');
      print('  - Status Code: ${response.statusCode}');
      print('  - Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // ✅ VERIFICAR SI LA SESIÓN HA EXPIRADO
        if (responseData['success'] == false && responseData['sesion_iniciada'] == false) {
          mostrarSnackBar(context, 'Sesión cerrada. Por favor, inicia sesión nuevamente.');
          _reiniciarAplicacion(context);
          return;
        }

        if (responseData['success'] == true) {
          mostrarSnackBar(context, 'Empresa agregada exitosamente');
          // Actualizar datos del usuario
          await _verificarSesionActualizada();
        } else {
          final mensajeError = responseData['message'] ?? responseData['error'] ?? 'Error al agregar empresa';
          mostrarSnackBar(context, mensajeError);
        }
      } else if (response.statusCode == 401) {
        // ✅ SESIÓN EXPIRADA POR STATUS 401
        print('🔐 Sesión expirada (401 Unauthorized)');
        mostrarSnackBar(context, 'Sesión cerrada. Por favor, inicia sesión nuevamente.');
        _reiniciarAplicacion(context);
      } else {
        print('❌ Error en API AgregarEmpresaComprador - Status: ${response.statusCode}');
        mostrarSnackBar(context, 'Error al agregar empresa: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error agregando nueva empresa: $e');
      mostrarSnackBar(context, 'Error de conexión: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ✅ MÉTODO ACTUALIZADO: ASIGNAR NUEVO AUTORIZADOR (API v2)
  Future<void> _asignarNuevoAutorizador(String run) async {
    print( 'Función manejada por el diálogo de opciones');
    return;
  }

  // ✅ MÉTODO: MOSTRAR LISTA DE AUTORIZADORES (PANTALLA COMPLETA) - CORREGIDO
  void _mostrarListaAutorizadores() {
    print('🔄 Abriendo pantalla de autorizadores...');

    // Asegurarnos de que el estado esté limpio antes de navegar
    if (_isModalOpen) {
      _resetModalState();
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OptionsModal.crearVistaAutorizadores(
          context: context,
          userData: _currentUserData,
          empresaSeleccionada: _empresaSeleccionada,
          onAsignarAutorizador: _asignarNuevoAutorizador,
          onActualizarAutorizadores: _obtenerAutorizadores,
          onVolver: () => Navigator.pop(context),
          onReiniciarApp: () => _reiniciarAplicacion(context),
        ),
      ),
    ).then((_) {
      // Limpiar estado cuando regresemos
      _resetModalState();
    });
  }

  // ✅ MÉTODO ACTUALIZADO: OBTENER AUTORIZADORES (API v2)
  Future<List<Map<String, dynamic>>> _obtenerAutorizadores() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final empresa = _getEmpresaSeleccionada();
      if (empresa == null || empresa.isEmpty) {
        mostrarSnackBar(context, 'No hay empresa seleccionada');
        return [];
      }

      final tokenEmpresa = empresa['token_empresa']?.toString() ?? '';
      final tokenRepresentante = _getTokenComprador();

      if (tokenRepresentante.isEmpty || tokenEmpresa.isEmpty) {
        mostrarSnackBar(context, 'No se pudo obtener la información necesaria');
        return [];
      }

      // ✅ OBTENER TOKEN DEL DISPOSITIVO (FCM)
      String? deviceToken;
      try {
        await Firebase.initializeApp();
        deviceToken = await FirebaseMessaging.instance.getToken();

        if (deviceToken == null) {
          deviceToken = 'fcm_fallback_${DateTime.now().millisecondsSinceEpoch}';
        }
      } catch (e) {
        print('❌ Error obteniendo token FCM: $e');
        deviceToken = 'fcm_error_${DateTime.now().millisecondsSinceEpoch}';
      }

      // Construir la URL usando la baseUrl de variables globales
      final String apiUrl = '${GlobalVariables.baseUrl}/ListarAutorizadores/api/v2/';

      // Preparar el body del request
      final requestBody = {
        'token_representante': tokenRepresentante,
        'token_empresa': tokenEmpresa,
        'token_dispositivo': deviceToken!,
      };

      print('══════════════════════════════════════════════════════════════');
      print('📡 [API REQUEST] - ListarAutorizadores (v2)');
      print('├─ URL: $apiUrl');
      print('├─ Headers:');
      print('│  ├─ Content-Type: application/json');
      print('│  └─ api-key: ${GlobalVariables.apiKey}');
      print('└─ Body: ${jsonEncode(requestBody)}');
      print('══════════════════════════════════════════════════════════════');

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'api-key': GlobalVariables.apiKey,
        },
        body: jsonEncode(requestBody),
      );

      print('══════════════════════════════════════════════════════════════');
      print('📡 [API RESPONSE] - ListarAutorizadores (v2)');
      print('├─ Status Code: ${response.statusCode}');
      print('└─ Body: ${response.body}');
      print('══════════════════════════════════════════════════════════════');

      List<Map<String, dynamic>> nuevaLista = [];

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // ✅ VERIFICAR SI LA SESIÓN HA EXPIRADA
        if (data['success'] == false && data['sesion_iniciada'] == false) {
          mostrarSnackBar(context, 'Sesión cerrada. Por favor, inicia sesión nuevamente.');
          _reiniciarAplicacion(context);
          return [];
        }

        if (data.containsKey('autorizadores_designados') &&
            data['autorizadores_designados'] is List) {
          final List<dynamic> autorizadoresData = data['autorizadores_designados'];

          nuevaLista = autorizadoresData.map((item) {
            final runNumero = item['run_comprador']?.toString() ?? '';
            final runDv = item['dv_run_comprador']?.toString() ?? '1';
            final runCompleto = '$runNumero-$runDv';
            final runFormateado = RutUtils.formatRut(runCompleto);

            return {
              'nombre': item['nombre_comprador']?.toString() ?? 'Sin nombre',
              'run': runFormateado,
              'run_numero': runNumero,
              'run_dv': runDv,
              'email': item['correo_comprador']?.toString() ?? '',
              'estado': item['estado_comprador']?.toString() == '1' ? 'activo' : 'inactivo',
              'token': item['token_comprador']?.toString() ?? '',
            };
          }).toList();
        } else {
          nuevaLista = [];
        }
      } else if (response.statusCode == 401) {
        // ✅ SESIÓN EXPIRADA POR STATUS 401
        print('🔐 Sesión expirada (401 Unauthorized)');
        mostrarSnackBar(context, 'Sesión cerrada. Por favor, inicia sesión nuevamente.');
        _reiniciarAplicacion(context);
        return [];
      } else {
        print('❌ [ERROR API] - Status Code: ${response.statusCode}');
        mostrarSnackBar(context, 'Error al cargar autorizadores: ${response.statusCode}');
        nuevaLista = [];
      }

      setState(() {
        _autorizadores = nuevaLista;
      });

      return nuevaLista;
    } catch (e) {
      print('❌ [EXCEPCIÓN] - Error en _obtenerAutorizadores: $e');
      print('══════════════════════════════════════════════════════════════');
      mostrarSnackBar(context, 'Error de conexión: $e');
      setState(() {
        _autorizadores = [];
      });
      return [];
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ✅ MÉTODO: ELIMINAR AUTORIZADOR
  void _eliminarAutorizador(Map<String, dynamic> autorizador) {
    print('🗑️ Eliminando autorizador: ${autorizador['nombre']}');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Eliminar Autorizador',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _blueDarkColor,
          ),
        ),
        content: Text(
          '¿Estás seguro de que quieres eliminar a ${autorizador['nombre']} como autorizador?',
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey,
            ),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _cambiarValidezAutorizador(autorizador);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _blueDarkColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Confirmar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ MÉTODO ACTUALIZADO: CAMBIAR VALIDEZ DEL AUTORIZADOR (API v2)
  Future<void> _cambiarValidezAutorizador(Map<String, dynamic> autorizador) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final empresa = _getEmpresaSeleccionada();
      if (empresa == null || empresa.isEmpty) {
        mostrarSnackBar(context, 'No hay empresa seleccionada');
        return;
      }

      final rutEmpresa = empresa['rut_empresa']?.toString() ?? '';
      final dvEmpresa = empresa['dv_rut_empresa']?.toString() ?? '';
      final tokenRepresentante = _getTokenComprador();
      final runAutorizador = autorizador['run_numero'] ?? '';
      final dvRunAutorizador = autorizador['run_dv'] ?? '';

      if (tokenRepresentante.isEmpty || runAutorizador.isEmpty || dvRunAutorizador.isEmpty ||
          rutEmpresa.isEmpty || dvEmpresa.isEmpty) {
        mostrarSnackBar(context, 'Faltan datos para eliminar el autorizador');
        return;
      }

      // ✅ OBTENER TOKEN DEL DISPOSITIVO (FCM)
      String? deviceToken;
      try {
        await Firebase.initializeApp();
        deviceToken = await FirebaseMessaging.instance.getToken();

        if (deviceToken == null) {
          deviceToken = 'fcm_fallback_${DateTime.now().millisecondsSinceEpoch}';
        }
      } catch (e) {
        print('❌ Error obteniendo token FCM: $e');
        deviceToken = 'fcm_error_${DateTime.now().millisecondsSinceEpoch}';
      }

      // Construir la URL usando la baseUrl de variables globales
      final String apiUrl = '${GlobalVariables.baseUrl}/CambiarValidezCompradorDesignado/api/v2/';

      // Preparar el body del request
      final requestBody = {
        'token_representante': tokenRepresentante,
        'run_autorizador': runAutorizador,
        'dv_run_autorizador': dvRunAutorizador,
        'rut_empresa_autorizador': rutEmpresa,
        'dv_rut_empresa_autorizador': dvEmpresa,
        'token_dispositivo': deviceToken!,
      };

      print('══════════════════════════════════════════════════════════════');
      print('📡 [API REQUEST] - CambiarValidezCompradorDesignado (v2)');
      print('├─ URL: $apiUrl');
      print('├─ Headers:');
      print('│  ├─ Content-Type: application/json');
      print('│  └─ api-key: ${GlobalVariables.apiKey}');
      print('└─ Body: ${jsonEncode(requestBody)}');
      print('══════════════════════════════════════════════════════════════');

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'api-key': GlobalVariables.apiKey,
        },
        body: jsonEncode(requestBody),
      );

      print('══════════════════════════════════════════════════════════════');
      print('📡 [API RESPONSE] - CambiarValidezCompradorDesignado (v2)');
      print('├─ Status Code: ${response.statusCode}');
      print('└─ Body: ${response.body}');
      print('══════════════════════════════════════════════════════════════');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // ✅ VERIFICAR SI LA SESIÓN HA EXPIRADA
        if (data['success'] == false && data['sesion_iniciada'] == false) {
          mostrarSnackBar(context, 'Sesión cerrada. Por favor, inicia sesión nuevamente.');
          _reiniciarAplicacion(context);
          return;
        }

        final mensaje = data['message'] ?? data['mensaje'] ?? 'Autorizador eliminado correctamente';
        print('✅ [SUCCESS] - $mensaje');
        mostrarSnackBar(context, mensaje);
        // Recargar la lista de autorizadores
        await _obtenerAutorizadores();
      } else if (response.statusCode == 401) {
        // ✅ SESIÓN EXPIRADA POR STATUS 401
        print('🔐 Sesión expirada (401 Unauthorized)');
        mostrarSnackBar(context, 'Sesión cerrada. Por favor, inicia sesión nuevamente.');
        _reiniciarAplicacion(context);
        return;
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['message'] ?? errorData['mensaje'] ?? 'Error al eliminar autorizador';
        print('❌ [ERROR API] - $errorMessage (${response.statusCode})');
        mostrarSnackBar(context, '$errorMessage (${response.statusCode})');
      }
    } catch (e) {
      print('❌ [EXCEPCIÓN] - Error en _cambiarValidezAutorizador: $e');
      print('══════════════════════════════════════════════════════════════');
      mostrarSnackBar(context, 'Error de conexión: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ✅ MÉTODO: HOME SCREEN CON REFRESH
  Widget _buildHomeScreenWithRefresh() {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: _blueDarkColor,
      backgroundColor: Colors.white,
      displacement: 40,
      child: _buildHomeScreenContent(),
    );
  }

  // ✅ MÉTODO: HOME SCREEN CONTENT
  Widget _buildHomeScreenContent() {
    final int userStatus = _getUserStatus();
    final lineaCreditoData = _getLineaCreditoData();

    final bool tieneLineaCredito = lineaCreditoData['tiene_linea_credito'] as bool;
    final bool lineaValida = lineaCreditoData['linea_valida'] as bool;
    final bool relacionValida = _esRelacionValida();

    final int montoTotal = lineaCreditoData['monto_total'] as int;
    final int montoUtilizado = lineaCreditoData['monto_utilizado'] as int;
    final int montoDisponible = lineaCreditoData['monto_disponible'] as int;
    final double porcentajeUtilizado = _getPorcentajeUtilizado();

    final empresaInfoWidget = _buildEmpresaInfo();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      physics: const ClampingScrollPhysics(),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¡Hola, ${_getUserName()}! 👋',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _blueDarkColor,
                ),
              ),
              if (empresaInfoWidget is! SizedBox) ...[
                const SizedBox(height: 4),
                empresaInfoWidget,
              ],
              if (userStatus >= 3) ...[
                const SizedBox(height: 4),
                _buildRelacionInfo(),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (userStatus == 1)
          _buildVerificationSection(
            icon: Icons.email_outlined,
            title: 'Verificación de correo electrónico',
            subtitle: 'Hemos enviado un código de verificación a tu correo.',
            buttonText: 'Verificar',
            onPressed: _verifyEmail,
            color: _blueDarkColor,
          )
        else if (userStatus == 2)
          _buildVerificationSection(
            icon: Icons.verified_user_outlined,
            title: 'Verificación de identidad',
            subtitle: 'Completa la verificación de identidad para acceder a todas las funcionalidades de la plataforma.',
            buttonText: 'Verificar',
            onPressed: _verifyIdentity,
            color: _blueDarkColor,
          ),

        if (userStatus >= 3 && _empresaSeleccionada != null && lineaValida) ...[
          const SizedBox(height: 16),

          _buildTarjetaMontoDisponible(
            montoDisponible: montoDisponible,
            montoTotal: montoTotal,
            montoUtilizado: montoUtilizado,
            porcentajeUtilizado: porcentajeUtilizado,
          ),

          if (relacionValida &&
              (lineaCreditoData['fecha_asignacion'] != '' ||
                  lineaCreditoData['fecha_caducidad'] != '')) ...[
            _buildTarjetaFechas(lineaCreditoData),
          ],

          const SizedBox(height: 24),
        ],

        if (userStatus >= 3 && _empresaSeleccionada != null) ...[
          if (tieneLineaCredito && !relacionValida) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tienes línea de crédito pero tu relación con la empresa no es válida',
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ]

          else if (!tieneLineaCredito && relacionValida) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tu relación con la empresa es válida, pero no tienes línea de crédito asignada',
                      style: TextStyle(
                        color: Colors.blue.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ]

          else if (_mostrarMensajeLineaCredito) ...[
              // ✅ NUEVO: CONTENEDOR CON BOTÓN DE RECARGAR
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.grey.shade600),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'La empresa seleccionada no tiene línea de crédito disponible',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ✅ BOTÓN DE RECARGAR VISTA
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          print('🔄 Recargando vista desde botón...');
                          _verificarSesionActualizada();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _blueDarkColor, // ← Mismo azul oscuro
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Recargar Vista',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
        ],
      ],
    );
  }

  // ✅ MÉTODO: OBTENER ESTADO DEL USUARIO
  int _getUserStatus() {
    try {
      if (_currentUserData['comprador'] != null &&
          _currentUserData['comprador']['estado_comprador'] != null) {
        return _currentUserData['comprador']['estado_comprador'] as int;
      }
      return 1;
    } catch (e) {
      return 1;
    }
  }

  // ✅ MÉTODO: OBTENER NOMBRE DEL USUARIO
  String _getUserName() {
    try {
      if (_currentUserData['comprador'] != null &&
          _currentUserData['comprador']['alias_comprador'] != null) {
        return _currentUserData['comprador']['alias_comprador'].toString();
      }

      if (_currentUserData['comprador'] != null &&
          _currentUserData['comprador']['correo_comprador'] != null) {
        String email = _currentUserData['comprador']['correo_comprador'].toString();
        return email.split('@').first;
      }

      return 'Usuario';
    } catch (e) {
      return 'Usuario';
    }
  }

  // ✅ MÉTODO: OBTENER EMAIL DEL USUARIO
  String _getUserEmail() {
    try {
      if (_currentUserData['comprador'] != null &&
          _currentUserData['comprador']['correo_comprador'] != null) {
        return _currentUserData['comprador']['correo_comprador'].toString();
      }
      return 'No disponible';
    } catch (e) {
      return 'No disponible';
    }
  }

  // ✅ MÉTODO: MOSTRAR EMPRESA SELECCIONADA
  Widget _buildEmpresaInfo() {
    final empresa = _getEmpresaSeleccionada();

    if (empresa == null || empresa.isEmpty) {
      return const SizedBox.shrink();
    }

    final nombreEmpresa = empresa['nombre_empresa']?.toString() ?? '';
    if (nombreEmpresa.isEmpty) {
      return const SizedBox.shrink();
    }

    final validezRelacion = empresa['validez_relacion']?.toString().toLowerCase() ?? '';
    if (validezRelacion.contains('no válida')) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        nombreEmpresa,
        style: TextStyle(
          fontSize: 16,
          color: Colors.grey.shade700,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // ✅ MÉTODO: CONSTRUIR INDICADOR DE RELACIÓN
  Widget _buildRelacionInfo() {
    final esValida = _esRelacionValida();
    final String texto = esValida ? 'Relación válida' : 'Relación no válida';
    final Color iconColor = esValida ? const Color(0xFF4CAF50) : const Color(0xFF9E9E9E);
    final IconData icon = esValida ? Icons.check_circle : Icons.cancel;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: iconColor,
        ),
        const SizedBox(width: 4),
        Text(
          texto,
          style: TextStyle(
            fontSize: 12,
            color: iconColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ✅ MÉTODO: FORMATEAR MONEDA
  String _formatCurrency(int amount) {
    return RutUtils.formatCurrency(amount);
  }

  // ✅ MÉTODO: OBTENER DATOS DE LÍNEA DE CRÉDITO
  Map<String, dynamic> _getLineaCreditoData() {
    try {
      final lineasCredito = _currentUserData['lineas_credito'] ?? [];

      if (_empresaSeleccionada != null) {
        for (int i = 0; i < lineasCredito.length; i++) {
          final linea = lineasCredito[i];
          final empresaLinea = linea['empresa'];
          final tokenEmpresaLinea = empresaLinea?['token_empresa'];

          if (tokenEmpresaLinea == _empresaSeleccionada) {
            final montoTotal = linea['monto_linea_credito'] ?? 0;
            final montoUtilizado = linea['monto_utilizado'] ?? 0;
            final montoDisponible = linea['monto_disponible'] ?? montoTotal;

            final tieneLineaCredito = montoTotal > 0;
            final empresa = _getEmpresaSeleccionada();
            final relacionValida = empresa != null ? _esRelacionValida() : false;

            return {
              'monto_total': montoTotal,
              'monto_utilizado': montoUtilizado,
              'monto_disponible': montoDisponible,
              'fecha_asignacion': linea['fecha_asignacion'] ?? '',
              'fecha_caducidad': linea['fecha_caducidad'] ?? '',
              'tiene_linea_credito': tieneLineaCredito,
              'linea_valida': tieneLineaCredito && relacionValida,
            };
          }
        }
      }

      return {
        'monto_total': 0,
        'monto_utilizado': 0,
        'monto_disponible': 0,
        'fecha_asignacion': '',
        'fecha_caducidad': '',
        'tiene_linea_credito': false,
        'linea_valida': false,
      };
    } catch (e) {
      return {
        'monto_total': 0,
        'monto_utilizado': 0,
        'monto_disponible': 0,
        'fecha_asignacion': '',
        'fecha_caducidad': '',
        'tiene_linea_credito': false,
        'linea_valida': false,
      };
    }
  }

  // ✅ MÉTODO: CALCULAR PORCENTAJE UTILIZADO
  double _getPorcentajeUtilizado() {
    final data = _getLineaCreditoData();
    final montoTotal = data['monto_total'] as int;
    final montoUtilizado = data['monto_utilizado'] as int;

    if (montoTotal == 0) return 0.0;
    return montoUtilizado / montoTotal;
  }

  // ✅ MÉTODO: OBTENER TOKEN DEL COMPRADOR
  String _getTokenComprador() {
    try {
      return _currentUserData['comprador']?['token_comprador'] ?? '';
    } catch (e) {
      return '';
    }
  }

  // ✅ MÉTODO: OBTENER TOKEN DEL DISPOSITIVO
  String _getTokenDispositivo() {
    try {
      return _currentUserData['dispositivo_actual']?['token_dispositivo'] ??
          _currentUserData['dispositivos']?[0]?['token_dispositivo'] ?? '';
    } catch (e) {
      return '';
    }
  }

  // ✅ MÉTODO: LOGOUT
  Future<void> _logout() async {
    try {
      print('🚪 Cerrando sesión...');

      final String tokenComprador = _getTokenComprador();
      final String tokenDispositivo = _getTokenDispositivo();

      final response = await http.post(
        Uri.parse('${GlobalVariables.baseUrl}/CerrarSesion/api/v1/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'api-key': GlobalVariables.apiKey,
        },
        body: json.encode({
          "token_comprador": tokenComprador,
          "token_dispositivo": tokenDispositivo,
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Sesión cerrada exitosamente');
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      } else {
        print('❌ Error al cerrar sesión: ${response.statusCode}');
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      }
    } catch (e) {
      print('❌ Error de conexión al cerrar sesión: $e');
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    }
  }

  // ✅ MÉTODO: TARJETA DE MONTO DISPONIBLE CON ANIMACIÓN
  Widget _buildTarjetaMontoDisponible({
    required int montoDisponible,
    required int montoTotal,
    required int montoUtilizado,
    required double porcentajeUtilizado,
  }) {
    final double porcentajeUtilizadoAnimado = montoTotal > 0
        ? _animatedMontoUtilizado / montoTotal.toDouble()
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            blurRadius: 3,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide.none,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _approvedCardBackground,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(
                'Línea de crédito',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _blueDarkColor,
                ),
              ),
              const SizedBox(height: 20),

              Center(
                child: Column(
                  children: [
                    const Text(
                      'Monto disponible',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF666666),
                      ),
                    ),
                    const SizedBox(height: 12),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: _blueDarkColor,
                      ),
                      child: Text(
                        _formatCurrency(_animatedMontoDisponible.toInt()),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'de ${_formatCurrency(montoTotal)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              LayoutBuilder(
                builder: (context, constraints) {
                  return Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Stack(
                      children: [
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0E0E0),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: constraints.maxWidth * porcentajeUtilizadoAnimado.clamp(0.0, 1.0),
                          decoration: BoxDecoration(
                            color: _blueDarkColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Utilizado',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF666666),
                    ),
                  ),
                  Row(
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                        child: Text(
                          _formatCurrency(_animatedMontoUtilizado.toInt()),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '(${(porcentajeUtilizadoAnimado * 100).toStringAsFixed(1)}%)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ MÉTODO: TARJETAS DE FECHAS
  Widget _buildTarjetaFechas(Map<String, dynamic> lineaCreditoData) {
    final fechaAsignacion = lineaCreditoData['fecha_asignacion'] as String;
    final fechaCaducidad = lineaCreditoData['fecha_caducidad'] as String;

    final bool tieneAsignacion = fechaAsignacion.isNotEmpty;
    final bool tieneCaducidad = fechaCaducidad.isNotEmpty;

    if (!tieneAsignacion && !tieneCaducidad) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      width: double.infinity,
      child: Row(
        children: [
          if (tieneAsignacion)
            Expanded(
              child: _buildTarjetaFechaIndividual(
                icon: Icons.calendar_today,
                titulo: 'Asignado',
                fecha: fechaAsignacion,
                esPrimera: true,
              ),
            ),

          if (tieneAsignacion && tieneCaducidad)
            const SizedBox(width: 12),

          if (tieneCaducidad)
            Expanded(
              child: _buildTarjetaFechaIndividual(
                icon: Icons.event_busy,
                titulo: 'Vence',
                fecha: fechaCaducidad,
                esPrimera: !tieneAsignacion,
              ),
            ),
        ],
      ),
    );
  }

  // ✅ MÉTODO: CONSTRUIR TARJETA INDIVIDUAL DE FECHA
  Widget _buildTarjetaFechaIndividual({
    required IconData icon,
    required String titulo,
    required String fecha,
    required bool esPrimera,
  }) {
    final fechaFormateada = _formatDateDDMMYYYY(fecha);

    return Container(
      margin: EdgeInsets.only(
        bottom: 16,
        right: esPrimera ? 0 : 0,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 2,
            offset: const Offset(0, 1),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide.none,
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _approvedCardBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _blueDarkColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: _blueDarkColor,
                  size: 24,
                ),
              ),
              const SizedBox(height: 12),

              Text(
                titulo,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              Text(
                fechaFormateada,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ MÉTODO: FORMATEAR FECHA
  String _formatDateDDMMYYYY(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();
      return '$day/$month/$year';
    } catch (e) {
      return dateString;
    }
  }

  // ✅ MÉTODO: VERIFICACIÓN SECCIÓN
  Widget _buildVerificationSection({
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonText,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            blurRadius: 3,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide.none,
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _approvedCardBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: onPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: Text(
                    buttonText,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ MÉTODO: VERIFICAR EMAIL
  void _verifyEmail() {
    print('📧 Verificar email: ${_getUserEmail()}');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmailVerificationScreen(
          userEmail: _getUserEmail(),
          tokenComprador: _getTokenComprador(),
          onBack: () {
            Navigator.pop(context);
          },
          userData: _currentUserData,
        ),
      ),
    );
  }

  // ✅ MÉTODO: VERIFICAR IDENTIDAD
  void _verifyIdentity() {
    print('🔐 Verificar identidad - Navegando a registro');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrsanfioHome(
          userData: _currentUserData,
        ),
      ),
    );
  }

  // ✅ MÉTODO: CAMBIAR A LA SIGUIENTE EMPRESA
  void _cambiarSiguienteEmpresa() {
    final empresas = _currentUserData['empresas'] ?? [];

    if (empresas.isEmpty) {
      mostrarSnackBar(context, 'No hay empresas disponibles');
      return;
    }

    final int cantidadEmpresas = empresas.length;

    if (cantidadEmpresas == 1) {
      mostrarSnackBar(context, 'Solo hay una empresa disponible');
      return;
    }

    int currentIndex = -1;
    for (int i = 0; i < cantidadEmpresas; i++) {
      if (empresas[i]['token_empresa'] == _empresaSeleccionada) {
        currentIndex = i;
        break;
      }
    }

    int nextIndex = (currentIndex + 1) % cantidadEmpresas;
    final siguienteEmpresa = empresas[nextIndex];
    final nuevaEmpresaToken = siguienteEmpresa['token_empresa'];
    final nombreEmpresa = siguienteEmpresa['nombre_empresa']?.toString() ??
        'Empresa ${siguienteEmpresa['rut_empresa']}-${siguienteEmpresa['dv_rut_empresa']}';

    print('🔄 Cambiando a siguiente empresa: $nombreEmpresa');
    mostrarSnackBar(context, 'Cambiando a: $nombreEmpresa');

    setState(() {
      _empresaSeleccionada = nuevaEmpresaToken;
    });

    _actualizarValoresAnimados();
    _iniciarAnimacion();
    _verificarMostrarMensajeLineaCredito();
  }

  // ✅ MÉTODO: VERIFICAR SI EL RUT YA EXISTE
  bool _rutEmpresaYaExiste(String rutEmpresa, String dvEmpresa) {
    try {
      final empresas = _currentUserData['empresas'] ?? [];

      for (final empresa in empresas) {
        final rutExistente = empresa['rut_empresa']?.toString() ?? '';
        final dvExistente = empresa['dv_rut_empresa']?.toString() ?? '';

        if (rutExistente == rutEmpresa && dvExistente == dvEmpresa) {
          return true;
        }

        final rutCompletoExistente = '$rutExistente-$dvExistente';
        final rutCompletoIngresado = '$rutEmpresa-$dvEmpresa';

        if (RutUtils.formatRut(rutCompletoExistente) == RutUtils.formatRut(rutCompletoIngresado)) {
          return true;
        }
      }

      return false;
    } catch (e) {
      print('❌ Error verificando si el RUT ya existe: $e');
      return false;
    }
  }

  // ✅ MÉTODO BUILD COMPLETO CON GESTOS DE DESLIZAMIENTO Y PROTECCIÓN DE MODALES
  @override
  Widget build(BuildContext context) {
    final int userStatus = _getUserStatus();
    final bool mostrarOpciones = userStatus >= 3;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Container(
          padding: const EdgeInsets.only(left: 8),
          child: Image.asset(
            'assets/images/logo_fio.png',
            height: 35,
            fit: BoxFit.contain,
          ),
        ),
        centerTitle: false,
        actions: [
          if (mostrarOpciones)
            IconButton(
              icon: Icon(Icons.more_vert, color: _blueDarkColor),
              onPressed: _showOptionsMenu,
              tooltip: 'Opciones',
            ),
        ],
      ),
      body: _isLoading
          ? Center(
        child: CircularProgressIndicator(
          color: _blueDarkColor,
        ),
      )
          : NotificationListener<ScrollNotification>(
        // ✅ INTERCEPTAR LOS GESTOS DE DESLIZAMIENTO HORIZONTAL
        onNotification: (ScrollNotification notification) {
          // Si hay un modal abierto, bloquear los gestos del PageView
          if (_isModalOpen) {
            return true; // Bloquear el scroll
          }
          return false;
        },
        child: PageView(
          controller: _pageController,
          onPageChanged: (index) {
            // Solo actualizar el índice si no hay un modal abierto
            if (!_isModalOpen) {
              setState(() {
                _currentIndex = index;
              });
            }
          },
          // ✅ DESHABILITAR FÍSICA CUANDO HAY MODAL ABIERTO
          physics: _isModalOpen
              ? const NeverScrollableScrollPhysics()
              : const BouncingScrollPhysics(),
          scrollDirection: Axis.horizontal,
          children: [
            // Página 0: Home (Dashboard)
            _buildHomeScreenWithRefresh(),

            // Página 1: Sales History (Compras)
            SalesHistoryScreen(
              userData: _currentUserData,
              empresaSeleccionada: _empresaSeleccionada,
              onRefresh: _verificarSesionActualizada,
            ),

            // Página 2: Profile (Perfil)
            ProfileScreen(
              userData: _currentUserData,
              onLogout: _logout,
              empresaSeleccionada: _empresaSeleccionada,
              onRefresh: _verificarSesionActualizada,
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            // ✅ BLOQUEAR TAPS DURANTE MODALES
            if (_isModalOpen) return;

            if (index == 2) {
              final now = DateTime.now();
              if (_lastProfileTap != null &&
                  now.difference(_lastProfileTap!) < const Duration(milliseconds: 500)) {
                _cambiarSiguienteEmpresa();
                _lastProfileTap = null;
              } else {
                // ✅ ANIMAR LA TRANSICIÓN DE PÁGINA AL TOCAR EL BOTÓN
                _pageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
                _lastProfileTap = now;
              }
            } else {
              // ✅ ANIMAR LA TRANSICIÓN DE PÁGINA AL TOCAR EL BOTÓN
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined, size: 24),
              activeIcon: Icon(Icons.home, size: 24),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shopping_cart_outlined, size: 24),
              activeIcon: Icon(Icons.shopping_cart, size: 24),
              label: 'Compras',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline, size: 24),
              activeIcon: Icon(Icons.person, size: 24),
              label: 'Perfil',
            ),
          ],
          selectedItemColor: _blueDarkColor,
          unselectedItemColor: Color(0xFF9E9E9E),
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w400,
            fontSize: 12,
          ),
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
        ),
      ),
    );
  }
}