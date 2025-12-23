import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'variables_globales.dart';

class SalesHistoryScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String? empresaSeleccionada;
  final VoidCallback? onRefresh; // ✅ NUEVO: Callback para refrescar datos globales

  const SalesHistoryScreen({
    super.key,
    required this.userData,
    this.empresaSeleccionada,
    this.onRefresh, // ✅ NUEVO: Parámetro opcional para refrescar datos
  });

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  List<dynamic> _sales = [];
  List<dynamic> _filteredSales = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String _errorMessage = '';
  String _selectedFilter = 'approved';

  @override
  void initState() {
    super.initState();
    _fetchSalesHistory();
  }

  // ✅ CORREGIDO: Método para manejar el pull-to-refresh que retorna Future<void>
  Future<void> _onRefresh() async {
    print('🔄 Pull to refresh en SalesHistoryScreen');

    setState(() {
      _isRefreshing = true;
    });

    try {
      // ✅ ACTUALIZAR DATOS GLOBALES SI HAY CALLBACK
      if (widget.onRefresh != null) {
        widget.onRefresh!();
      }

      // ✅ ACTUALIZAR DATOS LOCALES
      await _fetchSalesHistory();

      // ✅ PEQUEÑO DELAY PARA QUE SE VEA EL INDICADOR
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

  // ✅ WIDGET CON PULL-TO-REFRESH
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

  // ✅ CONTENIDO PRINCIPAL (DISEÑO ORIGINAL)
  Widget _buildContent() {
    return Column(
      children: [
        // ✅ FILTRO EN PARTE SUPERIOR (DISEÑO ORIGINAL)
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

  // ✅ MÉTODO CORREGIDO: FILTRAR VENTAS CON ESTADOS ACTUALIZADOS
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

  // ✅ MÉTODO MEJORADO: OBTENER EL HISTORIAL DE VENTAS CON FILTRADO POR EMPRESA
  Future<void> _fetchSalesHistory() async {
    try {
      if (!_isRefreshing) {
        setState(() {
          _isLoading = true;
          _errorMessage = '';
        });
      }

      final String tokenComprador = _getTokenComprador();

      print('🔄 Iniciando llamada a API VentasEmpresa...');
      print('📤 Request body:');
      print('  - token_comprador: $tokenComprador');
      print('  - empresa_seleccionada: ${widget.empresaSeleccionada}');
      print('🌐 URL: ${GlobalVariables.baseUrl}/VentasEmpresa/api/v1/');

      final response = await http.post(
        Uri.parse('${GlobalVariables.baseUrl}/VentasEmpresa/api/v1/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'api-key': GlobalVariables.apiKey,
        },
        body: json.encode({
          "token_comprador": tokenComprador,
        }),
      ).timeout(const Duration(seconds: 15));

      print('📥 Response recibido:');
      print('  - Status Code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        print('✅ API Response data:');
        print('  - success: ${responseData['success']}');
        print('  - total_empresas: ${responseData['total_empresas']}');

        if (responseData['success'] == true) {
          final List<dynamic> empresasVentas = responseData['empresas_ventas'] ?? [];
          print('🏢 Empresas encontradas: ${empresasVentas.length}');

          if (empresasVentas.isNotEmpty) {
            List<dynamic> todasLasVentas = [];

            // ✅ RECOLECTAR TODAS LAS VENTAS DE TODAS LAS EMPRESAS
            for (final empVentas in empresasVentas) {
              if (empVentas is Map<String, dynamic>) {
                final ventas = empVentas['ventas'] ?? [];
                if (ventas is List) {
                  todasLasVentas.addAll(ventas);
                }
              }
            }

            print('📦 Total de ventas encontradas (todas las empresas): ${todasLasVentas.length}');

            // ✅ FILTRAR VENTAS POR EMPRESA SELECCIONADA
            List<dynamic> ventasFiltradas = [];

            if (widget.empresaSeleccionada != null) {
              print('🎯 Filtrando ventas para empresa: ${widget.empresaSeleccionada}');

              for (final venta in todasLasVentas) {
                if (venta is Map<String, dynamic>) {
                  // Buscar la empresa asociada a esta venta
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
            } else {
              // Si no hay empresa seleccionada, mostrar todas las ventas
              ventasFiltradas = todasLasVentas;
              print('ℹ️ No hay empresa seleccionada, mostrando todas las ventas: ${ventasFiltradas.length}');
            }

            setState(() {
              _sales = ventasFiltradas;
            });

            _filterSales();

            // ✅ Imprimir detalles de cada venta filtrada
            for (var i = 0; i < ventasFiltradas.length; i++) {
              final venta = ventasFiltradas[i];
              if (venta is Map<String, dynamic>) {
                print('🛒 Venta ${i + 1} (EMPRESA FILTRADA):');
                print('    - token_venta: ${venta}');
                print('    - token_venta: ${venta['token_venta']}');
                print('    - fecha_venta: ${venta['fecha_venta']}');
                print('    - monto_venta: ${venta['monto_venta']}');
                print('    - estado_venta: ${venta['estado_venta']}');

                final vendedor = venta['vendedor'];
                if (vendedor is Map<String, dynamic>) {
                  print('    - vendedor: ${vendedor['nombre_comercio_vendedor']}');
                }
              }
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

  // ✅ NUEVO MÉTODO: ENCONTRAR LA EMPRESA ASOCIADA A UNA VENTA
  Map<String, dynamic>? _findEmpresaForVenta(Map<String, dynamic> venta, List<dynamic> empresasVentas) {
    final tokenVenta = venta['token_venta']?.toString();

    for (final empVentas in empresasVentas) {
      if (empVentas is Map<String, dynamic>) {
        final empresa = empVentas['empresa'];
        final ventas = empVentas['ventas'] ?? [];

        // Verificar si esta venta pertenece a esta empresa
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
    return null;
  }

  String _getTokenComprador() {
    try {
      final comprador = widget.userData['comprador'];
      if (comprador is Map<String, dynamic>) {
        return comprador['token_comprador']?.toString() ?? '';
      }
      return '';
    } catch (e) {
      print('❌ Error obteniendo token_comprador: $e');
      return '';
    }
  }

  // ✅ MÉTODO PARA FORMATEAR MONEDA
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

  // ✅ MÉTODO PARA FORMATEAR FECHA
  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  // ✅ MÉTODO CORREGIDO: COLORES SEGÚN LOS ESTADOS ACTUALIZADOS
  Color _getStatusColor(int estado) {
    switch (estado) {
      case 0: // Rechazada → Gris
        return const Color(0xFF757575);
      case 1: // Aprobada → Azul oscuro #0055B8
        return const Color(0xFF0055B8);
      case 2: // Pendiente → Naranja
        return const Color(0xFFFF9800);
      default:
        return Colors.grey;
    }
  }

  // ✅ MÉTODO CORREGIDO: COLOR DE FONDO SEGÚN ESTADOS ACTUALIZADOS
  Color _getBackgroundColor(int estado) {
    switch (estado) {
      case 0: // Rechazada
        return const Color(0xFFF5F5F5);
      case 1: // Aprobada
        return const Color(0xFFE8F0FE);
      case 2: // Pendiente
        return const Color(0xFFFFF8E1);
      default:
        return Colors.grey.withOpacity(0.05);
    }
  }

  // ✅ MÉTODO CORREGIDO: OBTENER WIDGET DE ESTADO CON ICONOS
  Widget _getSaleStatusWidget(int estado) {
    switch (estado) {
      case 0: // Rechazada
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
      case 1: // Aprobada
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
      case 2: // Pendiente
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

  // ✅ MÉTODO CORREGIDO: OBTENER NOMBRE DEL COMPRADOR DESDE LA VENTA
  String _getCompradorName(Map<String, dynamic> sale) {
    try {
      // Primero intentar obtener el nombre_comprador directamente de la venta
      final nombreComprador = sale['comprador']['nombre_comprador']?.toString();
      if (nombreComprador != null && nombreComprador.isNotEmpty) {
        return nombreComprador;
      }

      // Si no está en la venta, buscar en el objeto comprador dentro de la venta
      final comprador = sale['comprador'];
      if (comprador is Map<String, dynamic>) {
        final nombre = comprador['nombre_comprador']?.toString();
        if (nombre != null && nombre.isNotEmpty) {
          return nombre;
        }
      }

      // Si no hay nombre en la venta, usar el nombre del comprador logueado como fallback
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF0055B8),
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

  // ✅ WIDGET PARA CHIPS DE FILTRO
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
              // ✅ NOMBRE DEL COMERCIO Y ESTADO
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

              // ✅ INFORMACIÓN DEL COMPRADOR
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

              // ✅ MONTO Y FECHA
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