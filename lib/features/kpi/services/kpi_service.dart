import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/storage/session_storage.dart';

class KpiService {
  final String baseUrl = "http://192.168.1.231:5000/api/kpi";

  Future<Map<String, String>> _getHeaders() async {
    final user = await SessionStorage.getUser();
    return {
      'Content-Type': 'application/json',
      'x-user-name': user?.nombreUsuario ?? 'Desconocido',
      'x-user-role': user?.rol ?? '',
    };
  }

  // ==========================================
  // SECCIONES
  // ==========================================
  Future<List<dynamic>> obtenerSecciones() async {
    final response = await http.get(
      Uri.parse('$baseUrl/secciones'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Error al cargar secciones');
  }

  // ==========================================
  // BANCO DE TAREAS (CATÁLOGO)
  // ==========================================
  Future<List<dynamic>> obtenerBancoTareas() async {
    final response = await http.get(
      Uri.parse('$baseUrl/banco-tareas'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Error al cargar banco de tareas');
  }

  Future<void> crearTareaBanco(Map<String, dynamic> tarea) async {
    final response = await http.post(
      Uri.parse('$baseUrl/banco-tareas'),
      headers: await _getHeaders(),
      body: jsonEncode(tarea),
    );
    if (response.statusCode != 200) throw Exception('Error al crear tarea');
  }

  Future<void> editarTareaBanco(int tareaId, Map<String, dynamic> tarea) async {
    final response = await http.put(
      Uri.parse('$baseUrl/banco-tareas/$tareaId'),
      headers: await _getHeaders(),
      body: jsonEncode(tarea),
    );
    if (response.statusCode != 200) throw Exception('Error al editar tarea');
  }

  Future<void> eliminarTareaBanco(int tareaId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/banco-tareas/$tareaId'),
      headers: await _getHeaders(),
    );
    if (response.statusCode != 200) throw Exception('Error al eliminar tarea');
  }

  // ==========================================
  // TAREAS DIARIAS (ASIGNACIÓN Y SEGUIMIENTO)
  // ==========================================
  Future<void> asignarTarea(int tareaId, String usuario, String fecha) async {
    final response = await http.post(
      Uri.parse('$baseUrl/tareas-diarias/asignar'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'tarea_id': tareaId,
        'usuario': usuario,
        'fecha': fecha,
      }),
    );
    if (response.statusCode != 200) throw Exception('Error al asignar tarea');
  }

  Future<List<dynamic>> obtenerMisTareas(String usuario, String fecha) async {
    final response = await http.get(
      Uri.parse('$baseUrl/tareas-diarias/$usuario?fecha=$fecha'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Error al cargar mis tareas');
  }

  Future<void> marcarTareaRevision(int tareaId, String nombreTarea) async {
    final response = await http.patch(
      Uri.parse(
        '$baseUrl/tareas-diarias/$tareaId/revision?nombre_tarea=$nombreTarea',
      ),
      headers: await _getHeaders(),
    );
    if (response.statusCode != 200) throw Exception('Error al marcar revisión');
  }

  Future<void> evaluarTarea(
    int tareaId,
    double calificacion,
    String comentario,
    String usuarioTrabajador,
    String nombreTarea,
  ) async {
    final response = await http.patch(
      Uri.parse(
        '$baseUrl/tareas-diarias/$tareaId/evaluar?usuario_trabajador=$usuarioTrabajador&nombre_tarea=$nombreTarea',
      ),
      headers: await _getHeaders(),
      body: jsonEncode({
        'calificacion': calificacion,
        'comentario_admin': comentario,
      }),
    );
    if (response.statusCode != 200) throw Exception('Error al evaluar tarea');
  }

  // ==========================================
  // REPORTES Y RANKING
  // ==========================================
  Future<List<dynamic>> obtenerRankingMes(int mes, int anio) async {
    final response = await http.get(
      Uri.parse('$baseUrl/ranking?mes=$mes&anio=$anio'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Error al cargar ranking');
  }

  // 🔥 NUEVO: Función para consultar las evaluaciones detalladas (Business Intelligence) 🔥
  Future<List<dynamic>> obtenerEvaluacionesMes(int mes, int anio) async {
    final response = await http.get(
      Uri.parse('$baseUrl/evaluaciones-mes?mes=$mes&anio=$anio'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Error al cargar detalle de evaluaciones');
  }

  // ==========================================
  // USUARIOS Y AUDITORÍA
  // ==========================================
  Future<List<dynamic>> obtenerUsuarios() async {
    final response = await http.get(
      Uri.parse("http://192.168.1.231:5000/api/usuarios"),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['data'];
    }
    throw Exception('Error al cargar usuarios');
  }

  Future<List<dynamic>> obtenerTareasEnRevision() async {
    final response = await http.get(
      Uri.parse('$baseUrl/tareas-diarias/revision'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Error al cargar tareas en revisión');
  }

  // ==========================================
  // 🔥 ROBOT GUARDIÁN 🔥
  // ==========================================
  Future<void> forzarGuardianRutinas() async {
    final response = await http.post(
      Uri.parse('$baseUrl/cron/asignar-rutinas'),
      headers: await _getHeaders(),
    );
    if (response.statusCode != 200) {
      throw Exception('Error al ejecutar el guardián');
    }
  }

  // ==========================================
  // PLANTILLAS DE ACTIVIDADES
  // ==========================================
  Future<List<dynamic>> obtenerPlantillas() async {
    final res = await http.get(
      Uri.parse('$baseUrl/plantillas'),
      headers: await _getHeaders(),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Error al cargar plantillas');
  }

  Future<void> crearPlantilla(Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('$baseUrl/plantillas'),
      headers: await _getHeaders(),
      body: jsonEncode(data),
    );
    if (res.statusCode != 200) throw Exception('Error al crear plantilla');
  }

  // 🔥 NUEVO: Función para editar plantillas
  Future<void> editarPlantilla(int id, Map<String, dynamic> data) async {
    final res = await http.put(
      Uri.parse('$baseUrl/plantillas/$id'),
      headers: await _getHeaders(),
      body: jsonEncode(data),
    );
    if (res.statusCode != 200) throw Exception('Error al editar plantilla');
  }

  Future<void> eliminarPlantilla(int id) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/plantillas/$id'),
      headers: await _getHeaders(),
    );
    if (res.statusCode != 200) throw Exception('Error al eliminar plantilla');
  }

  // ==========================================
  // PREMIOS Y CASTIGOS MENSUALES
  // ==========================================
  Future<Map<String, dynamic>> obtenerPremioMes(int mes, int anio) async {
    final res = await http.get(
      Uri.parse('$baseUrl/premios-mensuales?mes=$mes&anio=$anio'),
      headers: await _getHeaders(),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Error al cargar premios');
  }

  Future<void> guardarPremioMes(
    int mes,
    int anio,
    String premio,
    String castigo,
  ) async {
    final data = {
      "mes": mes,
      "anio": anio,
      "premio": premio,
      "castigo": castigo,
    };
    final res = await http.post(
      Uri.parse('$baseUrl/premios-mensuales'),
      headers: await _getHeaders(),
      body: jsonEncode(data),
    );
    if (res.statusCode != 200) throw Exception('Error al guardar premios');
  }
}
