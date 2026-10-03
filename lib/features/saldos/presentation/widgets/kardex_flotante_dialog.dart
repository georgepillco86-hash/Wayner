import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/services/saldos_api_service.dart';

class KardexFlotanteDialog extends StatefulWidget {
  final String codigoProducto;
  final String nombreProducto;

  const KardexFlotanteDialog({
    super.key,
    required this.codigoProducto,
    required this.nombreProducto,
  });

  @override
  State<KardexFlotanteDialog> createState() => _KardexFlotanteDialogState();
}

class _KardexFlotanteDialogState extends State<KardexFlotanteDialog> {
  final SaldosApiService _apiService = SaldosApiService();

  DateTimeRange? rangoFechas;
  bool isLoading = false;
  List<dynamic> movimientosKardex = [];

  @override
  void initState() {
    super.initState();
    final hoy = DateTime.now();
    rangoFechas = DateTimeRange(
      start: DateTime(hoy.year, hoy.month, 1),
      end: hoy,
    );
    _cargarKardexReal();
  }

  Future<void> _seleccionarFechas() async {
    final DateTimeRange? seleccionado = await showDateRangePicker(
      context: context,
      initialDateRange: rangoFechas,
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
        rangoFechas = seleccionado;
      });
      _cargarKardexReal();
    }
  }

  Future<void> _cargarKardexReal() async {
    if (rangoFechas == null) return;

    setState(() => isLoading = true);

    try {
      final startStr = DateFormat('yyyy-MM-dd').format(rangoFechas!.start);
      final endStr = DateFormat('yyyy-MM-dd').format(rangoFechas!.end);

      // 🔥 Se corrigió el nombre al método real: getKardexTable
      final data = await _apiService.getKardexTable(
        widget.codigoProducto,
        startStr,
        endStr,
      );

      if (mounted) {
        setState(() {
          movimientosKardex = data;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al cargar Kardex: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final String textoRango = rangoFechas == null
        ? "Seleccionar Fechas"
        : "${dateFormat.format(rangoFechas!.start)} - ${dateFormat.format(rangoFechas!.end)}";

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        width: MediaQuery.of(context).size.width * 0.95,
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    "Kardex: ${widget.nombreProducto}",
                    style: const TextStyle(
                      fontSize: 18,
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
                  icon: const Icon(Icons.refresh, color: Colors.green),
                  tooltip: "Actualizar",
                  onPressed: _cargarKardexReal,
                ),
              ],
            ),
            const SizedBox(height: 12),

            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : movimientosKardex.isEmpty
                  ? const Center(
                      child: Text(
                        "No hay movimientos en este rango de fechas.",
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 24,
                          headingRowHeight: 40,
                          dataRowMinHeight: 40,
                          dataRowMaxHeight: 50,
                          headingTextStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            fontSize: 13,
                          ),
                          columns: const [
                            DataColumn(label: Text("Fecha")),
                            DataColumn(label: Text("Tipo documento")),
                            DataColumn(label: Text("Ingreso")),
                            DataColumn(label: Text("Egreso")),
                          ],
                          rows: movimientosKardex.map((mov) {
                            // 🔥 Se leen exactamente las mismas llaves que en el Detalle del Producto
                            final fecha = mov["fecha"]?.toString() ?? "-";
                            final tipoDoc =
                                mov["tipo_documento"]?.toString() ?? "-";
                            final ingreso = mov["ingreso"]?.toString() ?? "0";
                            final egreso = mov["egreso"]?.toString() ?? "0";

                            return DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    fecha,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 180,
                                    child: Text(
                                      tipoDoc,
                                      style: const TextStyle(fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 2,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    ingreso,
                                    style: TextStyle(
                                      color: ingreso == "0"
                                          ? Colors.grey
                                          : Colors.green.shade700,
                                      fontWeight: ingreso == "0"
                                          ? FontWeight.normal
                                          : FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    egreso,
                                    style: TextStyle(
                                      color: egreso == "0"
                                          ? Colors.grey
                                          : Colors.red.shade700,
                                      fontWeight: egreso == "0"
                                          ? FontWeight.normal
                                          : FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
