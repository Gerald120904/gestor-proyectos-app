import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_service.dart';

class ComentariosService {
  final AuthService authService = AuthService();

  Future<Map<String, String>> _headers() async {
    final token = await authService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('No hay sesión activa.');
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  dynamic _decodeResponse(http.Response response) {
    if (response.body.trim().isEmpty) {
      return {};
    }

    try {
      return jsonDecode(response.body);
    } catch (_) {
      return {
        'message': 'El servidor respondió con un formato no válido.',
      };
    }
  }

  Map<String, dynamic> _toMap(dynamic data) {
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    return {};
  }

  List<Map<String, dynamic>> _toList(dynamic data) {
    if (data is List) {
      return data.map((item) {
        return Map<String, dynamic>.from(item);
      }).toList();
    }

    return [];
  }

  void _validarRespuesta(
    http.Response response,
    dynamic data,
    String fallback,
  ) {
    if (response.statusCode >= 400) {
      throw Exception(
        _getErrorMessage(data, fallback),
      );
    }
  }

  Future<List<Map<String, dynamic>>> getComentariosProyecto(
    int proyectoId,
  ) async {
    final url = Uri.parse(
      '${ApiConfig.baseUrl}/proyectos/$proyectoId/comentarios',
    );

    final response = await http.get(
      url,
      headers: await _headers(),
    );

    final data = _decodeResponse(response);

    _validarRespuesta(
      response,
      data,
      'Error al obtener comentarios.',
    );

    return _toList(data);
  }

  Future<Map<String, dynamic>> crearComentario({
    required int proyectoId,
    required String titulo,
    required String contenido,
    required String fecha,
  }) async {
    final url = Uri.parse(
      '${ApiConfig.baseUrl}/proyectos/$proyectoId/comentarios',
    );

    final response = await http.post(
      url,
      headers: await _headers(),
      body: jsonEncode({
        'titulo': titulo,
        'contenido': contenido,
        'fecha': fecha,
      }),
    );

    final data = _decodeResponse(response);

    _validarRespuesta(
      response,
      data,
      'Error al crear comentario.',
    );

    return _toMap(data);
  }

  Future<Map<String, dynamic>> actualizarComentario({
    required int id,
    required String titulo,
    required String contenido,
    required String fecha,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/comentarios/$id');

    final response = await http.patch(
      url,
      headers: await _headers(),
      body: jsonEncode({
        'titulo': titulo,
        'contenido': contenido,
        'fecha': fecha,
      }),
    );

    final data = _decodeResponse(response);

    _validarRespuesta(
      response,
      data,
      'Error al actualizar comentario.',
    );

    return _toMap(data);
  }

  Future<void> eliminarComentario(int id) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/comentarios/$id');

    final response = await http.delete(
      url,
      headers: await _headers(),
    );

    final data = _decodeResponse(response);

    _validarRespuesta(
      response,
      data,
      'Error al eliminar comentario.',
    );
  }

  String _getErrorMessage(dynamic data, String fallback) {
    if (data is Map) {
      final message = data['message'];

      if (message is String && message.trim().isNotEmpty) {
        return message;
      }

      if (message is List) {
        return message.join('\n');
      }

      final error = data['error'];

      if (error is String && error.trim().isNotEmpty) {
        return error;
      }
    }

    return fallback;
  }
}