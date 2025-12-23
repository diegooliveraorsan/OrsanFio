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

// ✅ COLORES GLOBALES (MISMO QUE PERFIL)
final Color _blueDarkColor = const Color(0xFF0055B8);
final Color _approvedCardBackground = const Color(0xFFE8F0FE);

// Clase de utilidades para RUT chileno (copiada desde tu código)
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

  // ✅ NUEVO: PageController para navegación horizontal
  late PageController _pageController;

  // ✅ ANIMATION CONTROLLER PARA LA ANIMACIÓN DE LA LÍNEA DE CRÉDITO
  late AnimationController _animationController;
  late Animation<double> _animation;
  double _animatedMontoDisponible = 0.0;
  double _animatedMontoUtilizado = 0.0;

  @override
  void initState() {
    super.initState();
    _currentUserData = widget.userData;
    _inicializarEmpresaSeleccionada();
    _verificarSesionActualizada();

    // ✅ INICIALIZAR PAGE CONTROLLER PARA NAVEGACIÓN HORIZONTAL
    _pageController = PageController(initialPage: _currentIndex);

    // ✅ INICIALIZAR ANIMATION CONTROLLER
    _animationController = AnimationController(
      duration: const Duration(seconds: 1), // Duración de 1 segundo
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

    // ✅ IMPRIMIR RUN DEL COMPRADOR PARA DEPURACIÓN
    final runParseado = RutUtils.parseRunFromUserData(_currentUserData);
    print('- RUN comprador: ${runParseado['numero']}-${runParseado['dv']}');
    print('- Datos comprador completos: ${_currentUserData['comprador']}');
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
  void didUpdateWidget(DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reiniciar animación cuando cambian los datos
    if (oldWidget.userData != widget.userData) {
      _actualizarValoresAnimados();
      _iniciarAnimacion();
    }
  }

  @override
  void dispose() {
    // ✅ DISPONER DEL PAGE CONTROLLER
    _pageController.dispose();

    // ✅ DISPONER DEL ANIMATION CONTROLLER
    _animationController.dispose();
    super.dispose();
  }

  // ✅ MÉTODO MEJORADO: VERIFICAR SESIÓN ACTUALIZADA CON PRINTS COMPLETOS
  Future<void> _verificarSesionActualizada() async {
    try {
      if (_currentIndex == 0) {
        setState(() {
          _isLoading = true;
        });
      }

      print('🔄 Verificando sesión actualizada...');

      // Obtener token FCM
      await Firebase.initializeApp();
      String? fcmToken = await FirebaseMessaging.instance.getToken();
      final String deviceToken = fcmToken ?? 'fcm_fallback_${DateTime.now().millisecondsSinceEpoch}';

      print('📤 Request SesionIniciada:');
      print('  - token_dispositivo: $deviceToken');
      print('🌐 URL: ${GlobalVariables.baseUrl}/SesionIniciada/api/v1/');

      final response = await http.post(
        Uri.parse('${GlobalVariables.baseUrl}/SesionIniciada/api/v1/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'api-key': '${GlobalVariables.apiKey}',
        },
        body: json.encode({
          "token_dispositivo": deviceToken,
        }),
      ).timeout(const Duration(seconds: 10));

      print('📥 Response SesionIniciada:');
      print('  - Status: ${response.statusCode}');

      // ✅ MOSTRAR RESPONSE COMPLETO Y FORMATEADO
      _printCompleteResponse(response.body);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final bool sesionIniciada = responseData['sesion_iniciada'] == true;

        if (sesionIniciada) {
          print('✅ Sesión actualizada detectada, actualizando datos...');

          // ✅ ACTUALIZAR DATOS SIN CAMBIAR EL ÍNDICE
          setState(() {
            _currentUserData = responseData;
          });

          _inicializarEmpresaSeleccionada();
          _printUserData();
          _printLineaCreditoData();
          _printEmpresaData();

          // ✅ ACTUALIZAR VALORES ANIMADOS Y REINICIAR ANIMACIÓN
          _actualizarValoresAnimados();
          _iniciarAnimacion();
        }
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

  // ✅ NUEVO MÉTODO: PULL TO REFRESH CON REINICIO DE ANIMACIÓN
  Future<void> _onRefresh() async {
    print('🔄 Pull to refresh activado desde índice: $_currentIndex');

    // ✅ GUARDAR EL ÍNDICE ACTUAL ANTES DE REFRESCAR
    final int currentPageBeforeRefresh = _currentIndex;

    try {
      await _verificarSesionActualizada();

      // ✅ REINICIAR LA ANIMACIÓN AL REFRESCAR
      _actualizarValoresAnimados();
      _iniciarAnimacion();

      // ✅ RESTAURAR LA PÁGINA ACTUAL DESPUÉS DEL REFRESH
      if (mounted && currentPageBeforeRefresh != _currentIndex) {
        // Pequeño delay para asegurar que el refresh se complete
        await Future.delayed(const Duration(milliseconds: 100));

        _pageController.jumpToPage(currentPageBeforeRefresh);
        setState(() {
          _currentIndex = currentPageBeforeRefresh;
        });
      }
    } catch (e) {
      print('❌ Error durante refresh: $e');
    }
  }

  // ✅ MÉTODO MEJORADO: MOSTRAR MENÚ DE OPCIONES CON LAS NUEVAS FUNCIONALIDADES
  void _showOptionsMenu() {
    final empresaSeleccionada = _getEmpresaSeleccionada();
    final bool esRepresentanteValido = _esRepresentanteValido();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Encabezado
            Text(
              'Opciones',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _blueDarkColor,
              ),
            ),
            const SizedBox(height: 20),

            // ✅ OPCIÓN 1: EMPRESA SELECCIONADA
            _buildEmpresaSeleccionadaItem(empresaSeleccionada),

            const SizedBox(height: 16),

            // ✅ OPCIÓN 2: AÑADIR NUEVA EMPRESA
            _buildOptionItem(
              icon: Icons.add_business,
              title: 'Añadir nueva empresa',
              subtitle: 'Registrar nueva empresa con RUT',
              onTap: () {
                Navigator.pop(context);
                _mostrarDialogoNuevaEmpresa();
              },
            ),

            // ✅ OPCIÓN 3: ASIGNAR NUEVO AUTORIZADOR (SOLO PARA REPRESENTANTES VALIDADOS)
            if (esRepresentanteValido) ...[
              const SizedBox(height: 16),
              _buildOptionItem(
                icon: Icons.person_add,
                title: 'Asignar nuevo autorizador',
                subtitle: 'Agregar persona autorizada',
                onTap: () {
                  Navigator.pop(context);
                  _mostrarDialogoNuevoAutorizador();
                },
              ),
            ],

            // ✅ OPCIÓN 4: VER AUTORIZADORES (SOLO PARA REPRESENTANTES VALIDADOS)
            if (esRepresentanteValido) ...[
              const SizedBox(height: 16),
              _buildOptionItem(
                icon: Icons.people,
                title: 'Ver autorizadores',
                subtitle: 'Lista de personas autorizadas',
                onTap: () {
                  Navigator.pop(context);
                  _mostrarListaAutorizadores();
                },
              ),
            ],

            const SizedBox(height: 20),

            // Botón cerrar
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey,
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Cerrar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpresaSeleccionadaItem(Map<String, dynamic>? empresa) {
    String nombreEmpresa = 'No hay empresa seleccionada';
    String rutEmpresa = '';

    if (empresa != null && empresa.isNotEmpty) {
      final rut = empresa['rut_empresa']?.toString() ?? '';
      final dv = empresa['dv_rut_empresa']?.toString() ?? '';
      nombreEmpresa = empresa['nombre_empresa']?.toString() ?? 'Empresa ${rut}-$dv';

      final rutCompleto = '$rut-$dv';
      rutEmpresa = RutUtils.formatRut(rutCompleto);
    }

    return InkWell(
      onTap: () {
        Navigator.pop(context);
        _mostrarSelectorEmpresas();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 0),
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
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _approvedCardBackground,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                // Icono y información de la empresa
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _blueDarkColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.business,
                              color: _blueDarkColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Empresa seleccionada',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        nombreEmpresa,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      if (rutEmpresa.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'RUT: $rutEmpresa',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Flecha indicadora
                Icon(
                  Icons.arrow_forward_ios,
                  color: _blueDarkColor,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ✅ NUEVO MÉTODO: OBTENER EMPRESA SELECCIONADA
  Map<String, dynamic>? _getEmpresaSeleccionada() {
    if (_empresaSeleccionada == null) return null;

    final empresas = _currentUserData['empresas'] ?? [];
    return empresas.firstWhere(
          (emp) => emp['token_empresa'] == _empresaSeleccionada,
      orElse: () => {},
    );
  }

  // ✅ NUEVO MÉTODO: VERIFICAR SI ES REPRESENTANTE VALIDADO
  bool _esRepresentanteValido() {
    final empresa = _getEmpresaSeleccionada();
    if (empresa == null || empresa.isEmpty) return false;

    // Verificar si tiene relación de representante y está validada
    final tipoRelacion = empresa['tipo_relacion']?.toString().toLowerCase() ?? '';
    final validezRelacion = empresa['validez_relacion']?.toString().toLowerCase() ?? '';
    print('validezRelacion: $validezRelacion');
    return tipoRelacion.contains('representante') && !validezRelacion.contains('no válida');
  }

  // ✅ NUEVO MÉTODO: VERIFICAR SI LA RELACIÓN ES VÁLIDA
  bool _esRelacionValida() {
    final empresa = _getEmpresaSeleccionada();
    if (empresa == null || empresa.isEmpty) return false;

    final validezRelacion = empresa['validez_relacion']?.toString().toLowerCase() ?? '';
    return !validezRelacion.contains('no válida');
  }

  // ✅ NUEVO MÉTODO: OBTENER TIPO DE USUARIO (REPRESENTANTE O COMPRADOR)
  String _getTipoUsuario() {
    final empresa = _getEmpresaSeleccionada();
    if (empresa == null || empresa.isEmpty) return 'comprador';

    final tipoRelacion = empresa['tipo_relacion']?.toString().toLowerCase() ?? '';
    if (tipoRelacion.contains('representante')) {
      return 'representante';
    }
    return 'comprador';
  }

  // ✅ NUEVO MÉTODO: MOSTRAR SELECTOR DE EMPRESAS
  void _mostrarSelectorEmpresas() {
    final empresas = _currentUserData['empresas'] ?? [];

    if (empresas.isEmpty) {
      _mostrarSnackBar('No hay empresas disponibles');
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
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

                  // ✅ CORREGIDO: Formatear RUT para mostrar con puntos
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
                      // ✅ GUARDAR LA EMPRESA SELECCIONADA TEMPORALMENTE
                      final nuevaEmpresaSeleccionada = empresa['token_empresa'];

                      Navigator.pop(context);
                      _mostrarSnackBar('Cambiando a empresa: $nombreEmpresa');

                      // ✅ USAR EL MÉTODO SIMPLIFICADO (COMO DOBLE TAP)
                      _cambiarEmpresaSinRedirigir(nuevaEmpresaSeleccionada);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey,
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Cerrar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ MÉTODO ACTUALIZADO: CAMBIAR EMPRESA SIN REDIRIGIR CON REINICIO DE ANIMACIÓN
  void _cambiarEmpresaSinRedirigir(String nuevaEmpresaToken) {
    print('🔄 Cambiando empresa sin redirigir...');
    print('🎯 Nueva empresa seleccionada: $nuevaEmpresaToken');

    // ✅ OBTENER DATOS DE LA NUEVA EMPRESA PARA DEPURACIÓN
    final empresas = _currentUserData['empresas'] ?? [];
    for (final empresa in empresas) {
      if (empresa['token_empresa'] == nuevaEmpresaToken) {
        print('   📋 Datos nueva empresa:');
        print('      - Nombre: ${empresa['nombre_empresa']}');
        print('      - RUT: ${empresa['rut_empresa']}-${empresa['dv_rut_empresa']}');
        print('      - Estado: ${empresa['estado_empresa']}');
        print('      - Relación: ${empresa['tipo_relacion']}');
        print('      - Validez: ${empresa['validez_relacion']}');
        break;
      }
    }

    // Cambiar la empresa
    setState(() {
      _empresaSeleccionada = nuevaEmpresaToken;
    });

    _mostrarSnackBar('Empresa cambiada exitosamente');

    // ✅ ACTUALIZAR VALORES ANIMADOS Y REINICIAR ANIMACIÓN
    _actualizarValoresAnimados();
    _iniciarAnimacion();

    // ✅ DEPURAR: Obtener línea de crédito después de cambiar
    final lineaCreditoData = _getLineaCreditoData();
    print('📊 Línea de crédito después de cambiar empresa:');
    print('   - Tiene línea: ${lineaCreditoData['tiene_linea_credito']}');
    print('   - Monto total: ${lineaCreditoData['monto_total']}');
    print('   - Monto disponible: ${lineaCreditoData['monto_disponible']}');
  }

  // ✅ MÉTODO MEJORADO: MOSTRAR DIÁLOGO PARA NUEVA EMPRESA CON OPCIONES DE ROL Y SCROLL
  void _mostrarDialogoNuevaEmpresa() {
    final TextEditingController rutController = TextEditingController();
    bool rutValido = false;
    String mensajeValidacion = '';
    String? tipoRelacionSeleccionada;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header limpio sin fondo
                    Container(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Añadir Nueva Empresa',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _blueDarkColor,
                        ),
                      ),
                    ),

                    // Línea divisoria sutil
                    Container(
                      height: 1,
                      color: Colors.grey.shade300,
                    ),

                    // Contenido scrollable
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Formato: sin puntos, con guión y dígito verificador',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Campo de RUT
                            TextFormField(
                              controller: rutController,
                              decoration: InputDecoration(
                                labelText: 'RUT (ej: 12345678-9)',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                suffixIcon: rutController.text.isNotEmpty
                                    ? Icon(
                                  rutValido ? Icons.check_circle : Icons.error,
                                  color: rutValido ? Colors.green : Colors.red,
                                )
                                    : null,
                              ),
                              onChanged: (value) {
                                // Formatear automáticamente usando la lógica de tu código
                                final formattedRut = RutUtils.formatRut(value);
                                if (formattedRut != value) {
                                  rutController.value = TextEditingValue(
                                    text: formattedRut,
                                    selection: TextSelection.collapsed(offset: formattedRut.length),
                                  );
                                }

                                // Validar RUT usando tu lógica
                                final valido = RutUtils.validateRut(formattedRut);

                                // ✅ NUEVA VALIDACIÓN: VERIFICAR SI YA EXISTE
                                String mensajeDuplicado = '';
                                if (valido) {
                                  final rutParseado = RutUtils.parseRut(formattedRut);
                                  final rutEmpresa = rutParseado['numero'] ?? '';
                                  final dvEmpresa = rutParseado['dv'] ?? '';

                                  if (_rutEmpresaYaExiste(rutEmpresa, dvEmpresa)) {
                                    mensajeDuplicado = 'Esta empresa ya está registrada';
                                  }
                                }

                                setState(() {
                                  rutValido = valido && mensajeDuplicado.isEmpty;
                                  mensajeValidacion = mensajeDuplicado.isNotEmpty
                                      ? mensajeDuplicado
                                      : (valido ? 'RUT válido' : 'RUT inválido');
                                });
                              },
                            ),
                            if (mensajeValidacion.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                mensajeValidacion,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: rutValido ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],

                            const SizedBox(height: 20),

                            // ✅ NUEVO: SELECTOR DE TIPO DE RELACIÓN (EN VERTICAL)
                            _buildSelectorTipoRelacionVertical(
                              tipoSeleccionado: tipoRelacionSeleccionada,
                              onTipoCambiado: (String tipo) {
                                setState(() {
                                  tipoRelacionSeleccionada = tipo;
                                });
                              },
                            ),

                            const SizedBox(height: 8),

                            // ✅ NUEVO: INFORMACIÓN ADICIONAL SOBRE LOS TIPOS
                            if (tipoRelacionSeleccionada != null)
                              _buildInfoTipoRelacion(tipoRelacionSeleccionada!),

                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),

                    // Línea divisoria sutil
                    Container(
                      height: 1,
                      color: Colors.grey.shade300,
                    ),

                    // Botones en la parte inferior
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.grey,
                            ),
                            child: const Text('Cancelar'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: (rutValido && tipoRelacionSeleccionada != null)
                                ? () {
                              final rut = rutController.text.trim();
                              Navigator.pop(context);
                              _agregarNuevaEmpresa(rut, tipoRelacionSeleccionada!);
                            }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _blueDarkColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Agregar',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ✅ NUEVO MÉTODO: CONSTRUIR SELECTOR DE TIPO DE RELACIÓN EN VERTICAL
  Widget _buildSelectorTipoRelacionVertical({
    required String? tipoSeleccionado,
    required Function(String) onTipoCambiado,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tipo de relación con la empresa',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),

        // OPCIÓN AUTORIZADOR (ARRIBA)
        _buildOpcionRelacionVertical(
          titulo: 'Autorizador',
          subtitulo: 'Persona autorizada para realizar compras',
          icono: Icons.person_outline,
          seleccionado: tipoSeleccionado == 'autorizador',
          onTap: () {
            onTipoCambiado('autorizador');
          },
        ),

        const SizedBox(height: 12),

        // OPCIÓN REPRESENTANTE (ABAJO)
        _buildOpcionRelacionVertical(
          titulo: 'Representante',
          subtitulo: 'Representante legal de la empresa',
          icono: Icons.badge_outlined,
          seleccionado: tipoSeleccionado == 'representante',
          onTap: () {
            onTipoCambiado('representante');
          },
        ),
      ],
    );
  }

  // ✅ NUEVO MÉTODO: CONSTRUIR OPCIÓN DE RELACIÓN EN VERTICAL CON ICONO A LA IZQUIERDA
  Widget _buildOpcionRelacionVertical({
    required String titulo,
    required String subtitulo,
    required IconData icono,
    required bool seleccionado,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: seleccionado
              ? _blueDarkColor.withOpacity(0.1)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: seleccionado ? _blueDarkColor : Colors.grey.shade300,
            width: seleccionado ? 2 : 1,
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
        child: Row(
          children: [
            // Icono a la izquierda
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: seleccionado ? _blueDarkColor : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: seleccionado ? _blueDarkColor : Colors.grey.shade400,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Icon(
                icono,
                color: seleccionado ? Colors.white : Colors.grey.shade600,
                size: 20,
              ),
            ),

            const SizedBox(width: 12),

            // Textos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        titulo,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: seleccionado ? _blueDarkColor : Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Checkmark cuando está seleccionado
                      if (seleccionado)
                        Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: Color(0xFF4CAF50),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  Text(
                    subtitulo,
                    style: TextStyle(
                      fontSize: 12,
                      color: seleccionado
                          ? _blueDarkColor.withOpacity(0.8)
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ NUEVO MÉTODO: CONSTRUIR INFORMACIÓN DEL TIPO SELECCIONADO (ACTUALIZADO)
  Widget _buildInfoTipoRelacion(String tipoRelacion) {
    final Map<String, Map<String, String>> infoTipos = {
      'autorizador': {
        'titulo': 'Autorizador',
        'descripcion': 'Eres una persona autorizada para realizar compras en nombre de la empresa.',
        'permisos': '• Autorizar compras\n• Consultar historial\n• Ver líneas de crédito',
      },
      'representante': {
        'titulo': 'Representante Legal',
        'descripcion': 'Eres el representante legal de la empresa con permisos administrativos completos.',
        'permisos': '• Todas las funciones de autorizador\n• Gestionar autorizadores',
      },
    };

    final info = infoTipos[tipoRelacion]!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _blueDarkColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _blueDarkColor.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: _blueDarkColor,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                info['titulo']!,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _blueDarkColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            info['descripcion']!,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            info['permisos']!,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ MÉTODO ACTUALIZADO: AGREGAR NUEVA EMPRESA
  Future<void> _agregarNuevaEmpresa(String rut, String tipoRelacion) async {
    print('🔄 Agregando nueva empresa con RUT: $rut');
    print('🎯 Tipo de relación seleccionado: $tipoRelacion');

    try {
      setState(() {
        _isLoading = true;
      });

      // Parsear RUT ingresado
      final rutParseado = RutUtils.parseRut(rut);
      final rutEmpresa = rutParseado['numero'] ?? '';
      final dvEmpresa = rutParseado['dv'] ?? '';

      if (rutEmpresa.isEmpty || dvEmpresa.isEmpty) {
        _mostrarSnackBar('RUT inválido');
        return;
      }

      // ✅ NUEVA VALIDACIÓN: VERIFICAR SI EL RUT YA EXISTE
      if (_rutEmpresaYaExiste(rutEmpresa, dvEmpresa)) {
        _mostrarSnackBar('Esta empresa ya está registrada en tu cuenta');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final runComprador = _currentUserData['comprador']?['run_comprador']?.toString() ?? '';
      final dvComprador = _currentUserData['comprador']?['dv_run_comprador']?.toString() ?? '';

      print('runComprador: $runComprador');
      print('dvComprador: $dvComprador');

      if (runComprador.isEmpty || dvComprador.isEmpty) {
        print('⚠️ No se pudo obtener RUN del comprador');
        print('📊 Datos del comprador: ${_currentUserData['comprador']}');
        _mostrarSnackBar('Error: No se pudo obtener RUN del usuario');
        return;
      }

      // Obtener token del comprador
      final tokenComprador = _getTokenComprador();

      // Determinar valor numérico para representante_o_autorizador
      final int valorRelacion = tipoRelacion == 'autorizador' ? 1 : 2;

      // ✅ CORREGIDO: Typo en el campo "represetante_o_autorizador"
      // Preparar request body
      final requestBody = {
        "token_comprador": tokenComprador,
        "run_comprador": runComprador,
        "dv_comprador": dvComprador,
        "rut_empresa": rutEmpresa,
        "dv_rut_empresa": dvEmpresa,
        "represetante_o_autorizador": valorRelacion.toString(),
      };

      print('📤 Request AgregarEmpresaAComprador:');
      print('🌐 URL: ${GlobalVariables.baseUrl}/AgregarEmpresaAComprador/api/v1/');
      print('📋 Body: ${json.encode(requestBody)}');

      // Llamar a la API
      final response = await http.post(
        Uri.parse('${GlobalVariables.baseUrl}/AgregarEmpresaAComprador/api/v1/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'api-key': '${GlobalVariables.apiKey}',
        },
        body: json.encode(requestBody),
      );

      print('📥 Response AgregarEmpresaAComprador:');
      print('  - Status: ${response.statusCode}');
      print('  - Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('✅ API Response:');
        _printCompleteResponse(response.body);

        if (responseData['success'] == true) {
          _mostrarSnackBar('Empresa agregada exitosamente');

          // Actualizar datos del usuario
          await _verificarSesionActualizada();
        } else {
          final mensajeError = responseData['message'] ?? 'Error desconocido';
          _mostrarSnackBar('Error: $mensajeError');
        }
      } else {
        print('❌ Error en API AgregarEmpresaAComprador - Status: ${response.statusCode}');
        _mostrarSnackBar('Error al agregar empresa: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error agregando nueva empresa: $e');
      _mostrarSnackBar('Error de conexión: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ✅ MÉTODO MEJORADO: MOSTRAR DIÁLOGO PARA NUEVO AUTORIZADOR
  void _mostrarDialogoNuevoAutorizador() {
    final TextEditingController runController = TextEditingController();
    bool runValido = false;
    String mensajeValidacion = '';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                'Asignar Nuevo Autorizador',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _blueDarkColor,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Formato: sin puntos, con guión y dígito verificador',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: runController,
                    decoration: InputDecoration(
                      labelText: 'RUN (ej: 12345678-9)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      suffixIcon: runController.text.isNotEmpty
                          ? Icon(
                        runValido ? Icons.check_circle : Icons.error,
                        color: runValido ? Colors.green : Colors.red,
                      )
                          : null,
                    ),
                    onChanged: (value) {
                      // Formatear automáticamente usando la lógica de tu código
                      final formattedRun = RutUtils.formatRut(value);
                      if (formattedRun != value) {
                        runController.value = TextEditingValue(
                          text: formattedRun,
                          selection: TextSelection.collapsed(offset: formattedRun.length),
                        );
                      }

                      // Validar RUN usando tu lógica
                      final valido = RutUtils.validateRut(formattedRun);
                      setState(() {
                        runValido = valido;
                        mensajeValidacion = valido ? 'RUN válido' : 'RUN inválido';
                      });
                    },
                  ),
                  if (mensajeValidacion.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      mensajeValidacion,
                      style: TextStyle(
                        fontSize: 12,
                        color: runValido ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
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
                  onPressed: runValido
                      ? () {
                    final run = runController.text.trim();
                    Navigator.pop(context);
                    _asignarNuevoAutorizador(run);
                  }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blueDarkColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Asignar',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ✅ NUEVO MÉTODO: ASIGNAR NUEVO AUTORIZADOR (CON LLAMADA A API - CORREGIDO)
  Future<void> _asignarNuevoAutorizador(String run) async {
    print('🔄 Asignando nuevo autorizador con RUN: $run');

    try {
      setState(() {
        _isLoading = true;
      });

      // Parsear RUN ingresado
      final runParseado = RutUtils.parseRut(run);
      final runAutorizador = runParseado['numero'] ?? '';
      final dvAutorizador = runParseado['dv'] ?? '';

      if (runAutorizador.isEmpty || dvAutorizador.isEmpty) {
        _mostrarSnackBar('RUN inválido');
        return;
      }

      // Obtener datos de la empresa seleccionada
      final empresa = _getEmpresaSeleccionada();
      if (empresa == null || empresa.isEmpty) {
        _mostrarSnackBar('No hay empresa seleccionada');
        return;
      }

      final rutEmpresa = empresa['rut_empresa']?.toString() ?? '';
      final dvEmpresa = empresa['dv_rut_empresa']?.toString() ?? '';
      final tokenRepresentante = _getTokenComprador();

      // Preparar request body
      final requestBody = {
        "token_representante": tokenRepresentante,
        "run_autorizador": runAutorizador,
        "dv_autorizador": dvAutorizador,
        "rut_empresa": rutEmpresa,
        "dv_empresa": dvEmpresa,
      };

      print('📤 Request CrearAutorizador:');
      print('🌐 URL: ${GlobalVariables.baseUrl}/CrearAutorizador/api/v1/');
      print('📋 Body: ${json.encode(requestBody)}');

      // Llamar a la API
      final response = await http.post(
        Uri.parse('${GlobalVariables.baseUrl}/CrearAutorizador/api/v1/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'api-key': '${GlobalVariables.apiKey}',
        },
        body: json.encode(requestBody),
      );

      print('📥 Response CrearAutorizador:');
      print('  - Status: ${response.statusCode}');
      print('  - Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('✅ API Response:');
        _printCompleteResponse(response.body);

        if (responseData['success'] == true) {
          _mostrarSnackBar('Autorizador asignado exitosamente');

          // ✅ NUEVO: MOSTRAR LA LISTA DE AUTORIZADORES DESPUÉS DE AGREGAR
          await Future.delayed(const Duration(milliseconds: 500));
          _mostrarListaAutorizadores();
        } else {
          final mensajeError = responseData['message'] ?? 'Error desconocido';
          _mostrarSnackBar('Error: $mensajeError');
        }
      } else {
        print('❌ Error en API CrearAutorizador - Status: ${response.statusCode}');
        _mostrarSnackBar('Error al asignar autorizador: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error asignando nuevo autorizador: $e');
      _mostrarSnackBar('Error de conexión: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ✅ NUEVO MÉTODO: OBTENER AUTORIZADORES DE LA API (CORREGIDO)
  Future<void> _obtenerAutorizadores() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Obtener datos de la empresa seleccionada
      final empresa = _getEmpresaSeleccionada();
      if (empresa == null || empresa.isEmpty) {
        _mostrarSnackBar('No hay empresa seleccionada');
        return;
      }

      final tokenEmpresa = empresa['token_empresa']?.toString() ?? '';
      final tokenRepresentante = _getTokenComprador();

      // Preparar request body
      final requestBody = {
        "token_representante": tokenRepresentante,
        "token_empresa": tokenEmpresa,
      };

      print('📤 Request ListarAutorizadores:');
      print('🌐 URL: ${GlobalVariables.baseUrl}/ListarAutorizadores/api/v1/');
      print('📋 Body: ${json.encode(requestBody)}');

      // Llamar a la API
      final response = await http.post(
        Uri.parse('${GlobalVariables.baseUrl}/ListarAutorizadores/api/v1/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'api-key': '${GlobalVariables.apiKey}',
        },
        body: json.encode(requestBody),
      );

      print('📥 Response ListarAutorizadores:');
      print('  - Status: ${response.statusCode}');
      print('  - Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('✅ API Response:');
        _printCompleteResponse(response.body);

        // ✅ CORREGIDO: Campo correcto es "autorizadores_designados"
        if (responseData.containsKey('autorizadores_designados') &&
            responseData['autorizadores_designados'] is List) {
          final List<dynamic> autorizadoresData = responseData['autorizadores_designados'];

          setState(() {
            _autorizadores = autorizadoresData.map((item) {
              // Formatear RUN para mostrar
              final runNumero = item['run_comprador']?.toString() ?? '';
              final runDv = item['dv_run_comprador']?.toString() ?? '1';
              final runCompleto = '$runNumero-$runDv';
              final runFormateado = RutUtils.formatRut(runCompleto);

              return {
                'nombre': item['nombre_comprador']?.toString() ?? 'Sin nombre',
                'run': runFormateado,
                'run_numero': runNumero,
                'run_dv': runDv,
                'token': item['token_comprador']?.toString() ?? '',
              };
            }).toList();
          });

          print('📋 Autorizadores obtenidos: ${_autorizadores.length}');
        } else {
          print('⚠️ No se encontró campo "autorizadores_designados" en la respuesta');
          setState(() {
            _autorizadores = [];
          });
        }
      } else {
        print('❌ Error en API ListarAutorizadores - Status: ${response.statusCode}');
        setState(() {
          _autorizadores = [];
        });
      }
    } catch (e) {
      print('❌ Error obteniendo autorizadores: $e');
      setState(() {
        _autorizadores = [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ✅ NUEVO MÉTODO: ELIMINAR AUTORIZADOR (IMPLEMENTADO CON API - CON COLOR AZUL Y CORREGIDO)
  void _eliminarAutorizador(Map<String, dynamic> autorizador) {
    print('🗑️ Eliminando autorizador: ${autorizador['nombre']}');

    // ✅ GUARDAR EL CONTEXTO ANTES DE CERRAR EL MODAL
    final BuildContext currentContext = context;

    showDialog(
      context: currentContext,
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
              await _cambiarValidezAutorizador(autorizador, currentContext);
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

  // ✅ NUEVO MÉTODO: CAMBIAR VALIDEZ DEL AUTORIZADOR (CORREGIDO)
  Future<void> _cambiarValidezAutorizador(Map<String, dynamic> autorizador, BuildContext dialogContext) async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Obtener datos de la empresa seleccionada
      final empresa = _getEmpresaSeleccionada();
      if (empresa == null || empresa.isEmpty) {
        if (mounted) {
          _mostrarSnackBar('No hay empresa seleccionada');
        }
        return;
      }

      final rutEmpresa = empresa['rut_empresa']?.toString() ?? '';
      final dvEmpresa = empresa['dv_rut_empresa']?.toString() ?? '';
      final tokenRepresentante = _getTokenComprador();
      final runAutorizador = autorizador['run_numero'] ?? '';
      final dvRunAutorizador = autorizador['run_dv'] ?? '';

      // Preparar request body
      final requestBody = {
        "token_representante": tokenRepresentante,
        "run_autorizador": runAutorizador,
        "dv_run_autorizador": dvRunAutorizador,
        "rut_empresa_autorizador": rutEmpresa,
        "dv_rut_empresa_autorizador": dvEmpresa,
      };

      print('📤 Request CambiarValidezCompradorDesignado:');
      print('🌐 URL: ${GlobalVariables.baseUrl}/CambiarValidezCompradorDesignado/api/v1/');
      print('📋 Body: ${json.encode(requestBody)}');

      // Llamar a la API
      final response = await http.post(
        Uri.parse('${GlobalVariables.baseUrl}/CambiarValidezCompradorDesignado/api/v1/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'api-key': '${GlobalVariables.apiKey}',
        },
        body: json.encode(requestBody),
      );

      print('📥 Response CambiarValidezCompradorDesignado:');
      print('  - Status: ${response.statusCode}');
      print('  - Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('✅ API Response:');
        _printCompleteResponse(response.body);

        if (responseData['success'] == true) {
          // ✅ CERRAR EL MODAL DE LISTA DE AUTORIZADORES
          Navigator.pop(dialogContext);

          _mostrarSnackBar('Autorizador eliminado exitosamente');

          // ✅ ACTUALIZAR LA LISTA DE AUTORIZADORES
          await _obtenerAutorizadores();

          // ✅ VOLVER A MOSTRAR LA LISTA ACTUALIZADA DESPUÉS DE UN PEQUEÑO RETRASO
          await Future.delayed(const Duration(milliseconds: 300));
          _mostrarListaAutorizadores();
        } else {
          final mensajeError = responseData['message'] ?? 'Error desconocido';
          _mostrarSnackBar('Error: $mensajeError');
        }
      } else {
        print('❌ Error en API CambiarValidezCompradorDesignado - Status: ${response.statusCode}');
        _mostrarSnackBar('Error al eliminar autorizador: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error eliminando autorizador: $e');
      _mostrarSnackBar('Error de conexión: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ✅ NUEVO MÉTODO: MOSTRAR LISTA DE AUTORIZADORES CON DATOS DE LA API (CORREGIDO)
  void _mostrarListaAutorizadores() {
    // Obtener autorizadores de la API antes de mostrar
    _obtenerAutorizadores().then((_) {
      final BuildContext currentContext = context;

      if (!mounted) return;

      showModalBottomSheet(
        context: currentContext,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        isScrollControlled: true,
        builder: (context) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Autorizadores',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _blueDarkColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Personas autorizadas en la empresa',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _isLoading
                    ? Center(
                  child: CircularProgressIndicator(
                    color: _blueDarkColor,
                  ),
                )
                    : _autorizadores.isEmpty
                    ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No hay autorizadores registrados',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
                    : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _autorizadores.length,
                  itemBuilder: (context, index) {
                    final autorizador = _autorizadores[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _approvedCardBackground,
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
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _blueDarkColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.person,
                              color: _blueDarkColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  autorizador['nombre']!,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'RUN: ${autorizador['run']}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              _eliminarAutorizador(autorizador);
                            },
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.red.shade200,
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey,
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Cerrar'),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  // ✅ NUEVO MÉTODO: MOSTRAR SNACKBAR
  void _mostrarSnackBar(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  // ✅ NUEVO MÉTODO: CONSTRUIR ITEM DE OPCIÓN
  Widget _buildOptionItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _blueDarkColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: _blueDarkColor,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey.shade600,
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }

  // ✅ NUEVO MÉTODO: CONSTRUIR HOME SCREEN CON PULL TO REFRESH
  Widget _buildHomeScreenWithRefresh() {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: _blueDarkColor,
      backgroundColor: Colors.white,
      displacement: 40,
      edgeOffset: 0,
      child: _buildHomeScreen(),
    );
  }

  // ✅ MÉTODO: IMPRIMIR RESPONSE COMPLETO
  void _printCompleteResponse(String responseBody) {
    try {
      final parsedJson = json.decode(responseBody);
      final formattedJson = JsonEncoder.withIndent('  ').convert(parsedJson);

      print('📋 RESPONSE COMPLETO:');
      print('=' * 50);
      print(formattedJson);
      print('=' * 50);
    } catch (e) {
      print('❌ Error formateando JSON: $e');
      print('📋 RESPONSE COMPLETO (texto plano):');
      print('=' * 50);
      print(responseBody);
      print('=' * 50);
    }
  }

  // ✅ MÉTODO: IMPRIMIR DATOS DE LÍNEA DE CRÉDITO
  void _printLineaCreditoData() {
    print('💳 DATOS LÍNEA CRÉDITO:');
    final lineasCredito = _currentUserData['lineas_credito'] ?? [];
    print('- Cantidad de líneas: ${lineasCredito.length}');

    for (int i = 0; i < lineasCredito.length; i++) {
      final linea = lineasCredito[i];
      print('\n📊 LÍNEA ${i + 1}:');

      final montoTotal = linea['monto_linea_credito'] ?? 0;
      final montoUtilizado = linea['monto_utilizado'] ?? 0;
      final montoDisponible = linea['monto_disponible'] ?? montoTotal;
      final porcentajeUtilizado = montoTotal > 0 ? (montoUtilizado / montoTotal * 100) : 0;

      print('💰 FINANCIERO:');
      print('   - Total: \$${_formatCurrency(montoTotal)}');
      print('   - Utilizado: \$${_formatCurrency(montoUtilizado)}');
      print('   - Disponible: \$${_formatCurrency(montoDisponible)}');
      print('   - Porcentaje: ${porcentajeUtilizado.toStringAsFixed(1)}%');

      print('📅 FECHAS:');
      print('   - Asignación: ${_formatDate(linea['fecha_asignacion'] ?? '')}');
      print('   - Caducidad: ${_formatDate(linea['fecha_caducidad'] ?? '')}');

      if (linea['empresa'] != null) {
        final empresa = linea['empresa'];
        print('🏢 EMPRESA:');
        print('   - RUT: ${empresa['rut_empresa']}-${empresa['dv_rut_empresa']}');
        print('   - Estado: ${_getEstadoEmpresaTexto(empresa['estado_empresa'])}');
      }
    }
  }

  // ✅ MÉTODO: IMPRIMIR DATOS DE EMPRESA
  void _printEmpresaData() {
    print('🏢 DATOS EMPRESA:');
    final empresas = _currentUserData['empresas'] ?? [];
    print('- Cantidad de empresas: ${empresas.length}');

    for (int i = 0; i < empresas.length; i++) {
      final empresa = empresas[i];
      print('  Empresa ${i + 1}:');
      print('    - Token: ${empresa['token_empresa']}');
      print('    - RUT: ${empresa['rut_empresa']}');
      print('    - DV: ${empresa['dv_rut_empresa']}');
      print('    - Estado: ${empresa['estado_empresa']}');
      print('    - Nombre: ${empresa['nombre_empresa']}');
    }
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

  bool _debeMostrarNombreEmpresa(Map<String, dynamic>? empresa) {
    if (empresa == null || empresa.isEmpty) return false;

    final nombreEmpresa = empresa['nombre_empresa']?.toString() ?? '';
    if (nombreEmpresa.isEmpty || nombreEmpresa.trim().isEmpty) return false;

    final validezRelacion = empresa['validez_relacion']?.toString().toLowerCase() ?? '';
    if (validezRelacion.contains('no válida')) return false;

    return true;
  }

  // ✅ MÉTODO REEMPLAZADO: MOSTRAR EMPRESA SELECCIONADA COMO TEXTO PLANO
  Widget _buildEmpresaInfo() {
    final empresa = _getEmpresaSeleccionada();

    if (empresa == null || empresa.isEmpty) {
      return const SizedBox.shrink();
    }
    if (!_debeMostrarNombreEmpresa(empresa)) {
      return const SizedBox.shrink();
    }
    final nombreEmpresa = empresa['nombre_empresa']?.toString() ?? '';

    if (nombreEmpresa.isEmpty || nombreEmpresa.trim().isEmpty) {
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

  // ✅ NUEVO MÉTODO: CONSTRUIR INDICADOR DE RELACIÓN (TEXTO CON ICONO)
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

  // Método para formatear moneda
  String _formatCurrency(int amount) {
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

  // ✅ MÉTODO CORREGIDO: OBTENER DATOS REALES DE LÍNEA DE CRÉDITO POR EMPRESA
  Map<String, dynamic> _getLineaCreditoData() {
    try {
      final lineasCredito = _currentUserData['lineas_credito'] ?? [];

      print('🔍 Buscando línea de crédito para empresa seleccionada:');
      print('   - Empresa seleccionada token: $_empresaSeleccionada');
      print('   - Total de líneas de crédito: ${lineasCredito.length}');

      // ✅ BUSCAR LÍNEA DE CRÉDITO ESPECÍFICA PARA LA EMPRESA SELECCIONADA
      if (_empresaSeleccionada != null) {
        // Depurar todas las líneas de crédito disponibles
        for (int i = 0; i < lineasCredito.length; i++) {
          final linea = lineasCredito[i];
          final empresaLinea = linea['empresa'];
          final tokenEmpresaLinea = empresaLinea?['token_empresa'];

          print('   📋 Línea ${i + 1}:');
          print('      - Token empresa en línea: $tokenEmpresaLinea');
          print('      - ¿Coincide?: ${tokenEmpresaLinea == _empresaSeleccionada}');
          print('      - Monto total: ${linea['monto_linea_credito']}');

          if (tokenEmpresaLinea == _empresaSeleccionada) {
            final montoTotal = linea['monto_linea_credito'] ?? 0;
            final montoUtilizado = linea['monto_utilizado'] ?? 0;
            final montoDisponible = linea['monto_disponible'] ?? montoTotal;

            // ✅ CORREGIDO: Mejor lógica para determinar si tiene línea de crédito
            // Verificamos si hay una línea de crédito asignada (monto total > 0)
            // y también si la empresa tiene relación válida
            final tieneLineaCredito = montoTotal > 0;
            final empresa = _getEmpresaSeleccionada();
            final relacionValida = empresa != null ? _esRelacionValida() : false;

            print('   ✅ ENCONTRADA línea para empresa seleccionada');
            print('      - Monto total: $montoTotal');
            print('      - Monto utilizado: $montoUtilizado');
            print('      - Monto disponible: $montoDisponible');
            print('      - ¿Tiene línea de crédito?: $tieneLineaCredito');
            print('      - ¿Relación válida?: $relacionValida');

            return {
              'monto_total': montoTotal,
              'monto_utilizado': montoUtilizado,
              'monto_disponible': montoDisponible,
              'fecha_asignacion': linea['fecha_asignacion'] ?? '',
              'fecha_caducidad': linea['fecha_caducidad'] ?? '',
              // ✅ CORREGIDO: Solo tiene línea de crédito si montoTotal > 0
              'tiene_linea_credito': tieneLineaCredito,
              // ✅ AGREGADO: Campo para saber si es una línea de crédito válida (con relación válida)
              'linea_valida': tieneLineaCredito && relacionValida,
            };
          }
        }

        print('   ❌ NO se encontró línea de crédito para empresa seleccionada');

        // Si no se encontró línea específica, verificar si hay alguna empresa
        final empresas = _currentUserData['empresas'] ?? [];
        print('   🔍 Verificando empresas disponibles:');
        for (final empresa in empresas) {
          print('      - Token: ${empresa['token_empresa']}, Nombre: ${empresa['nombre_empresa']}');
        }
      } else {
        print('   ⚠️ No hay empresa seleccionada (_empresaSeleccionada es null)');
      }

      // ✅ SI NO ENCUENTRA LÍNEA ESPECÍFICA, MOSTRAR DATOS VACÍOS
      print('   📊 Retornando datos vacíos - sin línea de crédito');
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
      print('❌ Error obteniendo datos de línea de crédito: $e');
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

  // ✅ MÉTODO CORREGIDO: CALCULAR PORCENTAJE UTILIZADO CON DATOS REALES
  double _getPorcentajeUtilizado() {
    final data = _getLineaCreditoData();
    final montoTotal = data['monto_total'] as int;
    final montoUtilizado = data['monto_utilizado'] as int;

    if (montoTotal == 0) return 0.0;
    return montoUtilizado / montoTotal;
  }

  // ✅ MÉTODO: OBTENER PORCENTAJE UTILIZADO EN TEXTO
  String _getPorcentajeUtilizadoTexto() {
    final porcentaje = _getPorcentajeUtilizado() * 100;
    return '(${porcentaje.toStringAsFixed(1)}%)';
  }

  // Método para obtener tokens de forma segura
  String _getTokenComprador() {
    try {
      return _currentUserData['comprador']?['token_comprador'] ?? '';
    } catch (e) {
      return '';
    }
  }

  String _getTokenDispositivo() {
    try {
      return _currentUserData['dispositivo_actual']?['token_dispositivo'] ??
          _currentUserData['dispositivos']?[0]?['token_dispositivo'] ?? '';
    } catch (e) {
      return '';
    }
  }

  // ✅ MÉTODO DE LOGOUT
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
            'api-key': '${GlobalVariables.apiKey}',
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

    // ✅ LISTA DE PANTALLAS CORREGIDA - SIN onEmpresaCambiada
    List<Widget> _getScreens() {
    return [
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
    ),
    ];
    }

    // ✅ MÉTODO MODIFICADO: TARJETA DE MONTO DISPONIBLE CON ANIMACIÓN CORREGIDA
    Widget _buildTarjetaMontoDisponible({
    required int montoDisponible,
    required int montoTotal,
    required int montoUtilizado,
    required double porcentajeUtilizado,
    }) {
    // Calcular porcentaje animado
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

    // ✅ BARRA DE PROGRESO ANIMADA MEJORADA
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
    // Fondo de la barra
    Container(
    width: double.infinity,
    decoration: BoxDecoration(
    color: const Color(0xFFE0E0E0),
    borderRadius: BorderRadius.circular(4),
    ),
    ),
    // Barra de progreso animada
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

    // ✅ NUEVO MÉTODO: TARJETA DE FECHAS CON NUEVO DISEÑO
    Widget _buildTarjetaFechas(Map<String, dynamic> lineaCreditoData) {
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
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
    color: _approvedCardBackground,
    borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    Text(
    'Información de la línea',
    style: TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: _blueDarkColor,
    ),
    ),
    const SizedBox(height: 16),

    if (lineaCreditoData['fecha_asignacion'] != '')
    Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
    children: [
    Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
    color: _blueDarkColor.withOpacity(0.1),
    shape: BoxShape.circle,
    ),
    child: Icon(
    Icons.calendar_today,
    color: _blueDarkColor,
    size: 20,
    ),
    ),
    const SizedBox(width: 12),
    Expanded(
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    Text(
    'Asignado',
    style: TextStyle(
    fontSize: 12,
    color: Colors.grey,
    ),
    ),
    Text(
    _formatDate(lineaCreditoData['fecha_asignacion'] as String),
    style: const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.black,
    ),
    ),
    ],
    ),
    ),
    ],
    ),
    ),
    if (lineaCreditoData['fecha_caducidad'] != '')
    Row(
    children: [
    Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
    color: _blueDarkColor.withOpacity(0.1),
    shape: BoxShape.circle,
    ),
    child: Icon(
    Icons.event_busy,
    color: _blueDarkColor,
    size: 20,
    ),
    ),
    const SizedBox(width: 12),
    Expanded(
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    Text(
    'Vence',
    style: TextStyle(
    fontSize: 12,
    color: Colors.grey,
    ),
    ),
    Text(
    _formatDate(lineaCreditoData['fecha_caducidad'] as String),
    style: const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.black,
    ),
    ),
    ],
    ),
    ),
    ],
    ),
    ],
    ),
    ),
    ),
    );
    }

    // ✅ MÉTODO: FORMATEAR FECHA
    String _formatDate(String dateString) {
    try {
    final date = DateTime.parse(dateString);
    return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
    return dateString;
    }
    }

    // ✅ MÉTODO MODIFICADO: CONSTRUIR SECCIÓN DE VERIFICACIÓN CON NUEVO DISEÑO
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
    // Icono y título en una fila
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

    // Subtítulo con más espacio
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

    // Botón alineado a la derecha
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

    // ✅ MÉTODO: OBTENER TEXTO DEL ESTADO DE EMPRESA
    String _getEstadoEmpresaTexto(dynamic estado) {
    if (estado == null) return 'Desconocido';

    switch (estado) {
    case 2:
    return 'Pendiente';
    case 3:
    return 'Aprobada';
    case 4:
    return 'Rechazada';
    case 5:
    return 'Caducada';
    default:
    return 'Desconocido ($estado)';
    }
    }

    // ✅ MÉTODOS PARA VERIFICACIONES
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

    // ✅ MÉTODO ACTUALIZADO: CAMBIAR A LA SIGUIENTE EMPRESA (DOUBLE TAP)
    void _cambiarSiguienteEmpresa() {
    final empresas = _currentUserData['empresas'] ?? [];

    if (empresas.isEmpty) {
    _mostrarSnackBar('No hay empresas disponibles');
    return;
    }

    final int cantidadEmpresas = empresas.length;

    if (cantidadEmpresas == 1) {
    _mostrarSnackBar('Solo hay una empresa disponible');
    return;
    }

    // Encontrar el índice de la empresa actual
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
    _mostrarSnackBar('Cambiando a: $nombreEmpresa');

    // Cambiar la empresa
    setState(() {
    _empresaSeleccionada = nuevaEmpresaToken;
    });

    // ✅ ACTUALIZAR VALORES ANIMADOS Y REINICIAR ANIMACIÓN
    _actualizarValoresAnimados();
    _iniciarAnimacion();
    }

    bool _rutEmpresaYaExiste(String rutEmpresa, String dvEmpresa) {
    try {
    final empresas = _currentUserData['empresas'] ?? [];

    for (final empresa in empresas) {
    final rutExistente = empresa['rut_empresa']?.toString() ?? '';
    final dvExistente = empresa['dv_rut_empresa']?.toString() ?? '';

    // Comparar sin formato
    if (rutExistente == rutEmpresa && dvExistente == dvEmpresa) {
    return true;
    }

    // También comparar con formato para mayor seguridad
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

    // ✅ MÉTODO: CONSTRUIR HOME SCREEN COMPLETO
    Widget _buildHomeScreen() {
    final int userStatus = _getUserStatus();
    final lineaCreditoData = _getLineaCreditoData();

    // ✅ OBTENER TODOS LOS DATOS NECESARIOS DEL NUEVO MÉTODO
    final bool tieneLineaCredito = lineaCreditoData['tiene_linea_credito'] as bool;
    final bool lineaValida = lineaCreditoData['linea_valida'] as bool;
    final bool relacionValida = _esRelacionValida();

    final int montoTotal = lineaCreditoData['monto_total'] as int;
    final int montoUtilizado = lineaCreditoData['monto_utilizado'] as int;
    final int montoDisponible = lineaCreditoData['monto_disponible'] as int;
    final double porcentajeUtilizado = _getPorcentajeUtilizado();

    // ✅ OBTENER LA INFORMACIÓN DE LA EMPRESA
    final empresaInfoWidget = _buildEmpresaInfo();

    return SingleChildScrollView(
    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
    physics: const AlwaysScrollableScrollPhysics(),
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    // ✅ SALUDO CON EMOJI
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
    // ✅ MOSTRAR NOMBRE DE EMPRESA SI HAY INFORMACIÓN
    if (empresaInfoWidget is! SizedBox) ...[
    const SizedBox(height: 4),
    empresaInfoWidget,
    ],
    // ✅ SIEMPRE MOSTRAR INDICADOR DE RELACIÓN CUANDO userStatus >= 3
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

    // ✅ MOSTRAR LÍNEA DE CRÉDITO SOLO SI:
    // 1. User status >= 3
    // 2. Hay empresa seleccionada
    // 3. La línea de crédito es válida (tiene monto y relación válida)
    if (userStatus >= 3 && _empresaSeleccionada != null && lineaValida) ...[
    const SizedBox(height: 16),

    // ✅ TARJETA DE LÍNEA DE CRÉDITO CON ANIMACIÓN
    _buildTarjetaMontoDisponible(
    montoDisponible: montoDisponible,
    montoTotal: montoTotal,
    montoUtilizado: montoUtilizado,
    porcentajeUtilizado: porcentajeUtilizado,
    ),

    // ✅ TARJETA DE FECHAS SOLO SI LA RELACIÓN ES VÁLIDA
    if (relacionValida && lineaCreditoData['fecha_asignacion'] != '') ...[
    const SizedBox(height: 16),
    _buildTarjetaFechas(lineaCreditoData),
    ],

    const SizedBox(height: 24),
    ],

    // ✅ MOSTRAR MENSAJES INFORMATIVOS SEGÚN LA SITUACIÓN
    if (userStatus >= 3 && _empresaSeleccionada != null) ...[
    // Caso 1: Tiene línea de crédito pero relación no válida
    if (tieneLineaCredito && !relacionValida) ...[
    const SizedBox(height: 16),
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

    // Caso 2: No tiene línea de crédito pero relación es válida
    else if (!tieneLineaCredito && relacionValida) ...[
    const SizedBox(height: 16),
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

    // Caso 3: No tiene línea de crédito y relación no válida
    else if (!tieneLineaCredito && !relacionValida) ...[
    const SizedBox(height: 16),
    Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
    color: Colors.grey.shade100,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: Colors.grey.shade300),
    ),
    child: Row(
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
    ),
    ],

    const SizedBox(height: 16),
    ],

    const SizedBox(height: 24),
    ],
    ),
    );
    }

    // ✅ MÉTODO BUILD COMPLETO
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
        : PageView(
    controller: _pageController,
    physics: const PageScrollPhysics(),
    onPageChanged: (index) {
    setState(() {
    _currentIndex = index;
    });
    },
    children: _getScreens(),
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
    if (index == 2) {
    final now = DateTime.now();
    if (_lastProfileTap != null &&
    now.difference(_lastProfileTap!) < Duration(milliseconds: 500)) {
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