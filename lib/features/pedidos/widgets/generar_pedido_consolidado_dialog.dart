import 'package:ferrotienda_flutter_proyecto/features/saldos/data/services/saldos_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:provider/provider.dart';
import '../../favoritos/providers/favorites_provider.dart';

import '../services/pedidos_service.dart';
import 'package:ferrotienda_flutter_proyecto/features/mermas/data/services/merma_service.dart';
import 'package:ferrotienda_flutter_proyecto/features/mermas/presentation/screens/merma_screen.dart';
import '../../../core/storage/session_storage.dart';
import '../../saldos/presentation/widgets/kardex_flotante_dialog.dart';
import 'package:ferrotienda_flutter_proyecto/features/scanner/screens/lector_codigo_screen.dart';

class GenerarPedidoConsolidadoDialog extends StatefulWidget {
  final String proveedor;
  final bool isNotificado;

  const GenerarPedidoConsolidadoDialog({
    super.key,
    required this.proveedor,
    this.isNotificado = false,
  });

  @override
  State<GenerarPedidoConsolidadoDialog> createState() =>
      _GenerarPedidoConsolidadoDialogState();
}

class _GenerarPedidoConsolidadoDialogState
    extends State<GenerarPedidoConsolidadoDialog> {
  final PedidosService service = PedidosService();
  late final SaldosApiService saldosService;
  final MermaService _mermaService = MermaService();

  bool isLoading = true;
  String? errorMessage;
  Map<String, dynamic>? dataConsolidada;

  bool tieneMermas = false;
  List<String> unidadesGlobales = ["UNIDAD/ES"];

  Map<String, Map<String, dynamic>?> costosGlobalesCache = {};
  Map<String, List<dynamic>> historialCache = {};
  Map<String, Map<String, dynamic>> stockYMinimoCache = {};

  final TextEditingController _descProvController = TextEditingController(
    text: "0",
  );
  final Map<String, TextEditingController> _descItemControllers = {};
  final Map<String, TextEditingController> _cantControllers = {};
  final Map<String, TextEditingController> _costoControllers = {};

  String _estadoDialogo = "BORRADOR";

  final Map<String, bool> _usarProphetState = {};

  @override
  void initState() {
    super.initState();
    saldosService = SaldosApiService();
    _cargarTodo();
  }

  @override
  void dispose() {
    _descProvController.dispose();
    for (var c in _descItemControllers.values) {
      c.dispose();
    }
    for (var c in _cantControllers.values) {
      c.dispose();
    }
    for (var c in _costoControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _getDescItemController(String uniqueKey) {
    if (!_descItemControllers.containsKey(uniqueKey)) {
      _descItemControllers[uniqueKey] = TextEditingController(text: "0");
    }
    return _descItemControllers[uniqueKey]!;
  }

  TextEditingController _getCantController(
    String uniqueKey,
    String valorInicial,
  ) {
    if (!_cantControllers.containsKey(uniqueKey)) {
      _cantControllers[uniqueKey] = TextEditingController(text: valorInicial);
    }
    return _cantControllers[uniqueKey]!;
  }

  TextEditingController _getCostoController(
    String uniqueKey,
    String valorInicial,
  ) {
    if (!_costoControllers.containsKey(uniqueKey)) {
      _costoControllers[uniqueKey] = TextEditingController(text: valorInicial);
    }
    return _costoControllers[uniqueKey]!;
  }

  double _getDescuentoProv() {
    return double.tryParse(_descProvController.text) ?? 0.0;
  }

  double _getDescuentoItem(String uniqueKey) {
    return double.tryParse(_descItemControllers[uniqueKey]?.text ?? "0") ?? 0.0;
  }

  double _obtenerCostoActualParaCalculos(
    String uniqueKey,
    String codigo,
    double costoBaseFallback,
  ) {
    if (_costoControllers.containsKey(uniqueKey)) {
      return double.tryParse(_costoControllers[uniqueKey]!.text) ??
          costoBaseFallback;
    }
    return _obtenerUltimoCostoParaProveedor(codigo, costoBaseFallback);
  }

  Future<void> _cargarTodo() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      try {
        final uni = await service.obtenerUnidadesMedida();
        if (uni.isNotEmpty) unidadesGlobales = uni;
      } catch (e) {
        debugPrint("Error cargando unidades: $e");
      }

      final data = await service.obtenerDetalleBorradoresProveedor(
        widget.proveedor,
        notificado: widget.isNotificado,
      );
      dataConsolidada = data;

      bool todosNotificados = true;
      final itemsBD = data?["items"] as List<dynamic>? ?? [];
      if (itemsBD.isNotEmpty) {
        for (var item in itemsBD) {
          if (item["notificado"] != true &&
              item["notificado"] != "true" &&
              item["notificado"] != 1) {
            todosNotificados = false;
            break;
          }
        }
      } else {
        todosNotificados = false;
      }
      _estadoDialogo = todosNotificados ? "ENVIADO" : "BORRADOR";

      try {
        final provs = await _mermaService
            .obtenerProveedoresConMermasPendientes();
        tieneMermas = provs
            .map((p) => p.toUpperCase().trim())
            .contains(widget.proveedor.toUpperCase().trim());
      } catch (e) {
        debugPrint("Error cargando mermas: $e");
      }

      await Future.wait([
        _cargarCostosGlobales(),
        _cargarHistorialCostos(),
        _cargarStockYMinimoEnVivo(),
      ]);
    } catch (e) {
      errorMessage = "Error al cargar el consolidado del proveedor.";
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _cargarStockYMinimoEnVivo() async {
    final items = dataConsolidada?["items"] as List<dynamic>? ?? [];
    List<Future> peticiones = [];

    for (var item in items) {
      final codigo = item["codigo_producto"]?.toString();
      if (codigo != null &&
          codigo.isNotEmpty &&
          !stockYMinimoCache.containsKey(codigo)) {
        peticiones.add(
          saldosService
              .buscarRapido(termino: codigo)
              .then((resultados) {
                if (resultados.isNotEmpty) {
                  final dataInfo = resultados.first;
                  stockYMinimoCache[codigo] = {
                    "stock":
                        dataInfo["Stock"] ??
                        dataInfo["stock"] ??
                        dataInfo["stock_actual"] ??
                        0,
                    "minimo":
                        dataInfo["Minimo"] ??
                        dataInfo["minimo"] ??
                        dataInfo["stock_minimo"] ??
                        0,
                  };
                }
              })
              .catchError((_) {}),
        );
      }
    }
    await Future.wait(peticiones);
  }

  Future<void> _cargarCostosGlobales() async {
    final items = dataConsolidada?["items"] as List<dynamic>? ?? [];
    List<Future> peticiones = [];

    for (var item in items) {
      final codigo = item["codigo_producto"]?.toString();
      if (codigo != null &&
          codigo.isNotEmpty &&
          !costosGlobalesCache.containsKey(codigo)) {
        peticiones.add(
          service
              .obtenerMejorCostoGlobal(codigo, meses: 3)
              .then((costoData) {
                costosGlobalesCache[codigo] = costoData;
              })
              .catchError((_) {}),
        );
      }
    }
    await Future.wait(peticiones);
  }

  Future<void> _cargarHistorialCostos() async {
    final items = dataConsolidada?["items"] as List<dynamic>? ?? [];
    List<Future> peticiones = [];

    for (var item in items) {
      final codigo = item["codigo_producto"]?.toString();
      if (codigo != null &&
          codigo.isNotEmpty &&
          !historialCache.containsKey(codigo)) {
        peticiones.add(
          service
              .obtenerHistorialCostos(codigo, 20)
              .then((historial) {
                historialCache[codigo] = historial;
              })
              .catchError((_) {}),
        );
      }
    }
    await Future.wait(peticiones);
  }

  double _obtenerUltimoCostoParaProveedor(
    String codigo,
    double costoBaseFallback,
  ) {
    final historial = historialCache[codigo];
    if (historial == null || historial.isEmpty) return costoBaseFallback;

    for (var h in historial) {
      final provHistorial =
          h["proveedor"]?.toString().trim().toUpperCase() ?? "";
      if (provHistorial == widget.proveedor.trim().toUpperCase()) {
        return double.tryParse(h["costo_final"]?.toString() ?? "0") ??
            costoBaseFallback;
      }
    }
    return costoBaseFallback;
  }

  String _formatearFechaCorta(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }

  Future<void> _guardarCantidadEscrita(
    Map<String, dynamic> item,
    String uniqueKey,
    String valorTipeado,
  ) async {
    double nuevaCant = double.tryParse(valorTipeado) ?? 1.0;
    if (nuevaCant <= 0) nuevaCant = 1.0;

    final pedidoId = int.tryParse(item["pedido_id"].toString()) ?? 0;
    final itemId = int.tryParse(item["id"].toString()) ?? 0;

    if (pedidoId > 0 && itemId > 0) {
      try {
        await service.actualizarCantidadItemPedido(
          pedidoId: pedidoId,
          itemId: itemId,
          cantidad: nuevaCant,
        );
        setState(() {
          item["cantidad_pedida"] = nuevaCant;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Cantidad actualizada",
              style: TextStyle(fontSize: 12),
            ),
            duration: Duration(seconds: 1),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al guardar cantidad: $e")),
        );
      }
    }
  }

  Future<void> _guardarCostoEscrito(
    Map<String, dynamic> item,
    String uniqueKey,
    String valorTipeado,
  ) async {
    double nuevoCosto = double.tryParse(valorTipeado) ?? 0.0;
    if (nuevoCosto < 0) nuevoCosto = 0.0;

    final pedidoId = int.tryParse(item["pedido_id"].toString()) ?? 0;
    final itemId = int.tryParse(item["id"].toString()) ?? 0;

    if (pedidoId > 0 && itemId > 0) {
      try {
        await service.actualizarCostoItemPedido(
          pedidoId: pedidoId,
          itemId: itemId,
          costo: nuevoCosto,
        );
        setState(() {
          item["costo_base"] = nuevoCosto;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Costo actualizado correctamente",
              style: TextStyle(fontSize: 12),
            ),
            duration: Duration(seconds: 1),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al guardar costo: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _modificarCantidadBoton(
    Map<String, dynamic> item,
    String uniqueKey,
    double delta,
  ) async {
    double cantActual =
        double.tryParse(_getCantController(uniqueKey, "").text) ?? 1.0;
    double nuevaCant = cantActual + delta;
    if (nuevaCant <= 0) return;

    _getCantController(uniqueKey, "").text = nuevaCant.toStringAsFixed(
      nuevaCant.truncateToDouble() == nuevaCant ? 0 : 2,
    );
    await _guardarCantidadEscrita(
      item,
      uniqueKey,
      _getCantController(uniqueKey, "").text,
    );
  }

  Future<void> _cambiarUnidadMedidaItem(
    Map<String, dynamic> item,
    String nuevaUnidad,
  ) async {
    final pedidoId = int.tryParse(item["pedido_id"].toString()) ?? 0;
    final itemId = int.tryParse(item["id"].toString()) ?? 0;

    if (pedidoId > 0 && itemId > 0) {
      try {
        await service.actualizarUnidadItemPedido(
          pedidoId: pedidoId,
          itemId: itemId,
          unidad: nuevaUnidad,
        );
        setState(() => item["unidad"] = nuevaUnidad);
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error al cambiar unidad: $e")));
      }
    }
  }

  Future<void> _eliminarProducto(Map<String, dynamic> item) async {
    bool confirmar =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Eliminar producto"),
            content: const Text(
              "¿Estás seguro de quitar este producto de su respectivo pedido?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancelar"),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Eliminar"),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmar) {
      final pedidoId = int.tryParse(item["pedido_id"].toString()) ?? 0;
      final itemId = int.tryParse(item["id"].toString()) ?? 0;
      if (pedidoId > 0 && itemId > 0) {
        try {
          await service.eliminarItemPedido(pedidoId: pedidoId, itemId: itemId);
          _cargarTodo();
        } catch (e) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Error: $e")));
        }
      }
    }
  }

  Future<void> _agregarPromocion(Map<String, dynamic> item) async {
    final TextEditingController cantPromoController = TextEditingController(
      text: "1",
    );
    final nombreProd = item["nombre_producto"]?.toString() ?? "Producto";
    final codigoProd = item["codigo_producto"]?.toString() ?? "";
    final unidadStr = item["unidad"]?.toString() ?? "UNIDAD/ES";
    final pedidoId = int.tryParse(item["pedido_id"].toString()) ?? 0;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Añadir Bonificación / Promo"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nombreProd,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Se agregará una copia de este producto que será detectada automáticamente como PROMO (Costo \$0) en el PDF.",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: cantPromoController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Cantidad gratis (Ej: 3)",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.card_giftcard),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancelar"),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Agregar Bonificación"),
            ),
          ],
        );
      },
    );

    if (confirmar == true && pedidoId > 0) {
      final cantPromo = double.tryParse(cantPromoController.text) ?? 1;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      try {
        await service.agregarItemPedido(
          pedidoId: pedidoId,
          codigoProducto: codigoProd,
          cantidad: cantPromo,
          unidad: unidadStr,
          notaCompra: "PROMO",
        );
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("✅ Promoción agregada exitosamente")),
          );
          _cargarTodo();
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _agregarProducto() async {
    final items = dataConsolidada?["items"] as List<dynamic>? ?? [];
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Debe haber al menos un pedido activo para este proveedor antes de agregar más productos.",
          ),
        ),
      );
      return;
    }

    final targetPedidoId =
        int.tryParse(items.first["pedido_id"].toString()) ?? 0;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BuscadorProductosSheet(
        saldosService: saldosService,
        pedidoId: targetPedidoId,
        unidadesGlobales: unidadesGlobales,
        onItemAdded: () => _cargarTodo(),
      ),
    );
  }

  Future<void> _asignarProveedorGlobal(int pId, int iId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final todosLosProveedores = await service.obtenerProveedores();
      if (!mounted) return;
      Navigator.pop(context);

      String provSeleccionado = "";

      final bool? confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text(
              "Asignar a proveedor global",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            content: Autocomplete<String>(
              optionsBuilder: (TextEditingValue textValue) {
                if (textValue.text.isEmpty) return todosLosProveedores.take(15);
                return todosLosProveedores.where(
                  (p) => p.toLowerCase().contains(textValue.text.toLowerCase()),
                );
              },
              onSelected: (val) => provSeleccionado = val,
              fieldViewBuilder: (context, controller, focus, onSubmitted) {
                return TextField(
                  controller: controller,
                  focusNode: focus,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: "Buscar en la base de datos...",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (val) => provSeleccionado = val,
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Cancelar"),
              ),
              FilledButton(
                onPressed: () {
                  if (provSeleccionado.trim().isEmpty) return;
                  Navigator.pop(ctx, true);
                },
                child: const Text("Asignar"),
              ),
            ],
          );
        },
      );

      if (confirmar == true && provSeleccionado.isNotEmpty) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );
        await service.actualizarProveedorItemPedido(
          pedidoId: pId,
          itemId: iId,
          proveedor: provSeleccionado.trim(),
        );
        if (mounted) {
          Navigator.pop(context);
          _cargarTodo();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("✅ Producto asignado a $provSeleccionado")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _cambiarProveedor(Map<String, dynamic> item) async {
    final codigo = item["codigo_producto"]?.toString() ?? "";
    final pedidoId = int.tryParse(item["pedido_id"].toString()) ?? 0;
    final itemId = int.tryParse(item["id"].toString()) ?? 0;

    if (codigo.isEmpty || itemId == 0) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final proveedores = await service.obtenerProveedoresProducto(codigo);
      if (!mounted) return;
      Navigator.pop(context);

      if (proveedores.isEmpty) return;

      showModalBottomSheet(
        context: context,
        builder: (_) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        "Seleccionar Nuevo Destino",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.add_circle,
                        color: Colors.green,
                        size: 28,
                      ),
                      tooltip: "Asignar a cualquier proveedor",
                      onPressed: () {
                        Navigator.pop(context);
                        _asignarProveedorGlobal(pedidoId, itemId);
                      },
                    ),
                  ],
                ),
              ),
              if (proveedores.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text(
                      "El producto no tiene proveedores registrados.\nUsa el botón (+) para asignar uno nuevo.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: proveedores.length,
                    itemBuilder: (context, index) {
                      final p = proveedores[index];
                      final nombreProv =
                          p["proveedor"]?.toString() ?? "Sin nombre";

                      return ListTile(
                        leading: const Icon(
                          Icons.swap_horiz,
                          color: Colors.blue,
                        ),
                        title: Text(nombreProv),
                        onTap: () async {
                          Navigator.pop(context);
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                          try {
                            await service.actualizarProveedorItemPedido(
                              pedidoId: pedidoId,
                              itemId: itemId,
                              proveedor: nombreProv,
                            );
                            if (mounted) {
                              Navigator.pop(context);
                              _cargarTodo();
                            }
                          } catch (e) {
                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Error: $e")),
                              );
                            }
                          }
                        },
                      );
                    },
                  ),
                ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  void _verHistorial(String codigo, String nombreProducto) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final historial = await service.obtenerHistorialCostos(codigo, 5);
      if (!mounted) return;
      Navigator.pop(context);

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Historial de Costos",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  nombreProducto,
                  style: const TextStyle(color: Colors.grey),
                ),
                const Divider(),
                Expanded(
                  child: historial.isEmpty
                      ? const Center(
                          child: Text("No hay historial de compras disponible"),
                        )
                      : ListView.builder(
                          itemCount: historial.length,
                          itemBuilder: (context, index) {
                            final h = historial[index];
                            final costoFinal =
                                double.tryParse(
                                  h["costo_final"]?.toString() ?? "0",
                                ) ??
                                0.0;
                            final ivaPct =
                                h["iva_porcentaje"]?.toString() ?? "0";
                            final etiquetaIva = h["tiene_iva"] == true
                                ? "(Con IVA)"
                                : "(Sin IVA)";

                            return Card(
                              child: ListTile(
                                title: Text(
                                  "\$${costoFinal.toStringAsFixed(3)} $etiquetaIva",
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
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  String _construirTextoComoPDF(List<dynamic> items) {
    double totalConIvaAcumulado = 0.0;
    double subtotal0 = 0.0;
    double totalDescuentos = 0.0;
    Set<String> codigosVistos = {};

    final descGlobalProv = _getDescuentoProv();

    final pedidosInvolucrados = items
        .map((i) => i['pedido_id'].toString())
        .toSet()
        .toList()
        .join(', ');

    String txt = "*Duchi Sanchez Rosa Emperatriz*\n";
    txt += "RUC: 0102249976001\n";
    txt += "*FERROTIENDA*\n";
    txt += "Dirección Matriz: 1ro de Septiembre y Cantón Sígsig\n\n";
    txt += "Órdenes agrupadas: #$pedidosInvolucrados\n";
    txt += "Proveedor: ${widget.proveedor}\n";
    txt += "Fecha de emisión: ${_formatearFechaCorta(DateTime.now())}\n";
    txt += "Vigencia del pedido: 1 semana\n\n";
    txt += "📦 *DETALLE DEL PEDIDO (CONSOLIDADO):*\n";
    txt += "----------------------------------------\n";

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final cant = double.tryParse(item["cantidad_pedida"].toString()) ?? 0;
      final tieneIva = item["tiene_iva"] == true;
      final codigo = item["codigo_producto"]?.toString() ?? "";
      final costoBaseData =
          double.tryParse(item["costo_base"]?.toString() ?? "0") ?? 0.0;
      final uniqueKey = "${widget.proveedor}_${codigo}_$i";

      final costoUnit = _obtenerCostoActualParaCalculos(
        uniqueKey,
        codigo,
        costoBaseData,
      );
      final descItem = _getDescuentoItem(uniqueKey);

      double descPorcentajeTotal = descGlobalProv + descItem;
      if (descPorcentajeTotal > 100) descPorcentajeTotal = 100;

      bool esPromo = false;
      if (codigosVistos.contains(codigo)) {
        esPromo = true;
      } else {
        codigosVistos.add(codigo);
      }

      double descUnitario = esPromo
          ? costoUnit
          : (costoUnit * (descPorcentajeTotal / 100));
      double costoFinalUnit = costoUnit - descUnitario;
      double subtotalItem = costoFinalUnit * cant;

      totalDescuentos += (descUnitario * cant);

      if (tieneIva) {
        totalConIvaAcumulado += subtotalItem;
      } else {
        subtotal0 += subtotalItem;
      }

      final unidadTxt = item["unidad"] ?? "UNIDAD/ES";

      txt += "▪️ ${item["nombre_producto"]} ${esPromo ? '🎁 (PROMO)' : ''}\n";
      txt += "   Código: $codigo | Cant: $cant $unidadTxt\n";
      txt +=
          "   Costo U: \$${costoUnit.toStringAsFixed(4)} | Dscto/U: \$${descUnitario.toStringAsFixed(4)}\n";
      txt += "   Total: \$${subtotalItem.toStringAsFixed(2)}\n\n";
    }

    final base15 = totalConIvaAcumulado / 1.15;
    final totalIva = totalConIvaAcumulado - base15;
    final totalNeto = totalConIvaAcumulado + subtotal0;

    txt += "----------------------------------------\n";
    if (descGlobalProv > 0)
      txt += "Descuento del Proveedor Aplicado: $descGlobalProv%\n";
    txt += "Subtotal 15% (Base sin IVA): \$${base15.toStringAsFixed(2)}\n";
    txt += "Subtotal 0% (Base sin IVA): \$${subtotal0.toStringAsFixed(2)}\n";
    txt += "Total Ahorro/Dsctos: \$${totalDescuentos.toStringAsFixed(2)}\n";
    txt += "Valor Total de IVA (15%): \$${totalIva.toStringAsFixed(2)}\n";
    txt += "💰 *TOTAL NETO A PAGAR: \$${totalNeto.toStringAsFixed(2)}*\n\n";
    txt += "🕒 *Recepción de pedidos:*\n";
    txt += "*Lunes a Viernes: 08:30 - 14:00 y 15:00 - 17:00*\n";
    txt += "*Sábados: 08:30 - 12:30*\n";

    return txt;
  }

  Future<void> _compartirUnificado(
    List<dynamic> items,
    String textoPlano, {
    bool esPreOrden = false,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text("Sincronizando datos con el servidor...")),
          ],
        ),
      ),
    );

    List<Future> peticionesGuardado = [];
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final codigo = item["codigo_producto"]?.toString() ?? "";

      final uniqueKey = "${item['proveedor'] ?? widget.proveedor}_${codigo}_$i";

      final costoUI =
          double.tryParse(_costoControllers[uniqueKey]?.text ?? "0") ?? 0.0;
      final cantUI =
          double.tryParse(_cantControllers[uniqueKey]?.text ?? "1") ?? 1.0;

      final pedidoId = int.tryParse(item["pedido_id"].toString()) ?? 0;
      final itemId = int.tryParse(item["id"].toString()) ?? 0;

      if (pedidoId > 0 && itemId > 0) {
        Future<void> sincronizarSilencioso() async {
          try {
            await service.actualizarCostoItemPedido(
              pedidoId: pedidoId,
              itemId: itemId,
              costo: costoUI,
            );
          } catch (_) {}
          try {
            await service.actualizarCantidadItemPedido(
              pedidoId: pedidoId,
              itemId: itemId,
              cantidad: cantUI,
            );
          } catch (_) {}
        }

        peticionesGuardado.add(sincronizarSilencioso());
      }
    }

    await Future.wait(peticionesGuardado);

    if (mounted) {
      Navigator.pop(context);
    }

    final pdf = pw.Document();

    double totalConIvaAcumulado = 0.0;
    double subtotal0 = 0.0;
    double totalDescuentos = 0.0;
    Set<String> codigosVistos = {};

    final descGlobalProv = _getDescuentoProv();
    final pedidosInvolucrados = items
        .map((i) => i['pedido_id'].toString())
        .toSet()
        .toList()
        .join(', ');

    final tableData = items.asMap().entries.map((entry) {
      final i = entry.key;
      final item = entry.value;

      final cant = double.tryParse(item["cantidad_pedida"].toString()) ?? 0;
      final tieneIva = item["tiene_iva"] == true;
      final codigo = item["codigo_producto"]?.toString() ?? "";
      final costoBaseData =
          double.tryParse(item["costo_base"]?.toString() ?? "0") ?? 0.0;
      final uniqueKey = "${widget.proveedor}_${codigo}_$i";

      final costoUnit = _obtenerCostoActualParaCalculos(
        uniqueKey,
        codigo,
        costoBaseData,
      );
      final descItem = _getDescuentoItem(uniqueKey);

      double descPorcentajeTotal = descGlobalProv + descItem;
      if (descPorcentajeTotal > 100) descPorcentajeTotal = 100;

      bool esPromo = false;
      if (codigosVistos.contains(codigo)) {
        esPromo = true;
      } else {
        codigosVistos.add(codigo);
      }

      double descUnitario = esPromo
          ? costoUnit
          : (costoUnit * (descPorcentajeTotal / 100));
      double costoFinalUnit = costoUnit - descUnitario;
      double subtotalItem = costoFinalUnit * cant;

      totalDescuentos += (descUnitario * cant);

      if (tieneIva) {
        totalConIvaAcumulado += subtotalItem;
      } else {
        subtotal0 += subtotalItem;
      }

      return [
        codigo,
        "${item["nombre_producto"]} ${esPromo ? '(PROMO)' : ''}",
        cant.toString(),
        "\$${costoUnit.toStringAsFixed(4)}",
        "\$${descUnitario.toStringAsFixed(4)}",
        tieneIva ? "15%" : "0%",
        "\$${subtotalItem.toStringAsFixed(2)}",
      ];
    }).toList();

    final base15 = totalConIvaAcumulado / 1.15;
    final totalIva = totalConIvaAcumulado - base15;
    final totalNeto = totalConIvaAcumulado + subtotal0;

    final headerText = esPreOrden
        ? "PRE-ORDEN DE PEDIDO (VERIFICACIÓN)"
        : "Órdenes agrupadas: #$pedidosInvolucrados";
    final vigenciaText = esPreOrden
        ? "Sujeto a verificación de precios"
        : "Vigencia del pedido: 1 semana";

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Text(
              "Duchi Sanchez Rosa Emperatriz",
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16),
            ),
            pw.Text("RUC: 0102249976001"),
            pw.Text(
              "FERROTIENDA",
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
            ),
            pw.Text("Dirección Matriz: 1ro de Septiembre y Cantón Sígsig"),
            pw.SizedBox(height: 20),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      headerText,
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 14,
                        color: esPreOrden
                            ? PdfColors.orange800
                            : PdfColors.black,
                      ),
                    ),
                    pw.Text("Proveedor: ${widget.proveedor}"),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      "Fecha de emisión: ${_formatearFechaCorta(DateTime.now())}",
                    ),
                    pw.Text(vigenciaText),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: [
                'Código',
                'Descripción',
                'Cant.',
                'Costo U.',
                'Dscto.',
                'IVA',
                'Total',
              ],
              data: tableData,
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blueGrey800,
              ),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
              },
            ),
            pw.SizedBox(height: 20),
            pw.Container(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  if (descGlobalProv > 0)
                    pw.Text(
                      "Descuento del Proveedor Aplicado: $descGlobalProv%",
                    ),
                  pw.Text(
                    "Subtotal 15% (Base sin IVA): \$${base15.toStringAsFixed(2)}",
                  ),
                  pw.Text(
                    "Subtotal 0% (Base sin IVA): \$${subtotal0.toStringAsFixed(2)}",
                  ),
                  pw.Text(
                    "Total Ahorro/Dsctos: \$${totalDescuentos.toStringAsFixed(2)}",
                  ),
                  pw.Text(
                    "Valor Total de Impuestos (IVA 15%): \$${totalIva.toStringAsFixed(2)}",
                  ),
                  pw.Container(width: 180, child: pw.Divider()),
                  pw.Text(
                    "Total Neto a Pagar: \$${totalNeto.toStringAsFixed(2)}",
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 30),
            pw.Text(
              "🕒 Recepción de pedidos:",
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
            ),
            pw.Text(
              "Lunes a Viernes: 08:30 - 14:00 y 15:00 - 17:00",
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
            ),
            pw.Text(
              "Sábados: 08:30 - 12:30",
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
            ),
          ];
        },
      ),
    );

    final bytes = await pdf.save();
    final fileName = esPreOrden
        ? 'PreOrden_Consolidado_${widget.proveedor}.pdf'
        : 'Consolidado_${widget.proveedor}.pdf';
    final xFile = XFile.fromData(
      bytes,
      name: fileName,
      mimeType: 'application/pdf',
    );

    String textoACompartir = esPreOrden
        ? "⚠️ *PRE-ORDEN PARA VERIFICACIÓN DE PRECIOS Y PROMOS*\n\n$textoPlano"
        : textoPlano;

    await Share.shareXFiles([xFile], text: textoACompartir);

    if (esPreOrden) return;

    try {
      final Set<int> pedidosIdsSet = items
          .map((i) => int.tryParse(i['pedido_id'].toString()) ?? 0)
          .where((id) => id > 0)
          .toSet();
      for (var pId in pedidosIdsSet) {
        await service.notificarEnvioProveedor(
          pedidoId: pId,
          proveedor: widget.proveedor,
        );
      }

      if (mounted) {
        setState(() {
          _estadoDialogo = "ENVIADO";
          for (var item in dataConsolidada!["items"]) {
            item["notificado"] = true;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Órdenes enviadas oficialmente al proveedor"),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al notificar al sistema: $e")),
        );
    }
  }

  Widget _buildIABadge(
    String label,
    int valor,
    TextEditingController ctrl,
    Map<String, dynamic> item,
    String uniqueKey,
    bool isProphet,
  ) {
    final colorBase = isProphet ? Colors.amber : Colors.purple;

    return InkWell(
      onTap: () {
        ctrl.text = valor.toString();
        _guardarCantidadEscrita(item, uniqueKey, valor.toString());
      },
      borderRadius: BorderRadius.circular(8),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: colorBase.shade800,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: colorBase.shade600,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              "$valor",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = dataConsolidada?["items"] as List<dynamic>? ?? [];

    final Map<String, String> colaboradoresParticipantes = {};
    for (var item in items) {
      final user = item["usuario_creacion"]?.toString() ?? "";
      final cel = item["celular_usuario"]?.toString() ?? "";
      if (user.isNotEmpty && cel.isNotEmpty) {
        colaboradoresParticipantes[user] = cel;
      }
    }

    final textoPlanoFinal = items.isEmpty ? "" : _construirTextoComoPDF(items);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(12),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.95,
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          child: isLoading
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    SizedBox(height: 24),
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      "Cargando consolidado del proveedor...",
                      style: TextStyle(color: Colors.grey),
                    ),
                    SizedBox(height: 24),
                  ],
                )
              : errorMessage != null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 24),
                    Text(errorMessage!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cerrar"),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            "Consolidado: ${widget.proveedor}",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo.shade900,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.add_circle,
                            color: Colors.green,
                            size: 28,
                          ),
                          tooltip: "Agregar Producto",
                          onPressed: _agregarProducto,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _estadoDialogo == "ENVIADO"
                                ? Colors.blue
                                : Colors.orange,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            "Estado: $_estadoDialogo",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.indigo.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            "Items únicos: ${items.length}",
                            style: TextStyle(
                              color: Colors.indigo.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            const Text(
                              "Desc Prov (%): ",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(
                              width: 45,
                              height: 25,
                              child: TextField(
                                controller: _descProvController,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12),
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 16, thickness: 1.5),

                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          if (tieneMermas) ...[
                            InkWell(
                              onTap: () async {
                                final user = await SessionStorage.getUser();
                                if (!mounted) return;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MermaScreen(
                                      usuarioActual: user?.nombreUsuario ?? '',
                                      rolUsuario: user?.rol ?? '',
                                      esModoReporte: true,
                                    ),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.amber.shade400,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      color: Colors.amber.shade800,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        "⚠️ Este proveedor tiene productos en merma pendientes por gestionar",
                                        style: TextStyle(
                                          color: Colors.amber.shade900,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right,
                                      color: Colors.amber.shade800,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.orange.shade700,
                                side: BorderSide(
                                  color: Colors.orange.shade400,
                                  width: 1.5,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              icon: const Icon(Icons.plagiarism_outlined),
                              label: const Text(
                                "Compartir Pre-Orden Pedido PDF y Texto",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              onPressed: items.isEmpty
                                  ? null
                                  : () {
                                      FocusScope.of(context).unfocus();
                                      _compartirUnificado(
                                        items,
                                        textoPlanoFinal,
                                        esPreOrden: true,
                                      );
                                    },
                            ),
                          ),
                          const SizedBox(height: 8),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _estadoDialogo == "ENVIADO"
                                    ? Colors.blue.shade200
                                    : Colors.blue.shade700,
                                foregroundColor: _estadoDialogo == "ENVIADO"
                                    ? Colors.blue.shade900
                                    : Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                elevation: 0,
                              ),
                              icon: const Icon(Icons.share),
                              label: const Text(
                                "Compartir PDF Consolidado y Texto (Oficial)",
                              ),
                              onPressed:
                                  (items.isEmpty || _estadoDialogo == "ENVIADO")
                                  ? null
                                  : () {
                                      FocusScope.of(context).unfocus();
                                      _compartirUnificado(
                                        items,
                                        textoPlanoFinal,
                                        esPreOrden: false,
                                      );
                                    },
                            ),
                          ),

                          if (colaboradoresParticipantes.isNotEmpty &&
                              items.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            ...colaboradoresParticipantes.entries.map((entry) {
                              final nombreColab = entry.key;
                              String numero = entry.value.replaceAll(" ", "");
                              if (numero.startsWith('0')) {
                                numero = numero.substring(1);
                              }

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6.0),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.green.shade700,
                                      side: BorderSide(
                                        color: Colors.green.shade300,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                    ),
                                    icon: const Icon(Icons.chat, size: 20),
                                    label: Text("Notificar a $nombreColab"),
                                    onPressed: () async {
                                      FocusScope.of(context).unfocus();
                                      final pedidosInvolucrados = items
                                          .map((i) => i['pedido_id'].toString())
                                          .toSet()
                                          .toList()
                                          .join(', ');
                                      final textoWhats =
                                          "Hola *$nombreColab*, te notifico que tus requerimientos de las órdenes #$pedidosInvolucrados para el proveedor *${widget.proveedor}* ya fueron procesados y enviados.\n\nAquí tienes el detalle consolidado:\n$textoPlanoFinal";
                                      final url = Uri.parse(
                                        "https://wa.me/593$numero?text=${Uri.encodeComponent(textoWhats)}",
                                      );
                                      try {
                                        await launchUrl(
                                          url,
                                          mode: LaunchMode.externalApplication,
                                        );
                                      } catch (e) {
                                        if (context.mounted)
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                "No se pudo abrir WhatsApp.",
                                              ),
                                            ),
                                          );
                                      }
                                    },
                                  ),
                                ),
                              );
                            }).toList(),
                          ],

                          if (items.isNotEmpty || tieneMermas)
                            const Divider(height: 32, thickness: 1.5),

                          if (items.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(20.0),
                              child: Center(
                                child: Text("No hay ítems para consolidar."),
                              ),
                            )
                          else
                            ...items.asMap().entries.map((entry) {
                              final int index = entry.key;
                              final item = entry.value;

                              final codigo =
                                  item["codigo_producto"]?.toString() ?? "";
                              final uniqueKey =
                                  "${widget.proveedor}_${codigo}_$index";
                              final ordenOriginal =
                                  item["pedido_id"]?.toString() ?? "0";

                              final stock =
                                  stockYMinimoCache[codigo]?['stock'] ??
                                  item["stock_actual"] ??
                                  "0";
                              final minimo =
                                  stockYMinimoCache[codigo]?['minimo'] ??
                                  item["minimo"] ??
                                  "0";
                              final cantController = _getCantController(
                                uniqueKey,
                                item["cantidad_pedida"]?.toString() ?? "1",
                              );

                              final int ia7 = item["ia_7_dias"] ?? 0;
                              final int ia15 = item["ia_15_dias"] ?? 0;
                              final int ia30 = item["ia_30_dias"] ?? 0;

                              final bool alertaProphet =
                                  item["alerta_prophet"] == true;
                              final String eventoProximo =
                                  item["evento_proximo"]?.toString() ?? "";
                              final int diasParaEvento =
                                  item["dias_para_evento"] ?? 0;

                              final int prophet7 = item["prophet_7"] ?? 0;
                              final int prophet15 = item["prophet_15"] ?? 0;
                              final int prophet30 = item["prophet_30"] ?? 0;

                              bool usarProphet =
                                  _usarProphetState[uniqueKey] ?? false;

                              final costoGlobalData =
                                  costosGlobalesCache[codigo];
                              String txtMejorCosto =
                                  "Mejor costo (3m): Sin registro";
                              String txtMejorProv = "";
                              if (costoGlobalData != null) {
                                final cGlobal =
                                    double.tryParse(
                                      costoGlobalData["costo_final"]
                                              ?.toString() ??
                                          "0",
                                    ) ??
                                    0.0;
                                if (cGlobal > 0) {
                                  txtMejorCosto =
                                      "Mejor costo (3m): \$${cGlobal.toStringAsFixed(4)}";
                                  txtMejorProv =
                                      "Prov: ${costoGlobalData["proveedor"] ?? 'Desconocido'}";
                                }
                              }

                              final costoBase =
                                  double.tryParse(
                                    item["costo_base"]?.toString() ?? "0",
                                  ) ??
                                  0.0;
                              final ultimoCostoProv =
                                  _obtenerUltimoCostoParaProveedor(
                                    codigo,
                                    costoBase,
                                  );
                              final costoController = _getCostoController(
                                uniqueKey,
                                ultimoCostoProv.toStringAsFixed(4),
                              );

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item["nombre_producto"]
                                                    ?.toString() ??
                                                "",
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            InkWell(
                                              onTap: () {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) =>
                                                      KardexFlotanteDialog(
                                                        codigoProducto: codigo,
                                                        nombreProducto:
                                                            item["nombre_producto"]
                                                                ?.toString() ??
                                                            "",
                                                      ),
                                                );
                                              },
                                              child: const Padding(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 4,
                                                  vertical: 2,
                                                ),
                                                child: Icon(
                                                  Icons.inventory,
                                                  color: Colors.purple,
                                                  size: 22,
                                                ),
                                              ),
                                            ),
                                            InkWell(
                                              onTap: () =>
                                                  _agregarPromocion(item),
                                              child: const Padding(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 4,
                                                  vertical: 2,
                                                ),
                                                child: Icon(
                                                  Icons.card_giftcard,
                                                  color: Colors.orange,
                                                  size: 22,
                                                ),
                                              ),
                                            ),
                                            InkWell(
                                              onTap: () =>
                                                  _eliminarProducto(item),
                                              child: const Padding(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 4,
                                                  vertical: 2,
                                                ),
                                                child: Icon(
                                                  Icons.delete_outline,
                                                  color: Colors.red,
                                                  size: 22,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "Viene de la Orden #$ordenOriginal",
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontStyle: FontStyle.italic,
                                        color: Colors.indigo.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 6),

                                    Row(
                                      children: [
                                        const Text(
                                          "Cant: ",
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 11,
                                          ),
                                        ),
                                        InkWell(
                                          onTap: () => _modificarCantidadBoton(
                                            item,
                                            uniqueKey,
                                            -1,
                                          ),
                                          child: const Padding(
                                            padding: EdgeInsets.all(4),
                                            child: Icon(
                                              Icons.remove_circle_outline,
                                              color: Colors.blueGrey,
                                              size: 22,
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 35,
                                          height: 25,
                                          child: TextField(
                                            controller: cantController,
                                            keyboardType:
                                                const TextInputType.numberWithOptions(
                                                  decimal: true,
                                                ),
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            decoration: const InputDecoration(
                                              border: OutlineInputBorder(),
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                            onSubmitted: (val) =>
                                                _guardarCantidadEscrita(
                                                  item,
                                                  uniqueKey,
                                                  val,
                                                ),
                                          ),
                                        ),
                                        InkWell(
                                          onTap: () => _modificarCantidadBoton(
                                            item,
                                            uniqueKey,
                                            1,
                                          ),
                                          child: const Padding(
                                            padding: EdgeInsets.all(4),
                                            child: Icon(
                                              Icons.add_circle_outline,
                                              color: Colors.blueGrey,
                                              size: 22,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Container(
                                            height: 26,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade50,
                                              border: Border.all(
                                                color: Colors.grey.shade300,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: DropdownButtonHideUnderline(
                                              child: DropdownButton<String>(
                                                isExpanded: true,
                                                value:
                                                    unidadesGlobales.contains(
                                                      item["unidad"],
                                                    )
                                                    ? item["unidad"]
                                                    : unidadesGlobales.first,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.blueGrey,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                iconSize: 16,
                                                items: unidadesGlobales
                                                    .map(
                                                      (u) => DropdownMenuItem(
                                                        value: u,
                                                        child: Text(
                                                          u,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                    )
                                                    .toList(),
                                                onChanged: (newVal) {
                                                  if (newVal != null)
                                                    _cambiarUnidadMedidaItem(
                                                      item,
                                                      newVal,
                                                    );
                                                },
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Text(
                                          "Desc(%): ",
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 11,
                                          ),
                                        ),
                                        SizedBox(
                                          width: 35,
                                          height: 25,
                                          child: TextField(
                                            controller: _getDescItemController(
                                              uniqueKey,
                                            ),
                                            keyboardType: TextInputType.number,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                            decoration: const InputDecoration(
                                              border: OutlineInputBorder(),
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                            onChanged: (_) => setState(() {}),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),

                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 2,
                                            ),
                                            child: Text(
                                              "Stock: $stock (Mín: $minimo)",
                                              style: TextStyle(
                                                color: Colors.green.shade700,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text(
                                              "Costo (\$): ",
                                              style: TextStyle(
                                                color: Colors.black87,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            SizedBox(
                                              width: 55,
                                              height: 25,
                                              child: TextField(
                                                controller: costoController,
                                                keyboardType:
                                                    const TextInputType.numberWithOptions(
                                                      decimal: true,
                                                    ),
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                decoration:
                                                    const InputDecoration(
                                                      border:
                                                          OutlineInputBorder(),
                                                      contentPadding:
                                                          EdgeInsets.zero,
                                                    ),
                                                onChanged: (_) =>
                                                    setState(() {}),
                                                onSubmitted: (val) =>
                                                    _guardarCostoEscrito(
                                                      item,
                                                      uniqueKey,
                                                      val,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),

                                    if (ia7 > 0 ||
                                        ia15 > 0 ||
                                        ia30 > 0 ||
                                        alertaProphet)
                                      Container(
                                        margin: const EdgeInsets.only(
                                          top: 8,
                                          bottom: 4,
                                        ),
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: usarProphet
                                              ? Colors.amber.shade50
                                              : Colors.purple.shade50,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: usarProphet
                                                ? Colors.amber.shade400
                                                : Colors.purple.shade200,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        usarProphet
                                                            ? Icons.insights
                                                            : Icons
                                                                  .auto_awesome,
                                                        color: usarProphet
                                                            ? Colors
                                                                  .amber
                                                                  .shade800
                                                            : Colors.purple,
                                                        size: 14,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Expanded(
                                                        child: Text(
                                                          usarProphet
                                                              ? "🔮 Prophet (Temporada Alta):"
                                                              : "✨ Sugerencia Inteligente:",
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: usarProphet
                                                                ? Colors
                                                                      .amber
                                                                      .shade900
                                                                : Colors
                                                                      .purple
                                                                      .shade800,
                                                            fontSize: 11,
                                                          ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                if (alertaProphet)
                                                  TweenAnimationBuilder<double>(
                                                    tween: Tween(
                                                      begin: 0.8,
                                                      end: 1.0,
                                                    ),
                                                    duration: const Duration(
                                                      milliseconds: 700,
                                                    ),
                                                    curve: Curves.easeInOut,
                                                    builder:
                                                        (
                                                          context,
                                                          scale,
                                                          child,
                                                        ) {
                                                          return Transform.scale(
                                                            scale: usarProphet
                                                                ? 1.0
                                                                : scale,
                                                            child: child,
                                                          );
                                                        },
                                                    child: FilledButton.icon(
                                                      style: FilledButton.styleFrom(
                                                        backgroundColor:
                                                            usarProphet
                                                            ? Colors.grey
                                                            : Colors
                                                                  .amber
                                                                  .shade600,
                                                        visualDensity:
                                                            VisualDensity
                                                                .compact,
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 8,
                                                            ),
                                                        minimumSize: const Size(
                                                          0,
                                                          26,
                                                        ),
                                                      ),
                                                      icon: Icon(
                                                        usarProphet
                                                            ? Icons.close
                                                            : Icons
                                                                  .warning_amber_rounded,
                                                        size: 12,
                                                      ),
                                                      label: Text(
                                                        usarProphet
                                                            ? "Apagar"
                                                            : "$eventoProximo en ${diasParaEvento}d",
                                                        style: const TextStyle(
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      onPressed: () {
                                                        setState(() {
                                                          _usarProphetState[uniqueKey] =
                                                              !usarProphet;
                                                        });
                                                      },
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceAround,
                                              children: [
                                                _buildIABadge(
                                                  "7 Días",
                                                  usarProphet ? prophet7 : ia7,
                                                  cantController,
                                                  item,
                                                  uniqueKey,
                                                  usarProphet,
                                                ),
                                                _buildIABadge(
                                                  "15 Días",
                                                  usarProphet
                                                      ? prophet15
                                                      : ia15,
                                                  cantController,
                                                  item,
                                                  uniqueKey,
                                                  usarProphet,
                                                ),
                                                _buildIABadge(
                                                  "1 Mes",
                                                  usarProphet
                                                      ? prophet30
                                                      : ia30,
                                                  cantController,
                                                  item,
                                                  uniqueKey,
                                                  usarProphet,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),

                                    const Divider(height: 12),

                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                txtMejorCosto,
                                                style: const TextStyle(
                                                  color: Colors.green,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                ),
                                              ),
                                              if (txtMejorProv.isNotEmpty)
                                                Text(
                                                  txtMejorProv,
                                                  style: TextStyle(
                                                    color:
                                                        Colors.green.shade700,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              const SizedBox(height: 4),
                                              Text(
                                                "Último con ${widget.proveedor}: \$${ultimoCostoProv.toStringAsFixed(4)}",
                                                style: TextStyle(
                                                  color: Colors.blue.shade700,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            InkWell(
                                              onTap: () =>
                                                  _cambiarProveedor(item),
                                              child: const Padding(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 4,
                                                  vertical: 4,
                                                ),
                                                child: Icon(
                                                  Icons.swap_horiz,
                                                  color: Colors.blue,
                                                  size: 24,
                                                ),
                                              ),
                                            ),
                                            InkWell(
                                              onTap: () => _verHistorial(
                                                codigo,
                                                item["nombre_producto"]
                                                        ?.toString() ??
                                                    "",
                                              ),
                                              child: const Padding(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 4,
                                                  vertical: 4,
                                                ),
                                                child: Icon(
                                                  Icons.history,
                                                  color: Colors.blue,
                                                  size: 24,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),

                          if (items.isNotEmpty) ...[
                            const Divider(height: 32, thickness: 1.5),
                            ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              title: const Text(
                                "Vista previa del texto para WhatsApp:",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: SelectableText(
                                    textoPlanoFinal,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () {
                                      Clipboard.setData(
                                        ClipboardData(text: textoPlanoFinal),
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "Texto copiado al portapapeles",
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.copy, size: 16),
                                    label: const Text("Copiar Texto"),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          "Cerrar",
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _BuscadorProductosSheet extends StatefulWidget {
  final dynamic saldosService;
  final int pedidoId;
  final List<String> unidadesGlobales;
  final VoidCallback onItemAdded;

  const _BuscadorProductosSheet({
    required this.saldosService,
    required this.pedidoId,
    required this.unidadesGlobales,
    required this.onItemAdded,
  });

  @override
  State<_BuscadorProductosSheet> createState() =>
      _BuscadorProductosSheetState();
}

class _BuscadorProductosSheetState extends State<_BuscadorProductosSheet> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _marcaController = TextEditingController();
  final PedidosService _pedidosService = PedidosService();

  List<dynamic> _resultados = [];
  bool _isLoading = false;
  String? _error;

  List<String> proveedores = [];
  List<String> marcasGlobales = [];
  List<String> clasesDisponibles = [
    'Todas las clases',
    'Mis favoritos',
    'BAZAR',
    'COMISARIATO',
    'FERRETERIA',
  ];

  String? proveedorSeleccionado;
  String claseSeleccionada = 'Todas las clases';

  bool esAdmin = false;
  bool busquedaProfunda = false;

  @override
  void initState() {
    super.initState();
    _cargarFiltros();
  }

  Future<void> _cargarFiltros() async {
    final user = await SessionStorage.getUser();
    final rol = user?.rol.trim().toUpperCase() ?? "";
    if (mounted)
      setState(() => esAdmin = rol == "ADMIN" || rol == "SUPERADMIN");

    try {
      final marcas = await widget.saldosService.obtenerMarcasGlobales();
      if (mounted) setState(() => marcasGlobales = marcas);
    } catch (_) {}

    if (esAdmin) {
      try {
        final provs = await _pedidosService.obtenerProveedores();
        if (mounted) setState(() => proveedores = provs);
      } catch (_) {}
    }
  }

  Future<void> _escanearCodigo() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "La cámara no está soportada en el navegador Web.",
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final codigo = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(builder: (_) => const LectorCodigoScreen()),
    );

    if (codigo != null && codigo is String && codigo.isNotEmpty) {
      _searchController.text = codigo;
      _buscar();
    }
  }

  List<dynamic> get resultadosFiltrados {
    final filtroMarca = _marcaController.text.trim().toLowerCase();
    if (filtroMarca.isEmpty) return _resultados;

    return _resultados.where((item) {
      final m = (item["Marca"] ?? item["marca"] ?? "").toString().toLowerCase();
      return m.contains(filtroMarca);
    }).toList();
  }

  Future<void> _buscar() async {
    final query = _searchController.text.trim();
    if (query.isEmpty &&
        proveedorSeleccionado == null &&
        claseSeleccionada == 'Todas las clases') {
      setState(() {
        _resultados = [];
        _error = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _resultados = [];
    });

    try {
      final prov =
          (esAdmin &&
              proveedorSeleccionado != null &&
              proveedorSeleccionado!.isNotEmpty)
          ? proveedorSeleccionado
          : null;

      final bool esFiltroFavoritos = claseSeleccionada == 'Mis favoritos';
      final clase =
          (claseSeleccionada == 'Todas las clases' || esFiltroFavoritos)
          ? null
          : claseSeleccionada;

      List<dynamic> data = [];
      if (busquedaProfunda) {
        data = await widget.saldosService.buscarEnKardex(query);
      } else {
        data = await widget.saldosService.buscarRapido(
          termino: query,
          proveedor: prov,
          clase: clase,
        );
      }

      final Map<String, dynamic> productosUnicos = {};
      for (var item in data) {
        final codigo =
            item["Codigo"]?.toString() ?? item["codigo"]?.toString() ?? "";
        if (codigo.isNotEmpty && !productosUnicos.containsKey(codigo)) {
          productosUnicos[codigo] = item;
        }
      }

      List<dynamic> listaLimpia = productosUnicos.values.toList();

      if (esFiltroFavoritos && mounted) {
        final favProvider = context.read<FavoritesProvider>();
        listaLimpia = listaLimpia.where((item) {
          final codigo =
              item["Codigo"]?.toString() ?? item["codigo"]?.toString() ?? "";
          return favProvider.isFavorite(codigo);
        }).toList();
      }

      if (mounted) setState(() => _resultados = listaLimpia);
    } catch (e) {
      if (mounted) setState(() => _error = "Error al buscar: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildIABadge(
    String label,
    int valor,
    TextEditingController ctrl,
    bool isProphet,
    VoidCallback onUpdate,
  ) {
    final colorBase = isProphet ? Colors.amber : Colors.purple;

    return InkWell(
      onTap: () {
        ctrl.text = valor.toString();
        onUpdate();
      },
      borderRadius: BorderRadius.circular(8),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: colorBase.shade800,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: colorBase.shade600,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              "$valor",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _verHistorialLocal(String nombreProducto, List<dynamic> historial) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Historial de Costos",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(nombreProducto, style: const TextStyle(color: Colors.grey)),
              const Divider(),
              Expanded(
                child: historial.isEmpty
                    ? const Center(
                        child: Text("No hay historial de compras disponible"),
                      )
                    : ListView.builder(
                        itemCount: historial.length,
                        itemBuilder: (context, index) {
                          final h = historial[index];
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
                            child: ListTile(
                              title: Text(
                                "\$${costoFinal.toStringAsFixed(3)} $etiquetaIva",
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
        );
      },
    );
  }

  Future<void> _agregarPromocionLocal(
    String codigoProd,
    String nombreProd,
  ) async {
    final TextEditingController cantPromoController = TextEditingController(
      text: "1",
    );

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Añadir Bonificación / Promo"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nombreProd,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Se agregará detectado como PROMO (Costo \$0) en el PDF.",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: cantPromoController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Cantidad gratis (Ej: 3)",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.card_giftcard),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancelar"),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Agregar"),
            ),
          ],
        );
      },
    );

    if (confirmar == true) {
      final cantPromo = double.tryParse(cantPromoController.text) ?? 1;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      try {
        await _pedidosService.agregarItemPedido(
          pedidoId: widget.pedidoId,
          codigoProducto: codigoProd,
          cantidad: cantPromo,
          unidad: "UNIDAD/ES",
          notaCompra: "PROMO",
        );
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("✅ Promoción agregada exitosamente")),
          );
          widget.onItemAdded();
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _abrirDialogoInteligente(dynamic prod) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final codigo =
        prod["Codigo"]?.toString() ?? prod["codigo"]?.toString() ?? "";
    final nombre =
        prod["Nombre"]?.toString() ??
        prod["nombre_producto"]?.toString() ??
        "Desconocido";
    final stock =
        double.tryParse(
          (prod["Stock"] ?? prod["stock_actual"] ?? 0).toString(),
        ) ??
        0;
    final minimo =
        double.tryParse(
          (prod["Minimo"] ?? prod["stock_minimo"] ?? 0).toString(),
        ) ??
        0;
    final vdp = double.tryParse((prod["vdp"] ?? 0).toString()) ?? 0.0;

    final int ia7 = (vdp * 7).ceil();
    final int ia15 = (vdp * 15).ceil();
    final int ia30 = (vdp * 30).ceil();
    final bool alertaProphet = prod["alerta_prophet"] == true;
    final String eventoProximo = prod["evento_proximo"]?.toString() ?? "";
    final int diasParaEvento = prod["dias_para_evento"] ?? 0;

    final int prophet7 = prod["prophet_7"] ?? 0;
    final int prophet15 = prod["prophet_15"] ?? 0;
    final int prophet30 = prod["prophet_30"] ?? 0;

    Map<String, dynamic>? costoGlobalData;
    try {
      costoGlobalData = await _pedidosService.obtenerMejorCostoGlobal(
        codigo,
        meses: 3,
      );
    } catch (_) {}

    List<dynamic> historial = [];
    try {
      historial = await _pedidosService.obtenerHistorialCostos(codigo, 5);
    } catch (_) {}

    if (mounted) Navigator.pop(context);

    double ultimoCosto = 0.0;
    if (historial.isNotEmpty) {
      ultimoCosto =
          double.tryParse(historial.first["costo_final"]?.toString() ?? "0") ??
          0.0;
    }

    String txtMejorCosto = "Mejor costo (3m): Sin registro";
    String txtMejorProv = "";
    if (costoGlobalData != null) {
      final cGlobal =
          double.tryParse(costoGlobalData["costo_final"]?.toString() ?? "0") ??
          0.0;
      if (cGlobal > 0) {
        txtMejorCosto = "Mejor costo (3m): \$${cGlobal.toStringAsFixed(4)}";
        txtMejorProv = "Prov: ${costoGlobalData["proveedor"] ?? 'Desconocido'}";
      }
    }

    final TextEditingController cantController = TextEditingController(
      text: "1",
    );
    final TextEditingController costoController = TextEditingController(
      text: ultimoCosto.toStringAsFixed(4),
    );
    final TextEditingController descController = TextEditingController(
      text: "0",
    );
    String unidadSeleccionada = widget.unidadesGlobales.isNotEmpty
        ? widget.unidadesGlobales.first
        : "UNIDAD/ES";
    bool usarProphet = false;

    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              contentPadding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                "Añadir al Pedido",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            nombre,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () => showDialog(
                                context: context,
                                builder: (_) => KardexFlotanteDialog(
                                  codigoProducto: codigo,
                                  nombreProducto: nombre,
                                ),
                              ),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4),
                                child: Icon(
                                  Icons.inventory,
                                  color: Colors.purple,
                                  size: 22,
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () =>
                                  _agregarPromocionLocal(codigo, nombre),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4),
                                child: Icon(
                                  Icons.card_giftcard,
                                  color: Colors.orange,
                                  size: 22,
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () =>
                                  _verHistorialLocal(nombre, historial),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4),
                                child: Icon(
                                  Icons.history,
                                  color: Colors.blue,
                                  size: 22,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Código: $codigo",
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        const Text(
                          "Cant: ",
                          style: TextStyle(color: Colors.grey, fontSize: 11),
                        ),
                        InkWell(
                          onTap: () {
                            double c =
                                double.tryParse(cantController.text) ?? 1;
                            if (c > 1) {
                              setDialogState(
                                () => cantController.text = (c - 1)
                                    .toStringAsFixed(0),
                              );
                            }
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.remove_circle_outline,
                              color: Colors.blueGrey,
                              size: 22,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 40,
                          height: 25,
                          child: TextField(
                            controller: cantController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            double c =
                                double.tryParse(cantController.text) ?? 1;
                            setDialogState(
                              () => cantController.text = (c + 1)
                                  .toStringAsFixed(0),
                            );
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.add_circle_outline,
                              color: Colors.blueGrey,
                              size: 22,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            height: 26,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value:
                                    widget.unidadesGlobales.contains(
                                      unidadSeleccionada,
                                    )
                                    ? unidadSeleccionada
                                    : widget.unidadesGlobales.first,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.blueGrey,
                                  fontWeight: FontWeight.bold,
                                ),
                                iconSize: 16,
                                items: widget.unidadesGlobales
                                    .map(
                                      (u) => DropdownMenuItem(
                                        value: u,
                                        child: Text(
                                          u,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null)
                                    setDialogState(
                                      () => unidadSeleccionada = val,
                                    );
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Text(
                          "Desc(%): ",
                          style: TextStyle(color: Colors.grey, fontSize: 11),
                        ),
                        SizedBox(
                          width: 45,
                          height: 25,
                          child: TextField(
                            controller: descController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12),
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          "Costo (\$): ",
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(
                          width: 60,
                          height: 25,
                          child: TextField(
                            controller: costoController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Text(
                      "Stock: $stock (Mín: $minimo)",
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: usarProphet
                            ? Colors.amber.shade50
                            : Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: usarProphet
                              ? Colors.amber.shade400
                              : Colors.purple.shade200,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(
                                      usarProphet
                                          ? Icons.insights
                                          : Icons.auto_awesome,
                                      color: usarProphet
                                          ? Colors.amber.shade800
                                          : Colors.purple,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        usarProphet
                                            ? "🔮 Prophet (Feriados):"
                                            : "✨ Sugerencia Inteligente:",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: usarProphet
                                              ? Colors.amber.shade900
                                              : Colors.purple.shade800,
                                          fontSize: 11,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (alertaProphet)
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: usarProphet
                                        ? Colors.grey
                                        : Colors.amber.shade600,
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    minimumSize: const Size(0, 26),
                                  ),
                                  icon: Icon(
                                    usarProphet
                                        ? Icons.close
                                        : Icons.warning_amber_rounded,
                                    size: 12,
                                  ),
                                  label: Text(
                                    usarProphet
                                        ? "Apagar"
                                        : "$eventoProximo en ${diasParaEvento}d",
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onPressed: () => setDialogState(
                                    () => usarProphet = !usarProphet,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildIABadge(
                                "7 Días",
                                usarProphet ? prophet7 : ia7,
                                cantController,
                                usarProphet,
                                () => setDialogState(() {}),
                              ),
                              _buildIABadge(
                                "15 Días",
                                usarProphet ? prophet15 : ia15,
                                cantController,
                                usarProphet,
                                () => setDialogState(() {}),
                              ),
                              _buildIABadge(
                                "1 Mes",
                                usarProphet ? prophet30 : ia30,
                                cantController,
                                usarProphet,
                                () => setDialogState(() {}),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    Text(
                      txtMejorCosto,
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    if (txtMejorProv.isNotEmpty)
                      Text(
                        txtMejorProv,
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text(
                    "Cancelar",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text("Agregar"),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmar == true) {
      final cantidad = double.tryParse(cantController.text) ?? 1;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      try {
        await _pedidosService.agregarItemPedido(
          pedidoId: widget.pedidoId,
          codigoProducto: codigo,
          cantidad: cantidad,
          unidad: unidadSeleccionada,
          tipoDestino: "VENTA",
        );

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "✅ Producto agregado: $cantidad $unidadSeleccionada",
              ),
            ),
          );
          widget.onItemAdded();
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error al agregar producto: $e"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lista = resultadosFiltrados;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Agregar Producto al Pedido",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: "Buscar por nombre o código...",
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _buscar();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onSubmitted: (_) => _buscar(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                tooltip: "Escanear Código",
                onPressed: _escanearCodigo,
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _buscar,
                child: const Text(
                  "Buscar",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                DropdownButton<String>(
                  value: claseSeleccionada,
                  items: clasesDisponibles
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => claseSeleccionada = val);
                      _buscar();
                    }
                  },
                ),
                const SizedBox(width: 12),
                if (esAdmin && proveedores.isNotEmpty) ...[
                  DropdownButton<String?>(
                    hint: const Text("Proveedor"),
                    value: proveedorSeleccionado,
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text("Todos los proveedores"),
                      ),
                      ...proveedores.map(
                        (p) => DropdownMenuItem<String?>(
                          value: p,
                          child: Text(p, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() => proveedorSeleccionado = val);
                      _buscar();
                    },
                  ),
                  const SizedBox(width: 12),
                ],
                Row(
                  children: [
                    const Text("Profunda:", style: TextStyle(fontSize: 12)),
                    Switch(
                      value: busquedaProfunda,
                      onChanged: (val) {
                        setState(() => busquedaProfunda = val);
                        _buscar();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  )
                : lista.isEmpty
                ? const Center(
                    child: Text(
                      "No se encontraron productos.\nIngresa un término de búsqueda.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: lista.length,
                    itemBuilder: (context, index) {
                      final prod = lista[index];
                      final codigo =
                          prod["Codigo"]?.toString() ??
                          prod["codigo"]?.toString() ??
                          "";
                      final nombre =
                          prod["Nombre"]?.toString() ??
                          prod["nombre_producto"]?.toString() ??
                          "Sin nombre";
                      final stock = prod["Stock"] ?? prod["stock_actual"] ?? 0;
                      final pvp = prod["PVP"] ?? prod["pvp"] ?? 0.0;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text(
                            nombre,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            "Código: $codigo | Stock: $stock | PVP: \$$pvp",
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: const Icon(
                            Icons.add_shopping_cart,
                            color: Colors.indigo,
                          ),
                          onTap: () => _abrirDialogoInteligente(prod),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
