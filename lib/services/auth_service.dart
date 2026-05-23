import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

class AuthService {
  static const String tokenKey = 'accessToken';
  static const Duration _requestTimeout = Duration(seconds: 25);

  Map<String, String> _jsonHeaders() {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  Map<String, String> _authHeaders(String token) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<http.Response> _postJson(
    Uri url,
    Map<String, dynamic> body, {
    Map<String, String>? headers,
  }) async {
    try {
      return await http
          .post(
            url,
            headers: headers ?? _jsonHeaders(),
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout);
    } catch (_) {
      throw Exception(
        'El servidor tardó demasiado en responder. Intente de nuevo.',
      );
    }
  }

  Future<http.Response> _patchJson(
    Uri url,
    Map<String, dynamic> body, {
    required String token,
  }) async {
    try {
      return await http
          .patch(
            url,
            headers: _authHeaders(token),
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout);
    } catch (_) {
      throw Exception(
        'El servidor tardó demasiado en responder. Intente de nuevo.',
      );
    }
  }

  Future<http.Response> _getAuth(Uri url, String token) async {
    try {
      return await http
          .get(
            url,
            headers: _authHeaders(token),
          )
          .timeout(_requestTimeout);
    } catch (_) {
      throw Exception(
        'El servidor tardó demasiado en responder. Intente de nuevo.',
      );
    }
  }

  dynamic _decodeResponse(http.Response response) {
    final body = response.body.trim();

    if (body.isEmpty) {
      return {};
    }

    try {
      return jsonDecode(body);
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

    return {
      'data': data,
    };
  }

  void _validarRespuesta(
    http.Response response,
    dynamic data,
    String fallback,
  ) {
    if (response.statusCode >= 400) {
      throw Exception(_getErrorMessage(data, fallback));
    }
  }

  String? _tryGetToken(Map<String, dynamic> data) {
    final token = data['accessToken'] ?? data['token'] ?? data['access_token'];

    if (token is String && token.trim().isNotEmpty) {
      return token.trim();
    }

    return null;
  }

  Future<void> _saveTokenIfExists(Map<String, dynamic> data) async {
    final token = _tryGetToken(data);

    if (token != null) {
      await saveToken(token);
    }
  }

  Future<void> _saveRequiredLoginToken(Map<String, dynamic> data) async {
    final token = _tryGetToken(data);

    if (token == null) {
      throw Exception('El servidor no devolvió token.');
    }

    await saveToken(token);
  }

  Future<Map<String, dynamic>> register({
    required String nombre,
    required String email,
    required String password,
    required String telefono,
    required String phoneCountryIso2,
    required String phoneDialCode,
    String? fcmToken,
    String? platform,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/auth/register');

    final body = <String, dynamic>{
      'nombre': nombre.trim(),
      'email': email.trim().toLowerCase(),
      'password': password,
      'telefono': telefono.trim(),
      'phoneCountryIso2': phoneCountryIso2.trim().toUpperCase(),
      'phoneDialCode': phoneDialCode.trim(),
    };

    if (fcmToken != null && fcmToken.trim().isNotEmpty) {
      body['fcmToken'] = fcmToken.trim();
    }

    if (platform != null && platform.trim().isNotEmpty) {
      body['platform'] = platform.trim();
    }

    final response = await _postJson(url, body);

    final decoded = _decodeResponse(response);
    final data = _toMap(decoded);

    _validarRespuesta(
      response,
      data,
      'Error al registrar usuario.',
    );

    return data;
  }

  Future<Map<String, dynamic>> verifyEmail({
    required String email,
    required String code,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/auth/verify-email');

    final response = await _postJson(
      url,
      {
        'email': email.trim().toLowerCase(),
        'code': code.trim(),
      },
    );

    final decoded = _decodeResponse(response);
    final data = _toMap(decoded);

    _validarRespuesta(
      response,
      data,
      'Error al verificar correo.',
    );

    await _saveTokenIfExists(data);

    return data;
  }

  Future<Map<String, dynamic>> resendVerificationCode({
    required String email,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/auth/resend-verification-code');

    final response = await _postJson(
      url,
      {
        'email': email.trim().toLowerCase(),
      },
    );

    final decoded = _decodeResponse(response);
    final data = _toMap(decoded);

    _validarRespuesta(
      response,
      data,
      'Error al reenviar código.',
    );

    return data;
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/auth/login');

    final response = await _postJson(
      url,
      {
        'email': email.trim().toLowerCase(),
        'password': password,
      },
    );

    final decoded = _decodeResponse(response);
    final data = _toMap(decoded);

    _validarRespuesta(
      response,
      data,
      'Error al iniciar sesión.',
    );

    await _saveRequiredLoginToken(data);

    return data;
  }

  Future<Map<String, dynamic>> forgotPassword({
    required String email,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/auth/forgot-password');

    final response = await _postJson(
      url,
      {
        'email': email.trim().toLowerCase(),
      },
    );

    final decoded = _decodeResponse(response);
    final data = _toMap(decoded);

    _validarRespuesta(
      response,
      data,
      'Error al solicitar recuperación de contraseña.',
    );

    return data;
  }

  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/auth/reset-password');

    final response = await _postJson(
      url,
      {
        'email': email.trim().toLowerCase(),
        'code': code.trim(),
        'newPassword': newPassword,
      },
    );

    final decoded = _decodeResponse(response);
    final data = _toMap(decoded);

    _validarRespuesta(
      response,
      data,
      'Error al restablecer contraseña.',
    );

    return data;
  }

  Future<Map<String, dynamic>> profile() async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      throw Exception('No hay sesión activa.');
    }

    final url = Uri.parse('${ApiConfig.baseUrl}/auth/profile');

    final response = await _getAuth(url, token);

    final decoded = _decodeResponse(response);
    final data = _toMap(decoded);

    _validarRespuesta(
      response,
      data,
      'Error al obtener perfil.',
    );

    return data;
  }

  Future<Map<String, dynamic>> updateProfile({
    required String nombre,
  }) async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      throw Exception('No hay sesión activa.');
    }

    final url = Uri.parse('${ApiConfig.baseUrl}/auth/profile');

    final response = await _patchJson(
      url,
      {
        'nombre': nombre.trim(),
      },
      token: token,
    );

    final decoded = _decodeResponse(response);
    final data = _toMap(decoded);

    _validarRespuesta(
      response,
      data,
      'Error al actualizar perfil.',
    );

    await _saveTokenIfExists(data);

    return data;
  }

  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      throw Exception('No hay sesión activa.');
    }

