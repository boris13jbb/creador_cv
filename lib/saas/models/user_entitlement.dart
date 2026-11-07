import '../config/saas_config.dart';

/// Resultado de parsear un instante de concesión (fail-closed si es inválido).
enum GrantInstantKind { absent, invalid, ok }

class GrantInstant {
  const GrantInstant._(this.kind, this.value);
  const GrantInstant.absent() : this._(GrantInstantKind.absent, null);
  const GrantInstant.invalid() : this._(GrantInstantKind.invalid, null);
  GrantInstant.ok(DateTime value) : this._(GrantInstantKind.ok, value.toUtc());

  final GrantInstantKind kind;
  final DateTime? value;
}

/// Parsea ISO, DateTime o Timestamp-like de Firestore.
GrantInstant parseGrantInstant(dynamic value) {
  if (value == null) return const GrantInstant.absent();
  if (value is DateTime) {
    return GrantInstant.ok(value);
  }
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return const GrantInstant.invalid();
    final parsed = DateTime.tryParse(trimmed);
    if (parsed == null) return const GrantInstant.invalid();
    return GrantInstant.ok(parsed);
  }
  // cloud_firestore.Timestamp (duck-typed: toDate()).
  try {
    final dynamic maybe = value;
    if (maybe.toDate is Function) {
      final d = maybe.toDate() as DateTime;
      return GrantInstant.ok(d);
    }
  } catch (_) {
    return const GrantInstant.invalid();
  }
  return const GrantInstant.invalid();
}

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
  final String? grantedBy;
  final DateTime? grantedAt;
  final String? grantNote;
  final DateTime? grantStartsAt;
  final DateTime? grantExpiresAt;
  final String? grantModality;

  /// Si el doc traía fechas temporales ilegibles (no se confunden con «ausentes»).
  final bool grantWindowInvalid;

  const UserEntitlement({
    required this.uid,
    required this.plan,
    this.subscriptionStatus = 'active',
    this.trialEndsAt,
    this.source = 'client_bootstrap',
    this.schemaVersion = currentSchemaVersion,
    required this.createdAt,
    required this.updatedAt,
    this.grantedBy,
    this.grantedAt,
    this.grantNote,
    this.grantStartsAt,
    this.grantExpiresAt,
    this.grantModality,
    this.grantWindowInvalid = false,
  });

  bool get _hasTemporalSignal {
    if (grantModality == 'temporary') return true;
    if (grantStartsAt != null || grantExpiresAt != null) return true;
    if (grantWindowInvalid) return true;
    return false;
  }

  /// Pro de cortesía otorgado por superadmin (aún vigente en [now]).
  bool isAdminGrantActive({DateTime? now}) {
    if (source != 'admin_grant') return false;
    if (plan != SubscriptionPlan.pro) return false;
    if (subscriptionStatus != 'active') return false;

    final n = (now ?? DateTime.now()).toUtc();

    if (!_hasTemporalSignal) {
      // Cortesía habitual / legado sin ventana.
      return true;
    }
    if (grantWindowInvalid) return false;
    if (grantExpiresAt == null) return false;
    if (grantStartsAt != null && n.isBefore(grantStartsAt!.toUtc())) {
      return false;
    }
    // now < expiresAt  (igualdad en el vencimiento ⇒ denegado)
    if (!n.isBefore(grantExpiresAt!.toUtc())) return false;
    return true;
  }

  /// Compatibilidad: usa reloj del dispositivo.
  bool get isAdminGrant => isAdminGrantActive();

  bool isProAt({DateTime? now}) {
    if (plan != SubscriptionPlan.pro) return false;
    if (subscriptionStatus != 'active' && subscriptionStatus != 'trialing') {
      return false;
    }
    if (source == 'admin_grant') return isAdminGrantActive(now: now);
    return true;
  }

  bool get isPro => isProAt();

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
    if (grantedBy != null) 'grantedBy': grantedBy,
    if (grantedAt != null) 'grantedAt': grantedAt!.toIso8601String(),
    if (grantNote != null) 'grantNote': grantNote,
    if (grantStartsAt != null)
      'grantStartsAt': grantStartsAt!.toIso8601String(),
    if (grantExpiresAt != null)
      'grantExpiresAt': grantExpiresAt!.toIso8601String(),
    if (grantModality != null) 'grantModality': grantModality,
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
          ? DateTime.tryParse('${userMap['trialEndsAt']}')
          : null,
      source: 'legacy_migration',
      schemaVersion: currentSchemaVersion,
      createdAt:
          DateTime.tryParse(userMap['createdAt'] as String? ?? '') ?? now,
      updatedAt: now,
    );
  }

  factory UserEntitlement.fromMap(Map<String, dynamic> map) {
    // Prefer Timestamps de Rules/backend si existen.
    final startParsed = _preferInstant(
      map['grantStartsAtTs'],
      map['grantStartsAt'],
    );
    final endParsed = _preferInstant(
      map['grantExpiresAtTs'],
      map['grantExpiresAt'],
    );
    final modality = map['grantModality'] as String?;
    final temporalSignal = modality == 'temporary' ||
        startParsed.kind != GrantInstantKind.absent ||
        endParsed.kind != GrantInstantKind.absent;
    final invalid = temporalSignal &&
        (startParsed.kind == GrantInstantKind.invalid ||
            endParsed.kind == GrantInstantKind.invalid ||
            (modality == 'temporary' &&
                endParsed.kind == GrantInstantKind.absent) ||
            (temporalSignal &&
                endParsed.kind == GrantInstantKind.absent &&
                startParsed.kind != GrantInstantKind.absent));

    return UserEntitlement(
      uid: map['uid'] as String? ?? '',
      plan: SubscriptionPlan.fromId(map['plan'] as String?),
      subscriptionStatus: map['subscriptionStatus'] as String? ?? 'active',
      trialEndsAt: parseGrantInstant(map['trialEndsAt']).value,
      source: map['source'] as String? ?? 'unknown',
      schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 1,
      createdAt: parseGrantInstant(map['createdAt']).value ?? DateTime.now(),
      updatedAt: parseGrantInstant(map['updatedAt']).value ?? DateTime.now(),
      grantedBy: map['grantedBy'] as String?,
      grantedAt: parseGrantInstant(map['grantedAt']).value,
      grantNote: map['grantNote'] as String?,
      grantStartsAt: startParsed.value,
      grantExpiresAt: endParsed.value,
      grantModality: modality,
      grantWindowInvalid: invalid,
    );
  }

  static GrantInstant _preferInstant(dynamic primary, dynamic fallback) {
    final a = parseGrantInstant(primary);
    if (a.kind != GrantInstantKind.absent) return a;
    return parseGrantInstant(fallback);
  }
}
