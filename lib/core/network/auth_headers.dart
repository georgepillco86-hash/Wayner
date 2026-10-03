import '../storage/session_storage.dart';

class AuthHeaders {
  static Future<Map<String, String>> json() async {
    final user = await SessionStorage.getUser();

    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    if (user != null) {
      headers['x-user-id'] = user.id.toString();
      headers['x-user-name'] = user.nombreUsuario;
      headers['x-user-role'] = user.rol;
    }

    return headers;
  }

  static Future<Map<String, String>> plain() async {
    final user = await SessionStorage.getUser();

    final headers = <String, String>{};

    if (user != null) {
      headers['x-user-id'] = user.id.toString();
      headers['x-user-name'] = user.nombreUsuario;
      headers['x-user-role'] = user.rol;
    }

    return headers;
  }
}
