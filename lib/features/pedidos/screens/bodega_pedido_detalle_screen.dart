import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../services/pedidos_service.dart';
import 'recepcion_escaner_screen.dart'; // Asegúrate de tener este import

class BodegaPedidoDetalleScreen extends StatefulWidget {
  final int pedidoId;
  final String proveedorFiltro;

  const BodegaPedidoDetalleScreen({
    super.key,
    required this.pedidoId,
    required this.proveedorFiltro,
  });

  @override
  State<BodegaPedidoDetalleScreen> createState() =>
      _BodegaPedidoDetalleScreenState();
}

class _BodegaPedidoDetalleScreenState extends State<BodegaPedidoDetalleScreen> {
  final PedidosService service = PedidosService();

  bool isLoading = true;
  String? errorMessage;
  Map<String, dynamic>? detallePedido;

  WebSocketChannel? _channel;
  bool _isRpaDialogVisible = false;

  @override
  void initState() {
    super.initState();
    cargarDetalle();
    _conectarWebSocketRPA();
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }

  void _conectarWebSocketRPA() {
    // 🔥 Asegúrate de poner tu IP correcta aquí 🔥
    final wsUrl = Uri.parse(
      'ws://192.168.1.231:5000/pedidos/rpa/ws/${widget.pedidoId}',
    );

    try {
      _channel = WebSocketChannel.connect(wsUrl);

      _channel?.stream.listen(
        (message) {
          _cerrarCargaRPA();

          final data = jsonDecode(message);
          final estado = data['estado'];
          final mensaje = data['mensaje'] ?? 'Alerta del bot RPA';

          if (estado == 'REPORTE_VALIDACION') {
            // 1. Mostrar diálogo de historias
            List<dynamic> validaciones = data['validaciones'] ?? [];
            bool conErrores = data['con_errores'] ?? false;
            int docId = data['documento_id'] ?? 0;

            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => ValidacionXMLDialog(
                pedidoId: widget.pedidoId,
                documentoId: docId,
                validaciones: validaciones,
                conErrores: conErrores,
                onContinuar: () {
                  // Si todo está bien (verde), abrimos el escáner en modo RPA
                  _abrirFaseEscaner(docId, modoRpa: true);
                },
                onForzar: () async {
                  try {
                    // Si Forzó (rojo), llamamos al API de forzar y abrimos el escáner
                    await service.forzarExitoRPA(docId);
                    if (mounted) {
                      _abrirFaseEscaner(docId, modoRpa: true);
                    }
                  } catch (e) {
                    debugPrint("Error forzando: $e");
                  }
                },
              ),
            );
          } else if (estado == 'EXITO') {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(mensaje), backgroundColor: Colors.green),
            );
            cargarDetalle();
          } else {
            _mostrarAlertaRPA(estado, mensaje);
          }
        },
        onError: (error) {
          _cerrarCargaRPA();
          debugPrint("Error en WebSocket RPA: $error");
        },
        onDone: () {
          debugPrint("WebSocket RPA cerrado");
        },
      );
    } catch (e) {
      debugPrint("No se pudo iniciar WebSocket RPA: $e");
    }
  }

  void _mostrarCargaRPA() {
    _isRpaDialogVisible = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Expanded(
                child: Text(
                  "Conectando con el Robot RPA...\nValidando XML en el sistema BITS.",
                ),
              ),
            ],
          ),
        );
      },
    ).then((_) {
      _isRpaDialogVisible = false;
    });
  }

  void _cerrarCargaRPA() {
    if (_isRpaDialogVisible) {
      Navigator.of(context, rootNavigator: true).pop();
      _isRpaDialogVisible = false;
    }
  }

  void _mostrarAlertaRPA(String estado, String mensaje) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange),
              const SizedBox(width: 8),
              Text(estado == 'DUPLICADO' ? "XML Existente" : "Atención RPA"),
            ],
          ),
          content: Text(mensaje),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  // Llamada al servicio para anular (Debes implementarla en PedidosService)
                  await service.actualizarEstadoRPA(
                    0,
                    "ANULAR",
                    "Cancelado por usuario",
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Orden de anulación enviada"),
                      ),
                    );
                  }
                } catch (e) {}
              },
              child: const Text("Anular", style: TextStyle(color: Colors.red)),
            ),
            if (estado == 'DUPLICADO')
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  _mostrarCargaRPA();
                  try {
                    await service.actualizarEstadoRPA(
                      0,
                      "SOBRESCRIBIR",
                      "Sobrescribir XML",
                    );
                  } catch (e) {}
                },
                child: const Text("Sobrescribir"),
              ),
          ],
        );
      },
    );
  }

  // 🔥 NUEVO: Función que centraliza la apertura del escáner.
  // Identifica si va en modo RPA (completo) o Modo Verificación Interna.
  void _abrirFaseEscaner(int documentoId, {required bool modoRpa}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecepcionEscanerScreen(
          pedidoId: widget.pedidoId,
          documentoId: documentoId,
          usarIntegracionRpa: modoRpa, // Parametrizado
        ),
      ),
    ).then((_) => cargarDetalle()); // Recargar lista al volver
  }

  // 🔥 NUEVO: Botón inferior que pregunta qué camino tomar
  void _mostrarOpcionesDeRecepcion() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Selecciona el flujo de recepción",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Icon(Icons.smart_toy, color: Colors.white),
                ),
                title: const Text("Ingreso de factura (beta)"),
                subtitle: const Text(
                  "Valida, escanea y carga a BITS usando el robot.",
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pedirClaveAccesoSRI(); // Camino 1: Vía RPA
                },
              ),
              const Divider(),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.orange,
                  child: Icon(Icons.checklist, color: Colors.white),
                ),
                title: const Text("Verificación - Orden de pedido"),
                subtitle: const Text(
                  "Solo escaneo físico (No afecta al sistema BITS).",
                ),
                onTap: () {
                  Navigator.pop(context);
                  // Camino 2: Directo al escáner, sin RPA.
                  // Usamos documento_id = 0 porque no hay documento.
                  _abrirFaseEscaner(0, modoRpa: false);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Camino 1: Dialogo para capturar la clave de 49 dígitos
  void _pedirClaveAccesoSRI() {
    final TextEditingController claveController = TextEditingController();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Cargar Factura (SRI)"),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: claveController,
              keyboardType: TextInputType.number,
              maxLength: 49,
              decoration: const InputDecoration(
                labelText: "Clave de Acceso",
                border: OutlineInputBorder(),
              ),
              validator: (val) {
                if (val == null || val.isEmpty) return "Ingrese la clave";
                if (val.length != 49) return "Debe tener 49 dígitos";
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                "Cancelar",
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(dialogContext); // Cierra diálogo
                  _mostrarCargaRPA(); // Abre loading
                  try {
                    // Llamar al endpoint que mete la tarea a la BD para el RPA
                    await service.enviarClaveSRI(
                      pedidoId: widget.pedidoId,
                      proveedor: widget.proveedorFiltro,
                      claveAcceso: claveController.text.trim(),
                    );
                  } catch (e) {
                    _cerrarCargaRPA();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Error: $e"),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text("Procesar con RPA"),
            ),
          ],
        );
      },
    );
  }

  Future<void> cargarDetalle() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final data = await service.obtenerDetallePedidoBodega(widget.pedidoId);
      if (!mounted) return;
      setState(() {
        detallePedido = data;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = "No se pudo cargar el detalle del pedido";
      });
    } finally {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> actualizarRecepcion(
    int itemId,
    bool recibido,
    String? comentario,
  ) async {
    try {
      await service.actualizarRecepcionItemPedido(
        pedidoId: widget.pedidoId,
        itemId: itemId,
        recibido: recibido,
        comentarioRecepcion: comentario,
      );
      await cargarDetalle();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error al actualizar la recepción")),
      );
    }
  }

  void mostrarDialogoComentario(
    int itemId,
    bool recibidoActual,
    String? comentarioActual,
  ) {
    final TextEditingController controller = TextEditingController(
      text: comentarioActual ?? "",
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Comentario / Observación"),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: "Escribe alguna novedad (opcional)...",
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                actualizarRecepcion(
                  itemId,
                  recibidoActual,
                  controller.text.trim(),
                );
              },
              child: const Text("Guardar"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final usuario = detallePedido?["usuario"] ?? "";
    final estado = detallePedido?["estado"] ?? "";
    final observacionGeneral = detallePedido?["observacion"] ?? "";

    final todosLosProveedores =
        detallePedido?["proveedores"] as List<dynamic>? ?? [];
    final proveedoresFiltrados = todosLosProveedores.where((grupo) {
      final provNombre =
          grupo["proveedor"]?.toString().trim().toUpperCase() ?? "";
      return provNombre == widget.proveedorFiltro.trim().toUpperCase();
    }).toList();

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, true);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text("Recepción Pedido #${widget.pedidoId}"),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, true),
          ),
        ),

        // 🔥 AQUÍ INVOCAMOS EL MENÚ DE OPCIONES
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _mostrarOpcionesDeRecepcion,
          icon: const Icon(Icons.barcode_reader),
          label: const Text("Comenzar Recepción"),
          backgroundColor: Colors.blueGrey.shade800,
          foregroundColor: Colors.white,
        ),

        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
            ? Center(
                child: Text(
                  errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Usuario: $usuario",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text("Estado: $estado"),
                            if (observacionGeneral.isNotEmpty)
                              Text(
                                "Obs: $observacionGeneral",
                                style: const TextStyle(color: Colors.grey),
                              ),
                            const Divider(),
                            Text(
                              "Proveedor en revisión: ${widget.proveedorFiltro}",
                              style: const TextStyle(
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: proveedoresFiltrados.isEmpty
                          ? const Center(
                              child: Text(
                                "No hay productos asignados para este proveedor.",
                              ),
                            )
                          : ListView.builder(
                              itemCount: proveedoresFiltrados.length,
                              itemBuilder: (context, pIndex) {
                                final grupo = proveedoresFiltrados[pIndex];
                                final items =
                                    grupo["items"] as List<dynamic>? ?? [];

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ...items.map((item) {
                                      final itemId =
                                          int.tryParse(item["id"].toString()) ??
                                          0;
                                      final nombre =
                                          item["nombre_producto"] ?? "";
                                      final codigo =
                                          item["codigo_producto"] ?? "";
                                      final cantidad =
                                          item["cantidad_pedida"] ?? 0;
                                      final unidad = item["unidad"] ?? "U";
                                      final tipoDestino =
                                          item["tipo_destino"] ?? "VENTA";
                                      final recibido = item["recibido"] == true;
                                      final comentario =
                                          item["comentario_recepcion"];

                                      return Card(
                                        margin: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        child: ListTile(
                                          leading: Checkbox(
                                            value: recibido,
                                            onChanged: (val) {
                                              actualizarRecepcion(
                                                itemId,
                                                val ?? false,
                                                comentario,
                                              );
                                            },
                                          ),
                                          title: Text(
                                            nombre,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              decoration: recibido
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                            ),
                                          ),
                                          subtitle: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "Código: $codigo | Cantidad: $cantidad $unidad",
                                              ),
                                              Row(
                                                children: [
                                                  Chip(
                                                    label: Text(tipoDestino),
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                    backgroundColor:
                                                        Colors.blue.shade50,
                                                  ),
                                                ],
                                              ),
                                              if (comentario != null &&
                                                  comentario
                                                      .toString()
                                                      .isNotEmpty)
                                                Text(
                                                  "Obs: $comentario",
                                                  style: const TextStyle(
                                                    color: Colors.orange,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                            ],
                                          ),
                                          trailing: IconButton(
                                            icon: Icon(
                                              Icons.comment,
                                              color:
                                                  (comentario != null &&
                                                      comentario
                                                          .toString()
                                                          .isNotEmpty)
                                                  ? Colors.orange
                                                  : Colors.grey,
                                            ),
                                            tooltip: "Agregar observación",
                                            onPressed: () =>
                                                mostrarDialogoComentario(
                                                  itemId,
                                                  recibido,
                                                  comentario,
                                                ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

// 🔥 WIDGET DE VALIDACIÓN (HISTORIAS) SE MUEVE AQUÍ DESDE bodega_pedidos_screen.dart
class ValidacionXMLDialog extends StatefulWidget {
  final int pedidoId;
  final int documentoId;
  final List<dynamic> validaciones;
  final bool conErrores;
  final VoidCallback onContinuar;
  final VoidCallback onForzar;

  const ValidacionXMLDialog({
    super.key,
    required this.pedidoId,
    required this.documentoId,
    required this.validaciones,
    required this.conErrores,
    required this.onContinuar,
    required this.onForzar,
  });

  @override
  State<ValidacionXMLDialog> createState() => _ValidacionXMLDialogState();
}

class _ValidacionXMLDialogState extends State<ValidacionXMLDialog> {
  int pasoActual = 0;
  // (La lógica del timer es la misma que ya tenías)
  // Aquí puedes pegar el contenido de _ValidacionXMLDialogState original
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Validación RPA Finalizada"),
      content: const Text("Las historias de validación se muestran aquí"),
      actions: [
        TextButton(
          onPressed: widget.onContinuar,
          child: const Text("Continuar"),
        ),
      ],
    );
  }
}
