import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_service.dart';

class DashboardService {
  final AuthService authService = AuthService();

  // Token en memoria: evita leerlo del almacenamiento en cada petición.
  static String? _cachedToken;

  // Cliente HTTP persistente: reutiliza conexiones TCP.
  static final http.Client _client = http.Client();

  static const Duration _timeout = Duration(seconds: 8);

  Future<Map<String, String>> _headers() async {
    _cachedToken ??= await authService.getToken();

    if (_cachedToken == null || _cachedToken!.isEmpty) {
      throw Exception('No hay sesión activa.');
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_cachedToken',
    };
  }

  static void clearCache() {
    _cachedToken = null;
  }

  Future<Map<String, dynamic>> _getMap(String path) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$path');

    try {
      final response = await _client
          .get(url, headers: await _headers())
          .timeout(_timeout);

      if (response.body.trim().isEmpty) return {};

      final decoded = jsonDecode(response.body);

      if (response.statusCode >= 400) {
        if (decoded is Map) {
          throw Exception(
            decoded['message'] ??
                decoded['error'] ??
                'Error al obtener información del dashboard.',
          );
        }

        throw Exception('Error al obtener información del dashboard.');
      }

      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }

      return {};
    } on SocketException {
      throw Exception('Sin conexión a internet.');
    } on TimeoutException {
      throw Exception('El servidor tardó demasiado. Intenta de nuevo.');
    } on FormatException {
      throw Exception('El servidor devolvió una respuesta inválida.');
    }
  }

  // Endpoint viejo. Se deja para compatibilidad por si alguna pantalla todavía lo usa.
  Future<Map<String, dynamic>> getDashboard() async {
    return _getMap('/dashboard');
  }

  // Primera petición: datos visibles arriba del dashboard.
  Future<Map<String, dynamic>> getResumenDashboard() async {
    return _getMap('/dashboard/resumen');
  }

  // Segunda petición: estadísticas / proyectos por estado.
  Future<Map<String, dynamic>> getEstadosDashboard() async {
    return _getMap('/dashboard/estados');
  }

  // Tercera petición: detalles bajo demanda.
  Future<List<Map<String, dynamic>>> getUltimosProyectosDashboard({
    int page = 1,
    int limit = 5,
  }) async {
    final safePage = page < 1 ? 1 : page;
    final safeLimit = limit < 1 ? 5 : limit;

    final data = await _getMap(
      '/dashboard/ultimos-proyectos?page=$safePage&limit=$safeLimit',
    );

    final items = data['items'] ?? data['ultimosProyectos'];

    if (items is List) {
      return items.map((item) => Map<String, dynamic>.from(item)).toList();
    }

    return [];
  }
}
