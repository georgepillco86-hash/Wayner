import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../products/data/models/product_price.dart';
import '../../../products/data/models/sales_summary.dart';
import '../models/product_balance.dart';

class SaldosApiService {
  final ApiClient _apiClient;

  SaldosApiService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  List<dynamic> _extractData(dynamic response) {
    if (response is Map && response['data'] is List) {
      return response['data'] as List;
    }
    return [];
  }

  Map<String, dynamic>? _extractMap(dynamic response) {
    if (response is Map && response['data'] is Map<String, dynamic>) {
      return response['data'] as Map<String, dynamic>;
    }
    return null;
  }

  // =====================================================================
  // 🔥 MÉTODOS NUEVOS PARA "REALIZAR PEDIDO INTELIGENTE" 🔥
  // =====================================================================

  Future<List<dynamic>> buscarRapido({
    required String termino,
    String? clase,
    String? proveedor,
  }) async {
    try {
      final params = <String, dynamic>{'q': termino};

      if (clase != null && clase.isNotEmpty) params['clase'] = clase;
      if (proveedor != null && proveedor.isNotEmpty)
        params['proveedor'] = proveedor;

      final response = await _apiClient.get(
        '/api/proveedores/buscar-rapido',
        queryParameters: params,
      );

      if (response is List) return response;
      if (response is Map && response.containsKey('data'))
        return response['data'];
      return [];
    } catch (e) {
      print("❌ ERROR EN BUSCAR RAPIDO (CARRITO): $e");
      return [];
    }
  }

  Future<List<dynamic>> buscarEnKardex(String termino) async {
    return busquedaProfundaKardex(termino);
  }

  // =====================================================================
  // MÉTODOS ORIGINALES (No se modificaron para proteger la app)
  // =====================================================================

  Future<List<ProductBalance>> searchProducts({
    required String text,
    String? clase,
    String? proveedor,
    int limit = 50,
  }) async {
    try {
      final params = <String, dynamic>{'q': text};

      if (clase != null && clase.isNotEmpty) params['clase'] = clase;
      if (proveedor != null && proveedor.isNotEmpty) {
        params['proveedor'] = proveedor;
      }

      final response = await _apiClient.get(
        '/api/proveedores/buscar-rapido',
        queryParameters: params,
      );

      List<dynamic> data = [];
      if (response is List) {
        data = response;
      } else if (response is Map && response.containsKey('data')) {
        data = response['data'];
      }

      return data
          .whereType<Map<String, dynamic>>()
          .map(ProductBalance.fromJson)
          .toList();
    } catch (e) {
      print("❌ ERROR EN SEARCH PRODUCTS (MOTOR PREDICTIVO): $e");
      return [];
    }
  }

  Future<List<ProductBalance>> getDataset({
    int limit = 50,
    String? proveedor,
  }) async {
    return searchProducts(text: '', proveedor: proveedor, limit: limit);
  }

  Future<List<ProductBalance>> getProductsByClass(
    String clase, {
    int limit = 50,
    String? proveedor,
  }) async {
    return searchProducts(
      text: '',
      clase: clase,
      proveedor: proveedor,
      limit: limit,
    );
  }

  Future<ProductBalance?> getProductByCode(String code) async {
    final response = await _apiClient.get(
      '${ApiConfig.saldosBasePath}/producto/$code',
    );
    final data = _extractMap(response);
    if (data == null) return null;
    return ProductBalance.fromJson(data);
  }

  Future<List<String>> getClasses() async {
    try {
      final response = await _apiClient.get('/api/proveedores/clases');
      if (response is List) return response.map((e) => e.toString()).toList();
      return [];
    } catch (e) {
      print("❌ ERROR AL CARGAR CLASES EN FLUTTER: $e");
      return [];
    }
  }

  Future<List<String>> getProviders() async {
    try {
      final response = await _apiClient.get('/api/proveedores/');
      if (response is List) return response.map((e) => e.toString()).toList();
      return [];
    } catch (e) {
      print("❌ ERROR AL CARGAR PROVEEDORES EN FLUTTER: $e");
      return [];
    }
  }

  Future<List<SalesSummary>> getSalesSummary(
    String codigoBarra,
    String desde,
    String hasta,
  ) async {
    final response = await _apiClient.get(
      '/api/productos/$codigoBarra/ventas-resumen',
      queryParameters: {'desde': desde, 'hasta': hasta},
    );

    return _extractData(
      response,
    ).whereType<Map<String, dynamic>>().map(SalesSummary.fromJson).toList();
  }

  Future<ProductPrice> getProductPrice(String codigoBarra) async {
    final response = await _apiClient.get(
      '/api/productos/escanear/$codigoBarra',
    );

    final data = _extractMap(response);
    if (data == null) {
      throw const ApiException(
        'No se pudo obtener el precio del producto.',
        type: ApiErrorType.invalidResponse,
      );
    }

    return ProductPrice.fromJson(data);
  }

  Future<List<Map<String, dynamic>>> getKardexTable(
    String codigoBarra,
    String desde,
    String hasta,
  ) async {
    final response = await _apiClient.get(
      '/api/productos/$codigoBarra/kardex-tabla',
      queryParameters: {'desde': desde, 'hasta': hasta},
    );

    return _extractData(response).whereType<Map<String, dynamic>>().toList();
  }

  Future<List<dynamic>> busquedaProfundaKardex(String termino) async {
    try {
      final response = await _apiClient.get(
        '/api/proveedores/busqueda-profunda',
        queryParameters: {'q': termino},
      );

      if (response is List) return response;
      if (response is Map && response['data'] is List) return response['data'];
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> obtenerPrecioVivo(String codigo) async {
    try {
      final response = await _apiClient.get(
        '/api/proveedores/producto/$codigo/precio-vivo',
      );

      if (response is Map<String, dynamic>) {
        if (response.containsKey('data')) return response['data'];
        return response;
      }
      return {"precio_vivo": 0.0, "iva_vivo": 0.0, "costo_vivo": 0.0};
    } catch (e) {
      return {"precio_vivo": 0.0, "iva_vivo": 0.0, "costo_vivo": 0.0};
    }
  }

  Future<List<String>> obtenerProveedores() async {
    try {
      final response = await _apiClient.get('/api/proveedores/');
      if (response is List) return response.map((e) => e.toString()).toList();
      return [];
    } catch (e) {
      return [];
    }
  }

  // 🔥 NUEVO: Método para obtener TODAS las marcas globales desde MySQL 🔥
  Future<List<String>> obtenerMarcasGlobales() async {
    try {
      final response = await _apiClient.get('/api/proveedores/marcas');
      if (response is List) return response.map((e) => e.toString()).toList();
      return [];
    } catch (e) {
      return [];
    }
  }
}
