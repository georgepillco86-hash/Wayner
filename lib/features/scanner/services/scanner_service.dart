import '../../../core/network/api_client.dart';
import '../../products/data/models/product_price.dart';

class ScannerService {
  final ApiClient _apiClient = ApiClient();

  Future<ProductPrice> buscarProductoPorCodigo(String codigoBarra) async {
    final response = await _apiClient.get(
      '/api/productos/escanear/$codigoBarra',
    );

    return ProductPrice.fromJson(response['data']);
  }
}