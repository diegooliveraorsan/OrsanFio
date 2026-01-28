import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'variables_globales.dart';

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
  print('🔄 Reiniciando aplicación desde SalesHistoryScreen...');

  Navigator.pushNamedAndRemoveUntil(
    context,
    '/',
        (route) => false,
  );

  if (Navigator.canPop(context)) {
    Navigator.popUntil(context, (route) => route.isFirst);
  }
}

class SalesHistoryScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String? empresaSeleccionada;
  final VoidCallback? onRefresh;

  const SalesHistoryScreen({
    super.key,
    required this.userData,
    this.empresaSeleccionada,
    this.onRefresh,
  });

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  List<dynamic> _sales = [];
  List<dynamic> _filteredSales = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _initializingToken = true;
  String _errorMessage = '';
  String _selectedFilter = 'approved';
  String? _deviceToken;
  String? _lastEmpresaSeleccionada; // ✅ Para trackear cambios

  @override
  void initState() {
    super.initState();
    _lastEmpresaSeleccionada = widget.empresaSeleccionada;

    print('🎯 SalesHistoryScreen initState llamado');
    print('   Empresa seleccionada: ${widget.empresaSeleccionada}');

    // ✅ CARGAR DATOS INMEDIATAMENTE AL INICIAR
    _loadInitialData();
  }

  // ✅ MÉTODO MEJORADO: CARGAR DATOS INICIALES
  Future<void> _loadInitialData() async {
    print('🔄 Cargando datos iniciales para SalesHistoryScreen...');

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      // ✅ INICIALIZAR TOKEN PRIMERO
      await _initializeDeviceToken();

      // ✅ ESPERAR UN MOMENTO PARA QUE EL TOKEN SE INICIALICE
      if (_deviceToken == null) {
        print('⚠️ Token FCM aún no disponible, esperando...');
        await Future.delayed(const Duration(seconds: 1));

        if (_deviceToken == null) {
          print('⚠️ Creando token de fallback para carga inicial');
          _deviceToken = 'initial_fallback_${DateTime.now().millisecondsSinceEpoch}';
        }
      }

      // ✅ CARGAR HISTORIAL DE VENTAS
      await _fetchSalesHistory();

    } catch (e) {
      print('❌ Error en carga inicial: $e');
      setState(() {
        _errorMessage = 'Error al cargar historial: $e';
        _isLoading = false;
      });
    }
  }

  // ✅ NUEVO MÉTODO: DID UPDATE WIDGET - PARA REACCIONAR A CAMBIOS DE EMPRESA
  @override
  void didUpdateWidget(SalesHistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    print('🔄 SalesHistoryScreen - didUpdateWidget llamado');
    print('   Empresa anterior: ${oldWidget.empresaSeleccionada}');
    print('   Empresa nueva: ${widget.empresaSeleccionada}');

    // Verificar si la empresa seleccionada ha cambiado
    if (widget.empresaSeleccionada != _lastEmpresaSeleccionada) {
      print('🎯 ¡Empresa cambiada! Recargando historial de ventas...');
      _lastEmpresaSeleccionada = widget.empresaSeleccionada;

      // ✅ NO HACER setState AQUÍ, solo cargar datos
      _fetchSalesHistory();
    }
  }

  // ✅ OBTENER TOKEN DEL DISPOSITIVO (FCM) - CORREGIDO
  Future<void> _initializeDeviceToken() async {
    try {
      if (_deviceToken != null) {
        print('✅ Token FCM ya inicializado');
        return;
      }

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
        // Intentar nuevamente después de un breve retraso
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
      // Crear un token de fallback incluso si hay error
      final String errorToken = 'fcm_error_${DateTime.now().millisecondsSinceEpoch}';
      setState(() {
        _deviceToken = errorToken;
      });
    } finally {
      if (mounted) {
        setState(() {
          _initializingToken = false;
        });
      }
    }
  }

  Future<void> _onRefresh() async {
    print('🔄 Pull to refresh en SalesHistoryScreen');
    print('   Empresa actual: ${widget.empresaSeleccionada}');

    setState(() {
      _isRefreshing = true;
    });

    try {
      // ✅ SOLO ACTUALIZAR LOS DATOS, NO EL ESTADO DEL PADRE
      await _fetchSalesHistory();

      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      print('❌ Error durante refresh: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Widget _buildRefreshableContent() {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: const Color(0xFF0055B8),
      backgroundColor: Colors.white,
      displacement: 40,
      edgeOffset: 0,
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey.shade50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildFilterChip('Aprobadas', 'approved'),
              _buildFilterChip('Rechazadas', 'rejected'),
              _buildFilterChip('Todas', 'all'),
            ],
          ),
        ),
        Expanded(
          child: _filteredSales.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shopping_cart_outlined,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No hay compras ${_selectedFilter == 'approved' ? 'aprobadas' : _selectedFilter == 'rejected' ? 'rechazadas' : ''}',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
                if (_errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _fetchSalesHistory,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0055B8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Reintentar',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ],
            ),
          )
              : ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: _filteredSales.length,
            itemBuilder: (context, index) {
              final sale = _filteredSales[index];
              return _buildSaleCard(sale, index);
            },
          ),
        ),
      ],
    );
  }

  void _filterSales() {
    setState(() {
      switch (_selectedFilter) {
        case 'approved':
          _filteredSales = _sales.where((sale) {
            if (sale is Map<String, dynamic>) {
              final estado = sale['estado_venta'];
              return estado == 1;
            }
            return false;
          }).toList();
          break;
        case 'rejected':
          _filteredSales = _sales.where((sale) {
            if (sale is Map<String, dynamic>) {
              final estado = sale['estado_venta'];
              return estado == 0;
            }
            return false;
          }).toList();
          break;
        case 'all':
          _filteredSales = _sales;
          break;
        default:
          _filteredSales = _sales;
      }
    });
  }

  // ✅ API ACTUALIZADA A v2 CON TOKEN DISPOSITIVO - CORREGIDA
  Future<void> _fetchSalesHistory() async {
    try {
      if (!_isRefreshing) {
        setState(() {
          _isLoading = true;
          _errorMessage = '';
        });
      }

      print('🎯 _fetchSalesHistory llamado');
      print('   Empresa seleccionada: ${widget.empresaSeleccionada}');
      print('   Token dispositivo: ${_deviceToken?.substring(0, 20)}...');

      // ✅ VERIFICAR SI TENEMOS UNA EMPRESA SELECCIONADA
      if (widget.empresaSeleccionada == null || widget.empresaSeleccionada!.isEmpty) {
        print('⚠️ No hay empresa seleccionada, no se puede cargar historial');
        setState(() {
          _sales = [];
          _filteredSales = [];
          _isLoading = false;
          _isRefreshing = false;
          _errorMessage = 'Selecciona una empresa para ver el historial de compras';
        });
        return;
      }

      // ✅ VERIFICAR QUE TENEMOS TOKEN DEL DISPOSITIVO
      if (_deviceToken == null) {
        print('❌ _deviceToken es null, intentando obtenerlo nuevamente...');
        await _initializeDeviceToken();

        if (_deviceToken == null) {
          print('❌ No se pudo obtener el token del dispositivo');
          setState(() {
            _isLoading = false;
            _isRefreshing = false;
            _errorMessage = 'No se pudo obtener el token del dispositivo. Intenta nuevamente.';
          });
          return;
        }
      }

      final String tokenComprador = _getTokenComprador();

      if (tokenComprador.isEmpty) {
        print('❌ token_comprador está vacío');
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
          _errorMessage = 'No se pudo obtener la información del usuario';
        });
        return;
      }

      print('🔄 Iniciando llamada a API VentasEmpresa (v2)...');
      print('📤 Request body:');
      print('  - token_comprador: $tokenComprador');
      print('  - token_dispositivo: ${_deviceToken!.substring(0, 20)}...');
      print('🌐 URL: ${GlobalVariables.baseUrl}/VentasEmpresa/api/v2/');

      final response = await http.post(
        Uri.parse('${GlobalVariables.baseUrl}/VentasEmpresa/api/v2/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'api-key': GlobalVariables.apiKey,
        },
        body: json.encode({
          "token_comprador": tokenComprador,
          "token_dispositivo": _deviceToken!,
        }),
      ).timeout(const Duration(seconds: 15));

      print('📥 Response recibido:');
      print('  - Status Code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // ✅ VERIFICAR SI LA SESIÓN HA EXPIRADO
        if (responseData['success'] == false && responseData['sesion_iniciada'] == false) {
          mostrarSnackBar(context, 'Sesión cerrada. Por favor, inicia sesión nuevamente.');
          reiniciarAplicacion(context);
          return;
        }

        print('✅ API Response data:');
        print('  - success: ${responseData['success']}');
        print('  - sesion_iniciada: ${responseData['sesion_iniciada']}');
        print('  - total_empresas: ${responseData['total_empresas']}');

        if (responseData['success'] == true) {
          final List<dynamic> empresasVentas = responseData['empresas_ventas'] ?? [];
          print('🏢 Empresas encontradas: ${empresasVentas.length}');

          if (empresasVentas.isNotEmpty) {
            List<dynamic> todasLasVentas = [];

            for (final empVentas in empresasVentas) {
              if (empVentas is Map<String, dynamic>) {
                final ventas = empVentas['ventas'] ?? [];
                if (ventas is List) {
                  todasLasVentas.addAll(ventas);
                }
              }
            }

            print('📦 Total de ventas encontradas (todas las empresas): ${todasLasVentas.length}');

            List<dynamic> ventasFiltradas = [];

            // ✅ SIEMPRE FILTRAR POR EMPRESA SELECCIONADA
            print('🎯 Filtrando ventas para empresa: ${widget.empresaSeleccionada}');

            for (final venta in todasLasVentas) {
              if (venta is Map<String, dynamic>) {
                final empresaVenta = _findEmpresaForVenta(venta, empresasVentas);
                if (empresaVenta != null) {
                  final tokenEmpresa = empresaVenta['token_empresa']?.toString();
                  if (tokenEmpresa == widget.empresaSeleccionada) {
                    ventasFiltradas.add(venta);
                  }
                }
              }
            }

            print('✅ Ventas filtradas para empresa seleccionada: ${ventasFiltradas.length}');

            setState(() {
              _sales = ventasFiltradas;
            });

            _filterSales();

            if (ventasFiltradas.isEmpty) {
              print('ℹ️ No hay ventas para la empresa seleccionada');
              setState(() {
                _errorMessage = 'No hay compras registradas para esta empresa';
              });
            }

          } else {
            print('⚠️ No hay empresas en la respuesta');
            setState(() {
              _errorMessage = 'No se encontraron empresas asociadas';
              _sales = [];
              _filteredSales = [];
            });
          }
        } else {
          print('❌ API returned success: false');
          final error = responseData['error'];
          if (error != null) {
            print('   - Error: $error');
          }
          setState(() {
            _errorMessage = responseData['error']?.toString() ?? 'Error al cargar el historial';
          });
        }
      } else if (response.statusCode == 401) {
        // ✅ SESIÓN EXPIRADA POR STATUS 401
        print('🔐 Sesión expirada (401 Unauthorized)');
        mostrarSnackBar(context, 'Sesión cerrada. Por favor, inicia sesión nuevamente.');
        reiniciarAplicacion(context);
        return;
      } else {
        print('❌ Error HTTP: ${response.statusCode}');
        setState(() {
          _errorMessage = 'Error de conexión: ${response.statusCode}';
        });
      }
    } catch (e) {
      print('❌ Error en _fetchSalesHistory: $e');
      setState(() {
        _errorMessage = 'Error de conexión: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  Map<String, dynamic>? _findEmpresaForVenta(Map<String, dynamic> venta, List<dynamic> empresasVentas) {
    try {
      final tokenVenta = venta['token_venta']?.toString();

      for (final empVentas in empresasVentas) {
        if (empVentas is Map<String, dynamic>) {
          final empresa = empVentas['empresa'];
          final ventas = empVentas['ventas'] ?? [];

          for (final v in ventas) {
            if (v is Map<String, dynamic>) {
              final tokenV = v['token_venta']?.toString();
              if (tokenV == tokenVenta) {
                return empresa is Map<String, dynamic> ? empresa : null;
              }
            }
          }
        }
      }
    } catch (e) {
      print('❌ Error en _findEmpresaForVenta: $e');
    }
    return null;
  }

  String _getTokenComprador() {
    try {
      final comprador = widget.userData['comprador'];
      if (comprador is Map<String, dynamic>) {
        final token = comprador['token_comprador']?.toString() ?? '';

        // ✅ VERIFICAR QUE EL TOKEN NO ESTÉ VACÍO
        if (token.isEmpty) {
          print('❌ Token comprador está vacío');
          return '';
        }

        // ✅ SOLO MOSTRAR PRIMEROS CARACTERES SI EL TOKEN ES SUFICIENTEMENTE LARGO
        if (token.length >= 10) {
          print('🔑 Token comprador obtenido: ${token.substring(0, 10)}...');
        } else {
          print('🔑 Token comprador obtenido: $token');
        }

        return token;
      }
      print('❌ No se encontró comprador en userData');
      return '';
    } catch (e) {
      print('❌ Error obteniendo token_comprador: $e');
      return '';
    }
  }

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

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  Color _getStatusColor(int estado) {
    switch (estado) {
      case 0:
        return const Color(0xFF757575);
      case 1:
        return const Color(0xFF0055B8);
      case 2:
        return const Color(0xFFFF9800);
      default:
        return Colors.grey;
    }
  }

  Color _getBackgroundColor(int estado) {
    switch (estado) {
      case 0:
        return const Color(0xFFF5F5F5);
      case 1:
        return const Color(0xFFE8F0FE);
      case 2:
        return const Color(0xFFFFF8E1);
      default:
        return Colors.grey.withOpacity(0.05);
    }
  }

  Widget _getSaleStatusWidget(int estado) {
    switch (estado) {
      case 0:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cancel,
              size: 14,
              color: _getStatusColor(estado),
            ),
            const SizedBox(width: 4),
            Text(
              'Rechazada',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _getStatusColor(estado),
              ),
            ),
          ],
        );
      case 1:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle,
              size: 14,
              color: _getStatusColor(estado),
            ),
            const SizedBox(width: 4),
            Text(
              'Aprobada',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _getStatusColor(estado),
              ),
            ),
          ],
        );
      case 2:
        return Text(
          'Pendiente',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _getStatusColor(estado),
          ),
        );
      default:
        return Text(
          'Desconocido',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _getStatusColor(estado),
          ),
        );
    }
  }

  String _getCompradorName(Map<String, dynamic> sale) {
    try {
      final nombreComprador = sale['comprador']['nombre_comprador']?.toString();
      if (nombreComprador != null && nombreComprador.isNotEmpty) {
        return nombreComprador;
      }

      final comprador = sale['comprador'];
      if (comprador is Map<String, dynamic>) {
        final nombre = comprador['nombre_comprador']?.toString();
        if (nombre != null && nombre.isNotEmpty) {
          return nombre;
        }
      }

      final compradorLogueado = widget.userData['comprador'];
      if (compradorLogueado is Map<String, dynamic>) {
        final nombreLogueado = compradorLogueado['nombre_comprador']?.toString();
        if (nombreLogueado != null && nombreLogueado.isNotEmpty) {
          return nombreLogueado;
        }
      }

      return 'Comprador';
    } catch (e) {
      print('❌ Error obteniendo nombre del comprador: $e');
      return 'Comprador';
    }
  }

  @override
  Widget build(BuildContext context) {
    print('🏗️ SalesHistoryScreen build - isLoading: $_isLoading, error: $_errorMessage');

    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: const Color(0xFF0055B8),
            ),
            const SizedBox(height: 16),
            Text(
              'Cargando historial de compras...',
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      )
          : _errorMessage.isNotEmpty && _filteredSales.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchSalesHistory,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0055B8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Reintentar',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      )
          : _buildRefreshableContent(),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    return ChoiceChip(
      label: Text(label),
      selected: _selectedFilter == value,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
          _filterSales();
        });
      },
      selectedColor: const Color(0xFF0055B8),
      labelStyle: TextStyle(
        color: _selectedFilter == value ? Colors.white : Colors.black,
      ),
    );
  }

  Widget _buildSaleCard(Map<String, dynamic> sale, int index) {
    final String fechaVenta = sale['fecha_venta']?.toString() ?? '';
    final int montoVenta = sale['monto_venta'] is int ? sale['monto_venta'] : 0;
    final int estadoVenta = sale['estado_venta'] is int ? sale['estado_venta'] : 0;

    final vendedor = sale['vendedor'];
    String nombreComercio = 'Comercio no disponible';
    if (vendedor is Map<String, dynamic>) {
      nombreComercio = vendedor['nombre_comercio_vendedor']?.toString() ?? 'Comercio no disponible';
    }

    final String compradorName = _getCompradorName(sale);

    final statusColor = _getStatusColor(estadoVenta);
    final backgroundColor = _getBackgroundColor(estadoVenta);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shadowColor: Colors.grey.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: backgroundColor,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      nombreComercio,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: statusColor.withOpacity(0.7),
                        width: 1.5,
                      ),
                    ),
                    child: _getSaleStatusWidget(estadoVenta),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      compradorName,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatCurrency(montoVenta),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0055B8),
                    ),
                  ),
                  Text(
                    _formatDate(fechaVenta),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
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
}