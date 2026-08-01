import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import '../config/saas_platform.dart';
import 'identity_toolkit_client.dart';
import 'secure_session_store.dart';

/// Autenticación SaaS.
/// En Windows/Linux: Identity Toolkit REST + almacenamiento seguro de tokens.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  FirebaseAuth? _auth;
  AuthSession? _restSession;
  final _restAuthController = StreamController<User?>.broadcast();
  Timer? _refreshTimer;

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
    }
    return null;
  }

  String? get activeUid => currentUser?.uid ?? _restSession?.uid;

  String? get activeEmail => currentUser?.email ?? _restSession?.email;

  bool get isAuthenticated => activeUid != null && activeUid!.isNotEmpty;

  bool? get emailVerified {
    if (saasUseRestBackend) return _restSession?.emailVerified;
    return currentUser?.emailVerified;
  }

  Stream<User?> get authStateChanges {
    if (saasUseRestBackend) {
      return _restAuthController.stream;
    }
    return _native.authStateChanges();
  }

  /// Restaura sesión REST desde almacenamiento seguro y renueva el token.
  Future<AuthSession?> restoreRestSession() async {
    if (!saasUseRestBackend) return null;
    final stored = await SecureSessionStore.instance.read();
    if (stored == null) return null;

    try {
      final refreshed = await IdentityToolkitClient.instance.refresh(
        stored.refreshToken,
      );
      final merged = refreshed.copyWith(
        email: stored.email.isNotEmpty ? stored.email : refreshed.email,
        displayName: stored.displayName ?? refreshed.displayName,
      );
      final lookedUp = await _enrichWithLookup(merged);
      _restSession = lookedUp;
      await SecureSessionStore.instance.save(lookedUp);
      _scheduleRefresh(lookedUp);
      _restAuthController.add(null);
      return lookedUp;
    } catch (e) {
      debugPrint('restoreRestSession falló: $e');
      await clearRestSession();
      return null;
    }
  }

  Future<AuthSession> _enrichWithLookup(AuthSession session) async {
    try {
      final info = await IdentityToolkitClient.instance.lookup(session.idToken);
      return session.copyWith(
        email: info.email.isNotEmpty ? info.email : session.email,
        displayName: info.displayName ?? session.displayName,
        emailVerified: info.emailVerified,
      );
    } catch (_) {
      return session;
    }
  }

  Future<AuthSession> ensureValidRestToken() async {
    final session = _restSession;
    if (session == null) {
      throw Exception('No hay sesión activa.');
    }
    if (!session.isExpiredOrNearExpiry && session.idToken.isNotEmpty) {
      return session;
    }
    return refreshRestSession();
  }

  Future<AuthSession> refreshRestSession() async {
    final session = _restSession;
    if (session == null || session.refreshToken.isEmpty) {
      await clearRestSession();
      throw Exception('La sesión expiró. Vuelve a iniciar sesión.');
    }
    try {
      final refreshed = await IdentityToolkitClient.instance.refresh(
        session.refreshToken,
      );
      final merged = refreshed.copyWith(
        email: session.email.isNotEmpty ? session.email : refreshed.email,
        displayName: session.displayName ?? refreshed.displayName,
        emailVerified: session.emailVerified,
      );
      final lookedUp = await _enrichWithLookup(merged);
      _restSession = lookedUp;
      await SecureSessionStore.instance.save(lookedUp);
      _scheduleRefresh(lookedUp);
      return lookedUp;
    } catch (e) {
      await clearRestSession();
      rethrow;
    }
  }

  void _scheduleRefresh(AuthSession session) {
    _refreshTimer?.cancel();
    final expiresAt =
        session.expiresAt ?? DateTime.now().add(const Duration(hours: 1));
    var delay =
        expiresAt.difference(DateTime.now()) - const Duration(minutes: 5);
    if (delay.isNegative) delay = const Duration(seconds: 30);
    _refreshTimer = Timer(delay, () async {
      try {
        await refreshRestSession();
      } catch (e) {
        debugPrint('Refresh programado falló: $e');
      }
    });
  }

  Future<void> clearRestSession() async {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _restSession = null;
    await SecureSessionStore.instance.clear();
    if (saasUseRestBackend) {
      _restAuthController.add(null);
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    if (saasUseRestBackend) {
      var session = await IdentityToolkitClient.instance.signIn(
        email: email,
        password: password,
      );
      session = await _enrichWithLookup(session);
      _restSession = session;
      await SecureSessionStore.instance.save(session);
      _scheduleRefresh(session);
      _restAuthController.add(null);
      return;
    }
    try {
      await _native.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await clearRestSession();
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
      var session = await IdentityToolkitClient.instance.signUp(
        email: email,
        password: password,
        displayName: displayName,
      );
      try {
        await IdentityToolkitClient.instance.sendEmailVerification(
          session.idToken,
        );
      } catch (e) {
        debugPrint('sendEmailVerification REST: $e');
      }
      session = await _enrichWithLookup(session);
      _restSession = session;
      await SecureSessionStore.instance.save(session);
      _scheduleRefresh(session);
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
      try {
        await cred.user?.sendEmailVerification();
      } catch (e) {
        debugPrint('sendEmailVerification nativo: $e');
      }
      await clearRestSession();
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapNative(e));
    }
  }

  Future<void> sendEmailVerification() async {
    if (saasUseRestBackend) {
      final token = (await ensureValidRestToken()).idToken;
      await IdentityToolkitClient.instance.sendEmailVerification(token);
      return;
    }
    final user = _native.currentUser;
    if (user == null) throw Exception('No hay sesión activa.');
    await user.sendEmailVerification();
  }

  Future<bool> reloadEmailVerified() async {
    if (saasUseRestBackend) {
      final session = await ensureValidRestToken();
      final lookedUp = await _enrichWithLookup(session);
      _restSession = lookedUp;
      await SecureSessionStore.instance.save(lookedUp);
      return lookedUp.emailVerified == true;
    }
    final user = _native.currentUser;
    if (user == null) return false;
    await user.reload();
    return _native.currentUser?.emailVerified == true;
  }

  Future<void> deleteAccount() async {
    if (saasUseRestBackend) {
      final token = (await ensureValidRestToken()).idToken;
      await IdentityToolkitClient.instance.deleteAccount(token);
      await clearRestSession();
      return;
    }
    final user = _native.currentUser;
    if (user == null) throw Exception('No hay sesión activa.');
    await user.delete();
  }

  Future<void> signOut() async {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    if (saasUseRestBackend) {
      await clearRestSession();
      return;
    }
    try {
      await _native.signOut();
    } catch (e) {
      debugPrint('signOut nativo: $e');
    }
    await clearRestSession();
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

  /// ID token Firebase (nativo o REST) para llamar Cloud Functions HTTP.
  Future<String> getIdToken({bool forceRefresh = false}) async {
    if (saasUseRestBackend) {
      final session = await ensureValidRestToken();
      return session.idToken;
    }
    final user = _native.currentUser;
    if (user == null) {
      final rest = restSession ?? await restoreRestSession();
      if (rest != null) {
        final session = await ensureValidRestToken();
        return session.idToken;
      }
      throw Exception('No hay sesión activa.');
    }
    final token = await user.getIdToken(forceRefresh);
    if (token == null || token.isEmpty) {
      throw Exception('No se pudo obtener el token de sesión.');
    }
    return token;
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
      case 'requires-recent-login':
        return 'Por seguridad, vuelve a iniciar sesión e inténtalo de nuevo.';
      case 'internal-error':
      case 'unknown':
      case 'unknown-error':
        return 'Error interno de Auth. Prueba de nuevo.';
      default:
        return e.message ?? 'Error de autenticación (${e.code}).';
    }
  }
}
