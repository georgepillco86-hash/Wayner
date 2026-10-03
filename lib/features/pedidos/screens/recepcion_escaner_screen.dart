import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../saldos/presentation/screens/barcode_scanner_screen.dart';

class RecepcionEscanerScreen extends StatefulWidget {
  final int pedidoId;
  final int documentoId;
  final bool usarIntegracionRpa;

  const RecepcionEscanerScreen({
    super.key,
    required this.pedidoId,
    required this.documentoId,
    required this.usarIntegracionRpa,
  });

  @override
  State<RecepcionEscanerScreen> createState() => _RecepcionEscanerScreenState();
}

class _RecepcionEscanerScreenState extends State<RecepcionEscanerScreen> {
  bool isLoading = true;
  String? errorMessage;
  String proveedorNombre = "";

  List<dynamic> itemsXml = [];
  List<dynamic> itemsFaltantes = [];

  @override
  void initState() {
    super.initState();
    cargarDatosComparacion();
  }

  Future<void> cargarDatosComparacion() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final url = Uri.parse(
        "http://192.168.1.231:5000/api/pedidos/rpa/comparar-xml-orden/${widget.documentoId}",
      );
      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final res = jsonDecode(response.body);
        if (res['success'] == true) {
          final data = res['data'];
          setState(() {
            proveedorNombre = data['proveedor'] ?? 'Desconocido';
            itemsXml = List<dynamic>.from(data['items_xml'] ?? []);
            itemsFaltantes = List<dynamic>.from(data['items_faltantes'] ?? []);
            isLoading = false;
          });
        } else {
          setState(() {
            errorMessage = res['error'] ?? "Error desconocido en el servidor";
            isLoading = false;
          });
        }
      } else {
        setState(() {
          errorMessage = "Error del servidor: ${response.statusCode}";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Error de conexión al cargar datos: $e";
        isLoading = false;
      });
    }
  }

  Future<bool> _verificarCodigoEnBD(String codigo) async {
    try {
      final url = Uri.parse(
        "http://192.168.1.231:5000/api/pedidos/productos/$codigo",
      );
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final res = jsonDecode(response.body);
        if (res['success'] == true && res['data'] != null) {
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint("Error verificando código: $e");
      return false;
    }
  }

  Future<void> _procesarConValidacion(int indexXml, String codigoLeido) async {
    final codigoLimpio = codigoLeido.trim();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    bool existe = await _verificarCodigoEnBD(codigoLimpio);

    if (mounted) Navigator.pop(context);

    if (existe) {
      _procesarCodigoLeido(indexXml, codigoLimpio);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("❌ El código no existe en la base de datos"),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> escanearProducto(int indexXml) async {
    final String? codigoEscaneado = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );

    if (codigoEscaneado != null && codigoEscaneado.isNotEmpty) {
      await _procesarConValidacion(indexXml, codigoEscaneado);
    }
  }

  Future<void> _ingresarCodigoManual(int indexXml) async {
    final TextEditingController controller = TextEditingController();

    final String? codigoTipeado = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          "Ingresar Código Manual",
          style: TextStyle(fontSize: 18),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.text,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: "Código de barras",
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.keyboard),
          ),
          autofocus: true,
          onSubmitted: (value) => Navigator.pop(ctx, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text("Cancelar"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text("Aceptar"),
          ),
        ],
      ),
    );

    if (codigoTipeado != null && codigoTipeado.trim().isNotEmpty) {
      await _procesarConValidacion(indexXml, codigoTipeado);
    }
  }

  void _procesarCodigoLeido(int indexXml, String codigoLeido) {
    final codigoLimpio = codigoLeido.trim();

    setState(() {
      final codigoAnterior =
          itemsXml[indexXml]['codigo_sistema']?.toString() ?? '';
      final estadoAnterior = itemsXml[indexXml]['estado_item'] ?? '';

      if (codigoAnterior.isNotEmpty &&
          estadoAnterior != 'SOBRANTE_ACEPTADO' &&
          estadoAnterior != 'PENDIENTE') {
        itemsFaltantes.add({
          'id': itemsXml[indexXml]['faltante_id'],
          'pedido_id': itemsXml[indexXml]['faltante_pedido_id'],
          'codigo_sistema': codigoAnterior,
          'nombre_db': itemsXml[indexXml]['nombre_db'],
          'cantidad_esperada': itemsXml[indexXml]['cantidad_esperada'],
          'costo_esperado': itemsXml[indexXml]['costo_esperado'],
          'estado_item': 'PRODUCTO_FALTANTE',
          'tarifa_iva': 0.0,
        });
      }

      itemsXml[indexXml]['codigo_sistema'] = codigoLimpio;
      itemsXml[indexXml]['resolucion'] = '';

      int indexFaltante = itemsFaltantes.indexWhere(
        (faltante) =>
            faltante['codigo_sistema'].toString().toUpperCase() ==
            codigoLimpio.toUpperCase(),
      );

      if (indexFaltante != -1) {
        var esperado = itemsFaltantes[indexFaltante];

        itemsXml[indexXml]['faltante_id'] = esperado['id'];
        itemsXml[indexXml]['faltante_pedido_id'] = esperado['pedido_id'];
        itemsXml[indexXml]['nombre_db'] = esperado['nombre_db'];
        itemsXml[indexXml]['costo_esperado'] = esperado['costo_esperado'];
        itemsXml[indexXml]['cantidad_esperada'] = esperado['cantidad_esperada'];

        double cantXml = (itemsXml[indexXml]['cantidad_xml'] ?? 0.0).toDouble();
        double cantEsperada = (esperado['cantidad_esperada'] ?? 0.0).toDouble();
        double costoXml = (itemsXml[indexXml]['costo_xml'] ?? 0.0).toDouble();
        double costoEsperado = (esperado['costo_esperado'] ?? 0.0).toDouble();

        if (cantXml != cantEsperada) {
          itemsXml[indexXml]['estado_item'] = "DISCREPANCIA_CANTIDAD";
        } else if (costoXml.toStringAsFixed(2) !=
            costoEsperado.toStringAsFixed(2)) {
          itemsXml[indexXml]['estado_item'] = "DIFERENCIA_COSTO";
        } else {
          itemsXml[indexXml]['estado_item'] = "OK";
        }

        itemsFaltantes.removeAt(indexFaltante);
      } else {
        itemsXml[indexXml]['estado_item'] = "SOBRANTE_ACEPTADO";
        itemsXml[indexXml]['cantidad_esperada'] = 0.0;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Código registrado"),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _rechazarNovedad(int indexXml) {
    final double tarifaIva = (itemsXml[indexXml]['tarifa_iva'] ?? 0.0)
        .toDouble();
    setState(() {
      itemsXml[indexXml]['codigo_sistema'] = tarifaIva > 0 ? "2" : "1";
      itemsXml[indexXml]['resolucion'] = 'RECHAZADO';
    });
  }

  void _aceptarNovedad(int indexXml) {
    setState(() {
      itemsXml[indexXml]['resolucion'] = 'ACEPTADO';
    });
  }

  Future<void> _marcarFaltantesComoNoEntregados() async {
    for (var faltante in itemsFaltantes) {
      final idItem = faltante['id'];
      final idPedido = faltante['pedido_id'] ?? widget.pedidoId;

      if (idItem != null) {
        final url = Uri.parse(
          "http://192.168.1.231:5000/api/pedidos/$idPedido/items/$idItem/recepcion",
        );
        try {
          await http.patch(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "recibido": false,
              "comentario_recepcion": "No entregado",
            }),
          );
        } catch (e) {}
      }
    }
  }

  Future<void> _marcarRechazadosConObservacion() async {
    for (var item in itemsXml) {
      if (item['resolucion'] == 'RECHAZADO') {
        final idItem = item['faltante_id'];
        final idPedido = item['faltante_pedido_id'] ?? widget.pedidoId;
        final codigoSistema = item['codigo_sistema'] ?? '1';

        String motivo = "Rechazado por novedad";
        if (item['estado_item'] == 'DIFERENCIA_COSTO')
          motivo = "Rechazado: Diferencia de costo";
        if (item['estado_item'] == 'DISCREPANCIA_CANTIDAD')
          motivo = "Rechazado: Diferencia de cantidad";

        // 🔥 INYECTAMOS EL CÓDIGO (1 o 2) EN EL COMENTARIO
        motivo = "$motivo (Código: $codigoSistema)";

        if (idItem != null) {
          final url = Uri.parse(
            "http://192.168.1.231:5000/api/pedidos/$idPedido/items/$idItem/recepcion",
          );
          try {
            await http.patch(
              url,
              headers: {"Content-Type": "application/json"},
              body: jsonEncode({
                "recibido": false,
                "comentario_recepcion": motivo,
              }),
            );
          } catch (e) {}
        }
      }
    }
  }

  Future<void> _marcarExitososComoRecibidos() async {
    for (var item in itemsXml) {
      if (item['resolucion'] != 'RECHAZADO') {
        final idItem = item['faltante_id'];
        final idPedido = item['faltante_pedido_id'] ?? widget.pedidoId;
        final codigoSistema = item['codigo_sistema'] ?? 'Sin código';

        if (idItem != null) {
          final url = Uri.parse(
            "http://192.168.1.231:5000/api/pedidos/$idPedido/items/$idItem/recepcion",
          );
          try {
            await http.patch(
              url,
              headers: {"Content-Type": "application/json"},
              body: jsonEncode({
                "recibido": true,
                "comentario_recepcion": item['resolucion'] == 'ACEPTADO'
                    ? "Novedad Aceptada (Código Leído: $codigoSistema)" // 🔥 INYECTAMOS EL CÓDIGO DE BARRAS ACEPTADO
                    : null,
              }),
            );
          } catch (e) {}
        }
      }
    }
  }

  // 🔥 NUEVO: Función obligatoria para cambiar el estado general a RECIBIDO
  Future<void> _marcarPedidoComoRecibidoEnBD() async {
    try {
      final url = Uri.parse(
        "http://192.168.1.231:5000/api/pedidos/${widget.pedidoId}/recibir",
      );
      await http.patch(url);
    } catch (e) {
      debugPrint("Error marcando pedido como recibido: $e");
    }
  }

  Future<void> _cancelarProcesoEnRPA() async {
    if (!widget.usarIntegracionRpa) return;

    try {
      final url = Uri.parse(
        "http://192.168.1.231:5000/api/pedidos/rpa/cancelar-escaneo/${widget.documentoId}",
      );
      await http.post(url);
    } catch (e) {}
  }

  void completarRecepcion() {
    bool faltaCodigo = false;
    bool faltaDecision = false;

    for (var item in itemsXml) {
      String codigo = item['codigo_sistema']?.toString() ?? "";
      String estado = item['estado_item'] ?? 'PENDIENTE';
      String resolucion = item['resolucion'] ?? '';

      if (codigo.trim().isEmpty) {
        faltaCodigo = true;
      }

      bool isOk = estado == 'OK';
      bool escaneado = codigo.trim().isNotEmpty;
      bool isNoRequerido =
          estado == 'PENDIENTE' ||
          estado == 'PRODUCTO_NO_REQUERIDO' ||
          estado == 'SOBRANTE_ACEPTADO';
      bool hasNovedad = (escaneado && !isOk) || isNoRequerido;

      if (hasNovedad && resolucion.isEmpty) {
        faltaDecision = true;
      }
    }

    if (faltaCodigo || faltaDecision) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.block, color: Colors.red),
              SizedBox(width: 8),
              Text("Revisión Incompleta"),
            ],
          ),
          content: const Text(
            "No puedes completar la recepción hasta cumplir estas reglas:\n\n"
            "1. TODOS los productos deben tener un código escaneado o digitado.\n"
            "2. TODOS los productos en la sección 'Novedades' deben ser Aceptados o Rechazados explícitamente.",
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Entendido"),
            ),
          ],
        ),
      );
      return;
    }

    _enviarDatosFinales();
  }

  Future<void> _enviarDatosFinales() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(child: Text("Sincronizando información de recepción...")),
          ],
        ),
      ),
    );

    // 1. Guardar en Base de datos el resultado del escaneo
    await _marcarFaltantesComoNoEntregados();
    await _marcarRechazadosConObservacion();
    await _marcarExitososComoRecibidos();

    // 2. Evaluar qué ruta escogió el usuario
    if (widget.usarIntegracionRpa) {
      // ---> RUTA 1: CONTINÚA CON EL RPA
      List<String> codigosAEnviar = itemsXml
          .map((item) => item['codigo_sistema'].toString())
          .toList();

      try {
        final resetUrl = Uri.parse(
          "http://192.168.1.231:5000/api/pedidos/rpa/notificar-estado/${widget.documentoId}",
        );
        await http.patch(
          resetUrl,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "estado": "INICIANDO",
            "mensaje": "Conectando con el robot...",
          }),
        );
      } catch (e) {}

      try {
        final url = Uri.parse(
          "http://192.168.1.231:5000/api/escaner/rpa/enviar",
        );

        final response = await http.post(
          url,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "documento_id": widget.documentoId,
            "codigos": codigosAEnviar,
          }),
        );

        if (mounted) Navigator.pop(context); // Cierra loading

        if (response.statusCode == 200) {
          final res = jsonDecode(response.body);
          if (res['success'] == true) {
            final fueExito = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (ctx) =>
                  DialogoProgresoRPA(documentoId: widget.documentoId),
            );

            if (fueExito == true && mounted) {
              await _marcarPedidoComoRecibidoEnBD(); // Asegura estado final
              Navigator.pop(context); // Vuelve a la pantalla de bodega
            }
          } else {
            _mostrarErrorEnvio(res['message'] ?? "Error en el servidor");
          }
        } else {
          _mostrarErrorEnvio("Error de servidor: ${response.statusCode}");
        }
      } catch (e) {
        if (mounted) Navigator.pop(context);
        _mostrarErrorEnvio("Error de red invocando a RPA.");
      }
    } else {
      // ---> RUTA 2: SOLO VERIFICACIÓN (Ignora BITS)
      await _cancelarProcesoEnRPA();
      await _marcarPedidoComoRecibidoEnBD(); // Asegura estado final

      if (mounted) {
        Navigator.pop(context); // Cierra el Loading
        Navigator.pop(context); // Vuelve a la pantalla de Bodega
      }
    }
  }

  void _mostrarErrorEnvio(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
    );
  }

  Widget _buildCardWrapper(Map<String, dynamic> wrapper) {
    final bool isXml = wrapper['isXml'];
    final item = wrapper['data'];
    final int indexXml = wrapper['indexXml'] ?? -1;

    if (!isXml) {
      final double costoEsperado = (item['costo_esperado'] ?? 0.0).toDouble();
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Colors.red.shade200, width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      item['nombre_db'].toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    label: const Text(
                      "FALTANTE",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    backgroundColor: Colors.red,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "Cód Sistema: ${item['codigo_sistema']}",
                style: const TextStyle(color: Colors.grey),
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Cantidad:",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Flexible(
                    child: Text(
                      "Orden: ${item['cantidad_esperada']}  |  XML: 0",
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Costo U:",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Flexible(
                    child: Text(
                      "Orden: \$${costoEsperado.toStringAsFixed(4)}  |  XML: \$0.0000",
                      style: const TextStyle(color: Colors.black),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final bool escaneado =
        item['codigo_sistema'] != null &&
        item['codigo_sistema'].toString().isNotEmpty;
    final estado = item['estado_item'] ?? 'PENDIENTE';
    final String resolucion = item['resolucion'] ?? '';

    final bool isOk = estado == 'OK';
    final bool isSobrante = estado == 'SOBRANTE_ACEPTADO';
    final bool isDiffCant = estado == 'DISCREPANCIA_CANTIDAD';
    final bool isDiffCosto = estado == 'DIFERENCIA_COSTO';
    final bool isNoRequerido =
        estado == 'PENDIENTE' ||
        estado == 'PRODUCTO_NO_REQUERIDO' ||
        isSobrante;

    final bool hasNovedad = (escaneado && !isOk) || isNoRequerido;
    final bool requiereDecision = hasNovedad && resolucion.isEmpty;

    final Color cardColor = isOk || resolucion == 'ACEPTADO'
        ? Colors.green.shade50
        : (resolucion == 'RECHAZADO' ? Colors.red.shade50 : Colors.white);
    final Color borderColor = isOk
        ? Colors.green
        : (hasNovedad ? Colors.red.shade300 : Colors.grey.shade300);
    final double borderWidth = (isOk || hasNovedad) ? 2.0 : 1.0;

    String badgeText = '';
    if (isNoRequerido) badgeText = "NO REQUERIDO";
    if (isDiffCant) badgeText = "CANTIDAD DISTINTA";
    if (isDiffCosto) badgeText = "COSTO DISTINTO";

    final double costoUnitario = (item['costo_xml'] ?? 0.0).toDouble();
    final double cantidad = (item['cantidad_xml'] ?? 0.0).toDouble();
    final double tarifaIva = (item['tarifa_iva'] ?? 0.0).toDouble();
    final double costoTotal = costoUnitario * cantidad;

    return Card(
      elevation: escaneado ? 1 : 4,
      color: cardColor,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: borderColor, width: borderWidth),
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    "${item['indice_xml'] + 1}. ${item['descripcion_xml']}"
                        .toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (hasNovedad)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      badgeText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (tarifaIva > 0)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      border: Border.all(color: Colors.purple.shade200),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      "IVA ${tarifaIva.toStringAsFixed(0)}%",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple.shade700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            if (!hasNovedad || isNoRequerido || isSobrante) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Cant: $cantidad",
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text("Costo U: \$${costoUnitario.toStringAsFixed(4)}"),
                  Text(
                    "Total: \$${costoTotal.toStringAsFixed(2)}",
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Cantidad:",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Flexible(
                    child: Text(
                      "Orden: ${item['cantidad_esperada']}  |  XML: $cantidad",
                      style: TextStyle(
                        color: isDiffCant ? Colors.red : Colors.black,
                        fontWeight: isDiffCant
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Costo U:",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Flexible(
                    child: Text(
                      "Orden: \$${(item['costo_esperado'] ?? 0.0).toStringAsFixed(4)}  |  XML: \$${costoUnitario.toStringAsFixed(4)}",
                      style: TextStyle(
                        color: isDiffCosto ? Colors.red : Colors.black,
                        fontWeight: isDiffCosto
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Código Prov: ${item['codigo_proveedor']}",
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      if (escaneado)
                        Text(
                          "Código Leído: ${item['codigo_sistema']}",
                          style: TextStyle(
                            color: isOk || resolucion == 'ACEPTADO'
                                ? Colors.green.shade800
                                : Colors.red.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      else
                        const Text(
                          "Cód Sistema: No escaneado",
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),

                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => _ingresarCodigoManual(indexXml),
                      icon: const Icon(Icons.keyboard),
                      color: Colors.blueGrey,
                      tooltip: "Digitar código",
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: escaneado
                            ? Colors.white
                            : Colors.blue.shade800,
                        foregroundColor: escaneado
                            ? Colors.green
                            : Colors.white,
                        side: escaneado
                            ? const BorderSide(color: Colors.green)
                            : null,
                      ),
                      onPressed: () => escanearProducto(indexXml),
                      icon: Icon(
                        escaneado ? Icons.check_circle : Icons.qr_code_scanner,
                      ),
                      label: Text(escaneado ? "Re-Escanear" : "Escanear"),
                    ),
                  ],
                ),
              ],
            ),

            if (requiereDecision) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade300),
                      ),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text("Rechazar"),
                      onPressed: () => _rechazarNovedad(indexXml),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                      ),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text("Aceptar"),
                      onPressed: () => _aceptarNovedad(indexXml),
                    ),
                  ),
                ],
              ),
            ],

            if (resolucion.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: resolucion == 'ACEPTADO'
                      ? Colors.green.shade100
                      : Colors.red.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  resolucion == 'ACEPTADO'
                      ? "✅ Novedad Aceptada"
                      : "❌ Producto Rechazado",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: resolucion == 'ACEPTADO'
                        ? Colors.green.shade800
                        : Colors.red.shade800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> listaNormales = [];
    List<Map<String, dynamic>> listaNovedades = [];

    for (int i = 0; i < itemsXml.length; i++) {
      var item = itemsXml[i];
      bool escaneado =
          item['codigo_sistema'] != null &&
          item['codigo_sistema'].toString().isNotEmpty;
      String estado = item['estado_item'] ?? 'PENDIENTE';

      if (!escaneado || estado == 'OK') {
        if (estado == 'PRODUCTO_NO_REQUERIDO' ||
            estado == 'PENDIENTE' ||
            estado == 'SOBRANTE_ACEPTADO') {
          listaNovedades.add({"isXml": true, "data": item, "indexXml": i});
        } else {
          listaNormales.add({"isXml": true, "data": item, "indexXml": i});
        }
      } else {
        listaNovedades.add({"isXml": true, "data": item, "indexXml": i});
      }
    }

    for (var faltante in itemsFaltantes) {
      listaNovedades.add({"isXml": false, "data": faltante});
    }

    return WillPopScope(
      onWillPop: () async {
        final confirmar = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("¿Está seguro que desea salir?"),
            content: const Text(
              "Se perderá el progreso actual de la validación.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("No"),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text("Sí, salir"),
              ),
            ],
          ),
        );

        if (confirmar == true) {
          await _cancelarProcesoEnRPA();
          return true;
        }
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(title: const Text("Validación de Recepción")),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : CustomScrollView(
                slivers: [
                  if (listaNormales.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                        child: Row(
                          children: [
                            Icon(Icons.checklist, color: Colors.blue.shade900),
                            const SizedBox(width: 8),
                            Text(
                              "Productos a Recepcionar",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) =>
                              _buildCardWrapper(listaNormales[index]),
                          childCount: listaNormales.length,
                        ),
                      ),
                    ),
                  ],
                  if (listaNovedades.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.red,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              "Productos con Novedad",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) =>
                              _buildCardWrapper(listaNovedades[index]),
                          childCount: listaNovedades.length,
                        ),
                      ),
                    ),
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
        bottomNavigationBar: isLoading || errorMessage != null
            ? null
            : Padding(
                padding: const EdgeInsets.all(12.0),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.save_alt),
                  label: const Text(
                    "COMPLETAR RECEPCIÓN",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  onPressed: completarRecepcion,
                ),
              ),
      ),
    );
  }
}

