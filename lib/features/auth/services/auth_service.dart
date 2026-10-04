import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../models/auth_user.dart';

class AuthService {
  final String baseUrl = "${ApiConfig.baseUrl}/api/auth";

  Future<AuthUser> login({
    required String nombreUsuario,
    required String password,
  }) async {
    // 1. Intercepción para la cuenta Demo (Apple Review / Pruebas)
    if (nombreUsuario.trim().toLowerCase() == 'apple_test' &&
        password == 'demo123') {
      await Future.delayed(
        const Duration(milliseconds: 600),
      ); // Simula la latencia de red

      // Creamos un mapa simulando la respuesta "data" de tu API.
      // NOTA: Ajusta estas llaves si tu modelo AuthUser.fromJson exige otros campos exactos.
      return AuthUser.fromJson({
        "id": 99999,
        "nombre_usuario": "apple_test",
        "nombre_completo": "Usuario Demo (Apple Review)",
        "rol": "ADMIN", // Asignamos ADMIN para que puedan revisar toda la app
        "celular": "0999999999",
        "activo": true,
      });
    }

    // 2. Flujo normal de autenticación hacia tu backend
    final response = await http.post(
      Uri.parse("$baseUrl/login"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"nombre_usuario": nombreUsuario, "password": password}),
    );

    final json = jsonDecode(response.body);

    if (response.statusCode == 200 && json["success"] == true) {
      return AuthUser.fromJson(json["data"]);
    }

    throw Exception(json["message"] ?? "Usuario o contraseña incorrectos");
  }
}