    final url = Uri.parse('${ApiConfig.baseUrl}/auth/change-password');

    final response = await _postJson(
      url,
      {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
      headers: _authHeaders(token),
    );

    final decoded = _decodeResponse(response);
    final data = _toMap(decoded);

    _validarRespuesta(
      response,
      data,
      'Error al cambiar contraseña.',
    );

    return data;
  }

  Future<Map<String, dynamic>> requestEmailChange({
    required String newEmail,
  }) async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      throw Exception('No hay sesión activa.');
    }

    final url = Uri.parse('${ApiConfig.baseUrl}/auth/request-email-change');

    final response = await _postJson(
      url,
      {
        'newEmail': newEmail.trim().toLowerCase(),
      },
      headers: _authHeaders(token),
    );

    final decoded = _decodeResponse(response);
    final data = _toMap(decoded);

    _validarRespuesta(
      response,
      data,
      'Error al solicitar cambio de correo.',
    );

    return data;
  }

  Future<Map<String, dynamic>> confirmEmailChange({
    required String code,
  }) async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      throw Exception('No hay sesión activa.');
    }

    final url = Uri.parse('${ApiConfig.baseUrl}/auth/confirm-email-change');

    final response = await _postJson(
      url,
      {
        'code': code.trim(),
      },
      headers: _authHeaders(token),
    );

    final decoded = _decodeResponse(response);
    final data = _toMap(decoded);

    _validarRespuesta(
      response,
      data,
      'Error al confirmar cambio de correo.',
    );

    await _saveTokenIfExists(data);

    return data;
  }

  Future<Map<String, dynamic>> requestPhoneChange({
    required String newPhone,
  }) async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      throw Exception('No hay sesión activa.');
    }

    final url = Uri.parse('${ApiConfig.baseUrl}/auth/request-phone-change');

    final response = await _postJson(
      url,
      {
        'newPhone': newPhone.trim(),
      },
      headers: _authHeaders(token),
    );

    final decoded = _decodeResponse(response);
    final data = _toMap(decoded);

    _validarRespuesta(
      response,
      data,
      'Error al solicitar cambio de teléfono.',
    );

    return data;
  }

  Future<Map<String, dynamic>> confirmPhoneChange({
    required String code,
  }) async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      throw Exception('No hay sesión activa.');
    }

    final url = Uri.parse('${ApiConfig.baseUrl}/auth/confirm-phone-change');

    final response = await _postJson(
      url,
      {
        'code': code.trim(),
      },
      headers: _authHeaders(token),
    );

    final decoded = _decodeResponse(response);
    final data = _toMap(decoded);

    _validarRespuesta(
      response,
      data,
      'Error al confirmar cambio de teléfono.',
    );

    return data;
  }

  Future<void> saveToken(String token) async {
    if (token.trim().isEmpty) {
      throw Exception('Token inválido.');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(tokenKey, token.trim());
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(tokenKey);

    if (token == null || token.trim().isEmpty) {
      return null;
    }

    return token.trim();
  }

  Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(tokenKey);
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
