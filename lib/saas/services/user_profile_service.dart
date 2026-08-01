import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/saas_user_profile.dart';

/// Perfil editable del usuario. No escribe privilegios de suscripción.
class UserProfileService {
  UserProfileService._();
  static final UserProfileService instance = UserProfileService._();

  FirebaseFirestore? _db;

  FirebaseFirestore get _firestore {
    _db ??= FirebaseFirestore.instance;
    return _db!;
  }

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _firestore.collection('users').doc(uid);

  Future<SaasUserProfile> ensureProfile(User user) async {
    final ref = _userRef(user.uid);
    final snap = await ref.get();
    if (snap.exists && snap.data() != null) {
      final existing = SaasUserProfile.fromMap(snap.data()!);
      // Si el doc legacy tiene plan, no lo borramos aquí (migración a entitlements).
      // Solo aseguramos campos editables actualizados cuando falte schemaVersion.
      if (snap.data()!.containsKey('schemaVersion')) {
        return existing;
      }
      final patched = SaasUserProfile(
        uid: existing.uid,
        email: user.email ?? existing.email,
        displayName: user.displayName?.trim().isNotEmpty == true
            ? user.displayName!.trim()
            : existing.displayName,
        schemaVersion: SaasUserProfile.currentSchemaVersion,
        createdAt: existing.createdAt,
        updatedAt: DateTime.now(),
        legacyPlan: existing.legacyPlan,
        legacySubscriptionStatus: existing.legacySubscriptionStatus,
        legacyTrialEndsAt: existing.legacyTrialEndsAt,
      );
      // Update solo campos permitidos (no toca plan legacy).
      await ref.update({
        'email': patched.email,
        'displayName': patched.displayName,
        'updatedAt': patched.updatedAt.toIso8601String(),
        'schemaVersion': patched.schemaVersion,
      });
      return SaasUserProfile.fromMap({
        ...snap.data()!,
        ...{
          'email': patched.email,
          'displayName': patched.displayName,
          'updatedAt': patched.updatedAt.toIso8601String(),
          'schemaVersion': patched.schemaVersion,
        },
      });
    }

    final now = DateTime.now();
    final profile = SaasUserProfile(
      uid: user.uid,
      email: user.email ?? '',
      displayName:
          user.displayName ?? (user.email?.split('@').first ?? 'Usuario'),
      schemaVersion: SaasUserProfile.currentSchemaVersion,
      createdAt: now,
      updatedAt: now,
    );
    await ref.set(profile.toWritableMap());
    return profile;
  }

  Future<SaasUserProfile?> getProfile(String uid) async {
    final snap = await _userRef(uid).get();
    if (!snap.exists || snap.data() == null) return null;
    return SaasUserProfile.fromMap(snap.data()!);
  }

  Stream<SaasUserProfile?> watchProfile(String uid) {
    return _userRef(uid).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return SaasUserProfile.fromMap(snap.data()!);
    });
  }

  Future<void> updateDisplayName(String uid, String displayName) async {
    await _userRef(uid).update({
      'displayName': displayName.trim(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Exporta el documento de perfil (datos personales).
  Future<Map<String, dynamic>?> exportProfile(String uid) async {
    final snap = await _userRef(uid).get();
    return snap.data();
  }

  Future<void> deleteProfile(String uid) async {
    await _userRef(uid).delete();
  }
}
