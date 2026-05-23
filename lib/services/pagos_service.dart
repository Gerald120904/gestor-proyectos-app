import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_service.dart';

class PagosService {
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

  Future<Map<String, dynamic>> getPagosProyecto(int proyectoId) async {
    final url = Uri.parse(
      '${ApiConfig.baseUrl}/proyectos/$proyectoId/pagos',
    );

    final response = await http.get(
      url,
      headers: await _headers(),
    );

    final data = _decodeResponse(response);

    _validarRespuesta(
      response,
      data,
      'Error al obtener pagos.',
    );

    return _toMap(data);
  }

  Future<Map<String, dynamic>> crearPago({
    required int proyectoId,
    required double monto,
    required String fecha,
    required String metodo,
    required String observacion,
  }) async {
    final url = Uri.parse(
      '${ApiConfig.baseUrl}/proyectos/$proyectoId/pagos',
    );

    final response = await http.post(
      url,
      headers: await _headers(),
      body: jsonEncode({
        'monto': monto,
        'fecha': fecha,
        'metodo': metodo,
        'observacion': observacion,
      }),
    );

    final data = _decodeResponse(response);

    _validarRespuesta(
      response,
      data,
      'Error al crear pago.',
    );

    return _toMap(data);
  }

  Future<Map<String, dynamic>> actualizarPago({
    required int id,
    required double monto,
    required String fecha,
    required String metodo,
    required String observacion,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/pagos/$id');

    final response = await http.patch(
      url,
      headers: await _headers(),
      body: jsonEncode({
        'monto': monto,
        'fecha': fecha,
        'metodo': metodo,
        'observacion': observacion,
      }),
    );

    final data = _decodeResponse(response);

    _validarRespuesta(
      response,
      data,
      'Error al actualizar pago.',
    );

    return _toMap(data);
  }

  Future<void> eliminarPago(int id) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/pagos/$id');

    final response = await http.delete(
      url,
      headers: await _headers(),
    );

    final data = _decodeResponse(response);

    _validarRespuesta(
      response,
      data,
      'Error al eliminar pago.',
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