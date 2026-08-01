import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'identity_toolkit_client.dart';

/// Persistencia segura de tokens REST (Windows/Linux). Nunca guarda contraseñas.
class SecureSessionStore {
  SecureSessionStore._();
  static final SecureSessionStore instance = SecureSessionStore._();

  static const _kUid = 'saas_rest_uid';
  static const _kEmail = 'saas_rest_email';
  static const _kIdToken = 'saas_rest_id_token';
  static const _kRefreshToken = 'saas_rest_refresh_token';
  static const _kDisplayName = 'saas_rest_display_name';
  static const _kExpiresAtMs = 'saas_rest_expires_at_ms';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> save(AuthSession session) async {
    try {
      await _storage.write(key: _kUid, value: session.uid);
      await _storage.write(key: _kEmail, value: session.email);
      await _storage.write(key: _kIdToken, value: session.idToken);
      await _storage.write(key: _kRefreshToken, value: session.refreshToken);
      await _storage.write(
        key: _kDisplayName,
        value: session.displayName ?? '',
      );
      final expiresAt =
          session.expiresAt ??
          DateTime.now().add(
            Duration(seconds: session.expiresInSeconds ?? 3600),
          );
      await _storage.write(
        key: _kExpiresAtMs,
        value: expiresAt.millisecondsSinceEpoch.toString(),
      );
    } catch (e) {
      debugPrint('SecureSessionStore.save: $e');
      rethrow;
    }
  }

  Future<AuthSession?> read() async {
    try {
      final uid = await _storage.read(key: _kUid);
      final refresh = await _storage.read(key: _kRefreshToken);
      if (uid == null || uid.isEmpty || refresh == null || refresh.isEmpty) {
        return null;
      }
      final email = await _storage.read(key: _kEmail) ?? '';
      final idToken = await _storage.read(key: _kIdToken) ?? '';
      final displayName = await _storage.read(key: _kDisplayName);
      final expiresRaw = await _storage.read(key: _kExpiresAtMs);
      DateTime? expiresAt;
      if (expiresRaw != null) {
        expiresAt = DateTime.fromMillisecondsSinceEpoch(
          int.tryParse(expiresRaw) ?? 0,
        );
      }
      return AuthSession(
        uid: uid,
        email: email,
        idToken: idToken,
        refreshToken: refresh,
        displayName: (displayName == null || displayName.isEmpty)
            ? null
            : displayName,
        expiresAt: expiresAt,
      );
    } catch (e) {
      debugPrint('SecureSessionStore.read: $e');
      return null;
    }
  }

  Future<void> clear() async {
    try {
      await Future.wait([
        _storage.delete(key: _kUid),
        _storage.delete(key: _kEmail),
        _storage.delete(key: _kIdToken),
        _storage.delete(key: _kRefreshToken),
        _storage.delete(key: _kDisplayName),
        _storage.delete(key: _kExpiresAtMs),
      ]);
    } catch (e) {
      debugPrint('SecureSessionStore.clear: $e');
    }
  }

  /// En web el almacenamiento seguro usa localStorage cifrado por la librería.
  bool get isSupported => true;

  String get platformHint => kIsWeb ? 'web' : 'native';
}
