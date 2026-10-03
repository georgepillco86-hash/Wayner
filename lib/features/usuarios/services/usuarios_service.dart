import '../../../core/network/api_client.dart';
import '../models/usuario.dart';

class UsuariosService {
  final ApiClient _apiClient = ApiClient();

  Future<List<Usuario>> listarUsuarios() async {
    final response = await _apiClient.get('/api/usuarios');

    final data = response['data'] as List<dynamic>;

    return data
        .map((item) => Usuario.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Usuario> crearUsuario({
    required String nombreUsuario,
    required String password,
    required String nombreCompleto,
    String? celular, // 🔥 NUEVO CAMPO
    required String rol,
    required bool activo,
  }) async {
    final response = await _apiClient.post(
      '/api/usuarios',
      body: {
        'nombre_usuario': nombreUsuario,
        'password': password,
        'nombre_completo': nombreCompleto,
        'celular': celular, // 🔥 NUEVO CAMPO
        'rol': rol,
        'activo': activo,
      },
    );

    return Usuario.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<Usuario> actualizarUsuario({
    required int id,
    required String nombreUsuario,
    required String nombreCompleto,
    String? celular, // 🔥 NUEVO CAMPO
    required String rol,
    required bool activo,
  }) async {
    final response = await _apiClient.patch(
      '/api/usuarios/$id',
      body: {
        'nombre_usuario': nombreUsuario,
        'nombre_completo': nombreCompleto,
        'celular': celular, // 🔥 NUEVO CAMPO
        'rol': rol,
        'activo': activo,
      },
    );

    return Usuario.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<Usuario> cambiarPassword({
    required int id,
    required String password,
  }) async {
    final response = await _apiClient.patch(
      '/api/usuarios/$id/password',
      body: {'password': password},
    );

    return Usuario.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<Usuario> desactivarUsuario(int id) async {
    final response = await _apiClient.delete('/api/usuarios/$id');

    return Usuario.fromJson(response['data'] as Map<String, dynamic>);
  }
}
