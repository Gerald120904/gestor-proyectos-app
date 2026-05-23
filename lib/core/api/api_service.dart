import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  ApiService._();
  static const String baseUrl =
      'https://gestor-proyectos-backend-ezqx.onrender.com';

  static const Duration timeout = Duration(seconds: 10);

  static final http.Client _client = http.Client();

  static Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');

      final response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);

      final decoded = _decodeResponse(response);

      if (response.statusCode >= 400) {
        throw ApiException(
          decoded['message']?.toString() ??
              decoded['error']?.toString() ??
              'Error en la solicitud',
          response.statusCode,
        );
      }

      return decoded;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(
        'No se pudo conectar con el servidor. Intenta de nuevo.',
        0,
      );
    }
  }

  static Future<Map<String, dynamic>> get(
    String endpoint, {
    String? token,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');

      final response = await _client
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
          )
          .timeout(timeout);

      final decoded = _decodeResponse(response);

      if (response.statusCode >= 400) {
        throw ApiException(
          decoded['message']?.toString() ??
              decoded['error']?.toString() ??
              'Error en la solicitud',
          response.statusCode,
        );
      }

      return decoded;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(
        'No se pudo conectar con el servidor. Intenta de nuevo.',
        0,
      );
    }
  }

  static Map<String, dynamic> _decodeResponse(http.Response response) {
    if (response.body.isEmpty) {
      return {};
    }

    final decoded = jsonDecode(response.body);

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    return {'data': decoded};
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;

  ApiException(this.message, this.statusCode);

  @override
  String toString() => message;
}
