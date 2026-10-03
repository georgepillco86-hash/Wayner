import '../../../core/network/api_client.dart';
import '../models/promocion.dart';
import '../../products/data/models/product_price.dart';

class PromocionService {
  final ApiClient _apiClient = ApiClient();

  Future<ProductPrice> buscarProductoPorCodigo(String codigoBarra) async {
    final response = await _apiClient.get(
      '/api/productos/escanear/$codigoBarra',
    );

    return ProductPrice.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<List<Promocion>> listar({
    String? texto,
    String? codigoBarra,
    String? estado,
    DateTime? fechaDesde,
    DateTime? fechaHasta,
  }) async {
    final response = await _apiClient.get(
      '/api/promociones',
      queryParameters: {
        if (texto != null && texto.trim().isNotEmpty) 'texto': texto.trim(),
        if (codigoBarra != null && codigoBarra.trim().isNotEmpty)
          'codigo_barra': codigoBarra.trim(),
        if (estado != null && estado != 'TODAS') 'estado': estado,
        if (fechaDesde != null) 'fecha_desde': _formatDate(fechaDesde),
        if (fechaHasta != null) 'fecha_hasta': _formatDate(fechaHasta),
      },
    );

    final data = response['data'] as List<dynamic>;

    return data
        .map((item) => Promocion.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Promocion> crear({
    required String codigoBarra,
    required String nombreProducto,
    required double precioBase,
    required double precioAnterior,
    required double precioActualProm,
    required String encabezado,
    required DateTime fechaInicio,
    required DateTime fechaFin,
    bool activa = true,
  }) async {
    final response = await _apiClient.post(
      '/api/promociones',
      body: {
        'codigo_barra': codigoBarra,
        'nombre_producto': nombreProducto,
        'precio_base': precioBase,
        'precio_anterior': precioAnterior,
        'precio_actual_prom': precioActualProm,
        'encabezado': encabezado,
        'fecha_inicio': _formatDate(fechaInicio),
        'fecha_fin': _formatDate(fechaFin),
        'activa': activa,
      },
    );

    return Promocion.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<Promocion> actualizar({
    required int id,
    required String nombreProducto,
    required double precioBase,
    required double precioAnterior,
    required double precioActualProm,
    required String encabezado,
    required DateTime fechaInicio,
    required DateTime fechaFin,
    required bool activa,
  }) async {
    final response = await _apiClient.patch(
      '/api/promociones/$id',
      body: {
        'nombre_producto': nombreProducto,
        'precio_base': precioBase,
        'precio_anterior': precioAnterior,
        'precio_actual_prom': precioActualProm,
        'encabezado': encabezado,
        'fecha_inicio': _formatDate(fechaInicio),
        'fecha_fin': _formatDate(fechaFin),
        'activa': activa,
      },
    );

    return Promocion.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<Promocion> desactivar(int id) async {
    // Ajustado a PATCH para diferenciarlo de la eliminación real
    final response = await _apiClient.patch('/api/promociones/$id/desactivar');

    return Promocion.fromJson(response['data'] as Map<String, dynamic>);
  }

  // 🔥 NUEVO: Método para eliminar la promoción permanentemente
  Future<void> eliminar(int id) async {
    await _apiClient.delete('/api/promociones/$id');
  }

  String _formatDate(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }
}