class DialogoProgresoRPA extends StatefulWidget {
  final int documentoId;
  const DialogoProgresoRPA({super.key, required this.documentoId});

  @override
  State<DialogoProgresoRPA> createState() => _DialogoProgresoRPAState();
}

class _DialogoProgresoRPAState extends State<DialogoProgresoRPA> {
  Timer? _timer;
  String estadoStr = "INICIANDO";
  String mensaje = "Conectando con el robot...";
  bool isError = false;
  bool isSuccess = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _verificarEstado();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _verificarEstado() async {
    try {
      final url = Uri.parse(
        "http://192.168.1.231:5000/api/pedidos/rpa/estado-actual/${widget.documentoId}",
      );
      final res = await http.get(url).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final estadoApi = data['estado']?.toString() ?? "";
        final mensajeApi = data['mensaje']?.toString() ?? "";

        if (mounted) {
          setState(() {
            estadoStr = estadoApi;
            if (mensajeApi.isNotEmpty) mensaje = mensajeApi;

            if (estadoApi == "EXITO") {
              isSuccess = true;
              _timer?.cancel();
            } else if (estadoApi.contains("ERROR") ||
                estadoApi == "CLAVE_INCORRECTA") {
              isError = true;
              _timer?.cancel();
            }
          });
        }
      }
    } catch (e) {
      // Ignoramos errores momentáneos de red
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          if (isSuccess)
            const Icon(Icons.check_circle, color: Colors.green, size: 60)
          else if (isError)
            const Icon(Icons.error, color: Colors.red, size: 60)
          else
            const CircularProgressIndicator(),

          const SizedBox(height: 20),
          Text(
            isSuccess
                ? "¡Completado!"
                : isError
                ? "Error en BITS"
                : "Robot Trabajando",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            mensaje,
            style: TextStyle(
              fontSize: 14,
              color: isError ? Colors.red : Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
        ],
      ),
      actions: [
        if (isSuccess || isError)
          Center(
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: isSuccess ? Colors.green : Colors.red,
              ),
              onPressed: () => Navigator.pop(context, isSuccess),
              child: const Text("Cerrar"),
            ),
          ),
      ],
    );
  }
}
