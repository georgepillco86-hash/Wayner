import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../saldos/data/services/saldos_api_service.dart';
import '../services/conversiones_service.dart';
import '../../../core/storage/session_storage.dart';
import '../../saldos/presentation/screens/barcode_scanner_screen.dart';

class RealizarConversionDialog extends StatefulWidget {
  final Map<String, dynamic> requerimiento;
  final VoidCallback
  onSaved; // 🔥 NUEVO: Recibe el comando de recargar la lista principal

  const RealizarConversionDialog({
    super.key,
    required this.requerimiento,
    required this.onSaved, // 🔥 Obligatorio
  });

  @override
  State<RealizarConversionDialog> createState() =>
      _RealizarConversionDialogState();
}

class _RealizarConversionDialogState extends State<RealizarConversionDialog> {
  final SaldosApiService saldosService = SaldosApiService();
  final ConversionesService conversionesService = ConversionesService();

  // Datos Destino (Editables)
  String _codigoDestino = "";
  String _nombreDestino = "";
  late TextEditingController _cantDestinoController;

  // 🔥 ORIGENES MÚLTIPLES
  final List<Map<String, dynamic>> _origenes = [];

  bool _actividadCompleta = true;
  double _porcentaje = 1;
  DateTime? _fechaEstimada;
  bool _guardando = false;
  String _nombreUsuario = "Desconocido";

  @override
  void initState() {
    super.initState();
    _cargarUsuario();

    // Cargar Destino
    _codigoDestino =
        widget.requerimiento['codigo_destino'] ??
        widget.requerimiento['codigo_origen'] ??
        '';
    _nombreDestino =
        widget.requerimiento['nombre_destino'] ??
        widget.requerimiento['nombre_origen'] ??
        '';
    final double cantDestInicial =
        double.tryParse(
          widget.requerimiento['cantidad_destino']?.toString() ??
              widget.requerimiento['cantidad']?.toString() ??
              "1.0",
        ) ??
        1.0;
    _cantDestinoController = TextEditingController(
      text: cantDestInicial.toString(),
    );
  }

  Future<void> _cargarUsuario() async {
    final user = await SessionStorage.getUser();
    if (mounted && user != null) {
      setState(() => _nombreUsuario = user.nombreUsuario);
    }
  }

  // Buscar Destino
  Future<void> _buscarProductoDestino() async {
    final seleccionado = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _BuscadorProductosSheet(saldosService: saldosService),
    );

