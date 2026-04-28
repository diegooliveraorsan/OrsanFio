import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'variables_globales.dart';

final Color _blueDarkColor = const Color(0xFF0055B8);
final Color _approvedCardBackground = const Color(0xFFE8F0FE);

void reiniciarAplicacion(BuildContext context) {
  Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  if (Navigator.canPop(context)) Navigator.popUntil(context, (route) => route.isFirst);
}

class FCMTokenManager {
  static Future<String> getDeviceToken() async {
    try {
      await Firebase.initializeApp();
      String? fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) return fcmToken;
      await Future.delayed(const Duration(seconds: 1));
      fcmToken = await FirebaseMessaging.instance.getToken();
      return fcmToken ?? 'fcm_fallback_${DateTime.now().millisecondsSinceEpoch}';
    } catch (e) {
      return 'fcm_error_${DateTime.now().millisecondsSinceEpoch}';
    }
  }
}

class OptionsModal {
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Opciones', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _blueDarkColor)),
              const SizedBox(height: 20),
              _buildOptionItem(
                icon: Icons.add_business,
                title: 'Agregar nueva empresa',
                subtitle: 'Registrar nueva empresa con RUT',
                onTap: () {
                  // ✅ No cerramos el modal aquí para que podamos cerrarlo después desde la pantalla de nueva empresa
                  onMostrarNuevaEmpresa();
                },
              ),
              if (esRepresentanteValido) ...[
                const SizedBox(height: 16),
                _buildOptionItem(
                  icon: Icons.people,
                  title: 'Agregar autorizadores',
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
                  style: ElevatedButton.styleFrom(backgroundColor: _blueDarkColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  child: const Text('Cerrar'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

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

  static Widget crearVistaNuevaEmpresa({
    required BuildContext context,
    required Map<String, dynamic> userData,
    required Future<bool> Function(String, String, String) onAgregarEmpresa,
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

  static Map<String, dynamic>? _getEmpresaSeleccionada(Map<String, dynamic> userData, String? empresaSeleccionada) {
    if (empresaSeleccionada == null) return null;
    final empresas = userData['empresas'] ?? [];
    return empresas.firstWhere((emp) => emp['token_empresa'] == empresaSeleccionada, orElse: () => {});
  }

  static bool _esRepresentanteValido(Map<String, dynamic>? empresa) {
    if (empresa == null || empresa.isEmpty) return false;
    final tipoRelacion = empresa['tipo_relacion']?.toString().toLowerCase() ?? '';
    final validezRelacion = empresa['validez_relacion']?.toString().toLowerCase() ?? '';
    return tipoRelacion.contains('representante') && !validezRelacion.contains('no válida');
  }

  static Widget _buildOptionItem({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return ListTile(
      leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: _blueDarkColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: _blueDarkColor, size: 20)),
      title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }

  static String _formatRut(String rut) {
    String cleanRut = rut.replaceAll('.', '').replaceAll('-', '');
    if (cleanRut.length < 2) return rut;
    String numero = cleanRut.substring(0, cleanRut.length - 1);
    String dv = cleanRut.substring(cleanRut.length - 1);
    String formatted = '';
    for (int i = numero.length - 1, j = 0; i >= 0; i--, j++) {
      if (j > 0 && j % 3 == 0) formatted = '.$formatted';
      formatted = numero[i] + formatted;
    }
    return '$formatted-$dv'.toUpperCase();
  }

  static bool _validateRut(String rut) {
    if (rut.isEmpty) return false;
    try {
      String cleanRut = rut.replaceAll('.', '').replaceAll('-', '').toUpperCase();
      if (cleanRut.length < 8) return false;
      String numero = cleanRut.substring(0, cleanRut.length - 1);
      String dv = cleanRut.substring(cleanRut.length - 1);
      if (numero.length < 7) return false;
      if (int.tryParse(numero) == null) return false;
      if (int.parse(numero) < 1000000) return false;
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

  static bool _rutEmpresaYaExiste(Map<String, dynamic> userData, String rutEmpresa, String dvEmpresa) {
    try {
      final empresas = userData['empresas'] ?? [];
      for (final empresa in empresas) {
        final rutExistente = empresa['rut_empresa']?.toString() ?? '';
        final dvExistente = empresa['dv_rut_empresa']?.toString() ?? '';
        if (rutExistente == rutEmpresa && dvExistente == dvEmpresa) return true;
        final rutCompletoExistente = '$rutExistente-$dvExistente';
        final rutCompletoIngresado = '$rutEmpresa-$dvEmpresa';
        if (_formatRut(rutCompletoExistente) == _formatRut(rutCompletoIngresado)) return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}

// =============================================================================
// PANTALLA DE NUEVA EMPRESA (CIERRA MODAL CORRECTAMENTE)
// =============================================================================
class _NuevaEmpresaScreen extends StatefulWidget {
  final BuildContext context;
  final Map<String, dynamic> userData;
  final Future<bool> Function(String, String, String) onAgregarEmpresa;
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
  final TextEditingController _pinController = TextEditingController();
  bool _obscurePin = true;
  String? _tipoRelacionSeleccionada;
  bool _isLoading = false;
  bool _rutValido = false;
  bool _pinValido = false;
  String _mensajeValidacionRut = '';
  String _mensajeValidacionPin = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: _blueDarkColor), onPressed: widget.onVolver),
        title: Text('Agregar nueva empresa', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _blueDarkColor)),
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
          _buildRutForm(),
          const SizedBox(height: 24),
          _buildSelectorTipoRelacion(),
          if (_tipoRelacionSeleccionada != null) ...[const SizedBox(height: 16), _buildInfoTipoRelacion(_tipoRelacionSeleccionada!)],
          const SizedBox(height: 24),
          _buildPinField(),
          const SizedBox(height: 32),
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
        Text('RUT de la empresa', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _blueDarkColor)),
        const SizedBox(height: 12),
        TextFormField(
          controller: _rutController,
          decoration: InputDecoration(
            labelText: 'RUT (ej: 12.345.678-9)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.grey.shade50,
            suffixIcon: _rutController.text.isNotEmpty ? Icon(_rutValido ? Icons.check_circle : Icons.error, color: _rutValido ? Colors.green : Colors.red) : null,
          ),
          onChanged: (value) {
            final formattedRut = OptionsModal._formatRut(value);
            if (formattedRut != value) {
              _rutController.value = TextEditingValue(text: formattedRut, selection: TextSelection.collapsed(offset: formattedRut.length));
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
              _mensajeValidacionRut = mensajeDuplicado.isNotEmpty ? mensajeDuplicado : (valido ? 'RUT válido' : 'RUT inválido');
            });
          },
        ),
        if (_mensajeValidacionRut.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(_mensajeValidacionRut, style: TextStyle(fontSize: 12, color: _rutValido ? Colors.green : Colors.red, fontWeight: FontWeight.w500)),
        ],
      ],
    );
  }

  Widget _buildSelectorTipoRelacion() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tipo de relación con la empresa', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _blueDarkColor)),
        const SizedBox(height: 12),
        // Autorizador
        InkWell(
          onTap: () => setState(() => _tipoRelacionSeleccionada = 'autorizador'),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: _tipoRelacionSeleccionada == 'autorizador' ? _blueDarkColor.withOpacity(0.1) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _tipoRelacionSeleccionada == 'autorizador' ? _blueDarkColor : Colors.grey.shade300, width: _tipoRelacionSeleccionada == 'autorizador' ? 2 : 1),
              boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.3), blurRadius: 3, offset: const Offset(0, 2), spreadRadius: 0)],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _tipoRelacionSeleccionada == 'autorizador' ? _blueDarkColor : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: _tipoRelacionSeleccionada == 'autorizador' ? _blueDarkColor : Colors.grey.shade400, width: 1.5),
                  ),
                  child: Icon(Icons.person_outline, color: _tipoRelacionSeleccionada == 'autorizador' ? Colors.white : Colors.grey.shade600, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Autorizador', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _tipoRelacionSeleccionada == 'autorizador' ? _blueDarkColor : Colors.grey.shade800)),
                          const SizedBox(width: 8),
                          if (_tipoRelacionSeleccionada == 'autorizador')
                            Container(width: 20, height: 20, decoration: const BoxDecoration(color: Color(0xFF4CAF50), shape: BoxShape.circle), child: const Icon(Icons.check, color: Colors.white, size: 14)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('Persona autorizada para realizar compras', style: TextStyle(fontSize: 12, color: _tipoRelacionSeleccionada == 'autorizador' ? _blueDarkColor.withOpacity(0.8) : Colors.grey.shade600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Representante
        InkWell(
          onTap: () => setState(() => _tipoRelacionSeleccionada = 'representante'),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _tipoRelacionSeleccionada == 'representante' ? _blueDarkColor.withOpacity(0.1) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _tipoRelacionSeleccionada == 'representante' ? _blueDarkColor : Colors.grey.shade300, width: _tipoRelacionSeleccionada == 'representante' ? 2 : 1),
              boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.3), blurRadius: 3, offset: const Offset(0, 2), spreadRadius: 0)],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _tipoRelacionSeleccionada == 'representante' ? _blueDarkColor : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: _tipoRelacionSeleccionada == 'representante' ? _blueDarkColor : Colors.grey.shade400, width: 1.5),
                  ),
                  child: Icon(Icons.badge_outlined, color: _tipoRelacionSeleccionada == 'representante' ? Colors.white : Colors.grey.shade600, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Representante', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _tipoRelacionSeleccionada == 'representante' ? _blueDarkColor : Colors.grey.shade800)),
                          const SizedBox(width: 8),
                          if (_tipoRelacionSeleccionada == 'representante')
                            Container(width: 20, height: 20, decoration: const BoxDecoration(color: Color(0xFF4CAF50), shape: BoxShape.circle), child: const Icon(Icons.check, color: Colors.white, size: 14)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('Representante legal de la empresa', style: TextStyle(fontSize: 12, color: _tipoRelacionSeleccionada == 'representante' ? _blueDarkColor.withOpacity(0.8) : Colors.grey.shade600)),
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
      'autorizador': {'titulo': 'Autorizador', 'descripcion': 'Eres una persona autorizada para realizar compras en nombre de la empresa.', 'permisos': '• Autorizar compras\n• Consultar historial\n• Ver líneas de crédito'},
      'representante': {'titulo': 'Representante Legal', 'descripcion': 'Eres el representante legal de la empresa con permisos administrativos completos.', 'permisos': '• Todas las funciones de autorizador\n• Gestionar autorizadores'},
    };
    final info = infoTipos[tipoRelacion]!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _blueDarkColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _blueDarkColor.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 2, offset: const Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(Icons.info_outline, color: _blueDarkColor, size: 16), const SizedBox(width: 8), Text(info['titulo']!, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _blueDarkColor))]),
          const SizedBox(height: 8),
          Text(info['descripcion']!, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          const SizedBox(height: 8),
          Text(info['permisos']!, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildPinField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pin de seguridad', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _blueDarkColor)),
        const SizedBox(height: 8),
        Text('4 dígitos numéricos', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 12),
        TextFormField(
          controller: _pinController,
          obscureText: _obscurePin,
          keyboardType: TextInputType.number,
          decoration: GlobalInputStyles.inputDecoration(labelText: 'Pin de seguridad', prefixIcon: Icons.lock_outline).copyWith(
            suffixIcon: IconButton(
              icon: Icon(_obscurePin ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
              onPressed: () => setState(() => _obscurePin = !_obscurePin),
            ),
          ),
          onChanged: _validarPin,
        ),
        if (_mensajeValidacionPin.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(_mensajeValidacionPin, style: TextStyle(fontSize: 12, color: _pinValido ? Colors.green : Colors.red, fontWeight: FontWeight.w500)),
        ],
      ],
    );
  }

  void _validarPin(String value) {
    final esNumerico = RegExp(r'^[0-9]+$').hasMatch(value);
    final longitudValida = value.length >= 4;
    setState(() {
      _pinValido = esNumerico && longitudValida;
      _mensajeValidacionPin = _pinValido ? 'Pin válido' : (value.isEmpty ? 'Ingrese un pin' : (!esNumerico ? 'Solo se permiten números' : 'Debe tener 4 dígitos'));
    });
  }

  Widget _buildBotonAgregar() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: (_rutValido && _tipoRelacionSeleccionada != null && _pinValido && !_isLoading)
            ? () async {
          setState(() => _isLoading = true);
          try {
            final rut = _rutController.text.trim();
            final tipoRelacion = _tipoRelacionSeleccionada!;
            final pin = _pinController.text.trim();
            final success = await widget.onAgregarEmpresa(rut, tipoRelacion, pin);
            if (success && mounted) {
              // Esperar un momento para que el SnackBar se muestre
              await Future.delayed(const Duration(milliseconds: 150));
              // Cerrar esta pantalla
              if (mounted) Navigator.of(context, rootNavigator: true).pop();
              // Cerrar el modal (bottom sheet) que sigue abierto debajo
              if (mounted) Navigator.of(context, rootNavigator: true).pop();
            }
          } catch (e) {
            if (mounted) GlobalSnackBars.mostrarError(widget.context, 'Error: $e');
          } finally {
            if (mounted) setState(() => _isLoading = false);
          }
        }
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _blueDarkColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 2,
        ),
        child: _isLoading
            ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('Agregar empresa', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// =============================================================================
// PANTALLA DE AUTORIZADORES (NO MODIFICADA, PERO INCLUIDA PARA COMPLETITUD)
// =============================================================================
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
      await _initializeDeviceToken();
      int attempts = 0;
      while (_deviceToken == null && attempts < 5) {
        await Future.delayed(const Duration(milliseconds: 500));
        attempts++;
      }
      if (_deviceToken == null) {
        setState(() {
          _errorCarga = true;
          _initializingToken = false;
        });
        return;
      }
      await _cargarAutorizadores();
    } catch (e) {
      setState(() {
        _errorCarga = true;
        _initializingToken = false;
      });
    } finally {
      if (mounted) setState(() => _initializingToken = false);
    }
  }

  Future<void> _initializeDeviceToken() async {
    try {
      await Firebase.initializeApp();
      String? fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        setState(() => _deviceToken = fcmToken);
      } else {
        await Future.delayed(const Duration(seconds: 1));
        fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null) {
          setState(() => _deviceToken = fcmToken);
        } else {
          final String fallbackToken = 'fcm_fallback_${DateTime.now().millisecondsSinceEpoch}';
          setState(() => _deviceToken = fallbackToken);
        }
      }
    } catch (e) {
      final String errorToken = 'fcm_error_${DateTime.now().millisecondsSinceEpoch}';
      setState(() => _deviceToken = errorToken);
    }
  }

  Future<void> _cargarAutorizadores() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorCarga = false;
    });
    try {
      if (_deviceToken == null) {
        await _initializeDeviceToken();
        if (_deviceToken == null) {
          GlobalSnackBars.mostrarError(context, 'No se pudo obtener el token del dispositivo');
          if (mounted) setState(() {
            _isLoading = false;
            _errorCarga = true;
          });
          return;
        }
      }
      final tokenRepresentante = widget.userData['comprador']?['token_comprador'] ?? '';
      final empresa = _getEmpresaSeleccionada();
      final tokenEmpresa = empresa?['token_empresa'] ?? '';
      if (tokenRepresentante.isEmpty || tokenEmpresa.isEmpty) {
        GlobalSnackBars.mostrarError(context, 'No se pudo obtener la información necesaria');
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final String apiUrl = '${GlobalVariables.baseUrl}/ListarAutorizadores/api/v2/';
      final requestBody = {
        'token_representante': tokenRepresentante,
        'token_empresa': tokenEmpresa,
        'token_dispositivo': _deviceToken!,
      };
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json', 'api-key': GlobalVariables.apiKey},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == false && data['sesion_iniciada'] == false) {
          GlobalSnackBars.mostrarError(context, 'Sesión cerrada. Por favor, inicia sesión nuevamente.');
          reiniciarAplicacion(context);
          return;
        }
        final lista = data['autorizadores_designados'] ?? [];
        if (mounted) {
          setState(() {
            _autorizadores = List<Map<String, dynamic>>.from(lista);
            _errorCarga = false;
            _isLoading = false;
          });
        }
      } else if (response.statusCode == 401) {
        GlobalSnackBars.mostrarError(context, 'Sesión cerrada. Por favor, inicia sesión nuevamente.');
        reiniciarAplicacion(context);
        return;
      } else {
        GlobalSnackBars.mostrarError(context, 'Error al cargar autorizadores');
        if (mounted) setState(() {
          _errorCarga = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      GlobalSnackBars.mostrarError(context, 'Error de conexión');
      if (mounted) setState(() {
        _errorCarga = true;
        _isLoading = false;
      });
    }
  }

  void _recargarLista() {
    if (mounted) {
      setState(() => _isLoading = true);
      _cargarAutorizadores();
    }
  }

  Future<void> _eliminarAutorizador(Map<String, dynamic> autorizador, String pin) async {
    setState(() => _isLoading = true);
    try {
      final String deviceToken = await FCMTokenManager.getDeviceToken();
      final tokenRepresentante = widget.userData['comprador']?['token_comprador'] ?? '';
      final empresa = _getEmpresaSeleccionada();
      final rutEmpresa = empresa?['rut_empresa']?.toString() ?? '';
      final dvRutEmpresa = empresa?['dv_rut_empresa']?.toString() ?? '';
      final runComprador = autorizador['run_comprador']?.toString() ?? '';
      final dvRunComprador = autorizador['dv_run_comprador']?.toString() ?? '';
      if (tokenRepresentante.isEmpty || runComprador.isEmpty || dvRunComprador.isEmpty || rutEmpresa.isEmpty || dvRutEmpresa.isEmpty) {
        GlobalSnackBars.mostrarError(context, 'Faltan datos para eliminar el autorizador');
        return;
      }
      final String apiUrl = '${GlobalVariables.baseUrl}/CambiarValidezCompradorDesignado/api/v3/';
      final requestBody = {
        'token_representante': tokenRepresentante,
        'run_autorizador': runComprador,
        'dv_run_autorizador': dvRunComprador,
        'rut_empresa_autorizador': rutEmpresa,
        'dv_rut_empresa_autorizador': dvRutEmpresa,
        'token_dispositivo': deviceToken,
        'pin_seguridad': pin,
      };
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json', 'api-key': GlobalVariables.apiKey},
        body: jsonEncode(requestBody),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == false && data['sesion_iniciada'] == false) {
          GlobalSnackBars.mostrarError(context, 'Sesión cerrada. Por favor, inicia sesión nuevamente.');
          reiniciarAplicacion(context);
          return;
        }
        final mensaje = data['message'] ?? data['mensaje'] ?? 'Autorizador eliminado correctamente';
        GlobalSnackBars.mostrarExito(context, mensaje);
        _recargarLista();
      } else if (response.statusCode == 401) {
        GlobalSnackBars.mostrarError(context, 'Sesión cerrada. Por favor, inicia sesión nuevamente.');
        reiniciarAplicacion(context);
        return;
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['message'] ?? errorData['mensaje'] ?? 'Error al eliminar autorizador';
        GlobalSnackBars.mostrarError(context, errorMessage);
      }
    } catch (e) {
      GlobalSnackBars.mostrarError(context, 'Error de conexión: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _mostrarDialogoAgregarAutorizador() {
    _mostrarDialogoNuevoAutorizadorConPin();
  }

  void _mostrarDialogoNuevoAutorizadorConPin() {
    final TextEditingController runController = TextEditingController();
    final TextEditingController pinController = TextEditingController();
    bool runValido = false;
    bool pinValido = false;
    bool obscurePin = true;
    String mensajeValidacionRun = '';
    String mensajeValidacionPin = '';
    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Asignar Nuevo Autorizador', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _blueDarkColor)),
                      const SizedBox(height: 16),
                      Text('RUN', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _blueDarkColor)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: runController,
                        decoration: InputDecoration(
                          labelText: 'RUN (ej: 12345678-9)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          suffixIcon: runController.text.isNotEmpty ? Icon(runValido ? Icons.check_circle : Icons.error, color: runValido ? Colors.green : Colors.red) : null,
                        ),
                        onChanged: (value) {
                          final formattedRun = OptionsModal._formatRut(value);
                          if (formattedRun != value) {
                            runController.value = TextEditingValue(text: formattedRun, selection: TextSelection.collapsed(offset: formattedRun.length));
                          }
                          final valido = OptionsModal._validateRut(formattedRun);
                          if (valido) {
                            final comprador = widget.userData['comprador'];
                            if (comprador != null) {
                              final runComprador = comprador['run_comprador']?.toString() ?? '';
                              final dvComprador = comprador['dv_run_comprador']?.toString() ?? '';
                              final runCompletoComprador = '$runComprador-$dvComprador';
                              final runFormateadoComprador = OptionsModal._formatRut(runCompletoComprador);
                              if (formattedRun == runFormateadoComprador) {
                                setState(() {
                                  runValido = false;
                                  mensajeValidacionRun = 'No puedes usar tu propio RUN';
                                });
                                return;
                              }
                            }
                            final runParseado = OptionsModal._parseRut(formattedRun);
                            final runNumero = runParseado['numero'] ?? '';
                            final runDv = runParseado['dv'] ?? '';
                            bool yaRegistrado = false;
                            for (var autorizador in _autorizadores) {
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
                                mensajeValidacionRun = 'Este RUN ya está registrado como autorizador';
                              });
                              return;
                            }
                          }
                          setState(() {
                            runValido = valido;
                            mensajeValidacionRun = valido ? 'RUN válido y disponible' : 'RUN inválido';
                          });
                        },
                      ),
                      if (mensajeValidacionRun.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(mensajeValidacionRun, style: TextStyle(fontSize: 12, color: runValido ? Colors.green : Colors.red, fontWeight: FontWeight.w500)),
                      ],
                      const SizedBox(height: 16),
                      Text('Pin de seguridad', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _blueDarkColor)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: pinController,
                        obscureText: obscurePin,
                        keyboardType: TextInputType.number,
                        decoration: GlobalInputStyles.inputDecoration(labelText: 'Pin de seguridad', prefixIcon: Icons.lock_outline).copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(obscurePin ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                            onPressed: () => setState(() => obscurePin = !obscurePin),
                          ),
                        ),
                        onChanged: (value) {
                          final esNumerico = RegExp(r'^[0-9]+$').hasMatch(value);
                          final longitudValida = value.length == 4;
                          setState(() {
                            pinValido = esNumerico && longitudValida;
                            mensajeValidacionPin = pinValido ? 'Pin válido' : (value.isEmpty ? 'Ingrese el pin' : (!esNumerico ? 'Solo números' : 'Debe tener 4 dígitos'));
                          });
                        },
                      ),
                      if (mensajeValidacionPin.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(mensajeValidacionPin, style: TextStyle(fontSize: 12, color: pinValido ? Colors.green : Colors.red, fontWeight: FontWeight.w500)),
                      ],
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton(
                            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                            style: ElevatedButton.styleFrom(backgroundColor: _blueDarkColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                            child: const Text('Cancelar'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: (runValido && pinValido)
                                ? () async {
                              final run = runController.text.trim();
                              final pin = pinController.text.trim();
                              final BuildContext dialogContext = context;
                              Navigator.of(dialogContext, rootNavigator: true).pop();
                              try {
                                await _asignarAutorizadorApi(
                                  context: dialogContext,
                                  userData: widget.userData,
                                  run: run,
                                  pin: pin,
                                  onAsignarAutorizador: widget.onAsignarAutorizador,
                                  onReiniciarApp: widget.onReiniciarApp,
                                  onActualizarAutorizadores: widget.onActualizarAutorizadores,
                                );
                              } catch (e) {
                                print('❌ Error en diálogo: $e');
                              }
                            }
                                : null,
                            style: ElevatedButton.styleFrom(backgroundColor: _blueDarkColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                            child: const Text('Asignar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _mostrarDialogoEliminarAutorizador(Map<String, dynamic> autorizador) {
    final nombre = autorizador['nombre_comprador'] ?? 'Sin nombre';
    final runComprador = autorizador['run_comprador']?.toString() ?? '';
    final dvRunComprador = autorizador['dv_run_comprador']?.toString() ?? '';
    final runFormateado = OptionsModal._formatRut('$runComprador-$dvRunComprador');
    final TextEditingController pinController = TextEditingController();
    bool pinValido = false;
    bool obscurePin = true;
    String mensajeValidacionPin = '';
    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Eliminar Autorizador', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _blueDarkColor)),
                    const SizedBox(height: 16),
                    Text('¿Estás seguro de eliminar a "$nombre" (${runFormateado.isNotEmpty ? runFormateado : 'RUN no disponible'})?', style: TextStyle(fontSize: 14, color: Colors.grey.shade800, height: 1.4)),
                    const SizedBox(height: 16),
                    Text('Ingresa tu pin de seguridad', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _blueDarkColor)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: pinController,
                      obscureText: obscurePin,
                      keyboardType: TextInputType.number,
                      decoration: GlobalInputStyles.inputDecoration(labelText: 'Pin de seguridad', prefixIcon: Icons.lock_outline).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(obscurePin ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                          onPressed: () => setState(() => obscurePin = !obscurePin),
                        ),
                      ),
                      onChanged: (value) {
                        final esNumerico = RegExp(r'^[0-9]+$').hasMatch(value);
                        final longitudValida = value.length == 4;
                        setState(() {
                          pinValido = esNumerico && longitudValida;
                          mensajeValidacionPin = pinValido ? 'Pin válido' : (value.isEmpty ? 'Ingrese el pin' : (!esNumerico ? 'Solo números' : 'Debe tener 4 dígitos'));
                        });
                      },
                    ),
                    if (mensajeValidacionPin.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(mensajeValidacionPin, style: TextStyle(fontSize: 12, color: pinValido ? Colors.green : Colors.red, fontWeight: FontWeight.w500)),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton(
                          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                          style: ElevatedButton.styleFrom(backgroundColor: _blueDarkColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: pinValido
                              ? () async {
                            final pin = pinController.text.trim();
                            Navigator.of(context, rootNavigator: true).pop();
                            await _eliminarAutorizador(autorizador, pin);
                          }
                              : null,
                          style: ElevatedButton.styleFrom(backgroundColor: _blueDarkColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
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
      },
    );
  }

  Map<String, dynamic>? _getEmpresaSeleccionada() {
    if (widget.empresaSeleccionada == null) return null;
    final empresas = widget.userData['empresas'] ?? [];
    return empresas.firstWhere((emp) => emp['token_empresa'] == widget.empresaSeleccionada, orElse: () => {});
  }

  bool _esRepresentanteValido(Map<String, dynamic>? empresa) {
    if (empresa == null || empresa.isEmpty) return false;
    final tipoRelacion = empresa['tipo_relacion']?.toString().toLowerCase() ?? '';
    final validezRelacion = empresa['validez_relacion']?.toString().toLowerCase() ?? '';
    return tipoRelacion.contains('representante') && !validezRelacion.contains('no válida');
  }

  Widget _buildTituloEmpresa() {
    final empresa = _getEmpresaSeleccionada();
    if (empresa == null || empresa.isEmpty) return Container();
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
            Text(nombreEmpresa, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _blueDarkColor)),
            if (rutFormateado.isNotEmpty) ...[const SizedBox(height: 4), Text('RUT: $rutFormateado', style: TextStyle(fontSize: 14, color: Colors.grey.shade600))],
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
          Icon(Icons.people_outline, color: Colors.grey.shade400, size: 80),
          const SizedBox(height: 20),
          Text('No hay autorizadores asignados', style: TextStyle(fontSize: 18, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Asigna personas que puedan comprar en nombre de la empresa', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildItemAutorizador({required Map<String, dynamic> autorizador, required int index}) {
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
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.3), blurRadius: 3, offset: const Offset(0, 2), spreadRadius: 0)],
      ),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide.none),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: _approvedCardBackground, borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              Container(width: 40, height: 40, decoration: BoxDecoration(color: _blueDarkColor.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.person, color: _blueDarkColor, size: 20)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nombre, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black)),
                    const SizedBox(height: 4),
                    if (runComprador.isNotEmpty && dvRunComprador.isNotEmpty) Text('RUN: ${OptionsModal._formatRut(runCompleto)}', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: verificado ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                          child: Text(verificado ? 'Verificado' : 'No verificado', style: TextStyle(fontSize: 12, color: verificado ? Colors.green : Colors.orange, fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
                child: IconButton(
                  icon: Icon(Icons.close, color: Colors.red, size: 18),
                  onPressed: () => _mostrarDialogoEliminarAutorizador(autorizador),
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
          Icon(Icons.error_outline, color: Colors.red, size: 80),
          const SizedBox(height: 20),
          Text('Error al cargar autorizadores', style: TextStyle(fontSize: 18, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _initializeTokenAndFetchData, style: ElevatedButton.styleFrom(backgroundColor: _blueDarkColor, foregroundColor: Colors.white), child: const Text('Reintentar')),
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
        leading: IconButton(icon: Icon(Icons.arrow_back, color: _blueDarkColor), onPressed: widget.onVolver),
        title: Text('Autorizadores', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _blueDarkColor)),
        actions: [if (esRepresentanteValido) IconButton(icon: Icon(Icons.person_add, color: _blueDarkColor), onPressed: _mostrarDialogoAgregarAutorizador, tooltip: 'Agregar autorizador')],
      ),
      body: _initializingToken
          ? Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(color: _blueDarkColor), const SizedBox(height: 16), Text('Inicializando dispositivo...', style: TextStyle(color: Colors.grey.shade600))]),
      )
          : _isLoading
          ? Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(color: _blueDarkColor), const SizedBox(height: 16), Text('Cargando autorizadores...', style: TextStyle(color: Colors.grey.shade600))]),
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
                  Icon(Icons.info_outline, color: Colors.orange, size: 48),
                  const SizedBox(height: 16),
                  Text('Solo el representante legal puede gestionar autorizadores', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
                ],
              ),
            ),
          Expanded(
            child: _autorizadores.isEmpty
                ? _buildEstadoVacio()
                : RefreshIndicator(
              onRefresh: () async => _cargarAutorizadores(),
              color: _blueDarkColor,
              child: ListView.builder(
                itemCount: _autorizadores.length,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemBuilder: (context, index) => _buildItemAutorizador(autorizador: _autorizadores[index], index: index),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _asignarAutorizadorApi({
    required BuildContext context,
    required Map<String, dynamic> userData,
    required String run,
    required String pin,
    required Function(String) onAsignarAutorizador,
    required VoidCallback onReiniciarApp,
    required VoidCallback onActualizarAutorizadores,
  }) async {
    print('══════════════════════════════════════════════════════════════');
    print('🎯 INICIANDO API _asignarAutorizadorApi (v3)');
    print('══════════════════════════════════════════════════════════════');
    try {
      final String deviceToken = await FCMTokenManager.getDeviceToken();
      final tokenComprador = userData['comprador']?['token_comprador'] ?? '';
      final runComprador = userData['comprador']?['run_comprador']?.toString() ?? '';
      final dvRunComprador = userData['comprador']?['dv_run_comprador']?.toString() ?? '';
      if (tokenComprador.isEmpty || runComprador.isEmpty || dvRunComprador.isEmpty) return;
      final empresas = userData['empresas'] ?? [];
      final empresaSeleccionada = empresas.firstWhere((emp) => emp['seleccionada'] == true, orElse: () => empresas.isNotEmpty ? empresas[0] : {});
      if (empresaSeleccionada.isEmpty) return;
      final rutEmpresa = empresaSeleccionada['rut_empresa']?.toString() ?? '';
      final dvEmpresa = empresaSeleccionada['dv_rut_empresa']?.toString() ?? '';
      final runParseado = OptionsModal._parseRut(run);
      final runAutorizador = runParseado['numero'] ?? '';
      final dvRunAutorizador = runParseado['dv'] ?? '';
      if (runAutorizador.isEmpty || dvRunAutorizador.isEmpty) return;
      final requestBody = {
        "token_representante": tokenComprador,
        "run_autorizador": runAutorizador,
        "dv_autorizador": dvRunAutorizador,
        "rut_empresa": rutEmpresa,
        "dv_empresa": dvEmpresa,
        "token_dispositivo": deviceToken,
        "pin_seguridad": pin,
      };
      final response = await http.post(
        Uri.parse('${GlobalVariables.baseUrl}/CrearAutorizador/api/v3/'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json', 'api-key': GlobalVariables.apiKey},
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == false && responseData['sesion_iniciada'] == false) return;
        if (responseData['success'] == true) {
          final mensaje = responseData['message'] ?? 'Autorizador asignado exitosamente';
          GlobalSnackBars.mostrarExito(context, mensaje);
          onAsignarAutorizador(run);
          _cargarAutorizadores();
          if (onActualizarAutorizadores != null) onActualizarAutorizadores();
        } else {
          final mensajeError = responseData['message'] ?? responseData['error'] ?? 'Error al asignar autorizador';
          GlobalSnackBars.mostrarError(context, mensajeError);
        }
      } else if (response.statusCode == 401) {
        GlobalSnackBars.mostrarError(context, 'Sesión expirada. Inicie sesión nuevamente.');
        reiniciarAplicacion(context);
      } else {
        GlobalSnackBars.mostrarError(context, 'Error al asignar autorizador');
      }
    } catch (e) {
      GlobalSnackBars.mostrarError(context, 'Error de conexión: ${e.toString().split(':').first}');
    }
  }
}