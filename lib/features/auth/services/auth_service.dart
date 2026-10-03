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
    final response = await http.post(
      Uri.parse("$baseUrl/login"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "nombre_usuario": nombreUsuario,
        "password": password,
      }),
    );

    final json = jsonDecode(response.body);

    if (response.statusCode == 200 && json["success"] == true) {
      return AuthUser.fromJson(json["data"]);
    }

    throw Exception(json["message"] ?? "Usuario o contraseña incorrectos");
  }
}