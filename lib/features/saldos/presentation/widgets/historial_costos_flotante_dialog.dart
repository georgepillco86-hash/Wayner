import 'package:flutter/material.dart';
import '../../../pedidos/services/pedidos_service.dart';

class HistorialCostosFlotanteDialog extends StatefulWidget {
  final String codigoProducto;
  final String nombreProducto;

  const HistorialCostosFlotanteDialog({
    super.key,
    required this.codigoProducto,
    required this.nombreProducto,
  });

  @override
  State<HistorialCostosFlotanteDialog> createState() =>
      _HistorialCostosFlotanteDialogState();
}

class _HistorialCostosFlotanteDialogState
    extends State<HistorialCostosFlotanteDialog> {
  final PedidosService _pedidosService = PedidosService();
  bool _isLoading = true;
  List<dynamic> _historial = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
  }

  Future<void> _cargarHistorial() async {
    try {
      // Traemos el historial usando el servicio de pedidos existente
      final data = await _pedidosService.obtenerHistorialCostos(
        widget.codigoProducto,
        10,
      ); // Traemos los últimos 10
      if (mounted) {
        setState(() {
          _historial = data;
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Historial de Costos",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Text(
              widget.nombreProducto,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const Divider(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                  ? Center(child: Text("Error: $_errorMessage"))
                  : _historial.isEmpty
                  ? const Center(
                      child: Text(
                        "No hay historial de compras disponible para este producto.",
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      itemCount: _historial.length,
                      itemBuilder: (context, index) {
                        final h = _historial[index];
                        final costoFinal =
                            double.tryParse(
                              h["costo_final"]?.toString() ?? "0",
                            ) ??
                            0.0;
                        final ivaPct = h["iva_porcentaje"]?.toString() ?? "0";
                        final tieneIva = h["tiene_iva"] == true;
                        final etiquetaIva = tieneIva
                            ? "(Con IVA)"
                            : "(Sin IVA)";

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(
                              "\$${costoFinal.toStringAsFixed(4)} $etiquetaIva",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Proveedor: ${h["proveedor"] ?? 'Desconocido'}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  "Fecha: ${h["fecha"]?.toString().split('T').first ?? ''} | Impuesto: $ivaPct% IVA",
                                ),
                                Text(
                                  "Doc: ${h["documento"] ?? ''}",
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
