/// Perfil editable del usuario (sin privilegios de suscripción).
class SaasUserProfile {
  static const int currentSchemaVersion = 1;

  final String uid;
  final String email;
  final String displayName;
  final int schemaVersion;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Campos legacy (solo lectura migratoria). No se escriben en perfiles nuevos.
  final String? legacyPlan;
  final String? legacySubscriptionStatus;
  final DateTime? legacyTrialEndsAt;

  const SaasUserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    this.schemaVersion = currentSchemaVersion,
    required this.createdAt,
    required this.updatedAt,
    this.legacyPlan,
    this.legacySubscriptionStatus,
    this.legacyTrialEndsAt,
  });

  bool get hasLegacySubscriptionFields =>
      legacyPlan != null || legacySubscriptionStatus != null;

  /// Mapa seguro para escritura cliente (sin plan/subscription).
  Map<String, dynamic> toWritableMap() => {
    'uid': uid,
    'email': email,
    'displayName': displayName,
    'schemaVersion': schemaVersion,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory SaasUserProfile.fromMap(Map<String, dynamic> map) {
    return SaasUserProfile(
      uid: map['uid'] as String? ?? '',
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 1,
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      legacyPlan: map['plan'] as String?,
      legacySubscriptionStatus: map['subscriptionStatus'] as String?,
      legacyTrialEndsAt: map['trialEndsAt'] != null
          ? DateTime.tryParse(map['trialEndsAt'] as String)
          : null,
    );
  }
}
