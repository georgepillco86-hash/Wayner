import 'dart:convert';
import 'package:ferrotienda_flutter_proyecto/core/config/api_config.dart';
import 'package:ferrotienda_flutter_proyecto/core/network/auth_headers.dart';
import 'package:http/http.dart' as http;

class PedidosService {
  final String baseUrl = "${ApiConfig.baseUrl}/api/pedidos";

  Future<List<dynamic>> buscarProductos(
    String query, {
    String? query2,
    String? proveedor,
  }) async {
    final uri = Uri.parse("$baseUrl/productos/buscar").replace(
      queryParameters: {
        "q": query,
        if (query2 != null && query2.trim().isNotEmpty) "q2": query2.trim(),
        if (proveedor != null && proveedor.trim().isNotEmpty)
          "proveedor": proveedor.trim(),
      },
    );

    final response = await http.get(uri, headers: await AuthHeaders.plain());

    if (response.statusCode == 200) {
      return jsonDecode(response.body)["data"];
    } else {
      throw Exception("Error al buscar productos");
    }
  }

  // 🔥 CORRECCIÓN: Apuntamos a la ruta optimizada que liberamos en Python 🔥
  Future<List<String>> obtenerProveedores() async {
    final response = await http.get(
      Uri.parse("${ApiConfig.baseUrl}/api/proveedores/"),
      headers: await AuthHeaders.plain(),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);

      // La nueva ruta devuelve directamente una lista: ["Prov1", "Prov2"]
      if (decoded is List) {
        return decoded.map<String>((item) => item.toString()).toList();
      }
      // Fallback de seguridad por si alguna vez devuelve el formato antiguo
      else if (decoded is Map && decoded.containsKey('data')) {
        final data = decoded["data"] ?? [];
        return data
            .map<String>((item) => item["proveedor"]?.toString() ?? "")
            .where((item) => item.trim().isNotEmpty)
            .toList();
      }
      return [];
    }

