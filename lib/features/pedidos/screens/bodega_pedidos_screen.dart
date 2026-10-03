import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;
import 'recepcion_escaner_screen.dart';

import '../services/pedidos_service.dart';
import '../../saldos/presentation/screens/barcode_scanner_screen.dart';

class BodegaPedidosScreen extends StatefulWidget {
  const BodegaPedidosScreen({super.key});

  @override
  State<BodegaPedidosScreen> createState() => _BodegaPedidosScreenState();
}

class _BodegaPedidosScreenState extends State<BodegaPedidosScreen> {
  final PedidosService service = PedidosService();

  bool isLoading = true;
  String? errorMessage;
  List<dynamic> pedidos = [];
  String filtroSeleccionado = "TODOS";
  final TextEditingController busquedaController = TextEditingController();

  DateTime? fechaDesde;
  DateTime? fechaHasta;

  final List<String> filtrosRecepcion = [
    "TODOS",
    "PENDIENTES",
    "INCOMPLETOS",
    "COMPLETOS",
  ];

  WebSocketChannel? _channel;

  @override
  void initState() {
    super.initState();
    cargarPedidos();
  }

  @override
  void dispose() {
    busquedaController.dispose();
    _channel?.sink.close();
    super.dispose();
  }

  void _conectarWebSocketRPA({
    required int pedidoId,
    required Function(String estado, String mensaje, dynamic data) onMessage,
  }) {
    final wsUrl = Uri.parse(
      'ws://192.168.1.231:5000/api/pedidos/rpa/ws/$pedidoId',
    );

    try {
      _channel?.sink.close();
      _channel = WebSocketChannel.connect(wsUrl);

      _channel?.stream.listen(
        (message) {
          final data = jsonDecode(message);
          final estado = data['estado'] ?? 'DESCONOCIDO';
          final mensaje = data['mensaje'] ?? 'Alerta del bot RPA';

          onMessage(estado, mensaje, data);
        },
        onError: (error) {
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

  void _mostrarAlertaDuplicado(int pedidoId, int documentoId, String mensaje) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (alertContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text("XML Existente"),
            ],
          ),
          content: Text(mensaje),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(alertContext);
                try {
                  final url = Uri.parse(
                    "http://192.168.1.231:5000/api/pedidos/rpa/notificar-estado/$documentoId",
                  );
                  await http.patch(
                    url,
                    body: jsonEncode({
                      "estado": "ANULAR",
                      "mensaje": "Cancelado por el usuario",
                    }),
                    headers: {"Content-Type": "application/json"},
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Orden de anulación enviada"),
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint("Error al anular: $e");
                }
              },
              child: const Text("Anular", style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(alertContext);
                try {
                  final url = Uri.parse(
                    "http://192.168.1.231:5000/api/pedidos/rpa/notificar-estado/$documentoId",
                  );
                  await http.patch(
                    url,
                    body: jsonEncode({
                      "estado": "SOBRESCRIBIR",
                      "mensaje": "Usuario ordenó sobrescribir",
                    }),
                    headers: {"Content-Type": "application/json"},
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Orden de sobrescribir enviada"),
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint("Error al sobrescribir: $e");
                }
              },
              child: const Text("Sobrescribir"),
            ),
          ],
        );
      },
    );
  }

  // 🔥 FASE ESCÁNER ACTUALIZADA: Ahora recibe el modoRpa elegido por el usuario
  void _abrirFaseEscaner(
    int pedidoId,
    int documentoId, {
    required bool modoRpa,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecepcionEscanerScreen(
          pedidoId: pedidoId,
          documentoId: documentoId,
          usarIntegracionRpa:
              modoRpa, // Pasamos la decisión a la siguiente pantalla
        ),
      ),
    ).then((_) => cargarPedidos());
  }

  Future<void> cargarPedidos() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final data = await service.listarPedidosBodega();
      if (!mounted) return;
      setState(() {
        pedidos = data;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = "No se pudieron cargar los pedidos de bodega";
      });
    } finally {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  String formatearFecha(dynamic fecha) {
    if (fecha == null) return "";
    return fecha.toString().replaceAll("T", " ").split(".").first;
  }

  DateTime? parseFecha(dynamic fecha) {
    if (fecha == null) return null;
    try {
      return DateTime.parse(fecha.toString());
    } catch (_) {
      return null;
    }
  }

  Future<void> seleccionarRangoFechas() async {
    final ahora = DateTime.now();
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(ahora.year - 3),
      lastDate: DateTime(ahora.year + 1),
      initialDateRange: fechaDesde != null && fechaHasta != null
          ? DateTimeRange(start: fechaDesde!, end: fechaHasta!)
          : null,
    );

    if (rango == null) return;

    setState(() {
      fechaDesde = rango.start;
      fechaHasta = rango.end;
    });
  }

  void limpiarFiltrosAvanzados() {
    setState(() {
      busquedaController.clear();
      fechaDesde = null;
      fechaHasta = null;
    });
  }

  double calcularProgreso(dynamic pedido) {
    final total = int.tryParse((pedido["total_items"] ?? 0).toString()) ?? 0;
    final recibidos =
        int.tryParse((pedido["total_recibidos"] ?? 0).toString()) ?? 0;
    if (total <= 0) return 0;
    return recibidos / total;
  }

  String obtenerEstadoVisual(dynamic pedido) {
    final total = int.tryParse((pedido["total_items"] ?? 0).toString()) ?? 0;
    final recibidos =
        int.tryParse((pedido["total_recibidos"] ?? 0).toString()) ?? 0;
    final observaciones =
        int.tryParse((pedido["total_observaciones"] ?? 0).toString()) ?? 0;

    if (total > 0 && recibidos == total) {
      return "COMPLETO";
    }
    if (recibidos > 0 || observaciones > 0) {
      return "INCOMPLETO";
    }
    return "PENDIENTE";
  }

  List<dynamic> get pedidosFiltrados {
    return pedidos.where((pedido) {
      final estado = obtenerEstadoVisual(pedido);

      if (filtroSeleccionado == "PENDIENTES" && estado != "PENDIENTE") {
        return false;
      }
      if (filtroSeleccionado == "INCOMPLETOS" && estado != "INCOMPLETO") {
        return false;
      }
      if (filtroSeleccionado == "COMPLETOS" && estado != "COMPLETO") {
        return false;
      }

      final busqueda = busquedaController.text.trim().toLowerCase();

      if (busqueda.isNotEmpty) {
        final id = pedido["id"]?.toString().toLowerCase() ?? "";
        final codigo = pedido["codigo_pedido"]?.toString().toLowerCase() ?? "";
        final usuario = pedido["usuario"]?.toString().toLowerCase() ?? "";

        final proveedor =
            pedido["proveedor"]?.toString().toLowerCase() ??
            pedido["proveedores"]?.toString().toLowerCase() ??
            "";

        final coincide =
            id.contains(busqueda) ||
            codigo.contains(busqueda) ||
            usuario.contains(busqueda) ||
            proveedor.contains(busqueda);

        if (!coincide) return false;
      }

      final fechaPedido = parseFecha(pedido["fecha_creacion"]);

      if (fechaDesde != null) {
        if (fechaPedido == null) return false;
        final desde = DateTime(
          fechaDesde!.year,
          fechaDesde!.month,
          fechaDesde!.day,
        );
        if (fechaPedido.isBefore(desde)) return false;
      }

      if (fechaHasta != null) {
        if (fechaPedido == null) return false;
        final hasta = DateTime(
          fechaHasta!.year,
          fechaHasta!.month,
          fechaHasta!.day,
          23,
          59,
          59,
        );
        if (fechaPedido.isAfter(hasta)) return false;
      }

      return true;
    }).toList();
  }

  // 🔥 NUEVO: Manejo del estado "Con Novedad" debajo de "Recibido"
  Widget buildEstadoRecepcion(dynamic pedido) {
    final estadoDB = pedido["estado"]?.toString().toUpperCase() ?? "";
    final estadoVisual = obtenerEstadoVisual(pedido);
    final observaciones =
        int.tryParse((pedido["total_observaciones"] ?? 0).toString()) ?? 0;

    if (estadoDB == "RECIBIDO" || estadoVisual == "COMPLETO") {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Chip(
            label: const Text(
              "Recibido",
              style: TextStyle(
                color: Colors.purple,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: Colors.purple.shade50,
            side: const BorderSide(color: Colors.purple),
            visualDensity: VisualDensity.compact,
          ),
          // Si hubo observaciones (novedades), mostramos la alerta visual
          if (observaciones > 0)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.red.shade400),
              ),
              child: Text(
                "Con Novedad",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade800,
                ),
              ),
            ),
        ],
      );
    } else if (estadoVisual == "INCOMPLETO") {
      return Chip(
        label: const Text(
          "Incompleto",
          style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.purple.shade50,
        side: const BorderSide(color: Colors.purple),
      );
    }

    return Chip(
      label: Text(
        "Pendiente",
        style: TextStyle(
          color: Colors.orange.shade900,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: Colors.orange.shade100,
      side: BorderSide(color: Colors.orange.shade700),
    );
  }

  Future<void> _mostrarReporteRecepcion(int pedidoId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final url = Uri.parse(
        "http://192.168.1.231:5000/api/pedidos/$pedidoId/novedades-recepcion-texto",
      );
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (!mounted) return;
      Navigator.pop(context);

      if (response.statusCode == 200) {
        final res = jsonDecode(utf8.decode(response.bodyBytes));
        final data = res['data'];
        final textoReporte = data['texto'] ?? "Sin reporte generado";

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(
                  Icons.assignment_turned_in,
                  color: Colors.purple,
                  size: 28,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Reporte de Ingreso",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Text(
                textoReporte,
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
            ),
            actions: [
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.purple.shade700,
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Entendido"),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No se pudo obtener el reporte.")),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error de conexión: $e")));
    }
  }

  Future<void> abrirDetalle(dynamic pedido) async {
    final pedidoId = int.tryParse(pedido["id"].toString());
    final proveedorSeleccionado =
        pedido["proveedor"]?.toString() ?? "SIN PROVEEDOR";
    final estadoDB = pedido["estado"]?.toString().toUpperCase() ?? "";
    final estadoVisual = obtenerEstadoVisual(pedido);

    if (pedidoId == null) return;

    if (estadoDB == "RECIBIDO" ||
        estadoVisual == "COMPLETO" ||
        estadoVisual == "INCOMPLETO") {
      await _mostrarReporteRecepcion(pedidoId);
    } else {
      mostrarDialogoRPA(pedidoId, proveedorSeleccionado);
    }
  }

  void mostrarDialogoRPA(int pedidoId, String proveedor) {
    final TextEditingController claveController = TextEditingController();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      "Cargar Factura (SRI)",
                      style: TextStyle(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!isSubmitting)
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(dialogContext),
                    ),
                ],
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Pedido #$pedidoId - $proveedor",
                      style: const TextStyle(
                        color: Colors.blueGrey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (isSubmitting)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20.0),
                        child: Center(
                          child: Column(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text(
                                "Procesando en ERP BITS...",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                "Por favor, no cierres la aplicación.",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      TextFormField(
                        controller: claveController,
                        keyboardType: TextInputType.number,
                        maxLength: 49,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          labelText: "Clave de Acceso (49 dígitos)",
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(
                              Icons.qr_code_scanner,
                              color: Colors.blue,
                            ),
                            onPressed: () async {
                              final String? codigoEscaneado =
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const BarcodeScannerScreen(),
                                    ),
                                  );

                              if (codigoEscaneado != null &&
                                  codigoEscaneado.isNotEmpty) {
                                final soloNumeros = codigoEscaneado.replaceAll(
                                  RegExp(r'[^0-9]'),
                                  '',
                                );
                                claveController.text = soloNumeros;
                                formKey.currentState?.validate();
                              }
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Por favor ingresa la clave.";
                          }
                          if (value.length != 49) {
                            return "Debe tener exactamente 49 dígitos.";
                          }
                          if (double.tryParse(value) == null) {
                            return "Solo se permiten números.";
                          }
                          return null;
                        },
                      ),
                  ],
                ),
              ),
              actions: [
                if (!isSubmitting)
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text(
                      "Cancelar",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                if (!isSubmitting)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    onPressed: () async {
                      if (formKey.currentState!.validate()) {
                        FocusScope.of(context).unfocus();

                        setDialogState(() {
                          isSubmitting = true;
                        });

                        _conectarWebSocketRPA(
                          pedidoId: pedidoId,
                          onMessage: (estado, mensaje, data) {
                            if (estado == 'PROCESANDO' ||
                                estado == 'SOBRESCRIBIR' ||
                                estado == 'ANULAR') {
                              return;
                            }

                            if (estado == 'EXITO') {
                              if (Navigator.canPop(dialogContext)) {
                                Navigator.pop(dialogContext);
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(mensaje),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              cargarPedidos();
                            } else if (estado == 'DUPLICADO') {
                              int docId = data['documento_id'] ?? 0;
                              _mostrarAlertaDuplicado(pedidoId, docId, mensaje);
                            } else if (estado == 'REPORTE_VALIDACION') {
                              if (Navigator.canPop(dialogContext)) {
                                Navigator.pop(dialogContext);
                              }

                              List<dynamic> validaciones =
                                  data['validaciones'] ?? [];
                              bool conErrores = data['con_errores'] ?? false;
                              int docId = data['documento_id'] ?? 0;

                              // 🔥 LLAMAMOS AL DIÁLOGO QUE AHORA TIENE LAS 2 OPCIONES
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (_) => ValidacionXMLDialog(
                                  pedidoId: pedidoId,
                                  documentoId: docId,
                                  validaciones: validaciones,
                                  conErrores: conErrores,
                                  onContinuar: (bool usarRpa) {
                                    _abrirFaseEscaner(
                                      pedidoId,
                                      docId,
                                      modoRpa: usarRpa,
                                    );
                                  },
                                  onForzar: (bool usarRpa) async {
                                    try {
                                      final url = Uri.parse(
                                        "http://192.168.1.231:5000/api/pedidos/rpa/forzar-exito/$docId",
                                      );
                                      await http.patch(url);
                                      if (mounted) {
                                        _abrirFaseEscaner(
                                          pedidoId,
                                          docId,
                                          modoRpa: usarRpa,
                                        );
                                      }
                                    } catch (e) {
                                      debugPrint("Error forzando: $e");
                                    }
                                  },
                                ),
                              );
                            } else {
                              setDialogState(() {
                                isSubmitting = false;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(mensaje),
                                  backgroundColor: Colors.red,
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                            }
                          },
                        );

                        final exito = await service.enviarClaveSRI(
                          pedidoId: pedidoId,
                          proveedor: proveedor,
                          claveAcceso: claveController.text.trim(),
                        );

                        if (!context.mounted) return;

                        if (exito) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Enviado al bot RPA. Esperando confirmación de BITS...",
                              ),
                              backgroundColor: Colors.blue,
                              duration: Duration(seconds: 3),
                            ),
                          );
                        } else {
                          setDialogState(() {
                            isSubmitting = false;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Error de red: No se pudo contactar al servidor",
                              ),
                              backgroundColor: Colors.red,
                              duration: Duration(seconds: 4),
                            ),
                          );
                        }
                      }
                    },
                    child: const Text(
                      "Continuar",
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget buildFiltros() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Row(
        children: filtrosRecepcion.map((filtro) {
          final seleccionado = filtroSeleccionado == filtro;

          String texto = filtro;

          if (filtro == "TODOS") texto = "Todos";
          if (filtro == "PENDIENTES") texto = "Pendientes";
          if (filtro == "INCOMPLETOS") texto = "Incompletos";
          if (filtro == "COMPLETOS") texto = "Completos";

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(texto),
              selected: seleccionado,
              onSelected: (_) {
                setState(() {
                  filtroSeleccionado = filtro;
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget buildFiltrosAvanzados() {
    final textoRango = fechaDesde == null || fechaHasta == null
        ? "Filtrar por fecha"
        : "${fechaDesde!.year}-${fechaDesde!.month.toString().padLeft(2, '0')}-${fechaDesde!.day.toString().padLeft(2, '0')} "
              "a ${fechaHasta!.year}-${fechaHasta!.month.toString().padLeft(2, '0')}-${fechaHasta!.day.toString().padLeft(2, '0')}";

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        children: [
          TextField(
            controller: busquedaController,
            decoration: const InputDecoration(
              hintText: "Buscar por usuario, N° pedido o proveedor",
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (_) {
              setState(() {});
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: seleccionarRangoFechas,
                  icon: const Icon(Icons.date_range),
                  label: Text(textoRango, overflow: TextOverflow.ellipsis),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: "Limpiar filtros",
                onPressed: limpiarFiltrosAvanzados,
                icon: const Icon(Icons.clear),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Recepción de pedidos"),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: cargarPedidos),
        ],
      ),
      body: Column(
        children: [
          buildFiltros(),
          buildFiltrosAvanzados(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: cargarPedidos,
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : errorMessage != null
                  ? ListView(
                      children: [
                        const SizedBox(height: 80),
                        Center(
                          child: Text(
                            errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    )
                  : pedidosFiltrados.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 100),
                        Center(
                          child: Text(
                            "No hay pedidos para el filtro seleccionado",
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: pedidosFiltrados.length,
                      itemBuilder: (context, index) {
                        final pedido = pedidosFiltrados[index];
                        final estadoVisual = obtenerEstadoVisual(pedido);
                        final estadoDB =
                            pedido["estado"]?.toString().toUpperCase() ?? "";
                        final bool isProcesado =
                            estadoDB == "RECIBIDO" ||
                            estadoVisual == "COMPLETO" ||
                            estadoVisual == "INCOMPLETO";

                        final total =
                            int.tryParse(
                              (pedido["total_items"] ?? 0).toString(),
                            ) ??
                            0;

                        final recibidos =
                            int.tryParse(
                              (pedido["total_recibidos"] ?? 0).toString(),
                            ) ??
                            0;

                        final observaciones =
                            int.tryParse(
                              (pedido["total_observaciones"] ?? 0).toString(),
                            ) ??
                            0;

                        final proveedor =
                            pedido["proveedor"] ??
                            pedido["proveedores"] ??
                            'Sin proveedor asignado';

                        return Card(
                          color: isProcesado
                              ? Colors.purple.shade50
                              : Colors.white,
                          margin: const EdgeInsets.only(bottom: 10),
                          child: InkWell(
                            onTap: () => abrirDetalle(pedido),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: isProcesado
                                            ? Colors.purple.shade100
                                            : null,
                                        foregroundColor: isProcesado
                                            ? Colors.purple.shade900
                                            : null,
                                        child: Text(
                                          pedido["id"]?.toString() ?? "-",
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "Orden de pedido #${pedido["id"]}",
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: isProcesado
                                                    ? Colors.purple.shade900
                                                    : Colors.black,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              "Usuario: ${pedido["usuario"] ?? ""}",
                                            ),
                                            Text(
                                              "Fecha: ${formatearFecha(pedido["fecha_creacion"])}",
                                            ),
                                            Text(
                                              "Estado: ${pedido["estado"] ?? ""}",
                                            ),
                                            Text(
                                              "Proveedor: $proveedor",
                                              style: const TextStyle(
                                                fontStyle: FontStyle.italic,
                                                color: Colors.blueGrey,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      buildEstadoRecepcion(pedido),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  LinearProgressIndicator(
                                    value: calcularProgreso(pedido),
                                    minHeight: 7,
                                    backgroundColor: isProcesado
                                        ? Colors.purple.shade100
                                        : null,
                                    valueColor: isProcesado
                                        ? const AlwaysStoppedAnimation<Color>(
                                            Colors.purple,
                                          )
                                        : null,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Recibidos: $recibidos/$total",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 🔥 WIDGET: VALIDACIÓN CON SELECCIÓN DE FLUJO
// ==========================================
class ValidacionXMLDialog extends StatefulWidget {
  final int pedidoId;
  final int documentoId;
  final List<dynamic> validaciones;
  final bool conErrores;
  final Function(bool usarRpa) onContinuar;
  final Function(bool usarRpa) onForzar;

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
  Timer? _timer;
  bool forzarActivado = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (pasoActual < widget.validaciones.length) {
        setState(() {
          pasoActual++;
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool animacionTerminada = pasoActual == widget.validaciones.length;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.all(20),
      title: Column(
        children: [
          Row(
            children: List.generate(widget.validaciones.length, (index) {
              Color colorBarra = Colors.grey.shade300;
              if (index < pasoActual) {
                final estado = widget.validaciones[index]['estado'];
                colorBarra = estado == 'OK' ? Colors.green : Colors.red;
              }
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorBarra,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                widget.conErrores
                    ? Icons.gavel_rounded
                    : Icons.verified_rounded,
                color: widget.conErrores ? Colors.red : Colors.green,
                size: 28,
              ),
              const SizedBox(width: 10),
              const Text(
                "Validación SRI",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(widget.validaciones.length, (index) {
            if (index >= pasoActual) return const SizedBox.shrink();

            final val = widget.validaciones[index];
            final esOk = val['estado'] == 'OK';

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    esOk ? Icons.check_circle : Icons.cancel,
                    color: esOk ? Colors.green : Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          val['paso'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          val['detalle'],
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
      actions: [
        if (animacionTerminada) ...[
          // Si tiene errores y aún no ha forzado, muestra el botón para forzar
          if (widget.conErrores && !forzarActivado)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.warning),
                label: const Text("Forzar Continuar"),
                onPressed: () {
                  setState(() {
                    forzarActivado = true;
                  });
                },
              ),
            )
          else
            // MUESTRA LAS 2 OPCIONES: Vía RPA vs Vía Interna
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.smart_toy),
                  label: const Text("Ingreso de factura (beta)"),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.blue.shade800,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    if (widget.conErrores) {
                      widget.onForzar(true);
                    } else {
                      widget.onContinuar(true);
                    }
                  },
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.checklist),
                  label: const Text("Verificación - Orden de pedido"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange.shade800,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    if (widget.conErrores) {
                      widget.onForzar(false);
                    } else {
                      widget.onContinuar(false);
                    }
                  },
                ),
              ],
            ),

          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Recepción cancelada.")),
                );
              },
              child: const Text(
                "Cancelar",
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
