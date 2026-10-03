import 'dart:async';
import 'dart:convert'; // 🔥 Importante para decodificar la respuesta
import 'package:flutter/material.dart';
import 'package:http/http.dart'
    as http; // 🔥 Importante para consultar al RPA directamente

import '../models/promocion.dart';
import '../services/promocion_service.dart';
import '../../saldos/presentation/screens/barcode_scanner_screen.dart';

class PromocionFormScreen extends StatefulWidget {
  final Promocion? promocion;

  const PromocionFormScreen({super.key, this.promocion});

  @override
  State<PromocionFormScreen> createState() => _PromocionFormScreenState();
}

class _PromocionFormScreenState extends State<PromocionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final PromocionService _service = PromocionService();

  final codigoController = TextEditingController();
  final nombreController = TextEditingController();
  final precioBaseController = TextEditingController();
  final precioAnteriorController = TextEditingController();
  final precioPromoController = TextEditingController();
  final encabezadoController = TextEditingController();

  DateTime fechaInicio = DateTime.now();
  DateTime fechaFin = DateTime.now().add(const Duration(days: 30));
  bool activa = true;
  bool isLoading = false;

  bool get esEdicion => widget.promocion != null;

  @override
  void initState() {
    super.initState();

    final promo = widget.promocion;

    if (promo != null) {
      codigoController.text = promo.codigoBarra;
      nombreController.text = promo.nombreProducto;
      precioBaseController.text = promo.precioBase.toStringAsFixed(2);
      precioAnteriorController.text = promo.precioAnterior.toStringAsFixed(2);
      precioPromoController.text = promo.precioActualProm.toStringAsFixed(2);
      encabezadoController.text = promo.encabezado ?? 'PROMOCIÓN ESPECIAL';
      fechaInicio = promo.fechaInicio;
      fechaFin = promo.fechaFin;
      activa = promo.activa;
    } else {
      encabezadoController.text = 'PROMOCIÓN ESPECIAL';
    }
  }

  @override
  void dispose() {
    codigoController.dispose();
    nombreController.dispose();
    precioBaseController.dispose();
    precioAnteriorController.dispose();
    precioPromoController.dispose();
    encabezadoController.dispose();
    super.dispose();
  }

  double _toDouble(String value) {
    return double.tryParse(value.replaceAll(',', '.').trim()) ?? 0;
  }

  String _formatFecha(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year}';
  }

  Future<void> escanearCodigo() async {
    final codigo = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );

    if (codigo == null || codigo.trim().isEmpty) return;

    codigoController.text = codigo.trim();

    await buscarProductoPorCodigo(codigo.trim());
  }

  Future<void> buscarProductoPorCodigo(String codigoBarra) async {
    if (codigoBarra.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa o escanea un código de barras')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final producto = await _service.buscarProductoPorCodigo(
        codigoBarra.trim(),
      );

      if (!mounted) return;

      setState(() {
        codigoController.text = producto.codigoBarra;
        nombreController.text = producto.nombreProducto;
        precioBaseController.text = producto.precioConIva.toStringAsFixed(2);

        if (precioAnteriorController.text.trim().isEmpty) {
          precioAnteriorController.text = producto.precioConIva.toStringAsFixed(
            2,
          );
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Producto cargado correctamente')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Producto no encontrado: $e')));
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> seleccionarFechaInicio() async {
    final result = await showDatePicker(
      context: context,
      initialDate: fechaInicio,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (result == null) return;

    setState(() {
      fechaInicio = result;

      if (fechaFin.isBefore(fechaInicio)) {
        fechaFin = fechaInicio;
      }
    });
  }

  Future<void> seleccionarFechaFin() async {
    final result = await showDatePicker(
      context: context,
      initialDate: fechaFin,
      firstDate: fechaInicio,
      lastDate: DateTime(2100),
    );

    if (result == null) return;

    setState(() {
      fechaFin = result;
    });
  }

  Future<void> guardar() async {
    if (!_formKey.currentState!.validate()) return;

    final precioAnterior = _toDouble(precioAnteriorController.text);
    final precioPromo = _toDouble(precioPromoController.text);

    if (precioPromo > precioAnterior) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'El precio promocional no puede ser mayor al precio anterior',
          ),
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      int idPromocionActual;

      if (esEdicion) {
        await _service.actualizar(
          id: widget.promocion!.id,
          nombreProducto: nombreController.text.trim(),
          precioBase: _toDouble(precioBaseController.text),
          precioAnterior: precioAnterior,
          precioActualProm: precioPromo,
          encabezado: encabezadoController.text.trim(),
          fechaInicio: fechaInicio,
          fechaFin: fechaFin,
          activa: activa,
        );
        idPromocionActual = widget.promocion!.id;
      } else {
        final nuevaPromocion = await _service.crear(
          codigoBarra: codigoController.text.trim(),
          nombreProducto: nombreController.text.trim(),
          precioBase: _toDouble(precioBaseController.text),
          precioAnterior: precioAnterior,
          precioActualProm: precioPromo,
          encabezado: encabezadoController.text.trim(),
          fechaInicio: fechaInicio,
          fechaFin: fechaFin,
          activa: activa,
        );

        idPromocionActual = nuevaPromocion.id;
      }

      if (!mounted) return;

      final rootOverlay = Navigator.of(context, rootNavigator: true).overlay!;

      Navigator.pop(context, true);

      // 🔥 Quitamos el paso de '_service' y usamos texto personalizado
      _iniciarRastreoRPA(
        rootOverlay,
        idPromocionActual,
        "RPA actualizando precio...",
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Widget _campoTexto({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon),
      ),
      validator: validator,
    );
  }

  String? _requerido(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Campo requerido';
    }
    return null;
  }

  String? _numeroValido(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Campo requerido';
    }

    final parsed = double.tryParse(value.replaceAll(',', '.').trim());

    if (parsed == null) {
      return 'Número inválido';
    }

    if (parsed < 0) {
      return 'No puede ser negativo';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ahorro =
        _toDouble(precioAnteriorController.text) -
        _toDouble(precioPromoController.text);

    final porcentaje = _toDouble(precioAnteriorController.text) > 0
        ? ((ahorro / _toDouble(precioAnteriorController.text)) * 100).ceil()
        : 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(esEdicion ? 'Editar promoción' : 'Nueva promoción'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  onChanged: () => setState(() {}),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _campoTexto(
                              controller: codigoController,
                              label: 'Código de barras',
                              icon: Icons.qr_code,
                              enabled: !esEdicion,
                              validator: _requerido,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (!esEdicion)
                            SizedBox(
                              height: 56,
                              child: IconButton.filled(
                                tooltip: 'Escanear código',
                                onPressed: isLoading ? null : escanearCodigo,
                                icon: const Icon(Icons.qr_code_scanner),
                              ),
                            ),
                          const SizedBox(width: 8),
                          if (!esEdicion)
                            SizedBox(
                              height: 56,
                              child: IconButton.outlined(
                                tooltip: 'Buscar producto',
                                onPressed: isLoading
                                    ? null
                                    : () => buscarProductoPorCodigo(
                                        codigoController.text.trim(),
                                      ),
                                icon: const Icon(Icons.search),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      _campoTexto(
                        controller: nombreController,
                        label: 'Nombre del producto',
                        icon: Icons.inventory_2,
                        validator: _requerido,
                      ),
                      const SizedBox(height: 12),

                      _campoTexto(
                        controller: precioBaseController,
                        label: 'Precio base',
                        icon: Icons.attach_money,
                        keyboardType: TextInputType.number,
                        validator: _numeroValido,
                      ),
                      const SizedBox(height: 12),

                      _campoTexto(
                        controller: precioAnteriorController,
                        label: 'Precio anterior',
                        icon: Icons.price_change,
                        keyboardType: TextInputType.number,
                        validator: _numeroValido,
                      ),
                      const SizedBox(height: 12),

                      _campoTexto(
                        controller: precioPromoController,
                        label: 'Precio promocional',
                        icon: Icons.local_offer,
                        keyboardType: TextInputType.number,
                        validator: _numeroValido,
                      ),
                      const SizedBox(height: 12),

                      _campoTexto(
                        controller: encabezadoController,
                        label: 'Encabezado',
                        icon: Icons.campaign,
                        validator: _requerido,
                      ),

                      const SizedBox(height: 16),

                      Card(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              const Text(
                                'Cálculo automático',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Ahorro: \$${ahorro < 0 ? 0 : ahorro.toStringAsFixed(2)}',
                              ),
                              Text(
                                'Mecánica: DESCUENTO ${porcentaje < 0 ? 0 : porcentaje}%',
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: seleccionarFechaInicio,
                              icon: const Icon(Icons.calendar_month),
                              label: Text(
                                'Inicio: ${_formatFecha(fechaInicio)}',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: seleccionarFechaFin,
                              icon: const Icon(Icons.event),
                              label: Text('Fin: ${_formatFecha(fechaFin)}'),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      SwitchListTile(
                        title: const Text('Promoción activa'),
                        value: activa,
                        onChanged: (value) {
                          setState(() {
                            activa = value;
                          });
                        },
                      ),

                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: isLoading ? null : guardar,
                          icon: isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save),
                          label: Text(
                            isLoading
                                ? 'Guardando...'
                                : esEdicion
                                ? 'Actualizar promoción'
                                : 'Guardar promoción',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 🔥 WIDGET REUTILIZABLE: DYNAMIC ISLAND APUNTANDO AL ENDPOINT ORIGINAL 🔥
// ============================================================================
void _iniciarRastreoRPA(
  OverlayState overlay,
  int promoId,
  String initialMessage,
) async {
  late OverlayEntry entry;
  bool isPolling = true;
  bool isSuccess = false;
  String message = initialMessage;

  entry = OverlayEntry(
    builder: (context) => Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 0,
      right: 0,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.85,
            ),
            decoration: BoxDecoration(
              color: isPolling
                  ? Colors.indigo.shade800
                  : (isSuccess ? Colors.green.shade700 : Colors.red.shade700),
              borderRadius: BorderRadius.circular(40),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isPolling)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.0,
                    ),
                  )
                else
                  Icon(
                    isSuccess ? Icons.check_circle : Icons.cancel,
                    color: Colors.white,
                    size: 16,
                  ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    message,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  overlay.insert(entry);

  int intentos = 0;
  const int maxIntentos = 15; // 🔥 45 segundos de espera máxima

  // 🔥 BUCLE DE MONITOREO CONECTADO A TU BACKEND
  while (isPolling && intentos < maxIntentos) {
    await Future.delayed(const Duration(seconds: 3));
    intentos++;

    try {
      final url = Uri.parse(
        'http://192.168.1.231:5000/api/promociones/rpa/estado/$promoId',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final estadoDb = data['estado']?.toString().toUpperCase() ?? '';

        if (estadoDb == 'COMPLETADO' || estadoDb == 'ERROR') {
          isPolling = false;
          isSuccess = (estadoDb == 'COMPLETADO');

          final msgBackend = data['mensaje']?.toString() ?? '';
          if (msgBackend.isNotEmpty) {
            message = isSuccess ? "✅ $msgBackend" : "❌ $msgBackend";
          } else {
            message = isSuccess
                ? "✅ Precio actualizado en BITS"
                : "❌ Error RPA ($estadoDb)";
          }

          entry.markNeedsBuild();

          await Future.delayed(const Duration(seconds: 4));
          entry.remove();
          return;
        }
      }
    } catch (e) {
      debugPrint("⚠️ Error consultando estado RPA: $e");
    }
  }

  // 🔥 SI SE ACABA EL TIEMPO
  if (isPolling) {
    message = "⚠️ El RPA tardó demasiado";
    isSuccess = false;
    entry.markNeedsBuild();
    await Future.delayed(const Duration(seconds: 4));
    entry.remove();
  }
}
