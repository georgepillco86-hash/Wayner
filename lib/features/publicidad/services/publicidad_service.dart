import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class PublicidadService {
  // 🔥 Reemplaza con la IP/Dominio de tu API FastAPI
  static const String baseUrl = 'http://192.168.1.231:5000/api/publicidad';

  // 1. OBTENER TODOS LOS ANUNCIOS
  Future<List<Map<String, dynamic>>> obtenerAnuncios() async {
    try {
      final response = await http.get(Uri.parse(baseUrl));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Error al cargar la publicidad');
      }
    } catch (e) {
      debugPrint('Error en obtenerAnuncios: $e');
      return [];
    }
  }

  // 2. ACTUALIZAR EL ORDEN (Cuando arrastras un ítem en la lista)
  Future<bool> actualizarOrden(
    List<Map<String, dynamic>> anunciosOrdenados,
  ) async {
    try {
      // Extraemos solo los IDs en el nuevo orden para enviar al backend
      final nuevoOrden = anunciosOrdenados.map((a) => {'id': a['id']}).toList();

      final response = await http.put(
        Uri.parse('$baseUrl/orden'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'orden': nuevoOrden}),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error en actualizarOrden: $e');
      return false;
    }
  }

  // 3. CAMBIAR ESTADO (Switch de Activo/Inactivo)
  Future<bool> toggleEstado(int id, bool activo) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/$id/estado'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'activo': activo}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error en toggleEstado: $e');
      return false;
    }
  }

  // 4. ELIMINAR ANUNCIO
  Future<bool> eliminarAnuncio(int id) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/$id'));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error en eliminarAnuncio: $e');
      return false;
    }
  }
}
