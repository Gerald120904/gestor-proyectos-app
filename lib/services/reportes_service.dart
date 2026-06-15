import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_service.dart';

class UnauthorizedException implements Exception {
  final String message;

  UnauthorizedException(this.message);

  @override
  String toString() => message;
}

class ReportesService {
  ReportesService({AuthService? authService})
    : authService = authService ?? AuthService();

  final AuthService authService;

  String get baseUrl => ApiConfig.baseUrl;

  Future<String?> getCurrentToken() async {
    return authService.getToken();
  }

  Future<Map<String, dynamic>> getGeneralReport({
    String period = 'month',
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return _getReport(
      '/reports/general',
      period: period,
      startDate: startDate,
      endDate: endDate,
    );
  }

  Future<Map<String, dynamic>> getSummaryReport({
    String period = 'month',
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return _getReport(
      '/reports/summary',
      period: period,
      startDate: startDate,
      endDate: endDate,
    );
  }

  Future<Map<String, dynamic>> _getReport(
    String path, {
    required String period,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final token = await authService.getToken();

    if (token == null || token.trim().isEmpty) {
      throw UnauthorizedException(
        'No hay sesión activa. Inicia sesión de nuevo.',
      );
    }

    final query = <String, String>{'period': period};

    if (period == 'custom') {
      if (startDate == null || endDate == null) {
        throw Exception('Debe seleccionar fecha inicial y fecha final.');
      }

      query['startDate'] = _formatDate(startDate);
      query['endDate'] = _formatDate(endDate);
    }

    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0',
        'Authorization': 'Bearer $token',
      },
    );

    final decoded = _decodeResponse(response.body);

    if (response.statusCode == 401) {
      await authService.logout();
      throw UnauthorizedException(
        _extractErrorMessage(decoded) == 'No se pudo cargar el reporte.'
            ? 'Tu sesión expiró. Inicia sesión nuevamente.'
            : _extractErrorMessage(decoded),
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      throw Exception('La respuesta del reporte no tiene el formato esperado.');
    }

    throw Exception(_extractErrorMessage(decoded));
  }

  dynamic _decodeResponse(String body) {
    if (body.trim().isEmpty) return null;

    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }

  String _extractErrorMessage(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      final message = decoded['message'];

      if (message is List) {
        return message.join('\n');
      }

      if (message != null) {
        return message.toString();
      }

      if (decoded['error'] != null) {
        return decoded['error'].toString();
      }
    }

    if (decoded != null) {
      return decoded.toString();
    }

    return 'No se pudo cargar el reporte.';
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }
}
