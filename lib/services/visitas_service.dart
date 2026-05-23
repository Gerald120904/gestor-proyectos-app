import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_service.dart';

class VisitasService {
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

  Future<List<Map<String, dynamic>>> getVisitasProyecto(
    int proyectoId,
  ) async {
    final url = Uri.parse(
      '${ApiConfig.baseUrl}/proyectos/$proyectoId/visitas',
    );

    final response = await http.get(
      url,
      headers: await _headers(),
    );

    final data = _decodeResponse(response);

    _validarRespuesta(
      response,
      data,
      'Error al obtener visitas.',
    );

    return _toList(data);
  }

  Future<Map<String, dynamic>> crearVisita({
    required int proyectoId,
    required String fecha,
    required String hora,
    required String direccion,
    required String estado,
    required String observacion,
  }) async {
    final url = Uri.parse(
      '${ApiConfig.baseUrl}/proyectos/$proyectoId/visitas',
    );

    final response = await http.post(
      url,
      headers: await _headers(),
      body: jsonEncode({
        'fecha': fecha,
        'hora': hora,
        'direccion': direccion,
        'estado': estado,
        'observacion': observacion,
      }),
    );

    final data = _decodeResponse(response);

    _validarRespuesta(
      response,
      data,
      'Error al crear visita.',
    );

    return _toMap(data);
  }

  Future<Map<String, dynamic>> actualizarVisita({
    required int id,
    required String fecha,
    required String hora,
    required String direccion,
    required String estado,
    required String observacion,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/visitas/$id');

    final response = await http.patch(
      url,
      headers: await _headers(),
      body: jsonEncode({
        'fecha': fecha,
        'hora': hora,
        'direccion': direccion,
        'estado': estado,
        'observacion': observacion,
      }),
    );

    final data = _decodeResponse(response);

    _validarRespuesta(
      response,
      data,
      'Error al actualizar visita.',
    );

    return _toMap(data);
  }

  Future<void> eliminarVisita(int id) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/visitas/$id');

    final response = await http.delete(
      url,
      headers: await _headers(),
    );

    final data = _decodeResponse(response);

    _validarRespuesta(
      response,
      data,
      'Error al eliminar visita.',
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