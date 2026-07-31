import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/saas_config.dart';
import '../models/saas_user_profile.dart';

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
      return SaasUserProfile.fromMap(snap.data()!);
    }

    final now = DateTime.now();
    final profile = SaasUserProfile(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName ?? (user.email?.split('@').first ?? 'Usuario'),
      plan: SubscriptionPlan.free,
      subscriptionStatus: 'active',
      trialEndsAt: now.add(const Duration(days: 14)),
      createdAt: now,
      updatedAt: now,
    );
    await ref.set(profile.toMap());
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

  Future<void> setPlan(String uid, SubscriptionPlan plan, {String status = 'active'}) async {
    await _userRef(uid).update({
      'plan': plan.id,
      'subscriptionStatus': status,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }
}
