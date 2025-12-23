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

class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const DashboardScreen({super.key, required this.userData});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  Map<String, dynamic> _currentUserData = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentUserData = widget.userData;
    _verificarSesionActualizada();
    print('🎯 DashboardScreen iniciado con datos iniciales:');
    _printUserData();
  }

  // ✅ MÉTODO MEJORADO: VERIFICAR SESIÓN ACTUALIZADA CON PRINTS COMPLETOS
  Future<void> _verificarSesionActualizada() async {
    try {
      setState(() {
        _isLoading = true;
      });

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

        print('✅ Sesion iniciada: $sesionIniciada');

        if (sesionIniciada) {
          print('✅ Sesión actualizada detectada, actualizando datos...');
          setState(() {
            _currentUserData = responseData;
          });
          _printUserData();
          _printLineaCreditoData();
          _printEmpresaData();
        } else {
          print('❌ No hay sesión activa en verificación actualizada');
        }
      } else {
        print('⚠️ Error en API SesionIniciada - Status: ${response.statusCode}');
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

  // ✅ NUEVO MÉTODO: IMPRIMIR RESPONSE COMPLETO
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

  void _printUserData() {
    print('👤 DATOS USUARIO:');
    print('- Comprador: ${_currentUserData['comprador']?['alias_comprador']}');
    print('- Estado comprador: ${_currentUserData['comprador']?['estado_comprador']}');
    print('- Dispositivo actual: ${_currentUserData['dispositivo_actual'] != null}');
    print('- Sesión iniciada: ${_currentUserData['sesion_iniciada']}');
  }

  // ✅ MÉTODO OPTIMIZADO: IMPRIMIR DATOS DE LÍNEA DE CRÉDITO
  void _printLineaCreditoData() {
    print('💳 DATOS LÍNEA CRÉDITO:');
    final lineasCredito = _currentUserData['lineas_credito'] ?? [];
    print('- Cantidad de líneas: ${lineasCredito.length}');

    for (int i = 0; i < lineasCredito.length; i++) {
      final linea = lineasCredito[i];
      print('\n📊 LÍNEA ${i + 1}:');

      // ✅ DATOS FINANCIEROS REALES
      final montoTotal = linea['monto_linea_credito'] ?? 0;
      final montoUtilizado = linea['monto_utilizado'] ?? 0;
      final montoDisponible = linea['monto_disponible'] ?? montoTotal;
      final porcentajeUtilizado = montoTotal > 0 ? (montoUtilizado / montoTotal * 100) : 0;

      print('💰 FINANCIERO:');
      print('   - Total: \$${_formatCurrency(montoTotal)}');
      print('   - Utilizado: \$${_formatCurrency(montoUtilizado)}');
      print('   - Disponible: \$${_formatCurrency(montoDisponible)}');
      print('   - Porcentaje: ${porcentajeUtilizado.toStringAsFixed(1)}%');

      // ✅ FECHAS
      print('📅 FECHAS:');
      print('   - Asignación: ${_formatDate(linea['fecha_asignacion'] ?? '')}');
      print('   - Caducidad: ${_formatDate(linea['fecha_caducidad'] ?? '')}');

      // ✅ EMPRESA ASOCIADA
      if (linea['empresa'] != null) {
        final empresa = linea['empresa'];
        print('🏢 EMPRESA:');
        print('   - RUT: ${empresa['rut_empresa']}-${empresa['dv_rut_empresa']}');
        print('   - Estado: ${_getEstadoEmpresaTexto(empresa['estado_empresa'])}');
      }
    }
  }

  // ✅ MÉTODO ACTUALIZADO: IMPRIMIR DATOS DE EMPRESA
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
    }
  }

  // Método para obtener el estado del comprador
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

  // ✅ MÉTODO CORREGIDO: OBTENER DATOS REALES DE LÍNEA DE CRÉDITO
  Map<String, dynamic> _getLineaCreditoData() {
    try {
      final lineasCredito = _currentUserData['lineas_credito'] ?? [];
      if (lineasCredito.isNotEmpty) {
        final primeraLinea = lineasCredito[0];
        final montoTotal = primeraLinea['monto_linea_credito'] ?? 0;
        final montoUtilizado = primeraLinea['monto_utilizado'] ?? 0;
        final montoDisponible = primeraLinea['monto_disponible'] ?? montoTotal;

        return {
          'monto_total': montoTotal,
          'monto_utilizado': montoUtilizado,
          'monto_disponible': montoDisponible,
          'fecha_asignacion': primeraLinea['fecha_asignacion'] ?? '',
          'fecha_caducidad': primeraLinea['fecha_caducidad'] ?? '',
          'tiene_linea_credito': true,
        };
      } else {
        return {
          'monto_total': 0,
          'monto_utilizado': 0,
          'monto_disponible': 0,
          'fecha_asignacion': '',
          'fecha_caducidad': '',
          'tiene_linea_credito': false,
        };
      }
    } catch (e) {
      print('❌ Error obteniendo datos de línea de crédito: $e');
      return {
        'monto_total': 0,
        'monto_utilizado': 0,
        'monto_disponible': 0,
        'fecha_asignacion': '',
        'fecha_caducidad': '',
        'tiene_linea_credito': false,
      };
    }
  }

  // ✅ MÉTODO ACTUALIZADO: OBTENER DATOS DE EMPRESA
  Map<String, dynamic> _getEmpresaData() {
    try {
      final empresas = _currentUserData['empresas'] ?? [];
      if (empresas.isNotEmpty) {
        final primeraEmpresa = empresas[0];
        return {
          'token_empresa': primeraEmpresa['token_empresa'] ?? '',
          'rut_empresa': primeraEmpresa['rut_empresa'] ?? '',
          'dv_rut_empresa': primeraEmpresa['dv_rut_empresa'] ?? '',
          'estado_empresa': primeraEmpresa['estado_empresa'] ?? 2,
          'tiene_empresa': true,
        };
      } else {
        return {
          'token_empresa': '',
          'rut_empresa': '',
          'dv_rut_empresa': '',
          'estado_empresa': 2,
          'tiene_empresa': false,
        };
      }
    } catch (e) {
      print('❌ Error obteniendo datos de empresa: $e');
      return {
        'token_empresa': '',
        'rut_empresa': '',
        'dv_rut_empresa': '',
        'estado_empresa': 2,
        'tiene_empresa': false,
      };
    }
  }

  // ✅ MÉTODO: OBTENER ESTADO DE LA EMPRESA
  int _getEmpresaStatus() {
    try {
      final empresas = _currentUserData['empresas'] ?? [];
      if (empresas.isNotEmpty) {
        final primeraEmpresa = empresas[0];
        if (primeraEmpresa['estado_empresa'] != null) {
          return primeraEmpresa['estado_empresa'] as int;
        }
      }
      return 2;
    } catch (e) {
      print('❌ Error obteniendo estado de empresa: $e');
      return 2;
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

  // ✅ LISTA DE PANTALLAS
  List<Widget> _getScreens() {
    return [
      _buildHomeScreen(),
      SalesHistoryScreen(userData: _currentUserData),
      ProfileScreen(
        userData: _currentUserData,
        onLogout: _logout,
      ),
    ];
  }

  Widget _buildHomeScreen() {
    final int userStatus = _getUserStatus();
    final lineaCreditoData = _getLineaCreditoData();
    final bool tieneLineaCredito = lineaCreditoData['tiene_linea_credito'] as bool;

    // ✅ USAR DATOS REALES
    final int montoTotal = lineaCreditoData['monto_total'] as int;
    final int montoUtilizado = lineaCreditoData['monto_utilizado'] as int;
    final int montoDisponible = lineaCreditoData['monto_disponible'] as int;
    final double porcentajeUtilizado = _getPorcentajeUtilizado();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _getUserName(),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1976D2),
            ),
          ),
          const SizedBox(height: 8),

          Text(
            _getUserEmail(),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),

          const SizedBox(height: 24),

          if (userStatus == 1)
            _buildVerificationSection(
              icon: Icons.email_outlined,
              title: 'Verificar correo electrónico',
              subtitle: 'Necesitas verificar tu correo para continuar',
              buttonText: 'Verificar Correo',
              onPressed: _verifyEmail,
              color: Colors.orange.shade700,
            )
          else if (userStatus == 2)
            _buildVerificationSection(
              icon: Icons.verified_user_outlined,
              title: 'Verificar identidad',
              subtitle: 'Completa la verificación de tu identidad',
              buttonText: 'Verificar Identidad',
              onPressed: _verifyIdentity,
              color: Colors.blue.shade700,
            )
          else if (userStatus >= 3)
              _buildCreditStatusSection(tieneLineaCredito),

          if (userStatus >= 3) ...[
            const SizedBox(height: 24),

            const Text(
              'Monto disponible',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF666666),
              ),
            ),
            const SizedBox(height: 8),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatCurrency(montoDisponible), // ✅ MONTO REAL
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1976D2),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'de ${_formatCurrency(montoTotal)}', // ✅ MONTO REAL
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ✅ BARRA DE PROGRESO CON PORCENTAJE REAL
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(3),
              ),
              child: FractionallySizedBox(
                widthFactor: porcentajeUtilizado.clamp(0.0, 1.0),
                alignment: Alignment.centerLeft,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1976D2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

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
                Text(
                  _formatCurrency(montoUtilizado), // ✅ MONTO REAL
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ],
            ),

            // ✅ INFORMACIÓN ADICIONAL SI TIENE LÍNEA DE CRÉDITO
            if (tieneLineaCredito) ...[
              const SizedBox(height: 16),
              Column(
                children: [
                  // ✅ FECHA ASIGNACIÓN
                  if (lineaCreditoData['fecha_asignacion'] != '')
                    _buildDateInfo(
                      icon: Icons.calendar_today,
                      label: 'Asignado:',
                      date: lineaCreditoData['fecha_asignacion'] as String,
                      color: Colors.green.shade700,
                    ),

                  const SizedBox(height: 8),

                  // ✅ FECHA CADUCIDAD
                  if (lineaCreditoData['fecha_caducidad'] != '')
                    _buildDateInfo(
                      icon: Icons.event_busy,
                      label: 'Vence:',
                      date: lineaCreditoData['fecha_caducidad'] as String,
                      color: Colors.orange.shade700,
                    ),
                ],
              ),
            ],
          ],

          const SizedBox(height: 24),

          const Divider(
            color: Color(0xFFE0E0E0),
            height: 1,
            thickness: 1,
          ),

          const SizedBox(height: 16),

          if (userStatus >= 3)
            _buildVerifiedSection(),
        ],
      ),
    );
  }

  // ✅ MÉTODO: CONSTRUIR INFO DE FECHA
  Widget _buildDateInfo({
    required IconData icon,
    required String label,
    required String date,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label ${_formatDate(date)}',
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
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

  Widget _buildVerificationSection({
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonText,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 0),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text(
              buttonText,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ MÉTODO: ESTADO DE LÍNEA DE CRÉDITO
  Widget _buildCreditStatusSection(bool tieneLineaCredito) {
    final int estadoEmpresa = _getEmpresaStatus();

    String statusText = '';
    Color statusColor = Colors.grey;
    Color backgroundColor = Colors.grey.shade100;
    IconData statusIcon = Icons.credit_card;

    switch (estadoEmpresa) {
      case 3:
        statusText = tieneLineaCredito ? 'Aprobada' : 'Sin línea asignada';
        statusColor = tieneLineaCredito ? Colors.green.shade700 : Colors.grey;
        backgroundColor = tieneLineaCredito ? Colors.green.shade50 : Colors.grey.shade100;
        statusIcon = Icons.check_circle;
        break;
      case 4:
        statusText = 'Rechazada';
        statusColor = Colors.red.shade700;
        backgroundColor = Colors.red.shade50;
        statusIcon = Icons.cancel;
        break;
      case 5:
        statusText = 'Caducada';
        statusColor = Colors.orange.shade700;
        backgroundColor = Colors.orange.shade50;
        statusIcon = Icons.event_busy;
        break;
      case 2:
      default:
        statusText = tieneLineaCredito ? 'Pendiente' : 'Sin línea asignada';
        statusColor = tieneLineaCredito ? Colors.orange.shade700 : Colors.grey;
        backgroundColor = tieneLineaCredito ? Colors.orange.shade50 : Colors.grey.shade100;
        statusIcon = Icons.pending;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 0),
      child: Row(
        children: [
          Icon(
            statusIcon,
            color: statusColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Estado de línea de crédito',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 14,
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _buildEmpresaStatusMessage(estadoEmpresa, tieneLineaCredito),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ MÉTODO: MENSAJE DE ESTADO
  Widget _buildEmpresaStatusMessage(int estadoEmpresa, bool tieneLineaCredito) {
    String message = '';
    Color textColor = Colors.grey.shade600;

    switch (estadoEmpresa) {
      case 3:
        message = tieneLineaCredito
            ? '¡Felicidades! Tu línea de crédito ha sido aprobada'
            : 'Empresa aprobada - Esperando asignación de línea de crédito';
        textColor = Colors.green.shade700;
        break;
      case 4:
        message = 'Tu línea de crédito ha sido rechazada.';
        textColor = Colors.red.shade700;
        break;
      case 5:
        message = 'Tu línea de crédito ha caducada.';
        textColor = Colors.orange.shade700;
        break;
      case 2:
      default:
        message = tieneLineaCredito
            ? 'Tu solicitud de línea de crédito está en proceso de revisión'
            : 'Esperando aprobación de línea de crédito';
        textColor = Colors.orange.shade700;
        break;
    }

    return Text(
      message,
      style: TextStyle(
        fontSize: 12,
        color: textColor,
      ),
    );
  }

  // ✅ MÉTODO: OBTENER TEXTO DEL ESTADO DE EMPRESA
  String _getEstadoEmpresaTexto(dynamic estado) {
    if (estado == null) return 'Desconocido';

    switch (estado) {
      case 2: return 'Pendiente';
      case 3: return 'Aprobada';
      case 4: return 'Rechazada';
      case 5: return 'Caducada';
      default: return 'Desconocido ($estado)';
    }
  }

  Widget _buildVerifiedSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      child: Row(
        children: [
          const Icon(
            Icons.verified_user,
            color: Color(0xFF4CAF50),
            size: 24,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Cuenta verificada',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
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

  // ✅ MÉTODO PARA ACTUALIZAR MANUALMENTE
  Future<void> _actualizarDatosUsuario() async {
    await _verificarSesionActualizada();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Image.asset(
          'assets/images/logo_fio.png',
          height: 35,
          fit: BoxFit.contain,
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _isLoading ? null : _actualizarDatosUsuario,
            tooltip: 'Actualizar datos',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF1976D2),
        ),
      )
          : _getScreens()[_currentIndex],
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
            setState(() {
              _currentIndex = index;
            });
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
          selectedItemColor: Color(0xFF1976D2),
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