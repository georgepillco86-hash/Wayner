import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/config/api_config.dart';
import '../../../core/network/auth_headers.dart';

class ConversionesService {
  final String baseUrl = "${ApiConfig.baseUrl}/api/conversiones";

  Future<List<dynamic>> listarRequerimientos() async {
    final response = await http.get(
      Uri.parse(baseUrl),
      headers: await AuthHeaders.plain(),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json["data"] ?? [];
    }
    throw Exception("Error al obtener requerimientos de conversión");
  }

  // 🔥 Se agregó el parámetro opcional 'trabajadorAsignado'
  Future<Map<String, dynamic>> crearOrdenTrabajo(
    List<Map<String, dynamic>> items,
    String usuario, {
    String? trabajadorAsignado, // <--- NUEVO
  }) async {
    final headers = await AuthHeaders.json();
    headers['x-user-name'] = usuario; // Inyectamos el nombre de usuario real

    final response = await http.post(
      Uri.parse(baseUrl),
      headers: headers,
      body: jsonEncode({
        "items": items,
        if (trabajadorAsignado != null)
          "trabajador_asignado": trabajadorAsignado, // <--- NUEVO
      }),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json["data"];
    }
    throw Exception("Error al crear la orden de trabajo");
  }

  // 🔥 Se agregó el parámetro 'usuario'
  Future<Map<String, dynamic>> ejecutarConversion(
    int reqId,
    Map<String, dynamic> payload,
    String usuario,
  ) async {
    final headers = await AuthHeaders.json();
    headers['x-user-name'] = usuario; // Inyectamos el nombre de usuario real

    final response = await http.patch(
      Uri.parse("$baseUrl/$reqId/ejecutar"),
      headers: headers,
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json["data"];
    }
    throw Exception("Error al ejecutar la conversión");
  }

  // 🔥 Nuevo método para actualizar cantidad
  Future<void> actualizarCantidad(
    int reqId,
    double cantidad,
    String usuario,
  ) async {
    final headers = await AuthHeaders.json();
    headers['x-user-name'] = usuario;

    final response = await http.patch(
      Uri.parse("$baseUrl/$reqId/cantidad"),
      headers: headers,
      body: jsonEncode({"cantidad": cantidad}),
    );

    if (response.statusCode != 200) {
      throw Exception("Error al actualizar la cantidad");
    }
  }
}
