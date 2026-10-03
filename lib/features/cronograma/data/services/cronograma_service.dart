import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/storage/session_storage.dart';
import '../../../../core/config/api_config.dart';
import '../models/visita_model.dart';
import '../models/notificacion_model.dart';

class CronogramaService {
  final String baseUrl = '${ApiConfig.baseUrl}/api/cronograma';

  Future<Map<String, String>> _getHeaders() async {
    final user = await SessionStorage.getUser();
    return {
      'Content-Type': 'application/json',
      'X-Usuario': user?.nombreUsuario ?? 'Desconocido',
    };
  }

  // 1. Crear una nueva programación
  Future<bool> crearProgramacion({
    required String proveedor,
    required String
    contactoCelular, // 🔥 NUEVO: Recibimos el número de WhatsApp
    required String frecuencia,
    required List<Map<String, DateTime>> paresVisitaEntrega,
    required int repetirMeses,
    required List<String> usuariosVinculados,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'proveedor': proveedor,
        'contacto_celular': contactoCelular, // 🔥 NUEVO: Lo enviamos al backend
        'frecuencia': frecuencia,
        'repetir_meses': repetirMeses,
        'usuarios_vinculados': usuariosVinculados,
        // Convertimos los pares de Flutter a un formato JSON seguro
        'pares': paresVisitaEntrega
            .map(
              (par) => {
                'visita': par['visita']!.toIso8601String(),
                'entrega': par['entrega']!.toIso8601String(),
              },
            )
            .toList(),
      }),
    );

    if (response.statusCode == 200) return true;
    throw Exception('Error al crear el cronograma');
  }

  // 2. Obtener las visitas para pintar el calendario
  Future<List<Visita>> obtenerVisitasDelMes(int anio, int mes) async {
    final response = await http.get(
      Uri.parse('$baseUrl/calendario/$anio/$mes'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((item) => Visita.fromJson(item)).toList();
    }
    throw Exception('Error al cargar el calendario');
  }

  // 3. Obtener alertas del usuario actual
  Future<List<Notificacion>> misNotificaciones() async {
    final response = await http.get(
      Uri.parse('$baseUrl/notificaciones'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((item) => Notificacion.fromJson(item)).toList();
    }
    throw Exception('Error al cargar notificaciones');
  }

  // 4. Marcar alerta como leída
  Future<bool> marcarComoLeida(int idNotificacion) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/notificaciones/$idNotificacion/leer'),
      headers: await _getHeaders(),
    );
    return response.statusCode == 200;
  }

  // --- Obtener lista de proveedores para el autocompletado ---
  Future<List<String>> obtenerProveedores() async {
    // Apuntamos al endpoint de proveedores que creamos en Python
    final url = baseUrl.replaceAll('/cronograma', '/proveedores');
    final response = await http.get(
      Uri.parse('$url/'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((item) => item.toString()).toList();
    }
    // Si hay un error, devolvemos una lista vacía para no romper la pantalla
    return [];
  }

  // =====================================================================
  // 🔥 NUEVOS MÉTODOS PARA LA ADMINISTRACIÓN DE PROVEEDORES 🔥
  // =====================================================================

  // 5. Obtener lista de secuencias agrupadas (Para la pantalla de administración)
  Future<List<dynamic>> obtenerSecuenciasProgramadas() async {
    final response = await http.get(
      Uri.parse('$baseUrl/secuencias'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> body = jsonDecode(response.body);
      if (body['status'] == 'success') {
        return body['data'] as List<dynamic>;
      }
      return [];
    }
    throw Exception('Error al cargar las secuencias programadas');
  }

  // 6. Eliminar una secuencia completa
  Future<void> eliminarSecuencia(int id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/secuencias/$id'),
      headers: await _getHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('Error al eliminar la secuencia');
    }
  }
}
