import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_headers.dart';
import 'api_exception.dart';

class ApiClient {
  final http.Client _client;
  final Duration timeout;

  ApiClient({http.Client? client, this.timeout = const Duration(seconds: 12)})
    : _client = client ?? http.Client();

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path').replace(
      queryParameters: queryParameters?.map(
        (key, value) => MapEntry(key, value?.toString() ?? ''),
      ),
    );

    try {
      final response = await _client
          .get(uri, headers: await AuthHeaders.plain())
          .timeout(timeout);
      return _handleResponse(response, uri);
    } on SocketException catch (e) {
      throw ApiException(
        'No se pudo conectar con el servidor. Verifica que el teléfono esté en la misma red local de Ferrotienda.',
        technicalMessage: e.toString(),
        type: ApiErrorType.network,
      );
    } on TimeoutException catch (e) {
      throw ApiException(
        'El servidor tardó demasiado en responder. Intenta nuevamente.',
        technicalMessage: e.toString(),
        type: ApiErrorType.timeout,
      );
    } on FormatException catch (e) {
      throw ApiException(
        'La respuesta del servidor no tiene un formato válido.',
        technicalMessage: e.toString(),
        type: ApiErrorType.invalidResponse,
      );
    } on http.ClientException catch (e) {
      throw ApiException(
        'No se pudo completar la consulta al servidor.',
        technicalMessage: e.toString(),
        type: ApiErrorType.network,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        'Ocurrió un error inesperado al consultar el servidor.',
        technicalMessage: e.toString(),
        type: ApiErrorType.unknown,
      );
    }
  }

  Future<dynamic> post(String path, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');

    try {
      final response = await _client
          .post(
            uri,
            headers: await AuthHeaders.json(),
            body: jsonEncode(body ?? {}),
          )
          .timeout(timeout);

      return _handleResponse(response, uri);
    } on SocketException catch (e) {
      throw ApiException(
        'No se pudo conectar con el servidor.',
        technicalMessage: e.toString(),
        type: ApiErrorType.network,
      );
    } on TimeoutException catch (e) {
      throw ApiException(
        'El servidor tardó demasiado en responder.',
        technicalMessage: e.toString(),
        type: ApiErrorType.timeout,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        'Ocurrió un error inesperado.',
        technicalMessage: e.toString(),
        type: ApiErrorType.unknown,
      );
    }
  }

  Future<dynamic> patch(String path, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');

    try {
      final response = await _client
          .patch(
            uri,
            headers: await AuthHeaders.json(),
            body: jsonEncode(body ?? {}),
          )
          .timeout(timeout);

      return _handleResponse(response, uri);
    } on SocketException catch (e) {
      throw ApiException(
        'No se pudo conectar con el servidor.',
        technicalMessage: e.toString(),
        type: ApiErrorType.network,
      );
    } on TimeoutException catch (e) {
      throw ApiException(
        'El servidor tardó demasiado en responder.',
        technicalMessage: e.toString(),
        type: ApiErrorType.timeout,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        'Ocurrió un error inesperado.',
        technicalMessage: e.toString(),
        type: ApiErrorType.unknown,
      );
    }
  }

  Future<dynamic> delete(String path) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');

    try {
      final response = await _client
          .delete(uri, headers: await AuthHeaders.plain())
          .timeout(timeout);
      return _handleResponse(response, uri);
    } on SocketException catch (e) {
      throw ApiException(
        'No se pudo conectar con el servidor.',
        technicalMessage: e.toString(),
        type: ApiErrorType.network,
      );
    } on TimeoutException catch (e) {
      throw ApiException(
        'El servidor tardó demasiado en responder.',
        technicalMessage: e.toString(),
        type: ApiErrorType.timeout,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        'Ocurrió un error inesperado.',
        technicalMessage: e.toString(),
        type: ApiErrorType.unknown,
      );
    }
  }

  dynamic _handleResponse(http.Response response, Uri uri) {
    dynamic decoded;

    try {
      decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException catch (e) {
      throw ApiException(
        'La respuesta del servidor no tiene un formato válido.',
        technicalMessage: 'URI: $uri | ${e.toString()}',
        statusCode: response.statusCode,
        type: ApiErrorType.invalidResponse,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map && decoded['message'] != null
          ? decoded['message'].toString()
          : _messageForStatusCode(response.statusCode);

      throw ApiException(
        message,
        technicalMessage:
            'HTTP ${response.statusCode} | URI: $uri | Body: ${response.body}',
        statusCode: response.statusCode,
        type: _typeForStatusCode(response.statusCode),
      );
    }

    if (decoded is Map && decoded['success'] == false) {
      throw ApiException(
        decoded['message']?.toString() ?? 'La operación no fue exitosa.',
        technicalMessage: 'URI: $uri | Body: ${response.body}',
        statusCode: response.statusCode,
        type: ApiErrorType.http,
      );
    }

    return decoded;
  }

  String _messageForStatusCode(int statusCode) {
    if (statusCode == 404) {
      return 'No se encontró información para la consulta realizada.';
    }
    if (statusCode == 400) return 'La solicitud enviada no es válida.';
    if (statusCode == 401 || statusCode == 403) {
      return 'No tienes permisos para realizar esta acción.';
    }
    if (statusCode >= 500) {
      return 'El servidor presentó un problema interno. Intenta nuevamente.';
    }
    return 'No se pudo completar la consulta. Código HTTP: $statusCode.';
  }

  ApiErrorType _typeForStatusCode(int statusCode) {
    if (statusCode == 404) return ApiErrorType.notFound;
    if (statusCode >= 500) return ApiErrorType.server;
    return ApiErrorType.http;
  }
}
