import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/storage/session_storage.dart';

class HorariosMapaService {
  final String baseUrl = "http://192.168.1.231:5000/api/horarios-mapa";

  Future<Map<String, String>> _getHeaders() async {
    final user = await SessionStorage.getUser();
    return {
      'Content-Type': 'application/json',
      'x-user-name': user?.nombreUsuario ?? 'Desconocido',
    };
  }

  // ==========================================
  // HORARIOS
  // ==========================================
  Future<List<dynamic>> obtenerHorarios() async {
    final res = await http.get(
      Uri.parse('$baseUrl/horarios'),
      headers: await _getHeaders(),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Error al cargar horarios');
  }

  Future<void> crearHorario(Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('$baseUrl/horarios'),
      headers: await _getHeaders(),
      body: jsonEncode(data),
    );
    if (res.statusCode != 200) {
      throw Exception('Error al guardar horario');
    }
  }

  // ==========================================
  // ZONAS DEL MAPA
  // ==========================================
  Future<List<dynamic>> obtenerZonas() async {
    final res = await http.get(
      Uri.parse('$baseUrl/zonas'),
      headers: await _getHeaders(),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Error al cargar zonas');
  }

  Future<void> crearZona(String nombre, String colorHex) async {
    final res = await http.post(
      Uri.parse('$baseUrl/zonas'),
      headers: await _getHeaders(),
      body: jsonEncode({"nombre": nombre, "color_hex": colorHex}),
    );
    if (res.statusCode != 200) {
      throw Exception('Error al crear zona');
    }
  }

  Future<void> eliminarZona(int zonaId) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/zonas/$zonaId'),
      headers: await _getHeaders(),
    );
    if (res.statusCode != 200) {
      throw Exception('Error al eliminar zona');
    }
  }

  // ==========================================
  // CUADRÍCULA (EL DIBUJO)
  // ==========================================
  Future<List<dynamic>> obtenerCuadricula() async {
    final res = await http.get(
      Uri.parse('$baseUrl/cuadricula'),
      headers: await _getHeaders(),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Error al cargar cuadrícula');
  }

  Future<void> guardarCuadricula(List<Map<String, dynamic>> celdas) async {
    final res = await http.post(
      Uri.parse('$baseUrl/cuadricula'),
      headers: await _getHeaders(),
      body: jsonEncode({"celdas": celdas}),
    );
    if (res.statusCode != 200) {
      throw Exception('Error al guardar mapa');
    }
  }

  // ==========================================
  // ASIGNACIONES DEL MAPA 2D
  // ==========================================
  Future<void> crearAsignacion(Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('$baseUrl/asignaciones'),
      headers: await _getHeaders(),
      body: jsonEncode(data),
    );
    if (res.statusCode != 200) {
      throw Exception('Error al asignar zona al colaborador');
    }
  }

  // ==========================================
  // LO QUE VERÁ EL TRABAJADOR
  // ==========================================
  Future<Map<String, dynamic>> obtenerMiZonaActual() async {
    final res = await http.get(
      Uri.parse('$baseUrl/mi-zona'),
      headers: await _getHeaders(),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Error al cargar mi zona');
  }

  // ==========================================
  // NUEVAS FUNCIONES: ELIMINAR Y ASIGNACIONES
  // ==========================================
  Future<void> eliminarHorarioDia(String usuario, int diaSemana) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/horarios/$usuario/$diaSemana'),
      headers: await _getHeaders(),
    );
    if (res.statusCode != 200) {
      throw Exception('Error al eliminar horario');
    }
  }

  Future<List<dynamic>> obtenerAsignaciones() async {
    final res = await http.get(
      Uri.parse('$baseUrl/asignaciones'),
      headers: await _getHeaders(),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Error al cargar asignaciones');
  }

  Future<void> eliminarAsignacion(int asignacionId) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/asignaciones/$asignacionId'),
      headers: await _getHeaders(),
    );
    if (res.statusCode != 200) {
      throw Exception('Error al eliminar asignación');
    }
  }
}