    if (seleccionado != null) {
      setState(() {
        _codigoDestino = seleccionado["Codigo"] ?? seleccionado["codigo"] ?? "";
        _nombreDestino =
            seleccionado["Nombre"] ?? seleccionado["nombre_producto"] ?? "";
      });
    }
  }

  // Buscar Origen
  Future<void> _buscarProductoOrigen() async {
    final seleccionado = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _BuscadorProductosSheet(saldosService: saldosService),
    );

    if (seleccionado != null) {
      final stock =
          double.tryParse(seleccionado["Stock"]?.toString() ?? "0") ?? 0.0;

      if (stock <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Error: El producto de origen no tiene stock disponible (0).",
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      setState(() {
        _origenes.add({
          "codigo": seleccionado["Codigo"] ?? seleccionado["codigo"] ?? "",
          "nombre":
              seleccionado["Nombre"] ?? seleccionado["nombre_producto"] ?? "",
          "stock": stock,
          "controller": TextEditingController(text: "1.0"),
        });
      });
    }
  }

  Future<void> _guardarConversion() async {
    final cantDestino = double.tryParse(_cantDestinoController.text) ?? 0.0;

    if (_codigoDestino.isEmpty || cantDestino <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Verifica el producto destino y su cantidad."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_origenes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Debes añadir al menos un producto origen."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final origenesPayload = [];
    for (var orig in _origenes) {
      final cant = double.tryParse(orig["controller"].text) ?? 0.0;

      if (cant <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "La cantidad de ${orig['nombre']} debe ser mayor a 0.",
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (cant > orig["stock"]) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "La cantidad de ${orig['nombre']} ($cant) supera el stock (${orig['stock']}).",
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (orig["codigo"] == _codigoDestino) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Un producto no puede ser origen y destino a la vez.",
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      origenesPayload.add({
        "codigo": orig["codigo"],
        "nombre": orig["nombre"],
        "cantidad": cant,
      });
    }

    if (!_actividadCompleta && _fechaEstimada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Debes seleccionar una fecha estimada de fin"),
        ),
      );
      return;
    }

    setState(() => _guardando = true);

    try {
      final porcentajeReal = _actividadCompleta
          ? 100
          : (_porcentaje * 20).toInt();
      final fechaStr = _fechaEstimada != null
          ? "${_fechaEstimada!.year}-${_fechaEstimada!.month.toString().padLeft(2, '0')}-${_fechaEstimada!.day.toString().padLeft(2, '0')}"
          : null;

      final payload = {
        "codigo_destino": _codigoDestino,
        "nombre_destino": _nombreDestino,
        "cantidad_destino": cantDestino,
        "origenes": origenesPayload,
        "actividad_completa": _actividadCompleta,
        "porcentaje": porcentajeReal,
        "fecha_estimada": fechaStr,
        "usuario_ejecucion": _nombreUsuario,
      };

      final rootOverlay = Navigator.of(context, rootNavigator: true).overlay!;

      await conversionesService.ejecutarConversion(
        widget.requerimiento['id'],
        payload,
        _nombreUsuario,
      );

      if (mounted) {
        // 🔥 1. Refresca la lista PENDIENTE -> PESADO
        widget.onSaved();
        Navigator.pop(context);

        // 🔥 2. Lanzamos el monitor RPA y le pasamos onFinish para refrescar PESADO -> FINALIZADO
        _iniciarRastreoRPA(
          rootOverlay,
          widget.requerimiento['id'],
          conversionesService,
          onFinish: widget.onSaved,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        child: _guardando
            ? const SizedBox(
                height: 150,
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Ejecutar Conversión",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "Orden ${widget.requerimiento['orden_trabajo'] ?? ''}",
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(height: 24),

                    // 🔥 SECCIÓN DESTINO
                    const Text(
                      "1. Producto DESTINO (A obtener)",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.indigo.shade300),
                      ),
                      tileColor: Colors.indigo.shade50,
                      leading: const Icon(
                        Icons.move_to_inbox,
                        color: Colors.indigo,
                      ),
                      title: Text(
                        _nombreDestino.isEmpty
                            ? "Buscar destino..."
                            : _nombreDestino,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: _codigoDestino.isNotEmpty
                          ? Text(
                              "Cód: $_codigoDestino",
                              style: TextStyle(color: Colors.indigo.shade800),
                            )
                          : null,
                      trailing: const Icon(Icons.edit, color: Colors.indigo),
                      onTap: _buscarProductoDestino,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _cantDestinoController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d*'),
                        ),
                      ],
                      decoration: const InputDecoration(
                        labelText: "Cantidad Destino",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(
                          Icons.add_shopping_cart,
                          color: Colors.indigo,
                        ),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 🔥 SECCIÓN ORIGENES MÚLTIPLES
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "2. Orígenes (A reducir)",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.deepOrange,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _buscarProductoOrigen,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text("Añadir"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    ..._origenes.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final orig = entry.value;
                      return Card(
                        color: Colors.orange.shade50,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      orig["nombre"],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    onPressed: () =>
                                        setState(() => _origenes.removeAt(idx)),
                                  ),
                                ],
                              ),
                              Text(
                                "Cód: ${orig['codigo']} | Stock: ${orig['stock']}",
                                style: TextStyle(
                                  color: Colors.orange.shade800,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: orig["controller"],
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*\.?\d*'),
                                  ),
                                ],
                                decoration: const InputDecoration(
                                  labelText: "Cantidad a reducir",
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                    const Divider(height: 32),

                    const Text(
                      "¿Se encuentra realizada la actividad completamente?",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        Radio<bool>(
                          value: true,
                          groupValue: _actividadCompleta,
                          onChanged: (val) =>
                              setState(() => _actividadCompleta = val!),
                        ),
                        const Text("Sí"),
                        const SizedBox(width: 20),
                        Radio<bool>(
                          value: false,
                          groupValue: _actividadCompleta,
                          onChanged: (val) =>
                              setState(() => _actividadCompleta = val!),
                        ),
                        const Text("No"),
                      ],
                    ),

                    if (!_actividadCompleta) ...[
                      const SizedBox(height: 12),
                      const Text("¿Cuánto % de la actividad está realizada?"),
                      Slider(
                        value: _porcentaje,
                        min: 1,
                        max: 5,
                        divisions: 4,
                        label: "${(_porcentaje * 20).toInt()}%",
                        onChanged: (val) => setState(() => _porcentaje = val),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today),
                          label: Text(
                            _fechaEstimada == null
                                ? "¿Cuándo culminará la actividad?"
                                : "Culmina: ${_fechaEstimada!.day}/${_fechaEstimada!.month}/${_fechaEstimada!.year}",
                          ),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null)
                              setState(() => _fechaEstimada = picked);
                          },
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Cancelar"),
                        ),
                        FilledButton(
                          onPressed: _guardarConversion,
                          child: const Text("Confirmar y Procesar"),
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

// ============================================================================
// 🔥 WIDGET REUTILIZABLE: DYNAMIC ISLAND (POLLING AL RPA) 🔥
// ============================================================================
void _iniciarRastreoRPA(
  OverlayState overlay,
  int reqId,
  ConversionesService service, {
  VoidCallback?
  onFinish, // 🔥 NUEVO: Recibe el comando para refrescar la lista por detrás
}) async {
  late OverlayEntry entry;
  bool isPolling = true;
  bool isSuccess = false;
  String message = "RPA ejecutando...";

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

  while (isPolling) {
    await Future.delayed(const Duration(seconds: 3));
    try {
      final listado = await service.listarRequerimientos();
      final req = listado.firstWhere(
        (r) => r['id'] == reqId,
        orElse: () => null,
      );

      if (req != null && req['procesado_rpa'] == true) {
        isPolling = false;

        final estado = req['estado'].toString().toUpperCase();
        isSuccess = estado == 'FINALIZADO' || estado.contains('EXITO');
        message = isSuccess ? "✅ Éxito en BITS" : "❌ Error ($estado)";

        entry.markNeedsBuild();

        // 🔥 Ejecuta el refresco de la pantalla principal silenciosamente 🔥
        if (onFinish != null) {
          onFinish();
        }

        await Future.delayed(const Duration(seconds: 4));
        entry.remove();
        break;
      }
    } catch (e) {}
  }
}

// ============================================================================
// WIDGET REUTILIZABLE: BUSCADOR CON CÁMARA NATIVA PROPIA
// ============================================================================
class _BuscadorProductosSheet extends StatefulWidget {
  final dynamic saldosService;
  const _BuscadorProductosSheet({required this.saldosService});

  @override
  State<_BuscadorProductosSheet> createState() =>
      _BuscadorProductosSheetState();
}

class _BuscadorProductosSheetState extends State<_BuscadorProductosSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _resultados = [];
  bool _isLoading = false;

  Future<void> _escanearCodigo() async {
    if (kIsWeb) return;
    try {
      final code = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
      );
      if (code != null && code.isNotEmpty) {
        _searchController.text = code;
        _buscar();
      }
    } on PlatformException {}
  }

  Future<void> _buscar() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _isLoading = true;
      _resultados = [];
    });
    try {
      final data = await widget.saldosService.buscarRapido(termino: query);
      final Map<String, dynamic> productosUnicos = {};
      for (var item in data) {
        final codigo =
            item["Codigo"]?.toString() ?? item["codigo"]?.toString() ?? "";
        if (codigo.isNotEmpty && !productosUnicos.containsKey(codigo)) {
          productosUnicos[codigo] = item;
        }
      }
      setState(() => _resultados = productosUnicos.values.toList());
    } catch (e) {
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.only(
        bottom: bottomInset,
        left: 16,
        right: 16,
        top: 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: "Buscar por nombre o escanear...",
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.camera_alt, color: Colors.blue),
                      onPressed: _escanearCodigo,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onSubmitted: (_) => _buscar(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            )
          else
            Expanded(
              child: _resultados.isEmpty
                  ? const Center(
                      child: Text(
                        "Busca un producto para empezar",
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _resultados.length,
                      itemBuilder: (context, index) {
                        final prod = _resultados[index];
                        return ListTile(
                          leading: const Icon(Icons.inventory_2_outlined),
                          title: Text(
                            prod["Nombre"] ?? "Desconocido",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            "Cód: ${prod["Codigo"]} | Stock: ${prod["Stock"] ?? 0}",
                          ),
                          onTap: () => Navigator.pop(context, prod),
                        );
                      },
                    ),
            ),
        ],
      ),
    );
  }
}
