import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/saas_user_profile.dart';
import '../models/user_entitlement.dart';
import 'firestore_rest_client.dart';
import 'identity_toolkit_client.dart';

/// Lectura y bootstrap seguro de entitlements (sin elevar privilegios).
class EntitlementService {
  EntitlementService._();
  static final EntitlementService instance = EntitlementService._();

  FirebaseFirestore? _db;

  FirebaseFirestore get _firestore {
    _db ??= FirebaseFirestore.instance;
    return _db!;
  }

  DocumentReference<Map<String, dynamic>> _ref(String uid) =>
      _firestore.collection('entitlements').doc(uid);

  Future<UserEntitlement?> getEntitlement(String uid) async {
    final snap = await _ref(uid).get();
    if (!snap.exists || snap.data() == null) return null;
    return UserEntitlement.fromMap(snap.data()!);
  }

  Stream<UserEntitlement?> watchEntitlement(String uid) {
    return _ref(uid).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return UserEntitlement.fromMap(snap.data()!);
    });
  }

  /// Crea entitlement Free o migra desde campos legacy del perfil de usuario.
  /// Nunca inventa Pro: solo copia plan legacy existente o bootstrap Free.
  /// Si las reglas aún no están desplegadas, usa fallback local.
  Future<UserEntitlement> ensureEntitlement({
    required String uid,
    SaasUserProfile? profile,
  }) async {
    try {
      final existing = await getEntitlement(uid);
      if (existing != null) return existing;
    } catch (_) {
      return _localFallback(uid, profile);
    }

    final toCreate = _buildCreatePayload(uid, profile);

    try {
      await _ref(uid).set(toCreate.toMap());
      return toCreate;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied' || e.code == 'already-exists') {
        try {
          final again = await getEntitlement(uid);
          if (again != null) return again;
        } catch (_) {}
        return _localFallback(uid, profile);
      }
      rethrow;
    }
  }

  Future<UserEntitlement> ensureEntitlementRest({
    required AuthSession session,
    SaasUserProfile? profile,
  }) async {
    try {
      final existing = await FirestoreRestClient.instance.getEntitlement(
        session,
      );
      if (existing != null) return existing;
    } catch (_) {
      return _localFallback(session.uid, profile);
    }

    final toCreate = _buildCreatePayload(session.uid, profile);

    try {
      await FirestoreRestClient.instance.createEntitlementIfAbsent(
        session: session,
        entitlement: toCreate.toMap(),
      );
      return (await FirestoreRestClient.instance.getEntitlement(session)) ??
          toCreate;
    } catch (_) {
      return _localFallback(session.uid, profile);
    }
  }

  UserEntitlement _buildCreatePayload(String uid, SaasUserProfile? profile) {
    if (profile != null &&
        profile.hasLegacySubscriptionFields &&
        profile.legacyPlan != null) {
      return UserEntitlement.fromLegacyUserMap(uid, {
        'plan': profile.legacyPlan,
        'subscriptionStatus': profile.legacySubscriptionStatus ?? 'active',
        'trialEndsAt': profile.legacyTrialEndsAt?.toIso8601String(),
        'createdAt': profile.createdAt.toIso8601String(),
      });
    }
    return UserEntitlement.freeBootstrap(uid);
  }

  /// Fallback local: respeta plan legacy del perfil; nunca inventa Pro nuevo.
  UserEntitlement _localFallback(String uid, SaasUserProfile? profile) {
    return _buildCreatePayload(uid, profile);
  }
}
