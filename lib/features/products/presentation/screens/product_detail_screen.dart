import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/storage/session_storage.dart';
import '../../../saldos/data/models/product_balance.dart';
import '../../../saldos/data/services/saldos_api_service.dart';
// ---> NUEVA IMPORTACIÓN: El widget inteligente de la barra de stock <---
import '../../../saldos/presentation/widgets/stock_health_bar.dart';
import '../../data/models/sales_summary.dart';
import '../widgets/sales_chart_widget.dart';

import '../../data/models/product_price.dart';
import '../widgets/price_label_preview.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../../../printer/presentation/screens/printer_selection_screen.dart';
import '../../../printer/services/bluetooth_printer_service.dart';

class ProductDetailScreen extends StatefulWidget {
  final ProductBalance product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final SaldosApiService _service = SaldosApiService();

  bool _isLoading = true;
  bool _esAdmin = false;
  bool _isLoadingKardex = false;
  bool _mostrarKardex = true;

  String? _errorMessage;

  List<SalesSummary> _sales = [];
  List<Map<String, dynamic>> _kardexRows = [];

  DateTime? _kardexDesde;
  DateTime? _kardexHasta;

  ProductPrice? _productPrice;

  final BluetoothPrinterService _printerService = BluetoothPrinterService();
  BluetoothInfo? _selectedPrinter;

  // ---> NUEVA VARIABLE: Controla el tiempo de cobertura para el análisis <---
  int _diasCobertura = 7;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _loadSalesSummary();
    _loadProductPrice();
  }

  Future<void> _loadUserRole() async {
    final user = await SessionStorage.getUser();

    if (!mounted) return;

    setState(() {
      _esAdmin = user?.rol.trim().toUpperCase() == 'ADMIN';
    });
  }

  Future<void> _loadSalesSummary() async {
    final now = DateTime.now();
    final desde = DateFormat('yyyy-MM-01').format(now);
    final hasta = DateFormat('yyyy-MM-dd').format(now);

    try {
      final sales = await _service.getSalesSummary(
        widget.product.codigo,
        desde,
        hasta,
      );

      if (!mounted) return;

      setState(() {
        _sales = sales;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadProductPrice() async {
    try {
      final price = await _service.getProductPrice(widget.product.codigo);

      if (!mounted) return;

      setState(() {
        _productPrice = price;
      });
    } catch (_) {
      // No detenemos la pantalla si el precio falla.
    }
  }

  double get _totalVendido {
    return _sales.fold(0, (sum, item) => sum + item.cantidadVendida);
  }

  Future<void> _pickKardexRangeAndLoad() async {
    final now = DateTime.now();

    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
      initialDateRange: DateTimeRange(
        start: DateTime(now.year, now.month, 1),
        end: now,
      ),
    );

    if (range == null) return;

    setState(() {
      _kardexDesde = range.start;
      _kardexHasta = range.end;
      _isLoadingKardex = true;
      _kardexRows = [];
    });

    try {
      final desde = DateFormat('yyyy-MM-dd').format(range.start);
      final hasta = DateFormat('yyyy-MM-dd').format(range.end);

      final rows = await _service.getKardexTable(
        widget.product.codigo,
        desde,
        hasta,
      );

      if (!mounted) return;

      setState(() {
        _kardexRows = rows;
        _mostrarKardex = true;
      });

      if (rows.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No existen movimientos Kardex en el rango seleccionado',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingKardex = false;
        });
      }
    }
  }

  Future<void> _printLabel() async {
    if (_productPrice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aún no se ha cargado el precio del producto'),
        ),
      );
      return;
    }

    try {
      final savedMac = await _printerService.getSavedPrinterMac();

      if (savedMac != null && savedMac.isNotEmpty) {
        final connected = await _printerService.connect(savedMac);

        if (!connected) {
          await _printerService.clearSavedPrinter();
          throw Exception(
            'No se pudo conectar a la impresora guardada. Selecciónala nuevamente.',
          );
        }
      } else {
        _selectedPrinter = await Navigator.push<BluetoothInfo>(
          context,
          MaterialPageRoute(builder: (_) => const PrinterSelectionScreen()),
        );

        if (_selectedPrinter == null) return;
      }

      final printed = await _printerService.printPriceLabel(
        productPrice: _productPrice!,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            printed
                ? 'Cenefa enviada a imprimir'
                : 'No se pudo imprimir la cenefa',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Widget _buildKardexAdminSection() {
    if (!_esAdmin) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _isLoadingKardex ? null : _pickKardexRangeAndLoad,
            icon: _isLoadingKardex
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.table_chart),
            label: Text(
              _isLoadingKardex ? 'Generando...' : 'Generar tabla Kardex',
            ),
          ),
        ),
        if (_kardexDesde != null && _kardexHasta != null) ...[
          const SizedBox(height: 8),
          Text(
            'Rango: ${DateFormat('yyyy-MM-dd').format(_kardexDesde!)} a ${DateFormat('yyyy-MM-dd').format(_kardexHasta!)}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
        if (_kardexRows.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Movimientos Kardex: ${_kardexRows.length}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _mostrarKardex = !_mostrarKardex;
                  });
                },
                icon: Icon(
                  _mostrarKardex ? Icons.visibility_off : Icons.visibility,
                ),
                label: Text(_mostrarKardex ? 'Ocultar tabla' : 'Mostrar tabla'),
              ),
            ],
          ),
          if (_mostrarKardex)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Fecha')),
                  DataColumn(label: Text('Tipo documento')),
                  DataColumn(label: Text('Ingreso')),
                  DataColumn(label: Text('Egreso')),
                ],
                rows: _kardexRows.map((row) {
                  return DataRow(
                    cells: [
                      DataCell(Text(row['fecha']?.toString() ?? '')),
                      DataCell(Text(row['tipo_documento']?.toString() ?? '')),
                      DataCell(Text(row['ingreso']?.toString() ?? '0')),
                      DataCell(Text(row['egreso']?.toString() ?? '0')),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del producto')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.nombre,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Código: ${product.codigo}'),
                  Text('Marca: ${product.marca ?? 'Sin marca'}'),
                  Text('Clase: ${product.clase ?? 'Sin clase'}'),
                  const Divider(height: 28),

                  // ==========================================
                  // SECCIÓN: INVENTARIO PREDICTIVO INTELIGENTE
                  // ==========================================
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Salud del Inventario',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      // Selector dinámico de días de cobertura
                      DropdownButton<int>(
                        isDense: true,
                        value: _diasCobertura,
                        items: const [
                          DropdownMenuItem(value: 7, child: Text('1 Semana')),
                          DropdownMenuItem(value: 15, child: Text('15 Días')),
                          DropdownMenuItem(value: 30, child: Text('1 Mes')),
                          DropdownMenuItem(value: 60, child: Text('2 Meses')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _diasCobertura = value;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Aquí dibujamos la barra gráfica (cambia automáticamente si eliges otra fecha)
                  StockHealthBar(
                    product: product,
                    diasCobertura: _diasCobertura,
                  ),

                  // ==========================================
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Histórico de ventas del mes',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text('Cantidad vendida: $_totalVendido'),
                  const SizedBox(height: 16),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_errorMessage != null)
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    )
                  else
                    SalesChartWidget(sales: _sales),
                  _buildKardexAdminSection(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Vista previa de cenefa',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  PriceLabelPreview(
                    productPrice: _productPrice,
                    fallbackName: product.nombre,
                    fallbackCode: product.codigo,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _printLabel,
                      icon: const Icon(Icons.print),
                      label: const Text('Imprimir cenefa'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
