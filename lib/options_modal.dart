import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'variables_globales.dart';

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
void reiniciarAplicacion(BuildContext context) {
  print('🔄 Reiniciando aplicación desde OptionsModal...');

  Navigator.pushNamedAndRemoveUntil(
    context,
    '/',
        (route) => false,
  );

  if (Navigator.canPop(context)) {
    Navigator.popUntil(context, (route) => route.isFirst);
  }
}

// ✅ CLASE PARA MANEJAR TOKENS FCM DE MANERA SEGURA
class FCMTokenManager {
  static Future<String> getDeviceToken() async {
    try {
      print('🔄 Inicializando Firebase para obtener token...');
      await Firebase.initializeApp();

      print('🔄 Obteniendo token FCM...');
      String? fcmToken = await FirebaseMessaging.instance.getToken();

      if (fcmToken != null) {
        print('✅ Token FCM obtenido exitosamente');
        return fcmToken;
      } else {
        print('⚠️ Token FCM es null, reintentando...');
        // Esperar un momento y reintentar
        await Future.delayed(const Duration(seconds: 1));
        fcmToken = await FirebaseMessaging.instance.getToken();

        if (fcmToken != null) {
          print('✅ Token FCM obtenido en segundo intento');
          return fcmToken;
        } else {
          print('⚠️ No se pudo obtener token FCM, creando fallback');
          return 'fcm_fallback_${DateTime.now().millisecondsSinceEpoch}';
        }
      }
    } catch (e) {
      print('❌ Error obteniendo token FCM: $e');
      return 'fcm_error_${DateTime.now().millisecondsSinceEpoch}';
    }
  }
}

