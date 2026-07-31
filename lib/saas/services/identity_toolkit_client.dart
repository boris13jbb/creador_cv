import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

/// Sesión obtenida vía Identity Toolkit (REST).
class AuthSession {
  final String uid;
  final String email;
  final String idToken;
  final String refreshToken;
  final String? displayName;

  const AuthSession({
    required this.uid,
    required this.email,
    required this.idToken,
    required this.refreshToken,
    this.displayName,
  });
}

/// Cliente REST de Firebase Auth (evita el fallo gRPC de Windows).
class IdentityToolkitClient {
  IdentityToolkitClient._();
  static final IdentityToolkitClient instance = IdentityToolkitClient._();

  String get _apiKey => Firebase.app().options.apiKey;
  String get _projectId => Firebase.app().options.projectId;

  Future<AuthSession> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final body = <String, dynamic>{
      'email': email.trim(),
      'password': password,
      'returnSecureToken': true,
    };
    if (displayName != null && displayName.trim().isNotEmpty) {
      body['displayName'] = displayName.trim();
    }
    final data = await _post('accounts:signUp', body);
    return _sessionFrom(data, fallbackEmail: email.trim());
  }

  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    final data = await _post('accounts:signInWithPassword', {
      'email': email.trim(),
      'password': password,
      'returnSecureToken': true,
    });
    return _sessionFrom(data, fallbackEmail: email.trim());
  }

  Future<void> sendPasswordReset(String email) async {
    await _post('accounts:sendOobCode', {
      'requestType': 'PASSWORD_RESET',
      'email': email.trim(),
    });
  }

  Future<AuthSession> refresh(String refreshToken) async {
    final uri = Uri.parse(
      'https://securetoken.googleapis.com/v1/token?key=$_apiKey',
    );
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: 'grant_type=refresh_token&refresh_token=$refreshToken',
    );
    final data = jsonDecode(res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final error = data is Map ? data['error'] : null;
      final message = (error is Map ? error['message'] : null) ?? 'REFRESH_FAILED';
      throw Exception(_mapRestError(message.toString()));
    }
    final map = Map<String, dynamic>.from(data as Map);
    return AuthSession(
      uid: map['user_id'] as String? ?? '',
      email: '',
      idToken: map['id_token'] as String? ?? '',
      refreshToken: map['refresh_token'] as String? ?? refreshToken,
    );
  }

  AuthSession _sessionFrom(Map<String, dynamic> data, {required String fallbackEmail}) {
    return AuthSession(
      uid: data['localId'] as String? ?? '',
      email: data['email'] as String? ?? fallbackEmail,
      idToken: data['idToken'] as String? ?? '',
      refreshToken: data['refreshToken'] as String? ?? '',
      displayName: data['displayName'] as String?,
    );
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse(
      'https://identitytoolkit.googleapis.com/v1/$path?key=$_apiKey',
    );
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    final decoded = jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return Map<String, dynamic>.from(decoded as Map);
    }
    final error = (decoded is Map ? decoded['error'] : null) as Map?;
    final message = (error?['message'] as String?) ?? 'ERROR_DESCONOCIDO';
    debugPrint('IdentityToolkit [$path]: $message');
    throw Exception(_mapRestError(message));
  }

  String get projectId => _projectId;

  String _mapRestError(String message) {
    if (message.startsWith('WEAK_PASSWORD')) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }
    switch (message) {
      case 'EMAIL_EXISTS':
        return 'Ya existe una cuenta con ese correo.';
      case 'INVALID_EMAIL':
        return 'El correo no es válido.';
      case 'EMAIL_NOT_FOUND':
        return 'No existe una cuenta con ese correo.';
      case 'INVALID_PASSWORD':
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'Correo o contraseña incorrectos.';
      case 'USER_DISABLED':
        return 'Esta cuenta está deshabilitada.';
      case 'TOO_MANY_ATTEMPTS_TRY_LATER':
        return 'Demasiados intentos. Espera un momento.';
      case 'OPERATION_NOT_ALLOWED':
        return 'Activa Email/Password en Firebase Authentication.';
      case 'API_KEY_INVALID':
        return 'API key de Firebase inválida.';
      default:
        return 'No se pudo completar la autenticación ($message).';
    }
  }
}
