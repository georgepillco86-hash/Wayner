import '../../../core/network/api_client.dart';
import '../../../core/storage/session_storage.dart';
import '../models/audit_log.dart';

class AuditLogService {
  final ApiClient _apiClient;

  AuditLogService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  Future<List<AuditLog>> listarLogs({
    int limit = 100,
    int offset = 0,
    String? accion,
    String? modulo,
    String? nombreUsuario,
    String? desde,
    String? hasta,
  }) async {
    final user = await SessionStorage.getUser();

    if (user == null || user.rol.trim().toUpperCase() != 'ADMIN') {
      throw Exception('Solo el administrador puede consultar los logs');
    }

    final query = <String, dynamic>{
      'usuario_solicitante_id': user.id,
      'limit': limit,
      'offset': offset,
    };

    if (accion != null && accion.trim().isNotEmpty) {
      query['accion'] = accion.trim();
    }

    if (modulo != null && modulo.trim().isNotEmpty) {
      query['modulo'] = modulo.trim();
    }

    if (nombreUsuario != null && nombreUsuario.trim().isNotEmpty) {
      query['nombre_usuario'] = nombreUsuario.trim();
    }

    if (desde != null && desde.trim().isNotEmpty) {
      query['desde'] = desde.trim();
    }

    if (hasta != null && hasta.trim().isNotEmpty) {
      query['hasta'] = hasta.trim();
    }

    final response = await _apiClient.get('/api/logs', queryParameters: query);
    final rawData = response['data'];

    List<dynamic> data;

    if (rawData is List) {
      data = rawData;
    } else if (rawData is Map && rawData['items'] is List) {
      data = rawData['items'] as List<dynamic>;
    } else {
      data = [];
    }

    return data
        .map((item) => AuditLog.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> registrarEvento({
    required String accion,
    required String modulo,
    required String detalle,
  }) async {
    final user = await SessionStorage.getUser();

    final body = {
      'usuario_id': user?.id,
      'nombre_usuario': user?.nombreUsuario,
      'rol': user?.rol,
      'accion': accion,
      'modulo': modulo,
      'detalle': detalle,
    };

    try {
      await _apiClient.post('/api/logs', body: body);
    } catch (_) {
      // El log frontend no debe romper impresión, navegación ni flujos principales.
    }
  }
}