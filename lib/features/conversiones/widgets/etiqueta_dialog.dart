import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../../../core/storage/session_storage.dart';

class EtiquetaDialog extends StatefulWidget {
  final String nombreProducto;
  final String codigoBarras;

  const EtiquetaDialog({
    super.key,
    required this.nombreProducto,
    required this.codigoBarras,
  });

  @override
  State<EtiquetaDialog> createState() => _EtiquetaDialogState();
}

class _EtiquetaDialogState extends State<EtiquetaDialog> {
  late DateTime fechaElaboracion;
  late DateTime fechaCaducidad;
  int cantidadImprimir = 1;
  bool isPrinting = false;
  String usuarioActual = "Sistema";

  bool _imprimirNombre = true;
  bool _imprimirFechas = true;
  bool _imprimirBarras = true;

  // Variables para repeticiones en misma etiqueta
  int repeticionesMismaEtiqueta = 1;

  @override
  void initState() {
    super.initState();
    fechaElaboracion = DateTime.now();
    fechaCaducidad = DateTime.now().add(const Duration(days: 30));
    _cargarUsuario();
  }

  Future<void> _cargarUsuario() async {
    final user = await SessionStorage.getUser();
    if (mounted && user != null) {
      setState(() => usuarioActual = user.nombreUsuario);
    }
  }

  String _formatFecha(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  Future<void> _seleccionarFecha(bool isElaboracion) async {
    final initialDate = isElaboracion ? fechaElaboracion : fechaCaducidad;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        if (isElaboracion) {
          fechaElaboracion = picked;
          if (fechaCaducidad.isBefore(fechaElaboracion)) {
            fechaCaducidad = fechaElaboracion.add(const Duration(days: 1));
          }
        } else {
          fechaCaducidad = picked;
        }
      });
    }
  }

  // LÓGICA DE VALIDACIÓN DE TAMAÑO FÍSICO
  bool _esEtiquetaValida() {
    if (!_imprimirNombre && !_imprimirFechas && !_imprimirBarras) return false;

    int pesoColumna = 0;
    if (_imprimirBarras) pesoColumna += 50;
    if (_imprimirNombre) pesoColumna += 30;
    if (_imprimirFechas) pesoColumna += 20;

    int pesoTotal = pesoColumna * repeticionesMismaEtiqueta;

    // Límite arbitrario ajustado para la etiqueta térmica pequeña
    if (repeticionesMismaEtiqueta == 3 && _imprimirBarras && _imprimirNombre) {
      return false; // El código de barras + nombre no entra 3 veces.
    }

    return pesoTotal <= 150;
  }

  Future<void> _imprimir() async {
    setState(() => isPrinting = true);

    try {
      final url = Uri.parse(
        'http://192.168.1.231:5000/api/conversiones/imprimir_etiqueta',
      );

      final payload = {
        "codigo_barras": widget.codigoBarras,
        "nombre_producto": widget.nombreProducto,
        "fecha_elab": _formatFecha(fechaElaboracion),
        "fecha_cad": _formatFecha(fechaCaducidad),
        "cantidad": cantidadImprimir,
        "usuario": usuarioActual,
        "imprimir_nombre": _imprimirNombre,
        "imprimir_fechas": _imprimirFechas,
        "imprimir_barras": _imprimirBarras,
        "columnas": repeticionesMismaEtiqueta,
      };

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode(payload),
      );

      final data = json.decode(response.body);

      if (response.statusCode != 200 || data['success'] == false) {
        throw Exception(data['message'] ?? "Error del servidor");
      }

      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Orden enviada a la impresora Honeywell'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error de impresión: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => isPrinting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool permiteImprimir = _esEtiquetaValida();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Configurar Etiqueta",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),

              Container(
                width: 240,
                height: 180,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_imprimirNombre)
                      Text(
                        widget.nombreProducto.toUpperCase(),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: Colors.black,
                        ),
                      )
                    else
                      const SizedBox(height: 20),

                    if (_imprimirFechas)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "F.ELAB: ${_formatFecha(fechaElaboracion)}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                              color: Colors.black,
                            ),
                          ),
                          Text(
                            "F.CAD: ${_formatFecha(fechaCaducidad)}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      )
                    else
                      const SizedBox(height: 14),

                    if (_imprimirBarras)
                      SizedBox(
                        height: 50,
                        child: BarcodeWidget(
                          barcode: Barcode.code128(),
                          data: widget.codigoBarras.isEmpty
                              ? '000000000'
                              : widget.codigoBarras,
                          drawText: true,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          color: Colors.black,
                        ),
                      )
                    else
                      const SizedBox(height: 50),
                  ],
                ),
              ),
              const SizedBox(height: 15),

              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Imprimir Nombre",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Switch(
                          value: _imprimirNombre,
                          activeColor: Colors.indigo,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          onChanged: (val) =>
                              setState(() => _imprimirNombre = val),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Imprimir Fechas",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Switch(
                          value: _imprimirFechas,
                          activeColor: Colors.indigo,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          onChanged: (val) =>
                              setState(() => _imprimirFechas = val),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Imprimir Código",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Switch(
                          value: _imprimirBarras,
                          activeColor: Colors.indigo,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          onChanged: (val) =>
                              setState(() => _imprimirBarras = val),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 🔥 SOLUCIÓN OVERFLOW 1: Uso de Expanded y MainAxisSize.min
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      "Copias por etiqueta:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: repeticionesMismaEtiqueta > 1
                            ? () => setState(() => repeticionesMismaEtiqueta--)
                            : null,
                        icon: const Icon(
                          Icons.remove_circle,
                          color: Colors.blueGrey,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          "$repeticionesMismaEtiqueta",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: repeticionesMismaEtiqueta < 3
                            ? () => setState(() => repeticionesMismaEtiqueta++)
                            : null,
                        icon: const Icon(
                          Icons.add_circle,
                          color: Colors.blueGrey,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _seleccionarFecha(true),
                      icon: const Icon(Icons.edit_calendar, size: 16),
                      label: Text(
                        "ELAB: ${_formatFecha(fechaElaboracion)}",
                        style: const TextStyle(fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _seleccionarFecha(false),
                      icon: const Icon(Icons.event_available, size: 16),
                      label: Text(
                        "CAD: ${_formatFecha(fechaCaducidad)}",
                        style: const TextStyle(fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 🔥 SOLUCIÓN OVERFLOW 2: Uso de Expanded y MainAxisSize.min
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      "Cantidad a imprimir:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: cantidadImprimir > 1
                            ? () => setState(() => cantidadImprimir--)
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          "$cantidadImprimir",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => setState(() => cantidadImprimir++),
                        icon: const Icon(Icons.add_circle_outline),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (!permiteImprimir)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: const Text(
                    "⚠️ Límite de tamaño excedido. Reduce las repeticiones u oculta elementos.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

              SizedBox(
                width: double.infinity,
                height: 45,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: permiteImprimir
                        ? Colors.indigo.shade800
                        : Colors.grey,
                  ),
                  onPressed: (!isPrinting && permiteImprimir)
                      ? _imprimir
                      : null,
                  icon: isPrinting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.print),
                  label: Text(
                    isPrinting
                        ? "Enviando..."
                        : "IMPRIMIR $cantidadImprimir HOJA(S)",
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: isPrinting ? null : () => Navigator.pop(context),
                child: const Text(
                  "Cancelar",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