    throw Exception("Error al obtener proveedores");
  }

  Future<Map<String, dynamic>> obtenerMejorProveedorPrecio({
    required String codigoProducto,
    int meses = 6,
  }) async {
    final response = await http.get(
      Uri.parse(
        "$baseUrl/productos/$codigoProducto/mejor-proveedor-precio?meses=$meses",
      ),
      headers: await AuthHeaders.plain(),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json["data"] ?? {};
    }

    throw Exception("Error al obtener mejor proveedor por precio");
  }

  Future<void> crearPedido(Map<String, dynamic> payload) async {
    final response = await http.post(
      Uri.parse(baseUrl),
      headers: await AuthHeaders.json(),
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception("Error al crear pedido");
    }

    final json = jsonDecode(response.body);
    return json["data"]["id"];
  }

  Future<List<dynamic>> listarMisPedidos(String usuario) async {
    final response = await http.get(
      Uri.parse("$baseUrl/mis-pedidos?usuario=$usuario"),
      headers: await AuthHeaders.plain(),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json["data"] ?? [];
    }

    throw Exception("Error al obtener mis pedidos");
  }

  Future<String> obtenerTextoWhatsApp(int pedidoId) async {
    final response = await http.get(
      Uri.parse("$baseUrl/$pedidoId/whatsapp-text"),
      headers: await AuthHeaders.plain(),
    );

    final json = jsonDecode(response.body);
    return json["data"]["mensajes"][0]["mensaje"];
  }

  Future<Map<String, dynamic>> getProductoPorCodigo(String codigo) async {
    final response = await http.get(
      Uri.parse("$baseUrl/productos/$codigo"),
      headers: await AuthHeaders.plain(),
    );

    final json = jsonDecode(response.body);
    return json["data"];
  }

  Future<List<dynamic>> obtenerProveedoresProducto(String codigo) async {
    final response = await http.get(
      Uri.parse("$baseUrl/productos/$codigo/proveedores"),
      headers: await AuthHeaders.plain(),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json["data"] ?? [];
    } else {
      throw Exception("Error al obtener proveedores del producto");
    }
  }

  Future<Map<String, dynamic>> obtenerDetallePedidoUsuario(int pedidoId) async {
    final response = await http.get(
      Uri.parse("$baseUrl/$pedidoId/detalle-usuario"),
      headers: await AuthHeaders.plain(),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json["data"] ?? {};
    }

    throw Exception("Error al obtener detalle del pedido");
  }

  Future<List<dynamic>> listarPedidosAdmin() async {
    final response = await http.get(
      Uri.parse("$baseUrl/admin"),
      headers: await AuthHeaders.plain(),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json["data"] ?? [];
    }

    throw Exception("Error al obtener pedidos admin");
  }

  Future<Map<String, dynamic>> obtenerDetallePedidoAdmin(int pedidoId) async {
    final response = await http.get(
      Uri.parse("$baseUrl/$pedidoId/admin-detalle"),
      headers: await AuthHeaders.plain(),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json["data"] ?? {};
    }

    throw Exception("Error al obtener detalle admin");
  }

  Future<Map<String, dynamic>> obtenerTextoPorProveedor(int pedidoId) async {
    final response = await http.get(
      Uri.parse("$baseUrl/$pedidoId/proveedores-texto"),
      headers: await AuthHeaders.plain(),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json["data"] ?? {};
    }

    throw Exception("Error al obtener texto por proveedor");
  }

  Future<Map<String, dynamic>> obtenerTextosProveedor(int pedidoId) async {
    final response = await http.get(
      Uri.parse("$baseUrl/$pedidoId/proveedores-texto"),
      headers: await AuthHeaders.plain(),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json["data"] ?? {};
    }

    throw Exception("Error al obtener los textos del proveedor");
  }

  Future<List<dynamic>> obtenerHistorialCostos(String codigo, int meses) async {
    final uri = Uri.parse(
      "$baseUrl/producto/$codigo/historial-costos",
    ).replace(queryParameters: {"meses": meses.toString()});

    final response = await http.get(uri, headers: await AuthHeaders.plain());

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json["data"] ?? [];
    }

    throw Exception("Error al obtener el historial de costos");
  }

  Future<Map<String, dynamic>?> obtenerMejorCostoGlobal(
    String codigo, {
    int meses = 3,
  }) async {
    final response = await http.get(
      Uri.parse("$baseUrl/producto/$codigo/mejor-costo?meses=$meses"),
      headers: await AuthHeaders.plain(),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json["data"];
    }
    return null;
  }

  Future<Map<String, dynamic>> agregarItemPedido({
    required int pedidoId,
    required String codigoProducto,
    required dynamic cantidad,
    String? unidad,
    String? notaCompra,
    String tipoDestino = "VENTA",
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/$pedidoId/items"),
      headers: await AuthHeaders.json(),
      body: jsonEncode({
        "codigo_producto": codigoProducto,
        "cantidad_pedida": cantidad,
        "unidad": unidad,
        "nota_compra": notaCompra,
        "tipo_destino": tipoDestino,
      }),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json["data"] ?? {};
    }

    throw Exception("Error al agregar producto al pedido");
  }

  Future<Map<String, dynamic>> actualizarCantidadItemPedido({
    required int pedidoId,
    required int itemId,
    required dynamic cantidad,
  }) async {
    final response = await http.patch(
      Uri.parse("$baseUrl/$pedidoId/items/$itemId"),
      headers: await AuthHeaders.json(),
      body: jsonEncode({"cantidad_pedida": cantidad}),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json["data"] ?? {};
    }

    throw Exception("Error al actualizar cantidad");
  }

  // 🔥 Función para guardar el costo en la base de datos 🔥
  Future<Map<String, dynamic>> actualizarCostoItemPedido({
    required int pedidoId,
    required int itemId,
    required dynamic costo,
  }) async {
    final response = await http.patch(
      Uri.parse("$baseUrl/$pedidoId/items/$itemId/costo"),
      headers: await AuthHeaders.json(),
      body: jsonEncode({"costo_esperado": costo}),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json["data"] ?? {};
    }

    throw Exception("Error al actualizar el costo");
  }

  Future<Map<String, dynamic>> eliminarItemPedido({
    required int pedidoId,
    required int itemId,
  }) async {
    final response = await http.delete(
      Uri.parse("$baseUrl/$pedidoId/items/$itemId"),
      headers: await AuthHeaders.plain(),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json["data"] ?? {};
    }

    throw Exception("Error al eliminar producto del pedido");
  }

  Future<Map<String, dynamic>> actualizarProveedorItemPedido({
    required int pedidoId,
    required int itemId,
    required String proveedor,
  }) async {
    final response = await http.patch(
      Uri.parse("$baseUrl/$pedidoId/items/$itemId/proveedor"),
      headers: await AuthHeaders.json(),
      body: jsonEncode({"proveedor": proveedor}),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json["data"] ?? {};
    }

    throw Exception("Error al actualizar proveedor");
  }

  Future<Map<String, dynamic>> actualizarNotaItemPedido({
    required int pedidoId,
    required int itemId,
    required String? notaCompra,
  }) async {
    final response = await http.patch(
      Uri.parse("$baseUrl/$pedidoId/items/$itemId/nota"),
      headers: await AuthHeaders.json(),
      body: jsonEncode({"nota_compra": notaCompra}),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json["data"] ?? {};
    }

    throw Exception("Error al actualizar nota de compra");
  }

  Future<Map<String, dynamic>> actualizarUnidadItemPedido({
    required int pedidoId,
    required int itemId,
    required String? unidad,
  }) async {
    final response = await http.patch(
      Uri.parse("$baseUrl/$pedidoId/items/$itemId/unidad"),
      headers: await AuthHeaders.json(),
      body: jsonEncode({"unidad": unidad}),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json["data"] ?? {};
    }

    throw Exception("Error al actualizar unidad de medida");
  }

  Future<Map<String, dynamic>> actualizarTipoDestinoItemPedido({
    required int pedidoId,
    required int itemId,
    required String tipoDestino,
  }) async {
    final response = await http.patch(
      Uri.parse("$baseUrl/$pedidoId/items/$itemId/tipo-destino"),
      headers: await AuthHeaders.json(),
      body: jsonEncode({"tipo_destino": tipoDestino}),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json["data"] ?? {};
    }

    throw Exception("Error al actualizar destino del producto");
  }

  Future<Map<String, dynamic>> actualizarEstadoPedido({
    required int pedidoId,
    required String estado,
  }) async {
    final response = await http.patch(
      Uri.parse("$baseUrl/$pedidoId/estado"),
      headers: await AuthHeaders.json(),
      body: jsonEncode({"estado": estado}),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json["data"] ?? {};
    }

    throw Exception("Error al actualizar estado del pedido");
  }

  Future<List<dynamic>> listarPedidosBodega() async {
    final response = await http.get(
      Uri.parse("$baseUrl/bodega"),
      headers: await AuthHeaders.plain(),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json["data"] ?? [];
    }

    throw Exception("Error al obtener pedidos de bodega");
  }

  Future<Map<String, dynamic>> obtenerDetallePedidoBodega(int pedidoId) async {
    final response = await http.get(
      Uri.parse("$baseUrl/$pedidoId/bodega-detalle"),
      headers: await AuthHeaders.plain(),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json["data"] ?? {};
    }

    throw Exception("Error al obtener detalle de recepción");
  }

  Future<Map<String, dynamic>> actualizarRecepcionItemPedido({
    required int pedidoId,
    required int itemId,
    required bool recibido,
    String? comentarioRecepcion,
  }) async {
    final response = await http.patch(
      Uri.parse("$baseUrl/$pedidoId/items/$itemId/recepcion"),
      headers: await AuthHeaders.json(),
      body: jsonEncode({
        "recibido": recibido,
        "comentario_recepcion": comentarioRecepcion,
      }),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json["data"] ?? {};
    }

    throw Exception("Error al actualizar recepción del producto");
  }

  Future<Map<String, dynamic>> obtenerTextoNovedadesRecepcion(
    int pedidoId, {
    String? proveedor,
  }) async {
    final uri = proveedor == null || proveedor.trim().isEmpty
        ? Uri.parse("$baseUrl/$pedidoId/novedades-recepcion-texto")
        : Uri.parse(
            "$baseUrl/$pedidoId/novedades-recepcion-texto?proveedor=${Uri.encodeComponent(proveedor)}",
          );

    final response = await http.get(uri, headers: await AuthHeaders.plain());

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json["data"] ?? {};
    }

    throw Exception("Error al generar texto de novedades");
  }

  Future<Map<String, dynamic>> marcarPedidoRecibido(int pedidoId) async {
    final response = await http.patch(
      Uri.parse("$baseUrl/$pedidoId/recibir"),
      headers: await AuthHeaders.plain(),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json["data"] ?? {};
    }

    throw Exception("Error al marcar pedido como recibido");
  }

  Future<List<String>> obtenerUnidadesMedida() async {
    final response = await http.get(
      Uri.parse("${ApiConfig.baseUrl}/api/unidades-medida"),
      headers: await AuthHeaders.plain(),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final List data = json["data"] ?? [];
      return data.map<String>((item) => item["nombre"].toString()).toList();
    }

    throw Exception("Error al obtener unidades de medida");
  }

  Future<List<dynamic>> listarUnidadesMedidaAdmin() async {
    final response = await http.get(
      Uri.parse("${ApiConfig.baseUrl}/api/unidades-medida/admin"),
      headers: await AuthHeaders.plain(),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json["data"] ?? [];
    }

    throw Exception("Error al obtener unidades de medida");
  }

  Future<Map<String, dynamic>> crearUnidadMedida({
    required String nombre,
  }) async {
    final response = await http.post(
      Uri.parse("${ApiConfig.baseUrl}/api/unidades-medida"),
      headers: await AuthHeaders.json(),
      body: jsonEncode({"nombre": nombre}),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json["data"] ?? {};
    }

    throw Exception("Error al crear unidad de medida");
  }

  Future<Map<String, dynamic>> actualizarUnidadMedida({
    required int unidadId,
    required String nombre,
    required bool activo,
  }) async {
    final response = await http.patch(
      Uri.parse("${ApiConfig.baseUrl}/api/unidades-medida/$unidadId"),
      headers: await AuthHeaders.json(),
      body: jsonEncode({"nombre": nombre, "activo": activo}),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json["data"] ?? {};
    }

    throw Exception("Error al actualizar unidad de medida");
  }

  Future<Map<String, dynamic>> desactivarUnidadMedida({
    required int unidadId,
  }) async {
    final response = await http.delete(
      Uri.parse("${ApiConfig.baseUrl}/api/unidades-medida/$unidadId"),
      headers: await AuthHeaders.plain(),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json["data"] ?? {};
    }

    throw Exception("Error al desactivar unidad de medida");
  }

  // 🔥 MÉTODO AÑADIDO: Guarda el nuevo orden de las unidades
  Future<void> actualizarOrdenUnidades(List<int> idsOrdenados) async {
    final response = await http.post(
      Uri.parse("${ApiConfig.baseUrl}/api/unidades-medida/orden"),
      headers: await AuthHeaders.json(),
      body: jsonEncode({"orden_ids": idsOrdenados}),
    );

    if (response.statusCode != 200) {
      throw Exception("Error al actualizar el orden de las unidades de medida");
    }
  }

  Future<Map<String, dynamic>> obtenerCantidadRecomendadaProducto(
    String codigoProducto,
  ) async {
    final response = await http.get(
      Uri.parse("$baseUrl/productos/$codigoProducto/cantidad-recomendada"),
      headers: await AuthHeaders.plain(),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json["data"] ?? {};
    }

    throw Exception("Error al obtener cantidad recomendada");
  }

  // 🔥 MÉTODO AÑADIDO: Notifica a la base de datos central que el proveedor fue contactado
  Future<Map<String, dynamic>> notificarEnvioProveedor({
    required int pedidoId,
    required String proveedor,
  }) async {
    final response = await http.patch(
      Uri.parse("$baseUrl/$pedidoId/notificar-proveedor"),
      headers: await AuthHeaders.json(),
      body: jsonEncode({"proveedor": proveedor}),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json["data"] ?? {};
    }

    throw Exception("Error al notificar envío al proveedor");
  }

  // 🔥 MÉTODO AÑADIDO: Enviar clave de acceso SRI al backend (RPA)
  Future<bool> enviarClaveSRI({
    required int pedidoId,
    required String proveedor,
    required String claveAcceso,
  }) async {
    try {
      final uri = Uri.parse("$baseUrl/$pedidoId/sri-clave");

      final response = await http.post(
        uri,
        headers: await AuthHeaders.json(),
        body: jsonEncode({"proveedor": proveedor, "clave_acceso": claveAcceso}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        print("Error en enviarClaveSRI: ${response.body}");
        return false;
      }
    } catch (e) {
      print("Excepción en enviarClaveSRI: $e");
      return false;
    }
  }

  // =========================================================================
  // 🔥 RUTAS PARA LA VISTA CONSOLIDADA "POR PROVEEDORES" 🔥
  // =========================================================================

  Future<List<dynamic>> listarBorradoresAgrupadosPorProveedor({
    String? fechaInicio,
    String? fechaFin,
  }) async {
    var uri = Uri.parse("$baseUrl/borradores/agrupados-por-proveedor");

    // 🔥 Si enviamos fechas desde Flutter, se las pasamos a Python
    if (fechaInicio != null && fechaFin != null) {
      uri = uri.replace(
        queryParameters: {"fecha_inicio": fechaInicio, "fecha_fin": fechaFin},
      );
    }

    final response = await http.get(uri, headers: await AuthHeaders.plain());

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json["data"] ?? [];
    }

    throw Exception("Error al obtener borradores agrupados por proveedor");
  }

  // 🔥 NUEVO: Recibe si queremos los notificados (enviados) o los falses (borrador)
  Future<Map<String, dynamic>> obtenerDetalleBorradoresProveedor(
    String proveedor, {
    bool notificado = false,
  }) async {
    final uri = Uri.parse("$baseUrl/borradores/proveedor-detalle").replace(
      queryParameters: {
        "proveedor": proveedor,
        "notificado": notificado.toString(), // Agregamos la bandera
      },
    );
    final response = await http.get(uri, headers: await AuthHeaders.plain());

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json["data"] ?? {};
    }

    throw Exception("Error al obtener detalle consolidado del proveedor");
  }

  // =========================================================================
  // 🔥 FUNCIONES PARA EL MÓDULO DE FECHAS ESPECIALES (PROPHET IA) 🔥
  // =========================================================================

  Future<List<dynamic>> obtenerEventosCalendario() async {
    final response = await http.get(
      Uri.parse("$baseUrl/eventos"),
      headers: await AuthHeaders.plain(),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json["data"] ?? [];
    }

    throw Exception("Error al obtener eventos del calendario");
  }

  Future<Map<String, dynamic>> crearEventoCalendario(
    Map<String, dynamic> data,
  ) async {
    final response = await http.post(
      Uri.parse("$baseUrl/eventos"),
      headers: await AuthHeaders.json(),
      body: jsonEncode(data),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final json = jsonDecode(response.body);
      return json["data"] ?? {};
    }

    throw Exception("Error al crear evento");
  }

  Future<Map<String, dynamic>> actualizarEventoCalendario(
    int id,
    Map<String, dynamic> data,
  ) async {
    final response = await http.put(
      Uri.parse("$baseUrl/eventos/$id"),
      headers: await AuthHeaders.json(),
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json["data"] ?? {};
    }

    throw Exception("Error al actualizar evento");
  }

  Future<Map<String, dynamic>> actualizarEstadoEvento(
    int id,
    bool activo,
  ) async {
    final response = await http.patch(
      Uri.parse("$baseUrl/eventos/$id/estado?activo=$activo"),
      headers: await AuthHeaders.plain(),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json["data"] ?? {};
    }

    throw Exception("Error al actualizar estado del evento");
  }

  Future<void> eliminarEventoCalendario(int id) async {
    final response = await http.delete(
      Uri.parse("$baseUrl/eventos/$id"),
      headers: await AuthHeaders.plain(),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception("Error al eliminar evento");
    }
  }
}
