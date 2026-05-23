import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_service.dart';

class RecordatoriosService {
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _headers() async {
    final token = await _authService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Sesión expirada. Inicie sesión nuevamente.');
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  dynamic _decodeResponse(http.Response response) {
    if (response.body.isEmpty) {
      return null;
    }

    try {
      return jsonDecode(response.body);
    } catch (_) {
      return response.body;
    }
  }

  String _extractErrorMessage(dynamic body, String fallback) {
    if (body is Map<String, dynamic>) {
      final message = body['message'];

      if (message is List) {
        return message.join('\n');
      }

      if (message != null) {
        return message.toString();
      }

      final error = body['error'];

      if (error != null) {
        return error.toString();
      }
    }

    if (body is String && body.trim().isNotEmpty) {
      return body;
    }

    return fallback;
  }

  List<Map<String, dynamic>> _asList(dynamic body) {
    if (body is List) {
      return body
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    if (body is Map<String, dynamic>) {
      final data = body['data'];

      if (data is List) {
        return data
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    }

    return [];
  }

  Map<String, dynamic> _asMap(dynamic body) {
    if (body is Map<String, dynamic>) {
      final data = body['data'];

      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }

      return body;
    }

    return {};
  }

  Future<List<Map<String, dynamic>>> getRecordatorios() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/recordatorios'),
      headers: await _headers(),
    );

    final body = _decodeResponse(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _asList(body);
    }

    throw Exception(
      _extractErrorMessage(body, 'Error al cargar los recordatorios.'),
    );
  }

  Future<List<Map<String, dynamic>>> getRecordatoriosProyecto(
    int proyectoId,
  ) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/proyectos/$proyectoId/recordatorios'),
      headers: await _headers(),
    );

    final body = _decodeResponse(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _asList(body);
    }

    throw Exception(
      _extractErrorMessage(
        body,
        'Error al cargar los recordatorios del proyecto.',
      ),
    );
  }

  Future<Map<String, dynamic>> crearRecordatorio({
    required int proyectoId,
    required String titulo,
    required String descripcion,
    required String fecha,
    required String hora,
    required String prioridad,
    bool completado = false,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/proyectos/$proyectoId/recordatorios'),
      headers: await _headers(),
      body: jsonEncode({
        'titulo': titulo,
        'descripcion': descripcion,
        'fecha': fecha,
        'hora': hora,
        'prioridad': prioridad,
        'completado': completado,
      }),
    );

    final body = _decodeResponse(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _asMap(body);
    }

    throw Exception(
      _extractErrorMessage(body, 'Error al crear el recordatorio.'),
    );
  }

  Future<Map<String, dynamic>> actualizarRecordatorio({
    required int id,
    required String titulo,
    required String descripcion,
    required String fecha,
    required String hora,
    required String prioridad,
    required bool completado,
  }) async {
    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/recordatorios/$id'),
      headers: await _headers(),
      body: jsonEncode({
        'titulo': titulo,
        'descripcion': descripcion,
        'fecha': fecha,
        'hora': hora,
        'prioridad': prioridad,
        'completado': completado,
      }),
    );

    final body = _decodeResponse(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _asMap(body);
    }

    throw Exception(
      _extractErrorMessage(body, 'Error al actualizar el recordatorio.'),
    );
  }

  Future<Map<String, dynamic>> alternarCompletado(int id) async {
    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/recordatorios/$id/toggle'),
      headers: await _headers(),
    );

    final body = _decodeResponse(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _asMap(body);
    }

    throw Exception(
      _extractErrorMessage(
        body,
        'Error al cambiar el estado del recordatorio.',
      ),
    );
  }

  Future<void> eliminarRecordatorio(int id) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/recordatorios/$id'),
      headers: await _headers(),
    );

    final body = _decodeResponse(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    throw Exception(
      _extractErrorMessage(body, 'Error al eliminar el recordatorio.'),
    );
  }
}
