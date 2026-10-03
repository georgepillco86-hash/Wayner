import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/services/saldos_api_service.dart';
import '../../../products/data/models/sales_summary.dart';
import '../../../products/presentation/widgets/sales_chart_widget.dart';

class VentasFlotanteDialog extends StatefulWidget {
  final String codigoProducto;
  final String nombreProducto;

  const VentasFlotanteDialog({
    super.key,
    required this.codigoProducto,
    required this.nombreProducto,
  });

  @override
  State<VentasFlotanteDialog> createState() => _VentasFlotanteDialogState();
}

class _VentasFlotanteDialogState extends State<VentasFlotanteDialog> {
  final SaldosApiService _service = SaldosApiService();

  bool _isLoading = true;
  String? _errorMessage;
  List<SalesSummary> _sales = [];

  // Rango de fechas por defecto
  DateTimeRange? _rangoFechas;

  @override
  void initState() {
    super.initState();
    // Configurar por defecto los últimos 3 meses (90 días aprox)
    final hoy = DateTime.now();
    _rangoFechas = DateTimeRange(
      start: DateTime(hoy.year, hoy.month - 3, hoy.day),
      end: hoy,
    );
    _loadSalesSummary();
  }

  Future<void> _seleccionarFechas() async {
    final DateTimeRange? seleccionado = await showDateRangePicker(
      context: context,
      initialDateRange: _rangoFechas,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue.shade800,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (seleccionado != null) {
      setState(() {
        _rangoFechas = seleccionado;
      });
      _loadSalesSummary();
    }
  }

  Future<void> _loadSalesSummary() async {
    if (_rangoFechas == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final desde = DateFormat('yyyy-MM-dd').format(_rangoFechas!.start);
    final hasta = DateFormat('yyyy-MM-dd').format(_rangoFechas!.end);

    try {
      final sales = await _service.getSalesSummary(
        widget.codigoProducto,
        desde,
        hasta,
      );
      if (mounted) {
        setState(() {
          _sales = sales;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  double get _totalVendido =>
      _sales.fold(0, (sum, item) => sum + item.cantidadVendida);

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final String textoRango = _rangoFechas == null
        ? "Seleccionar Fechas"
        : "${dateFormat.format(_rangoFechas!.start)} - ${dateFormat.format(_rangoFechas!.end)}";

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        width: MediaQuery.of(context).size.width * 0.95,
        height:
            MediaQuery.of(context).size.height *
            0.6, // Un poco más alto para los botones
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    "Ventas: ${widget.nombreProducto}",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const Divider(),

            // --- NUEVO: Fila de controles de fecha ---
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _seleccionarFechas,
                    icon: const Icon(Icons.calendar_month, size: 18),
                    label: Text(
                      textoRango,
                      style: const TextStyle(fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.blue.shade700,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.blue),
                  tooltip: "Actualizar",
                  onPressed: _loadSalesSummary,
                ),
              ],
            ),
            const SizedBox(height: 12),

            Text(
              'Total vendido en el periodo: ${_totalVendido.toInt()}',
              style: TextStyle(
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            // --- Gráfica ---
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                  ? Center(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    )
                  : _sales.isEmpty
                  ? const Center(
                      child: Text(
                        "No hay ventas en este periodo",
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : SalesChartWidget(sales: _sales),
            ),
          ],
        ),
      ),
    );
  }
}
