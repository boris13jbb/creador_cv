import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../config.dart';

/// Cliente HTTP de las Functions de superadmin (Bearer + claim).
class AdminApiService {
  AdminApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri _uri(String name) {
    final base = AdminConfig.functionsBaseUrl.replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$base/$name');
  }

  Future<Map<String, dynamic>> _post(
    String name, [
    Map<String, dynamic>? body,
  ]) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Debes iniciar sesión.');
    }
    // Fuerza refresh para leer custom claims recién asignados.
    final token = await user.getIdToken(true);
    final res = await _client.post(
      _uri(name),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body ?? {}),
    );

    Map<String, dynamic> json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Respuesta inválida (${res.statusCode}).');
    }

    if (res.statusCode >= 400) {
      final err = json['error'] as Map<String, dynamic>?;
      throw Exception(err?['message'] as String? ?? 'Error ${res.statusCode}');
    }
    return json;
  }

  Future<Map<String, dynamic>> getMetrics() => _post('adminGetMetrics');

  Future<Map<String, dynamic>> listUsers({
    String? pageToken,
    int maxResults = 25,
  }) =>
      _post('adminListUsers', {
        if (pageToken != null) 'pageToken': pageToken,
        'maxResults': maxResults,
      });

  Future<Map<String, dynamic>> getUser({String? email, String? uid}) =>
      _post('adminGetUser', {
        if (email != null) 'email': email,
        if (uid != null) 'uid': uid,
      });

  Future<Map<String, dynamic>> grantPro({
    String? email,
    String? uid,
    String? note,
    String? expiresAt,
  }) =>
      _post('adminGrantPro', {
        if (email != null) 'email': email,
        if (uid != null) 'uid': uid,
        if (note != null) 'note': note,
        if (expiresAt != null) 'expiresAt': expiresAt,
      });

  Future<Map<String, dynamic>> revokeGrant({
    String? email,
    String? uid,
    String? note,
  }) =>
      _post('adminRevokeGrant', {
        if (email != null) 'email': email,
        if (uid != null) 'uid': uid,
        if (note != null) 'note': note,
      });
}
