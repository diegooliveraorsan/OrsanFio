import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'profile_screen.dart';
import 'email_verification_screen.dart';
import 'log_in_log_up/registro.dart';
import 'variables_globales.dart';
import 'sales_history_screen.dart';
import 'codigo_verificacion_screen.dart';
import 'options_modal.dart';
import 'animaciones/simple_loading_dialog.dart';
import 'pin_creation_screen.dart';

// ✅ COLORES GLOBALES (MISMO QUE PERFIL)
final Color _blueDarkColor = const Color(0xFF0055B8);
final Color _approvedCardBackground = const Color(0xFFE8F0FE);

// ✅ ESTILOS ESTANDARIZADOS PARA SNACKBARS (MISMO COLOR GRIS)
void mostrarSnackBarGlobal(BuildContext context, String mensaje) {
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          mensaje,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.grey[800],
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

// ✅ REINICIAR LA APLICACIÓN NAVEGANDO AL MAIN
void _reiniciarAplicacion(BuildContext context) {
  print('🔄 Reiniciando aplicación desde DashboardScreen...');
  Navigator.pushNamedAndRemoveUntil(
    context,
    '/',
        (route) => false,
  );
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

  static Map<String, String> parseRut(String rut) {
    String cleanRut = rut.replaceAll('.', '').replaceAll('-', '').toUpperCase();
    if (cleanRut.length < 2) return {'numero': '', 'dv': ''};
    String numero = cleanRut.substring(0, cleanRut.length - 1);
    String dv = cleanRut.substring(cleanRut.length - 1);
    return {'numero': numero, 'dv': dv};
  }

  static Map<String, String> parseRunFromUserData(Map<String, dynamic> userData) {
    try {
      print('🔍 Buscando RUN en userData...');
      final comprador = userData['comprador'];
      if (comprador is Map<String, dynamic>) {
        final runComprador = comprador['run_comprador']?.toString() ?? '';
        final dvRunComprador = comprador['dv_run_comprador']?.toString() ?? '';
        print('   - run_comprador: $runComprador');
        print('   - dv_run_comprador: $dvRunComprador');
        if (runComprador.isNotEmpty && dvRunComprador.isNotEmpty) {
          return {'numero': runComprador, 'dv': dvRunComprador};
        }
        final dvComprador = comprador['dv_run_comprador']?.toString() ?? '';
        print('   - dv_run_comprador: $dvComprador');
        if (runComprador.isNotEmpty && dvComprador.isNotEmpty) {
          return {'numero': runComprador, 'dv': dvComprador};
        }
        final runCompleto = comprador['run_completo']?.toString() ?? '';
        print('   - run_completo: $runCompleto');
        if (runCompleto.isNotEmpty) {
          return parseRut(runCompleto);
        }
      }
      print('🔍 Búsqueda profunda en userData...');
      final jsonStr = json.encode(userData);
      final runMatch = RegExp(r'"run[^"]*"\s*:\s*"(\d{7,9})"').firstMatch(jsonStr);
      final dvMatch = RegExp(r'"dv[^"]*"\s*:\s*"([0-9Kk])"').firstMatch(jsonStr);
      if (runMatch != null && dvMatch != null) {
        final foundRun = runMatch.group(1) ?? '';
        final foundDv = dvMatch.group(1) ?? '';
        if (foundRun.isNotEmpty && foundDv.isNotEmpty) {
          print('✅ RUN encontrado en búsqueda profunda: $foundRun-$foundDv');
          return {'numero': foundRun, 'dv': foundDv.toUpperCase()};
        }
      }
      print('❌ No se pudo encontrar RUN del comprador');
      print('🔍 Estructura completa del comprador:');
      print(json.encode(userData['comprador']));
      return {'numero': '', 'dv': ''};
    } catch (e) {
      print('❌ Error parseando RUN del comprador: $e');
      return {'numero': '', 'dv': ''};
    }
  }

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

  late PageController _pageController;
  bool _isModalOpen = false;
  int _lastPageBeforeModal = 0;

  late AnimationController _animationController;
  late Animation<double> _animation;
  double _animatedMontoDisponible = 0.0;
  double _animatedMontoUtilizado = 0.0;

  bool _mostrarMensajeLineaCredito = false;
  bool _isAgregandoEmpresa = false;
  String? _mensajePendiente;

  @override
  void initState() {
    super.initState();
    _currentUserData = widget.userData;
    _inicializarEmpresaSeleccionada();
    _pageController = PageController(initialPage: _currentIndex);
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _iniciarAnimacion();
      _verificarSesionActualizada();
    });
    print('🎯 DashboardScreen iniciado con datos iniciales:');
    _printUserData();
  }

  void _inicializarEmpresaSeleccionada() {
    final empresas = _currentUserData['empresas'] ?? [];
    if (empresas.isNotEmpty) {
      final primeraEmpresa = empresas[0];
      _empresaSeleccionada = primeraEmpresa['token_empresa'];
    }
  }

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

  void _iniciarAnimacion() {
    _actualizarValoresAnimados();
    if (mounted) {
      _animationController.reset();
      _animationController.forward();
    }
  }

  void _actualizarValoresAnimados() {
    final lineaCreditoData = _getLineaCreditoData();
    final int montoDisponible = lineaCreditoData['monto_disponible'] as int;
    final int montoUtilizado = lineaCreditoData['monto_utilizado'] as int;
    final montoDisponibleTween = Tween<double>(
      begin: 0.0,
      end: montoDisponible.toDouble(),
    );
    final montoUtilizadoTween = Tween<double>(
      begin: 0.0,
      end: montoUtilizado.toDouble(),
    );
    _animation.addListener(() {
      if (mounted) {
        setState(() {
          _animatedMontoDisponible = montoDisponibleTween.transform(_animation.value);
          _animatedMontoUtilizado = montoUtilizadoTween.transform(_animation.value);
        });
      }
    });
  }

  void goToProfilePage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(2);
        setState(() {
          _currentIndex = 2;
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _resetModalState() {
    if (mounted) {
      setState(() {
        _isModalOpen = false;
        _lastPageBeforeModal = _currentIndex;
      });
    }
  }

  Future<void> _verificarSesionActualizada() async {
    if (_isLoading) return;
    try {
      if (mounted) setState(() => _isLoading = true);
      print('🔄 Verificando sesión actualizada...');
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
        body: json.encode({"token_dispositivo": deviceToken}),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == false && responseData['sesion_iniciada'] == false) {
          _reiniciarAplicacion(context);
          return;
        }
        if (responseData['sesion_iniciada'] == true) {
          print('✅ Datos actualizados del servidor');
          if (mounted) {
            setState(() {
              _currentUserData = responseData;
              _actualizarEmpresaSeleccionada(responseData);
              _verificarMostrarMensajeLineaCredito();
            });
            _actualizarValoresAnimados();
            if (mounted) {
              _animationController.reset();
              _animationController.forward();
            }
          }
        }
      }
    } catch (e) {
      print('❌ Error verificando sesión actualizada: $e');
      if (mounted) _mostrarSnackBarSeguro('Error al actualizar datos: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _actualizarEmpresaSeleccionada(Map<String, dynamic> responseData) {
    final empresas = responseData['empresas'] ?? [];
    if (empresas.isNotEmpty) {
      if (_empresaSeleccionada != null &&
          empresas.any((empresa) => empresa['token_empresa'] == _empresaSeleccionada)) {
        print('✅ Manteniendo empresa seleccionada: $_empresaSeleccionada');
        return;
      }
      _empresaSeleccionada = empresas[0]['token_empresa'];
      print('✅ Nueva empresa seleccionada: $_empresaSeleccionada');
    } else {
      _empresaSeleccionada = null;
    }
  }

  void _verificarMostrarMensajeLineaCredito() {
    final lineaCreditoData = _getLineaCreditoData();
    final bool tieneLineaCredito = lineaCreditoData['tiene_linea_credito'] as bool;
    final bool relacionValida = _esRelacionValida();
    if (mounted) {
      setState(() {
        _mostrarMensajeLineaCredito = !tieneLineaCredito && !relacionValida;
      });
    }
  }

  Future<void> _onRefresh() async {
    print('🔄 Pull to refresh activado');
    try {
      await _verificarSesionActualizada();
    } catch (e) {
      print('❌ Error durante refresh: $e');
    }
  }

  void _showOptionsMenu() {
    OptionsModal.show(
      context: context,
      userData: _currentUserData,
      empresaSeleccionada: _empresaSeleccionada,
      onCambiarEmpresa: _cambiarEmpresa,
      onMostrarAutorizadores: _mostrarVistaAutorizadores,
      onMostrarNuevaEmpresa: _mostrarVistaNuevaEmpresa,
      onReiniciarApp: () => _reiniciarAplicacion(context),
      onActualizarVista: _verificarSesionActualizada,
    ).then((_) {
      _resetModalState();
    });
  }

  void _mostrarVistaAutorizadores() {
    _resetModalState();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OptionsModal.crearVistaAutorizadores(
          context: context,
          userData: _currentUserData,
          empresaSeleccionada: _empresaSeleccionada,
          onAsignarAutorizador: (run) {
            print('👤 Nuevo autorizador: $run');
          },
          onActualizarAutorizadores: () {
            print('🔄 Actualizando autorizadores...');
          },
          onVolver: () => Navigator.pop(context),
          onReiniciarApp: () => _reiniciarAplicacion(context),
        ),
      ),
    );
  }

  void _mostrarVistaNuevaEmpresa() {
    _resetModalState();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OptionsModal.crearVistaNuevaEmpresa(
          context: context,
          userData: _currentUserData,
          onAgregarEmpresa: (rut, tipoRelacion, pin) {
            print('📤 Empresa agregada desde pantalla: $rut - $tipoRelacion - PIN: $pin');
            _agregarEmpresaNuevoEnfoque(rut, tipoRelacion, pin);
          },
          onVolver: () => Navigator.pop(context),
          onReiniciarApp: () => _reiniciarAplicacion(context),
          onActualizarDashboard: _verificarSesionActualizada,
        ),
      ),
    );
  }

  Future<void> _agregarEmpresaNuevoEnfoque(String rut, String tipoRelacion, String pin) async {
    if (_isAgregandoEmpresa) {
      print('⚠️ Ya hay una operación en curso');
      _mostrarMensajeSeguro('Ya hay una operación en proceso');
      return;
    }

    print('🚀 NUEVO ENFOQUE: Iniciando proceso para agregar empresa: $rut con PIN: $pin');
    _isAgregandoEmpresa = true;
    if (mounted) setState(() {});

    bool operacionExitosa = false;
    String? mensajeResultado;
    bool? fueExitosoDirectamente = false;

    try {
      final Completer<void> loadingCompleter = Completer<void>();
      BuildContext? dialogContext;

      try {
        await showDialog(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black54,
          useRootNavigator: true,
          builder: (context) {
            dialogContext = context;
            return SimpleLoadingDialog(
              message: 'Agregando empresa...\nEsto puede tomar unos momentos',
              completer: loadingCompleter,
            );
          },
        );
      } catch (e) {
        print('⚠️ Error mostrando diálogo: $e');
      }

      await Future.delayed(const Duration(milliseconds: 300));

      try {
        await Firebase.initializeApp();
        String? fcmToken = await FirebaseMessaging.instance.getToken();
        final String deviceToken = fcmToken ?? 'fcm_fallback_${DateTime.now().millisecondsSinceEpoch}';

        final runData = RutUtils.parseRunFromUserData(_currentUserData);
        final tokenComprador = _currentUserData['comprador']?['token_comprador']?.toString() ?? '';
        final runComprador = runData['numero'] ?? '';
        final dvRunComprador = runData['dv'] ?? '';

        final rutParseado = RutUtils.parseRut(rut);
        final rutEmpresa = rutParseado['numero'] ?? '';
        final dvEmpresa = rutParseado['dv'] ?? '';

        final representanteOautorizador = tipoRelacion.toLowerCase() == 'autorizador' ? '1' : '2';

        final requestBody = {
          "token_comprador": tokenComprador,
          "run_comprador": runComprador,
          "dv_comprador": dvRunComprador,
          "rut_empresa": rutEmpresa,
          "dv_rut_empresa": dvEmpresa,
          "represetante_o_autorizador": representanteOautorizador,
          "token_dispositivo": deviceToken,
          "pin_seguridad": pin,
        };

        print('📦 Enviando request body...');
        final response = await http.post(
          Uri.parse('${GlobalVariables.baseUrl}/AgregarEmpresaAComprador/api/v3/'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'api-key': GlobalVariables.apiKey,
          },
          body: json.encode(requestBody),
        ).timeout(const Duration(seconds: 30));

        print('✅ Respuesta recibida: ${response.statusCode}');

        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);
          print('📦 Response Data:');
          print(responseData);

          if (responseData['success'] == false && responseData['sesion_iniciada'] == false) {
            print('🔐 Sesión expirada, reiniciando app...');
            _reiniciarAplicacion(context);
            return;
          }

          if (responseData['success'] == true) {
            operacionExitosa = true;
            fueExitosoDirectamente = true;
            mensajeResultado = responseData['message'] ?? responseData['mensaje'] ?? 'Empresa agregada exitosamente';
            print('✅ API exitosa: $mensajeResultado');
          } else {
            mensajeResultado = responseData['message'] ?? responseData['error'] ?? 'Error al agregar empresa';
            print('❌ API error: $mensajeResultado');
          }
        } else {
          mensajeResultado = 'Error del servidor: ${response.statusCode}';
          print('❌ HTTP error: ${response.statusCode}');
        }
      } catch (e) {
        print('❌ Error en API: $e');
        if (e is TimeoutException) {
          mensajeResultado = 'La empresa se está procesando. Se actualizará en unos momentos.';
          operacionExitosa = true;
          print('⏰ Timeout - Mensaje especial mostrado');
        } else {
          mensajeResultado = 'Error de conexión: ${e.toString().split(':').first}';
        }
      }

      print('🔒 Completando completer para cerrar diálogo...');
      if (!loadingCompleter.isCompleted) loadingCompleter.complete();
      if (dialogContext != null && mounted) {
        try {
          Navigator.of(dialogContext!, rootNavigator: true).pop();
        } catch (e) {
          print('⚠️ Error cerrando diálogo: $e');
        }
      }
      await Future.delayed(const Duration(milliseconds: 500));

    } catch (e) {
      print('❌ Error en flujo principal: $e');
      mensajeResultado = 'Error en el proceso: ${e.toString().split(':').first}';
    } finally {
      print('🏁 Procesando resultado final...');
      if (mensajeResultado != null) _mostrarMensajeSeguro(mensajeResultado!);
      if (operacionExitosa) {
        print('✅ Operación exitosa, preparando redirección...');
        if (fueExitosoDirectamente == true) {
          await Future.delayed(const Duration(seconds: 2));
          await _verificarSesionActualizada();
          _seleccionarYRedirigirEmpresa(rut);
        } else {
          _actualizarDatosDespuesDeAgregarEmpresa(rut);
        }
      }
      _isAgregandoEmpresa = false;
      if (mounted) setState(() {});
    }
  }

  void _seleccionarYRedirigirEmpresa(String rut) {
    print('🎯 Buscando y seleccionando empresa: $rut');
    final rutParseado = RutUtils.parseRut(rut);
    final rutNumero = rutParseado['numero'] ?? '';
    final rutDv = rutParseado['dv'] ?? '';
    if (rutNumero.isEmpty || rutDv.isEmpty) {
      print('❌ RUT inválido: $rut');
      return;
    }
    final empresas = _currentUserData['empresas'] ?? [];
    bool empresaEncontrada = false;
    for (var empresa in empresas) {
      final rutEmpresa = empresa['rut_empresa']?.toString() ?? '';
      final dvEmpresa = empresa['dv_rut_empresa']?.toString() ?? '';
      if (rutEmpresa == rutNumero && dvEmpresa == rutDv) {
        final nombreEmpresa = empresa['nombre_empresa']?.toString() ?? 'Nueva Empresa';
        final tokenEmpresa = empresa['token_empresa'];
        print('✅ Empresa encontrada: $nombreEmpresa (Token: $tokenEmpresa)');
        if (mounted && tokenEmpresa != null) {
          setState(() {
            _empresaSeleccionada = tokenEmpresa;
            empresaEncontrada = true;
          });
          _actualizarValoresAnimados();
          _iniciarAnimacion();
          _verificarMostrarMensajeLineaCredito();
          _mostrarMensajeSeguro('Empresa "$nombreEmpresa" seleccionada');
          Navigator.popUntil(context, (route) => route.isFirst);
          _pageController.animateToPage(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
          print('✅ Redirección completada');
        }
        break;
      }
    }
    if (!empresaEncontrada) {
      print('⚠️ Empresa no encontrada inmediatamente, se actualizará en background');
      _mostrarMensajeSeguro('La empresa se agregó correctamente y aparecerá pronto');
    }
  }

  void _mostrarSnackBarSeguro(String mensaje) {
    if (mounted) mostrarSnackBarGlobal(context, mensaje);
  }

  void _mostrarMensajeSeguro(String mensaje) {
    print('📢 Intentando mostrar mensaje: $mensaje');
    if (mounted) {
      print('✅ Widget montado, mostrando snackbar...');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          mostrarSnackBarGlobal(context, mensaje);
        } else {
          print('⚠️ Widget desmontado durante postFrameCallback, guardando mensaje pendiente');
          _mensajePendiente = mensaje;
        }
      });
    } else {
      print('⚠️ Widget NO montado, guardando mensaje pendiente: $mensaje');
      _mensajePendiente = mensaje;
    }
  }

  void _actualizarDatosDespuesDeAgregarEmpresa(String rutAgregado) {
    print('🔄 Iniciando actualización de datos...');
    Future.delayed(const Duration(seconds: 1), () async {
      print('⏰ Ejecutando actualización retardada...');
      try {
        print('🌐 Actualizando desde servidor...');
        await _verificarSesionActualizada();
        print('🎯 Buscando empresa: $rutAgregado');
        final rutParseado = RutUtils.parseRut(rutAgregado);
        final rutNumero = rutParseado['numero'] ?? '';
        final rutDv = rutParseado['dv'] ?? '';
        if (rutNumero.isEmpty || rutDv.isEmpty) {
          print('❌ RUT inválido: $rutAgregado');
          return;
        }
        final empresas = _currentUserData['empresas'] ?? [];
        bool empresaEncontrada = false;
        for (var empresa in empresas) {
          final rutEmpresa = empresa['rut_empresa']?.toString() ?? '';
          final dvEmpresa = empresa['dv_rut_empresa']?.toString() ?? '';
          if (rutEmpresa == rutNumero && dvEmpresa == rutDv) {
            final nombreEmpresa = empresa['nombre_empresa']?.toString() ?? 'Nueva Empresa';
            final tokenEmpresa = empresa['token_empresa'];
            print('✅ Empresa encontrada: $nombreEmpresa (Token: $tokenEmpresa)');
            if (mounted && tokenEmpresa != null && tokenEmpresa != _empresaSeleccionada) {
              setState(() {
                _empresaSeleccionada = tokenEmpresa;
                empresaEncontrada = true;
              });
              _actualizarValoresAnimados();
              _iniciarAnimacion();
              _verificarMostrarMensajeLineaCredito();
              _mostrarMensajeSeguro('Empresa "$nombreEmpresa" seleccionada');
              print('✅ Empresa seleccionada automáticamente');
            }
            break;
          }
        }
        if (!empresaEncontrada && empresas.isNotEmpty) {
          final primeraEmpresa = empresas[0];
          final tokenPrimeraEmpresa = primeraEmpresa['token_empresa'];
          final nombrePrimeraEmpresa = primeraEmpresa['nombre_empresa']?.toString() ?? 'Empresa';
          if (mounted && tokenPrimeraEmpresa != null && tokenPrimeraEmpresa != _empresaSeleccionada) {
            setState(() {
              _empresaSeleccionada = tokenPrimeraEmpresa;
            });
            _mostrarMensajeSeguro('Seleccionada: $nombrePrimeraEmpresa');
            print('⚠️ Empresa específica no encontrada, seleccionando primera disponible');
          }
        }
        print('✅ Actualización completada');
      } catch (e) {
        print('❌ Error en actualización: $e');
        _mostrarMensajeSeguro('Error al actualizar: ${e.toString().split(':').first}');
      }
    });
  }

  void _cambiarEmpresa(String nuevaEmpresaToken) {
    if (!mounted || _empresaSeleccionada == nuevaEmpresaToken) return;
    setState(() => _empresaSeleccionada = nuevaEmpresaToken);
    _actualizarValoresAnimados();
    _iniciarAnimacion();
    _verificarMostrarMensajeLineaCredito();
  }

  Map<String, dynamic>? _getEmpresaSeleccionada() {
    if (_empresaSeleccionada == null) return null;
    final empresas = _currentUserData['empresas'] ?? [];
    for (var emp in empresas) {
      if (emp['token_empresa'] == _empresaSeleccionada) return emp;
    }
    return null;
  }

  bool _esRelacionValida() {
    final empresa = _getEmpresaSeleccionada();
    if (empresa == null || empresa.isEmpty) return false;
    final validezRelacion = empresa['validez_relacion']?.toString().toLowerCase() ?? '';
    return !validezRelacion.contains('no válida');
  }

  Widget _buildHomeScreenWithRefresh() {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: _blueDarkColor,
      backgroundColor: Colors.white,
      displacement: 40,
      child: _buildHomeScreenContent(),
    );
  }

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
              if (userStatus >= 4) ...[
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
          )
        else if (userStatus == 3)
            _buildVerificationSection(
              icon: Icons.lock_outline,
              title: 'Crear PIN de seguridad',
              subtitle: 'Protege tu cuenta creando un PIN de 4 dígitos.',
              buttonText: 'Crear PIN',
              onPressed: _navigateToPinCreation,
              color: _blueDarkColor,
            ),

        if (userStatus >= 4 && _empresaSeleccionada != null && lineaValida) ...[
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

        if (userStatus >= 4 && _empresaSeleccionada != null) ...[
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
          ] else if (!tieneLineaCredito && relacionValida) ...[
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
          ] else if (_mostrarMensajeLineaCredito) ...[
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
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        print('🔄 Recargando vista desde botón...');
                        _verificarSesionActualizada();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _blueDarkColor,
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

  void _navigateToPinCreation() {
    final tokenComprador = _currentUserData['comprador']?['token_comprador']?.toString();
    final correo = _currentUserData['comprador']?['correo_comprador']?.toString();
    final tokenDispositivo = _currentUserData['dispositivo_actual']?['token_dispositivo']?.toString() ??
        (_currentUserData['dispositivos'] as List?)?.firstOrNull?['token_dispositivo']?.toString();
    if (tokenComprador == null || correo == null || tokenDispositivo == null) {
      mostrarSnackBarGlobal(context, 'Error: No se pudo obtener la información necesaria');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PinCreationScreen(
          tokenComprador: tokenComprador,
          correoComprador: correo,
          tokenDispositivo: tokenDispositivo,
          onPinCreated: _verificarSesionActualizada,
          crearPin: true,
        ),
      ),
    );
  }

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

  // 🆕 Método para mostrar selector de empresas
  void _mostrarSelectorEmpresas() {
    final empresas = _currentUserData['empresas'] ?? [];
    if (empresas.isEmpty) {
      mostrarSnackBarGlobal(context, 'No hay empresas disponibles');
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      useRootNavigator: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Seleccionar Empresa',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _blueDarkColor,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: empresas.length,
                  itemBuilder: (context, index) {
                    final empresa = empresas[index];
                    final rut = empresa['rut_empresa']?.toString() ?? '';
                    final dv = empresa['dv_rut_empresa']?.toString() ?? '';
                    final nombreEmpresa = empresa['nombre_empresa']?.toString() ?? 'Empresa ${rut}-$dv';
                    final bool isSelected = empresa['token_empresa'] == _empresaSeleccionada;

                    final rutFormateado = RutUtils.formatRut('$rut-$dv');

                    return ListTile(
                      leading: Icon(
                        Icons.business,
                        color: isSelected ? _blueDarkColor : Colors.grey,
                      ),
                      title: Text(
                        nombreEmpresa,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? _blueDarkColor : Colors.black,
                        ),
                      ),
                      subtitle: Text('RUT: $rutFormateado'),
                      trailing: isSelected
                          ? Icon(Icons.check, color: _blueDarkColor)
                          : null,
                      onTap: () {
                        final nuevaEmpresaToken = empresa['token_empresa'];
                        Navigator.of(context, rootNavigator: true).pop();
                        _cambiarEmpresa(nuevaEmpresaToken);
                        mostrarSnackBarGlobal(context, 'Cambiada a: $nombreEmpresa');
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blueDarkColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Cerrar'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 🆕 Modificación de _buildEmpresaInfo para que sea táctil
  Widget _buildEmpresaInfo() {
    final empresa = _getEmpresaSeleccionada();
    if (empresa == null || empresa.isEmpty) return const SizedBox.shrink();
    final nombreEmpresa = empresa['nombre_empresa']?.toString() ?? '';
    if (nombreEmpresa.isEmpty) return const SizedBox.shrink();
    final validezRelacion = empresa['validez_relacion']?.toString().toLowerCase() ?? '';
    if (validezRelacion.contains('no válida')) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: _mostrarSelectorEmpresas,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _blueDarkColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                nombreEmpresa,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.swap_horiz,
                size: 18,
                color: _blueDarkColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRelacionInfo() {
    final esValida = _esRelacionValida();
    final String texto = esValida ? 'Relación válida' : 'Relación no válida';
    final Color iconColor = esValida ? const Color(0xFF4CAF50) : const Color(0xFF9E9E9E);
    final IconData icon = esValida ? Icons.check_circle : Icons.cancel;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: iconColor),
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

  double _getPorcentajeUtilizado() {
    final data = _getLineaCreditoData();
    final montoTotal = data['monto_total'] as int;
    final montoUtilizado = data['monto_utilizado'] as int;
    if (montoTotal == 0) return 0.0;
    return montoUtilizado / montoTotal;
  }

  Future<void> _logout() async {
    try {
      print('🚪 Cerrando sesión...');
      final String tokenComprador = _currentUserData['comprador']?['token_comprador'] ?? '';
      final String tokenDispositivo = _currentUserData['dispositivo_actual']?['token_dispositivo'] ??
          _currentUserData['dispositivos']?[0]?['token_dispositivo'] ?? '';
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
        border: Border.all(color: Colors.grey.shade300, width: 1),
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
                        RutUtils.formatCurrency(_animatedMontoDisponible.toInt()),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'de ${RutUtils.formatCurrency(montoTotal)}',
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
                          RutUtils.formatCurrency(_animatedMontoUtilizado.toInt()),
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

  Widget _buildTarjetaFechas(Map<String, dynamic> lineaCreditoData) {
    final fechaAsignacion = lineaCreditoData['fecha_asignacion'] as String;
    final fechaCaducidad = lineaCreditoData['fecha_caducidad'] as String;
    final bool tieneAsignacion = fechaAsignacion.isNotEmpty;
    final bool tieneCaducidad = fechaCaducidad.isNotEmpty;
    if (!tieneAsignacion && !tieneCaducidad) return const SizedBox.shrink();
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
          if (tieneAsignacion && tieneCaducidad) const SizedBox(width: 12),
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

  Widget _buildTarjetaFechaIndividual({
    required IconData icon,
    required String titulo,
    required String fecha,
    required bool esPrimera,
  }) {
    final fechaFormateada = _formatDateDDMMYYYY(fecha);
    return Container(
      margin: EdgeInsets.only(bottom: 16, right: esPrimera ? 0 : 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 1),
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
                child: Icon(icon, color: _blueDarkColor, size: 24),
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
        border: Border.all(color: Colors.grey.shade300, width: 1),
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
                    child: Icon(icon, color: color, size: 20),
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

  void _verifyEmail() {
    print('📧 Verificar email: ${_getUserEmail()}');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmailVerificationScreen(
          userEmail: _getUserEmail(),
          tokenComprador: _currentUserData['comprador']?['token_comprador'] ?? '',
          onBack: () => Navigator.pop(context),
          userData: _currentUserData,
        ),
      ),
    );
  }

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

  void _cambiarSiguienteEmpresa() {
    final empresas = _currentUserData['empresas'] ?? [];
    if (empresas.isEmpty) return;
    final int cantidadEmpresas = empresas.length;
    if (cantidadEmpresas == 1) return;
    int currentIndex = -1;
    for (int i = 0; i < cantidadEmpresas; i++) {
      if (empresas[i]['token_empresa'] == _empresaSeleccionada) {
        currentIndex = i;
        break;
      }
    }
    int nextIndex = (currentIndex + 1) % (empresas.length as int);
    final siguienteEmpresa = empresas[nextIndex];
    final nuevaEmpresaToken = siguienteEmpresa['token_empresa'];
    print('🔄 Cambiando a siguiente empresa: ${siguienteEmpresa['nombre_empresa']}');
    if (mounted) setState(() => _empresaSeleccionada = nuevaEmpresaToken);
    _actualizarValoresAnimados();
    _iniciarAnimacion();
    _verificarMostrarMensajeLineaCredito();
  }

  @override
  Widget build(BuildContext context) {
    final int userStatus = _getUserStatus();
    final bool mostrarOpciones = userStatus >= 4;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_mensajePendiente != null && mounted) {
        mostrarSnackBarGlobal(context, _mensajePendiente!);
        _mensajePendiente = null;
      }
    });
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
          if (_isAgregandoEmpresa)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _blueDarkColor,
                  ),
                ),
              ),
            ),
          if (mostrarOpciones)
            IconButton(
              icon: Icon(Icons.add, color: _blueDarkColor), // 👈 Cambiado a +
              onPressed: _showOptionsMenu,
              tooltip: 'Opciones',
            ),
        ],
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: _blueDarkColor),
            const SizedBox(height: 16),
            Text(
              'Cargando...',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      )
          : NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification notification) {
          if (_isModalOpen) return true;
          return false;
        },
        child: PageView(
          controller: _pageController,
          onPageChanged: (index) {
            if (!_isModalOpen && mounted) {
              setState(() => _currentIndex = index);
            }
          },
          physics: _isModalOpen
              ? const NeverScrollableScrollPhysics()
              : const BouncingScrollPhysics(),
          scrollDirection: Axis.horizontal,
          children: [
            _buildHomeScreenWithRefresh(),
            SalesHistoryScreen(
              userData: _currentUserData,
              empresaSeleccionada: _empresaSeleccionada,
              onRefresh: _verificarSesionActualizada,
            ),
            ProfileScreen(
              userData: _currentUserData,
              onLogout: _logout,
              empresaSeleccionada: _empresaSeleccionada,
              onRefresh: _verificarSesionActualizada,
              onEditComplete: goToProfilePage,
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
            if (_isModalOpen) return;
            if (index == 2) {
              final now = DateTime.now();
              if (_lastProfileTap != null &&
                  now.difference(_lastProfileTap!) < const Duration(milliseconds: 500)) {
                _cambiarSiguienteEmpresa();
                _lastProfileTap = null;
              } else {
                _pageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
                _lastProfileTap = now;
              }
            } else {
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
          unselectedItemColor: const Color(0xFF9E9E9E),
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

  String _getNombreEmpresaSeleccionada() {
    if (_empresaSeleccionada == null) return 'No hay empresa seleccionada';
    final empresa = _getEmpresaSeleccionada();
    if (empresa == null || empresa.isEmpty) return 'Empresa no encontrada';
    final nombreEmpresa = empresa['nombre_empresa']?.toString() ?? '';
    final rut = empresa['rut_empresa']?.toString() ?? '';
    final dv = empresa['dv_rut_empresa']?.toString() ?? '';
    if (nombreEmpresa.isNotEmpty) return nombreEmpresa;
    if (rut.isNotEmpty && dv.isNotEmpty) return 'Empresa $rut-$dv';
    return 'Empresa desconocida';
  }
}