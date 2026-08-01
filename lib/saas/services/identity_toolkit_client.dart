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
  final int? expiresInSeconds;
  final DateTime? expiresAt;
  final bool? emailVerified;

  const AuthSession({
    required this.uid,
    required this.email,
    required this.idToken,
    required this.refreshToken,
    this.displayName,
    this.expiresInSeconds,
    this.expiresAt,
    this.emailVerified,
  });

  bool get isExpiredOrNearExpiry {
    if (expiresAt == null) return true;
    return DateTime.now().isAfter(
      expiresAt!.subtract(const Duration(minutes: 5)),
    );
  }

  AuthSession copyWith({
    String? uid,
    String? email,
    String? idToken,
    String? refreshToken,
    String? displayName,
    int? expiresInSeconds,
    DateTime? expiresAt,
    bool? emailVerified,
  }) {
    return AuthSession(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      idToken: idToken ?? this.idToken,
      refreshToken: refreshToken ?? this.refreshToken,
      displayName: displayName ?? this.displayName,
      expiresInSeconds: expiresInSeconds ?? this.expiresInSeconds,
      expiresAt: expiresAt ?? this.expiresAt,
      emailVerified: emailVerified ?? this.emailVerified,
    );
  }
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

  Future<void> sendEmailVerification(String idToken) async {
    await _post('accounts:sendOobCode', {
      'requestType': 'VERIFY_EMAIL',
      'idToken': idToken,
    });
  }

  Future<AuthSession> lookup(String idToken) async {
    final data = await _post('accounts:lookup', {'idToken': idToken});
    final users = data['users'] as List?;
    if (users == null || users.isEmpty) {
      throw Exception('No se pudo obtener el perfil de autenticación.');
    }
    final user = Map<String, dynamic>.from(users.first as Map);
    return AuthSession(
      uid: user['localId'] as String? ?? '',
      email: user['email'] as String? ?? '',
      idToken: idToken,
      refreshToken: '',
      displayName: user['displayName'] as String?,
      emailVerified: user['emailVerified'] == true,
    );
  }

  Future<void> deleteAccount(String idToken) async {
    await _post('accounts:delete', {'idToken': idToken});
  }

  Future<AuthSession> refresh(String refreshToken) async {
    final uri = Uri.parse(
      'https://securetoken.googleapis.com/v1/token?key=$_apiKey',
    );
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body:
          'grant_type=refresh_token&refresh_token=${Uri.encodeQueryComponent(refreshToken)}',
    );
    final data = jsonDecode(res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final error = data is Map ? data['error'] : null;
      final message =
          (error is Map ? error['message'] : null) ?? 'REFRESH_FAILED';
      throw Exception(_mapRestError(message.toString()));
    }
    final map = Map<String, dynamic>.from(data as Map);
    final expiresIn = int.tryParse('${map['expires_in'] ?? 3600}') ?? 3600;
    return AuthSession(
      uid: map['user_id'] as String? ?? '',
      email: '',
      idToken: map['id_token'] as String? ?? '',
      refreshToken: map['refresh_token'] as String? ?? refreshToken,
      expiresInSeconds: expiresIn,
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
    );
  }

  AuthSession _sessionFrom(
    Map<String, dynamic> data, {
    required String fallbackEmail,
  }) {
    final expiresIn = int.tryParse('${data['expiresIn'] ?? 3600}') ?? 3600;
    return AuthSession(
      uid: data['localId'] as String? ?? '',
      email: data['email'] as String? ?? fallbackEmail,
      idToken: data['idToken'] as String? ?? '',
      refreshToken: data['refreshToken'] as String? ?? '',
      displayName: data['displayName'] as String?,
      expiresInSeconds: expiresIn,
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
      emailVerified: data['emailVerified'] == true,
    );
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
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
      case 'INVALID_REFRESH_TOKEN':
      case 'TOKEN_EXPIRED':
      case 'USER_TOKEN_EXPIRED':
      case 'REFRESH_FAILED':
        return 'La sesión expiró. Vuelve a iniciar sesión.';
      default:
        return 'No se pudo completar la autenticación ($message).';
    }
  }
}