// Clase estática para manejar el modal de opciones
class OptionsModal {
  // Método estático para mostrar el modal de opciones
  static Future<void> show({
    required BuildContext context,
    required Map<String, dynamic> userData,
    required String? empresaSeleccionada,
    required Function(String) onCambiarEmpresa,
    required VoidCallback onMostrarAutorizadores,
    required VoidCallback onMostrarNuevaEmpresa,
    required VoidCallback onReiniciarApp,
    required VoidCallback onActualizarVista,
  }) {
    final empresa = _getEmpresaSeleccionada(userData, empresaSeleccionada);
    final bool esRepresentanteValido = _esRepresentanteValido(empresa);

    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Opciones',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _blueDarkColor,
                ),
              ),
              const SizedBox(height: 20),

              // ✅ TARJETA QUE SE PUEDE TOCAR EN CUALQUIER LADO
              _buildTarjetaEmpresaSeleccionadaInteractiva(
                context: context,
                empresa: empresa,
                userData: userData,
                empresaSeleccionada: empresaSeleccionada,
                onCambiarEmpresa: onCambiarEmpresa,
                onReiniciarApp: onReiniciarApp,
                onActualizarVista: onActualizarVista,
              ),

              const SizedBox(height: 16),

              // ✅ BOTÓN PARA NUEVA EMPRESA (REDIRIGE A PANTALLA COMPLETA)
              _buildOptionItem(
                icon: Icons.add_business,
                title: 'Agregar nueva empresa',
                subtitle: 'Registrar nueva empresa con RUT',
                onTap: () {
                  Navigator.pop(context); // Cerrar el modal
                  onMostrarNuevaEmpresa(); // ✅ Llamar al callback para mostrar pantalla
                },
              ),

              if (esRepresentanteValido) ...[
                const SizedBox(height: 16),
                _buildOptionItem(
                  icon: Icons.people,
                  title: 'Ver autorizadores',
                  subtitle: 'Lista de personas autorizadas',
                  onTap: () {
                    Navigator.pop(context);
                    onMostrarAutorizadores();
                  },
                ),
              ],

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
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

  // NUEVO: Pantalla completa de autorizadores
  static Widget crearVistaAutorizadores({
    required BuildContext context,
    required Map<String, dynamic> userData,
    required String? empresaSeleccionada,
    required Function(String) onAsignarAutorizador,
    required VoidCallback onActualizarAutorizadores,
    required VoidCallback onVolver,
    required VoidCallback onReiniciarApp,
  }) {
    return _AutorizadoresScreen(
      userData: userData,
      empresaSeleccionada: empresaSeleccionada,
      onAsignarAutorizador: onAsignarAutorizador,
      onActualizarAutorizadores: onActualizarAutorizadores,
      onVolver: onVolver,
      onReiniciarApp: onReiniciarApp,
    );
  }

  // ✅ NUEVO: CREAR VISTA DE NUEVA EMPRESA
  static Widget crearVistaNuevaEmpresa({
    required BuildContext context,
    required Map<String, dynamic> userData,
    required Function(String, String) onAgregarEmpresa,
    required VoidCallback onVolver,
    required VoidCallback onReiniciarApp,
    required VoidCallback onActualizarDashboard,
  }) {
    return _NuevaEmpresaScreen(
      context: context,
      userData: userData,
      onAgregarEmpresa: onAgregarEmpresa,
      onVolver: onVolver,
      onReiniciarApp: onReiniciarApp,
      onActualizarDashboard: onActualizarDashboard,
    );
  }

  // Métodos auxiliares
  static Map<String, dynamic>? _getEmpresaSeleccionada(
      Map<String, dynamic> userData,
      String? empresaSeleccionada,
      ) {
    if (empresaSeleccionada == null) return null;

    final empresas = userData['empresas'] ?? [];
    return empresas.firstWhere(
          (emp) => emp['token_empresa'] == empresaSeleccionada,
      orElse: () => {},
    );
  }

  static bool _esRepresentanteValido(Map<String, dynamic>? empresa) {
    if (empresa == null || empresa.isEmpty) return false;

    final tipoRelacion = empresa['tipo_relacion']?.toString().toLowerCase() ?? '';
    final validezRelacion = empresa['validez_relacion']?.toString().toLowerCase() ?? '';

    return tipoRelacion.contains('representante') &&
        !validezRelacion.contains('no válida');
  }

  // ✅ TARJETA INTERACTIVA QUE SE PUEDE TOCAR EN CUALQUIER LADO
  static Widget _buildTarjetaEmpresaSeleccionadaInteractiva({
    required BuildContext context,
    required Map<String, dynamic>? empresa,
    required Map<String, dynamic> userData,
    required String? empresaSeleccionada,
    required Function(String) onCambiarEmpresa,
    required VoidCallback onReiniciarApp,
    required VoidCallback onActualizarVista,
  }) {
    String nombreEmpresa = 'No hay empresa seleccionada';
    String rutEmpresa = '';

    if (empresa != null && empresa.isNotEmpty) {
      final rut = empresa['rut_empresa']?.toString() ?? '';
      final dv = empresa['dv_rut_empresa']?.toString() ?? '';
      nombreEmpresa = empresa['nombre_empresa']?.toString() ?? 'Empresa ${rut}-$dv';

      final rutCompleto = '$rut-$dv';
      rutEmpresa = _formatRut(rutCompleto);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
          child: Text(
            'Empresa seleccionada',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        InkWell(
          onTap: () {
            Navigator.of(context, rootNavigator: true).pop();
            Future.delayed(const Duration(milliseconds: 50), () {
              _mostrarSelectorEmpresas(
                context: context,
                userData: userData,
                empresaSeleccionada: empresaSeleccionada,
                onCambiarEmpresa: onCambiarEmpresa,
                onReiniciarApp: onReiniciarApp,
                onActualizarVista: onActualizarVista,
              );
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _approvedCardBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _blueDarkColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.business,
                    color: _blueDarkColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombreEmpresa,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (rutEmpresa.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'RUT: $rutEmpresa',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.swap_horiz,
                  color: _blueDarkColor,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static Widget _buildOptionItem({
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

  static void _mostrarSelectorEmpresas({
    required BuildContext context,
    required Map<String, dynamic> userData,
    required String? empresaSeleccionada,
    required Function(String) onCambiarEmpresa,
    required VoidCallback onReiniciarApp,
    required VoidCallback onActualizarVista,
  }) {
    final empresas = userData['empresas'] ?? [];

    if (empresas.isEmpty) {
      mostrarSnackBar(context, 'No hay empresas disponibles');
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
                    final bool isSelected = empresa['token_empresa'] == empresaSeleccionada;

                    final rutFormateado = _formatRut('$rut-$dv');

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
                        final nuevaEmpresaSeleccionada = empresa['token_empresa'];
                        Navigator.of(context, rootNavigator: true).pop();

                        // ✅ SIMPLEMENTE CAMBIAR LA EMPRESA SIN RECARGAR TODO
                        onCambiarEmpresa(nuevaEmpresaSeleccionada);

                        // ✅ MOSTRAR MENSAJE SIMPLE
                        mostrarSnackBar(context, 'Cambiada a: $nombreEmpresa');
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

  // Métodos auxiliares para RUT
  static String _formatRut(String rut) {
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

  static bool _validateRut(String rut) {
    if (rut.isEmpty) return false;

    try {
      String cleanRut = rut.replaceAll('.', '').replaceAll('-', '').toUpperCase();

      // Verificar longitud mínima
      if (cleanRut.length < 8) return false;

      String numero = cleanRut.substring(0, cleanRut.length - 1);
      String dv = cleanRut.substring(cleanRut.length - 1);

      // Verificar que el número tenga al menos 7 dígitos
      if (numero.length < 7) return false;

      // Verificar que el número sea válido
      if (int.tryParse(numero) == null) return false;

      // ✅ NUEVA VALIDACIÓN: El RUT debe ser mayor o igual a 1.000.000
      int rutNumerico = int.parse(numero);
      if (rutNumerico < 1000000) {
        return false;
      }

      // Validar dígito verificador
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

  static Map<String, String> _parseRut(String rut) {
    String cleanRut = rut.replaceAll('.', '').replaceAll('-', '').toUpperCase();
    if (cleanRut.length < 2) return {'numero': '', 'dv': ''};

    String numero = cleanRut.substring(0, cleanRut.length - 1);
    String dv = cleanRut.substring(cleanRut.length - 1);

    return {'numero': numero, 'dv': dv};
  }

  static bool _rutEmpresaYaExiste(
      Map<String, dynamic> userData,
      String rutEmpresa,
      String dvEmpresa,
      ) {
    try {
      final empresas = userData['empresas'] ?? [];

      for (final empresa in empresas) {
        final rutExistente = empresa['rut_empresa']?.toString() ?? '';
        final dvExistente = empresa['dv_rut_empresa']?.toString() ?? '';

        if (rutExistente == rutEmpresa && dvExistente == dvEmpresa) {
          return true;
        }

        final rutCompletoExistente = '$rutExistente-$dvExistente';
        final rutCompletoIngresado = '$rutEmpresa-$dvEmpresa';

        if (_formatRut(rutCompletoExistente) == _formatRut(rutCompletoIngresado)) {
          return true;
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }
}

// ✅ CLASE PARA LA PANTALLA DE NUEVA EMPRESA
class _NuevaEmpresaScreen extends StatefulWidget {
  final BuildContext context;
  final Map<String, dynamic> userData;
  final Function(String, String) onAgregarEmpresa;
  final VoidCallback onVolver;
  final VoidCallback onReiniciarApp;
  final VoidCallback onActualizarDashboard;

  const _NuevaEmpresaScreen({
    required this.context,
    required this.userData,
    required this.onAgregarEmpresa,
    required this.onVolver,
    required this.onReiniciarApp,
    required this.onActualizarDashboard,
  });

  @override
  __NuevaEmpresaScreenState createState() => __NuevaEmpresaScreenState();
}

class __NuevaEmpresaScreenState extends State<_NuevaEmpresaScreen> {
  final TextEditingController _rutController = TextEditingController();
  String? _tipoRelacionSeleccionada;
  bool _isLoading = false;
  bool _rutValido = false;
  String _mensajeValidacion = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _blueDarkColor),
          onPressed: () {
            widget.onVolver();
          },
        ),
        title: Text(
          'Agregar nueva empresa',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _blueDarkColor,
          ),
        ),
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ FORMULARIO DE RUT
          _buildRutForm(),

          const SizedBox(height: 24),

          // ✅ SELECTOR DE TIPO DE RELACIÓN
          _buildSelectorTipoRelacion(),

          if (_tipoRelacionSeleccionada != null) ...[
            const SizedBox(height: 16),
            _buildInfoTipoRelacion(_tipoRelacionSeleccionada!),
          ],

          const SizedBox(height: 32),

          // ✅ BOTÓN DE AGREGAR
          _buildBotonAgregar(),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildRutForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RUT de la empresa',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Formato: con puntos y guión (ej: 12.345.678-9)',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _rutController,
          decoration: InputDecoration(
            labelText: 'RUT (ej: 12.345.678-9)',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            suffixIcon: _rutController.text.isNotEmpty
                ? Icon(
              _rutValido ? Icons.check_circle : Icons.error,
              color: _rutValido ? Colors.green : Colors.red,
            )
                : null,
          ),
          onChanged: (value) {
            final formattedRut = OptionsModal._formatRut(value);
            if (formattedRut != value) {
              _rutController.value = TextEditingValue(
                text: formattedRut,
                selection: TextSelection.collapsed(offset: formattedRut.length),
              );
            }

            final valido = OptionsModal._validateRut(formattedRut);
            String mensajeDuplicado = '';

            if (valido) {
              final rutParseado = OptionsModal._parseRut(formattedRut);
              final rutEmpresa = rutParseado['numero'] ?? '';
              final dvEmpresa = rutParseado['dv'] ?? '';

              if (OptionsModal._rutEmpresaYaExiste(widget.userData, rutEmpresa, dvEmpresa)) {
                mensajeDuplicado = 'Esta empresa ya está registrada';
              }
            }

            setState(() {
              _rutValido = valido && mensajeDuplicado.isEmpty;
              _mensajeValidacion = mensajeDuplicado.isNotEmpty
                  ? mensajeDuplicado
                  : (valido ? 'RUT válido' : 'RUT inválido');
            });
          },
        ),

        if (_mensajeValidacion.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            _mensajeValidacion,
            style: TextStyle(
              fontSize: 12,
              color: _rutValido ? Colors.green : Colors.red,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSelectorTipoRelacion() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tipo de relación con la empresa',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),

        // ✅ OPCIÓN AUTORIZADOR
        InkWell(
          onTap: () {
            setState(() {
              _tipoRelacionSeleccionada = 'autorizador';
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: _tipoRelacionSeleccionada == 'autorizador'
                  ? _blueDarkColor.withOpacity(0.1)
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _tipoRelacionSeleccionada == 'autorizador'
                    ? _blueDarkColor
                    : Colors.grey.shade300,
                width: _tipoRelacionSeleccionada == 'autorizador' ? 2 : 1,
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
                    color: _tipoRelacionSeleccionada == 'autorizador'
                        ? _blueDarkColor
                        : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _tipoRelacionSeleccionada == 'autorizador'
                          ? _blueDarkColor
                          : Colors.grey.shade400,
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    Icons.person_outline,
                    color: _tipoRelacionSeleccionada == 'autorizador'
                        ? Colors.white
                        : Colors.grey.shade600,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Autorizador',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _tipoRelacionSeleccionada == 'autorizador'
                                  ? _blueDarkColor
                                  : Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (_tipoRelacionSeleccionada == 'autorizador')
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
                        'Persona autorizada para realizar compras',
                        style: TextStyle(
                          fontSize: 12,
                          color: _tipoRelacionSeleccionada == 'autorizador'
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
        ),

        // ✅ OPCIÓN REPRESENTANTE
        InkWell(
          onTap: () {
            setState(() {
              _tipoRelacionSeleccionada = 'representante';
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _tipoRelacionSeleccionada == 'representante'
                  ? _blueDarkColor.withOpacity(0.1)
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _tipoRelacionSeleccionada == 'representante'
                    ? _blueDarkColor
                    : Colors.grey.shade300,
                width: _tipoRelacionSeleccionada == 'representante' ? 2 : 1,
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
                    color: _tipoRelacionSeleccionada == 'representante'
                        ? _blueDarkColor
                        : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _tipoRelacionSeleccionada == 'representante'
                          ? _blueDarkColor
                          : Colors.grey.shade400,
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    Icons.badge_outlined,
                    color: _tipoRelacionSeleccionada == 'representante'
                        ? Colors.white
                        : Colors.grey.shade600,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Representante',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _tipoRelacionSeleccionada == 'representante'
                                  ? _blueDarkColor
                                  : Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (_tipoRelacionSeleccionada == 'representante')
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
                        'Representante legal de la empresa',
                        style: TextStyle(
                          fontSize: 12,
                          color: _tipoRelacionSeleccionada == 'representante'
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
        ),
      ],
    );
  }

  Widget _buildInfoTipoRelacion(String tipoRelacion) {
    final Map<String, Map<String, String>> infoTipos = {
      'autorizador': {
        'titulo': 'Autorizador',
        'descripcion':
        'Eres una persona autorizada para realizar compras en nombre de la empresa.',
        'permisos': '• Autorizar compras\n• Consultar historial\n• Ver líneas de crédito',
      },
      'representante': {
        'titulo': 'Representante Legal',
        'descripcion':
        'Eres el representante legal de la empresa con permisos administrativos completos.',
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

  Widget _buildBotonAgregar() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: (_rutValido && _tipoRelacionSeleccionada != null && !_isLoading)
            ? () async {
          setState(() {
            _isLoading = true;
          });

          try {
            final rut = _rutController.text.trim();
            final tipoRelacion = _tipoRelacionSeleccionada!;

            // ✅ LLAMAR AL MÉTODO DEL DASHBOARD
            await widget.onAgregarEmpresa(rut, tipoRelacion);

            // ✅ ACTUALIZAR EL DASHBOARD
            widget.onActualizarDashboard();

            // ✅ VOLVER ATRÁS
            widget.onVolver();

          } catch (e) {
            mostrarSnackBar(widget.context, 'Error: $e');
          } finally {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          }
        }
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _blueDarkColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 2,
        ),
        child: _isLoading
            ? SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        )
            : const Text(
          'Agregar empresa',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// Clase para la pantalla de autorizadores
class _AutorizadoresScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String? empresaSeleccionada;
  final Function(String) onAsignarAutorizador;
  final VoidCallback onActualizarAutorizadores;
  final VoidCallback onVolver;
  final VoidCallback onReiniciarApp;

  const _AutorizadoresScreen({
    required this.userData,
    required this.empresaSeleccionada,
    required this.onAsignarAutorizador,
    required this.onActualizarAutorizadores,
    required this.onVolver,
    required this.onReiniciarApp,
  });

  @override
  _AutorizadoresScreenState createState() => _AutorizadoresScreenState();
}

class _AutorizadoresScreenState extends State<_AutorizadoresScreen> {
  List<Map<String, dynamic>> _autorizadores = [];
  bool _isLoading = false;
  bool _errorCarga = false;
  bool _initializingToken = true;
  String? _deviceToken;

  @override
  void initState() {
    super.initState();
    _initializeTokenAndFetchData();
  }

  Future<void> _initializeTokenAndFetchData() async {
    try {
      setState(() {
        _initializingToken = true;
        _errorCarga = false;
      });

      print('🔄 Inicializando token FCM...');
      await _initializeDeviceToken();

      // Esperar a que el token esté disponible
      int attempts = 0;
      while (_deviceToken == null && attempts < 5) {
        print('⏳ Esperando token FCM... Intento ${attempts + 1}');
        await Future.delayed(const Duration(milliseconds: 500));
        attempts++;
      }

      if (_deviceToken == null) {
        print('⚠️ No se pudo obtener token FCM después de 5 intentos');
        setState(() {
          _errorCarga = true;
          _initializingToken = false;
        });
        return;
      }

      print('✅ Token FCM obtenido exitosamente');
      await _cargarAutorizadores();

    } catch (e) {
      print('❌ Error inicializando token y datos: $e');
      setState(() {
        _errorCarga = true;
        _initializingToken = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _initializingToken = false;
        });
      }
    }
  }

  Future<void> _initializeDeviceToken() async {
    try {
      print('🔄 Inicializando Firebase...');
      await Firebase.initializeApp();

      print('🔄 Obteniendo token FCM...');
      String? fcmToken = await FirebaseMessaging.instance.getToken();

      if (fcmToken != null) {
        print('✅ Token FCM obtenido exitosamente');
        setState(() {
          _deviceToken = fcmToken;
        });
      } else {
        print('⚠️ Token FCM es null, usando fallback');
        await Future.delayed(const Duration(seconds: 1));
        fcmToken = await FirebaseMessaging.instance.getToken();

        if (fcmToken != null) {
          print('✅ Token FCM obtenido en segundo intento');
          setState(() {
            _deviceToken = fcmToken;
          });
        } else {
          print('⚠️ No se pudo obtener token FCM, creando fallback');
          final String fallbackToken = 'fcm_fallback_${DateTime.now().millisecondsSinceEpoch}';
          setState(() {
            _deviceToken = fallbackToken;
          });
        }
      }
    } catch (e) {
      print('❌ Error obteniendo token FCM: $e');
      final String errorToken = 'fcm_error_${DateTime.now().millisecondsSinceEpoch}';
      setState(() {
        _deviceToken = errorToken;
      });
    }
  }

  // Método para cargar autorizadores desde la API
  Future<void> _cargarAutorizadores() async {
    print('🔄 Cargando autorizadores...');

    if (!mounted) {
      print('⚠️ Widget no está montado, cancelando carga');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorCarga = false;
    });

    try {
      if (_deviceToken == null) {
        print('⚠️ Token del dispositivo es null, obteniendo uno nuevo...');
        await _initializeDeviceToken();

        if (_deviceToken == null) {
          mostrarSnackBar(context, 'No se pudo obtener el token del dispositivo');
          if (mounted) {
            setState(() {
              _isLoading = false;
              _errorCarga = true;
            });
          }
          return;
        }
      }

      final tokenRepresentante = widget.userData['comprador']?['token_comprador'] ?? '';
      final empresa = _getEmpresaSeleccionada();
      final tokenEmpresa = empresa?['token_empresa'] ?? '';

      if (tokenRepresentante.isEmpty || tokenEmpresa.isEmpty) {
        mostrarSnackBar(context, 'No se pudo obtener la información necesaria');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      final String apiUrl = '${GlobalVariables.baseUrl}/ListarAutorizadores/api/v2/';
      final requestBody = {
        'token_representante': tokenRepresentante,
        'token_empresa': tokenEmpresa,
        'token_dispositivo': _deviceToken!,
      };

      print('📡 Enviando request a la API...');
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'api-key': GlobalVariables.apiKey,
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 10));

      print('📡 Response recibido: Status ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // VERIFICAR SI LA SESIÓN HA EXPIRADA
        if (data['success'] == false && data['sesion_iniciada'] == false) {
          mostrarSnackBar(context, 'Sesión cerrada. Por favor, inicia sesión nuevamente.');
          reiniciarAplicacion(context);
          return;
        }

        final lista = data['autorizadores_designados'] ?? [];
        print('✅ Autorizadores cargados: ${lista.length}');

        if (mounted) {
          setState(() {
            _autorizadores = List<Map<String, dynamic>>.from(lista);
            _errorCarga = false;
            _isLoading = false;
          });

          // Mostrar mensaje de éxito
          //mostrarSnackBar(context, 'Lista actualizada correctamente');
        }
      } else if (response.statusCode == 401) {
        print('🔐 Sesión expirada (401 Unauthorized)');
        mostrarSnackBar(context, 'Sesión cerrada. Por favor, inicia sesión nuevamente.');
        reiniciarAplicacion(context);
        return;
      } else {
        print('❌ Error en API: ${response.statusCode}');
        mostrarSnackBar(context, 'Error al cargar autorizadores');
        if (mounted) {
          setState(() {
            _errorCarga = true;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('❌ Excepción en _cargarAutorizadores: $e');
      mostrarSnackBar(context, 'Error de conexión');
      if (mounted) {
        setState(() {
          _errorCarga = true;
          _isLoading = false;
        });
      }
    }
  }

  // ✅ MÉTODO SIMPLE PARA RECARGAR LA LISTA
  void _recargarLista() {
    print('🔄 Recargando lista de autorizadores...');
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
      _cargarAutorizadores();
    }
  }

  // ✅ MÉTODO PARA ELIMINAR AUTORIZADOR
  Future<void> _eliminarAutorizador(Map<String, dynamic> autorizador) async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('🔄 Obteniendo token del dispositivo...');
      final String deviceToken = await FCMTokenManager.getDeviceToken();

      final tokenRepresentante = widget.userData['comprador']?['token_comprador'] ?? '';
      final empresa = _getEmpresaSeleccionada();
      final rutEmpresa = empresa?['rut_empresa']?.toString() ?? '';
      final dvRutEmpresa = empresa?['dv_rut_empresa']?.toString() ?? '';

      final runComprador = autorizador['run_comprador']?.toString() ?? '';
      final dvRunComprador = autorizador['dv_run_comprador']?.toString() ?? '';

      if (tokenRepresentante.isEmpty || runComprador.isEmpty || dvRunComprador.isEmpty ||
          rutEmpresa.isEmpty || dvRutEmpresa.isEmpty) {
        print('❌ Faltan datos para eliminar el autorizador');
        mostrarSnackBar(context, 'Faltan datos para eliminar el autorizador');
        return;
      }

      final String apiUrl = '${GlobalVariables.baseUrl}/CambiarValidezCompradorDesignado/api/v2/';
      final requestBody = {
        'token_representante': tokenRepresentante,
        'run_autorizador': runComprador,
        'dv_run_autorizador': dvRunComprador,
        'rut_empresa_autorizador': rutEmpresa,
        'dv_rut_empresa_autorizador': dvRutEmpresa,
        'token_dispositivo': deviceToken,
      };

      print('📡 Enviando request para eliminar autorizador...');
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'api-key': GlobalVariables.apiKey,
        },
        body: jsonEncode(requestBody),
      );

      print('📡 Response recibido: Status ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // VERIFICAR SI LA SESIÓN HA EXPIRADA
        if (data['success'] == false && data['sesion_iniciada'] == false) {
          mostrarSnackBar(context, 'Sesión cerrada. Por favor, inicia sesión nuevamente.');
          reiniciarAplicacion(context);
          return;
        }

        final mensaje = data['message'] ?? data['mensaje'] ?? 'Autorizador eliminado correctamente';
        print('✅ ÉXITO: $mensaje');
        mostrarSnackBar(context, mensaje);
        _recargarLista();
      } else if (response.statusCode == 401) {
        print('🔐 Sesión expirada (401 Unauthorized)');
        mostrarSnackBar(context, 'Sesión cerrada. Por favor, inicia sesión nuevamente.');
        reiniciarAplicacion(context);
        return;
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['message'] ?? errorData['mensaje'] ?? 'Error al eliminar autorizador';
        print('❌ ERROR API: $errorMessage');
        mostrarSnackBar(context, '$errorMessage');
      }
    } catch (e) {
      print('❌ EXCEPCIÓN: Error en _eliminarAutorizador: $e');
      mostrarSnackBar(context, 'Error de conexión: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _mostrarDialogoAgregarAutorizador() {
    print('🔍 Abriendo diálogo para agregar autorizador');

    _mostrarDialogoNuevoAutorizador(
      context: context,
      userData: widget.userData,
      onAsignarAutorizador: widget.onAsignarAutorizador,
      onReiniciarApp: widget.onReiniciarApp,
      autorizadoresExistentes: _autorizadores,
      onActualizarAutorizadores: _recargarLista,
    );
  }

  void _mostrarDialogoEliminarAutorizador(Map<String, dynamic> autorizador) {
    final nombre = autorizador['nombre_comprador'] ?? 'Sin nombre';
    final runComprador = autorizador['run_comprador']?.toString() ?? '';
    final dvRunComprador = autorizador['dv_run_comprador']?.toString() ?? '';
    final runFormateado = OptionsModal._formatRut('$runComprador-$dvRunComprador');

    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Eliminar Autorizador',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _blueDarkColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '¿Estás seguro de eliminar a "$nombre" (${runFormateado.isNotEmpty ? runFormateado : 'RUN no disponible'})?',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade800,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        print('❌ Eliminación cancelada');
                        Navigator.of(context, rootNavigator: true).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _blueDarkColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () async {
                        print('✅ Iniciando eliminación de: $nombre');
                        Navigator.of(context, rootNavigator: true).pop();
                        await _eliminarAutorizador(autorizador);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _blueDarkColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Eliminar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Map<String, dynamic>? _getEmpresaSeleccionada() {
    if (widget.empresaSeleccionada == null) return null;

    final empresas = widget.userData['empresas'] ?? [];
    return empresas.firstWhere(
          (emp) => emp['token_empresa'] == widget.empresaSeleccionada,
      orElse: () => {},
    );
  }

  bool _esRepresentanteValido(Map<String, dynamic>? empresa) {
    if (empresa == null || empresa.isEmpty) return false;

    final tipoRelacion = empresa['tipo_relacion']?.toString().toLowerCase() ?? '';
    final validezRelacion = empresa['validez_relacion']?.toString().toLowerCase() ?? '';

    return tipoRelacion.contains('representante') &&
        !validezRelacion.contains('no válida');
  }

  Widget _buildTituloEmpresa() {
    final empresa = _getEmpresaSeleccionada();

    if (empresa == null || empresa.isEmpty) {
      return Container();
    }

    final nombreEmpresa = empresa['nombre_empresa']?.toString() ?? 'Empresa';
    final rut = empresa['rut_empresa']?.toString() ?? '';
    final dv = empresa['dv_rut_empresa']?.toString() ?? '';
    final rutFormateado = OptionsModal._formatRut('$rut-$dv');

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        margin: const EdgeInsets.fromLTRB(16, 5, 16, 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              nombreEmpresa,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _blueDarkColor,
              ),
            ),
            if (rutFormateado.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'RUT: $rutFormateado',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEstadoVacio() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            color: Colors.grey.shade400,
            size: 80,
          ),
          const SizedBox(height: 20),
          Text(
            'No hay autorizadores asignados',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Asigna personas que puedan comprar en nombre de la empresa',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemAutorizador({
    required Map<String, dynamic> autorizador,
    required int index,
  }) {
    final nombre = autorizador['nombre_comprador'] ?? 'Sin nombre';
    final runComprador = autorizador['run_comprador']?.toString() ?? '';
    final dvRunComprador = autorizador['dv_run_comprador']?.toString() ?? '';
    final runCompleto = '$runComprador-$dvRunComprador';

    final verificado = autorizador['verificado'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
                      nombre,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (runComprador.isNotEmpty && dvRunComprador.isNotEmpty) ...[
                      Text(
                        'RUN: ${OptionsModal._formatRut(runCompleto)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: verificado ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            verificado ? 'Verificado' : 'No verificado',
                            style: TextStyle(
                              fontSize: 12,
                              color: verificado ? Colors.green : Colors.orange,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(Icons.close, color: Colors.red, size: 18),
                  onPressed: () {
                    print('❌ Eliminando autorizador: $nombre');
                    _mostrarDialogoEliminarAutorizador(autorizador);
                  },
                  padding: EdgeInsets.zero,
                  splashRadius: 20,
                  tooltip: 'Eliminar autorizador',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCarga() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 80,
          ),
          const SizedBox(height: 20),
          Text(
            'Error al cargar autorizadores',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _initializeTokenAndFetchData,
            style: ElevatedButton.styleFrom(
              backgroundColor: _blueDarkColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final empresa = _getEmpresaSeleccionada();
    final bool esRepresentanteValido = _esRepresentanteValido(empresa);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _blueDarkColor),
          onPressed: () {
            print('⬅️ Regresando a pantalla anterior');
            widget.onVolver();
          },
        ),
        title: Text(
          'Autorizadores',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _blueDarkColor,
          ),
        ),
        actions: [
          if (esRepresentanteValido)
            IconButton(
              icon: Icon(Icons.person_add, color: _blueDarkColor),
              onPressed: _mostrarDialogoAgregarAutorizador,
              tooltip: 'Agregar autorizador',
            ),
        ],
      ),
      body: _initializingToken
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: _blueDarkColor,
            ),
            const SizedBox(height: 16),
            Text(
              'Inicializando dispositivo...',
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      )
          : _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: _blueDarkColor,
            ),
            const SizedBox(height: 16),
            Text(
              'Cargando autorizadores...',
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      )
          : _errorCarga
          ? _buildErrorCarga()
          : Column(
        children: [
          _buildTituloEmpresa(),

          if (!esRepresentanteValido)
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.orange,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Solo el representante legal puede gestionar autorizadores',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: _autorizadores.isEmpty
                ? _buildEstadoVacio()
                : RefreshIndicator(
              onRefresh: () async {
                print('🔄 Actualizando lista...');
                await _cargarAutorizadores();
              },
              color: _blueDarkColor,
              child: ListView.builder(
                itemCount: _autorizadores.length,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemBuilder: (context, index) {
                  final autorizador = _autorizadores[index];
                  return _buildItemAutorizador(
                    autorizador: autorizador,
                    index: index,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ MÉTODO PARA MOSTRAR DIÁLOGO DE NUEVO AUTORIZADOR
  void _mostrarDialogoNuevoAutorizador({
    required BuildContext context,
    required Map<String, dynamic> userData,
    required Function(String) onAsignarAutorizador,
    required VoidCallback onReiniciarApp,
    required List<Map<String, dynamic>> autorizadoresExistentes,
    required VoidCallback onActualizarAutorizadores,
  }) {
    final TextEditingController runController = TextEditingController();
    bool runValido = false;
    String mensajeValidacion = '';

    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Asignar Nuevo Autorizador',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _blueDarkColor,
                      ),
                    ),
                    const SizedBox(height: 16),
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
                        final formattedRun = OptionsModal._formatRut(value);
                        if (formattedRun != value) {
                          runController.value = TextEditingValue(
                            text: formattedRun,
                            selection: TextSelection.collapsed(offset: formattedRun.length),
                          );
                        }

                        final valido = OptionsModal._validateRut(formattedRun);

                        if (valido) {
                          // VERIFICAR SI ES EL RUN DEL USUARIO ACTUAL
                          final comprador = userData['comprador'];
                          if (comprador != null) {
                            final runComprador = comprador['run_comprador']?.toString() ?? '';
                            final dvComprador = comprador['dv_run_comprador']?.toString() ?? '';
                            final runCompletoComprador = '$runComprador-$dvComprador';
                            final runFormateadoComprador = OptionsModal._formatRut(runCompletoComprador);

                            if (formattedRun == runFormateadoComprador) {
                              setState(() {
                                runValido = false;
                                mensajeValidacion = 'No puedes usar tu propio RUN';
                              });
                              return;
                            }
                          }

                          // VERIFICAR SI EL RUN YA ESTÁ REGISTRADO
                          final runParseado = OptionsModal._parseRut(formattedRun);
                          final runNumero = runParseado['numero'] ?? '';
                          final runDv = runParseado['dv'] ?? '';

                          bool yaRegistrado = false;
                          for (var autorizador in autorizadoresExistentes) {
                            final runExistente = autorizador['run_comprador']?.toString() ?? '';
                            final dvExistente = autorizador['dv_run_comprador']?.toString() ?? '';

                            if (runExistente == runNumero && dvExistente == runDv) {
                              yaRegistrado = true;
                              break;
                            }

                            final runCompletoExistente = '$runExistente-$dvExistente';
                            if (OptionsModal._formatRut(runCompletoExistente) == formattedRun) {
                              yaRegistrado = true;
                              break;
                            }
                          }

                          if (yaRegistrado) {
                            setState(() {
                              runValido = false;
                              mensajeValidacion = 'Este RUN ya está registrado como autorizador';
                            });
                            return;
                          }
                        }

                        setState(() {
                          runValido = valido;
                          mensajeValidacion = valido ? 'RUN válido y disponible' : 'RUN inválido';
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
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton(
                          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _blueDarkColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: runValido
                              ? () async {
                            final run = runController.text.trim();
                            print('✅ Confirmado: Agregando autorizador con RUN: $run');

                            // GUARDAR EL CONTEXTO ANTES DE CERRAR EL DIÁLOGO
                            final BuildContext dialogContext = context;

                            // Cerrar el diálogo primero
                            Navigator.of(dialogContext, rootNavigator: true).pop();

                            try {
                              await _asignarAutorizadorApi(
                                context: dialogContext,
                                userData: userData,
                                run: run,
                                onAsignarAutorizador: onAsignarAutorizador,
                                onReiniciarApp: onReiniciarApp,
                                onActualizarAutorizadores: onActualizarAutorizadores,
                              );
                            } catch (e) {
                              print('❌ Error en diálogo: $e');
                              // No mostrar snackbar aquí - ya se maneja en la API
                            }
                          }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _blueDarkColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Asignar'),
                        ),
                      ],
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

  // ✅ MÉTODO PARA ASIGNAR AUTORIZADOR
  Future<void> _asignarAutorizadorApi({
    required BuildContext context,
    required Map<String, dynamic> userData,
    required String run,
    required Function(String) onAsignarAutorizador,
    required VoidCallback onReiniciarApp,
    required VoidCallback onActualizarAutorizadores,
  }) async {
    print('══════════════════════════════════════════════════════════════');
    print('🎯 INICIANDO API _asignarAutorizadorApi');
    print('══════════════════════════════════════════════════════════════');

    try {
      // OBTENER TOKEN DEL DISPOSITIVO
      print('🔄 Obteniendo token del dispositivo...');
      final String deviceToken = await FCMTokenManager.getDeviceToken();

      final tokenComprador = userData['comprador']?['token_comprador'] ?? '';
      final runComprador = userData['comprador']?['run_comprador']?.toString() ?? '';
      final dvRunComprador = userData['comprador']?['dv_run_comprador']?.toString() ?? '';

      if (tokenComprador.isEmpty || runComprador.isEmpty || dvRunComprador.isEmpty) {
        print('❌ Faltan datos del comprador');
        return;
      }

      // Obtener la empresa seleccionada
      final empresas = userData['empresas'] ?? [];
      final empresaSeleccionada = empresas.firstWhere(
            (emp) => emp['seleccionada'] == true,
        orElse: () => empresas.isNotEmpty ? empresas[0] : {},
      );

      if (empresaSeleccionada.isEmpty) {
        print('❌ No hay empresa seleccionada');
        return;
      }

      final rutEmpresa = empresaSeleccionada['rut_empresa']?.toString() ?? '';
      final dvEmpresa = empresaSeleccionada['dv_rut_empresa']?.toString() ?? '';

      // Parsear RUN del autorizador
      final runParseado = OptionsModal._parseRut(run);
      final runAutorizador = runParseado['numero'] ?? '';
      final dvRunAutorizador = runParseado['dv'] ?? '';

      if (runAutorizador.isEmpty || dvRunAutorizador.isEmpty) {
        print('❌ RUN inválido');
        return;
      }

      // Preparar request
      final requestBody = {
        "token_representante": tokenComprador,
        "run_autorizador": runAutorizador,
        "dv_autorizador": dvRunAutorizador,
        "rut_empresa": rutEmpresa,
        "dv_empresa": dvEmpresa,
        "token_dispositivo": deviceToken,
      };

      print('📡 Enviando request a la API...');
      final response = await http.post(
        Uri.parse('${GlobalVariables.baseUrl}/CrearAutorizador/api/v2/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'api-key': GlobalVariables.apiKey,
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 15));

      print('📡 Response recibido: Status ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // VERIFICAR SI LA SESIÓN HA EXPIRADO
        if (responseData['success'] == false && responseData['sesion_iniciada'] == false) {
          print('🔐 Sesión expirada');
          return;
        }

        if (responseData['success'] == true) {
          final mensaje = responseData['message'] ?? 'Autorizador asignado exitosamente';
          print('✅ ÉXITO: $mensaje');

          // EJECUTAR EL CALLBACK DEL AUTORIZADOR
          onAsignarAutorizador(run);

          // LLAMAR AL CALLBACK PARA ACTUALIZAR LA LISTA
          if (onActualizarAutorizadores != null) {
            print('🔄 Ejecutando onActualizarAutorizadores...');
            onActualizarAutorizadores();
          }
        } else {
          final mensajeError = responseData['message'] ?? responseData['error'] ?? 'Error al asignar autorizador';
          print('❌ ERROR API: $mensajeError');
        }
      } else if (response.statusCode == 401) {
        print('🔐 Sesión expirada (401 Unauthorized)');
      } else {
        print('❌ ERROR HTTP: Status ${response.statusCode}');
      }
    } catch (e) {
      print('❌ EXCEPCIÓN: Error en _asignarAutorizadorApi: $e');
    }
  }
}