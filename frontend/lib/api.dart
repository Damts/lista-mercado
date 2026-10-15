import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config/app_config.dart';

class ApiException implements Exception {
  final int status;
  final String message;
  final String? type;
  ApiException(this.status, this.message, [this.type]);
}

class ApiClient {
  final String baseUrl;
  final SharedPreferences prefs;
  ApiClient({required this.prefs, String? baseUrl})
    : baseUrl = baseUrl ?? AppConfig.backendUrl;
  String? get token => prefs.getString('auth_token');
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    int? houseId,
  }) async {
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      if (houseId != null) 'X-Casa-ID': '$houseId',
    };
    final uri = Uri.parse('$baseUrl$path');
    http.Response response;
    try {
      response = await switch (method) {
        'GET' => http.get(uri, headers: headers),
        'POST' => http.post(
          uri,
          headers: headers,
          body: jsonEncode(body ?? {}),
        ),
        'PATCH' => http.patch(
          uri,
          headers: headers,
          body: jsonEncode(body ?? {}),
        ),
        'DELETE' => http.delete(uri, headers: headers),
        _ => throw StateError('Método inválido'),
      };
    } catch (e) {
      throw ApiException(
        0,
        'Não foi possível conectar ao servidor. Verifique a rede e tente novamente.',
      );
    }
    if (response.statusCode == 401) {
      await prefs.remove('auth_token');
      throw ApiException(401, 'Sessão expirada. Entre novamente.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      Map<String, dynamic> data = {};
      try {
        data = jsonDecode(response.body);
      } catch (_) {}
      final errors = data['errors'];
      final detail = errors is Map && errors.isNotEmpty
          ? (errors.values.first is List
                ? errors.values.first.first
                : errors.values.first.toString())
          : data['message'];
      throw ApiException(
        response.statusCode,
        detail?.toString() ?? 'Não foi possível concluir a operação.',
        data['type']?.toString(),
      );
    }
    if (response.statusCode == 204 || response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }
}
