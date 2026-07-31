import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import '../config/saas_platform.dart';
import 'identity_toolkit_client.dart';

/// Autenticación SaaS.
/// En Windows/Linux: solo Identity Toolkit REST (sin FirebaseAuth nativo).
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  FirebaseAuth? _auth;
  AuthSession? _restSession;
  final _restAuthController = StreamController<User?>.broadcast();

  AuthSession? get restSession => _restSession;

  FirebaseAuth get _native {
    _auth ??= FirebaseAuth.instance;
    return _auth!;
  }

  User? get currentUser {
    if (saasUseRestBackend) return null;
    try {
      return _native.currentUser;
    } catch (e) {
      debugPrint('FirebaseAuth.currentUser no disponible: $e');
      return null;
    }
  }

  String? get activeUid => currentUser?.uid ?? _restSession?.uid;

  String? get activeEmail => currentUser?.email ?? _restSession?.email;

  bool get isAuthenticated => activeUid != null && activeUid!.isNotEmpty;

  Stream<User?> get authStateChanges {
    if (saasUseRestBackend) {
      return _restAuthController.stream;
    }
    return _native.authStateChanges();
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    if (saasUseRestBackend) {
      _restSession = await IdentityToolkitClient.instance.signIn(
        email: email,
        password: password,
      );
      _restAuthController.add(null);
      return;
    }
    try {
      await _native.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      _restSession = null;
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapNative(e));
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    if (saasUseRestBackend) {
      _restSession = await IdentityToolkitClient.instance.signUp(
        email: email,
        password: password,
        displayName: displayName,
      );
      _restAuthController.add(null);
      return;
    }
    try {
      final cred = await _native.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (displayName != null && displayName.trim().isNotEmpty) {
        await cred.user?.updateDisplayName(displayName.trim());
      }
      _restSession = null;
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapNative(e));
    }
  }

  Future<void> signOut() async {
    _restSession = null;
    if (saasUseRestBackend) {
      _restAuthController.add(null);
      return;
    }
    try {
      await _native.signOut();
    } catch (e) {
      debugPrint('signOut nativo: $e');
    }
  }

  Future<void> resetPassword(String email) async {
    if (saasUseRestBackend) {
      await IdentityToolkitClient.instance.sendPasswordReset(email);
      return;
    }
    try {
      await _native.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapNative(e));
    }
  }

  String _mapNative(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'El correo no es válido.';
      case 'user-disabled':
        return 'Esta cuenta está deshabilitada.';
      case 'user-not-found':
        return 'No existe una cuenta con ese correo.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Correo o contraseña incorrectos.';
      case 'email-already-in-use':
        return 'Ya existe una cuenta con ese correo.';
      case 'weak-password':
        return 'La contraseña debe tener al menos 6 caracteres.';
      case 'too-many-requests':
        return 'Demasiados intentos. Espera un momento.';
      case 'network-request-failed':
        return 'Sin conexión a internet.';
      case 'operation-not-allowed':
        return 'Activa Email/Password en Firebase Authentication.';
      case 'internal-error':
      case 'unknown':
      case 'unknown-error':
        return 'Error interno de Auth. Prueba de nuevo.';
      default:
        return e.message ?? 'Error de autenticación (${e.code}).';
    }
  }
}
