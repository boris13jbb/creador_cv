import '../config/saas_config.dart';

/// Derechos de suscripción. Solo backend puede mutarlos tras el bootstrap inicial.
class UserEntitlement {
  static const int currentSchemaVersion = 1;

  final String uid;
  final SubscriptionPlan plan;
  final String subscriptionStatus;
  final DateTime? trialEndsAt;
  final String source;
  final int schemaVersion;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserEntitlement({
    required this.uid,
    required this.plan,
    this.subscriptionStatus = 'active',
    this.trialEndsAt,
    this.source = 'client_bootstrap',
    this.schemaVersion = currentSchemaVersion,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPro {
    if (plan != SubscriptionPlan.pro) return false;
    return subscriptionStatus == 'active' || subscriptionStatus == 'trialing';
  }

  /// Trial de marketing: solo aplica mientras el estado sea trialing y no haya expirado.
  bool get isTrialActive {
    if (subscriptionStatus != 'trialing') return false;
    if (trialEndsAt == null) return false;
    return trialEndsAt!.isAfter(DateTime.now());
  }

  int get maxCvs => plan.maxCvs;

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'plan': plan.id,
    'subscriptionStatus': subscriptionStatus,
    'trialEndsAt': trialEndsAt?.toIso8601String(),
    'source': source,
    'schemaVersion': schemaVersion,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory UserEntitlement.freeBootstrap(String uid, {DateTime? trialEndsAt}) {
    final now = DateTime.now();
    return UserEntitlement(
      uid: uid,
      plan: SubscriptionPlan.free,
      subscriptionStatus: 'active',
      trialEndsAt: trialEndsAt ?? now.add(const Duration(days: 14)),
      source: 'client_bootstrap',
      schemaVersion: currentSchemaVersion,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory UserEntitlement.fromLegacyUserMap(
    String uid,
    Map<String, dynamic> userMap,
  ) {
    final now = DateTime.now();
    return UserEntitlement(
      uid: uid,
      plan: SubscriptionPlan.fromId(userMap['plan'] as String?),
      subscriptionStatus: userMap['subscriptionStatus'] as String? ?? 'active',
      trialEndsAt: userMap['trialEndsAt'] != null
          ? DateTime.tryParse(userMap['trialEndsAt'] as String)
          : null,
      source: 'legacy_migration',
      schemaVersion: currentSchemaVersion,
      createdAt:
          DateTime.tryParse(userMap['createdAt'] as String? ?? '') ?? now,
      updatedAt: now,
    );
  }

  factory UserEntitlement.fromMap(Map<String, dynamic> map) {
    return UserEntitlement(
      uid: map['uid'] as String? ?? '',
      plan: SubscriptionPlan.fromId(map['plan'] as String?),
      subscriptionStatus: map['subscriptionStatus'] as String? ?? 'active',
      trialEndsAt: map['trialEndsAt'] != null
          ? DateTime.tryParse(map['trialEndsAt'] as String)
          : null,
      source: map['source'] as String? ?? 'unknown',
      schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 1,
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
