import '../config/saas_config.dart';

class SaasUserProfile {
  final String uid;
  final String email;
  final String displayName;
  final SubscriptionPlan plan;
  final String subscriptionStatus;
  final DateTime? trialEndsAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SaasUserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.plan,
    this.subscriptionStatus = 'active',
    this.trialEndsAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPro =>
      plan == SubscriptionPlan.pro &&
      (subscriptionStatus == 'active' || subscriptionStatus == 'trialing');

  int get maxCvs => plan.maxCvs;

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'plan': plan.id,
        'subscriptionStatus': subscriptionStatus,
        'trialEndsAt': trialEndsAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory SaasUserProfile.fromMap(Map<String, dynamic> map) {
    return SaasUserProfile(
      uid: map['uid'] as String? ?? '',
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      plan: SubscriptionPlan.fromId(map['plan'] as String?),
      subscriptionStatus: map['subscriptionStatus'] as String? ?? 'active',
      trialEndsAt: map['trialEndsAt'] != null
          ? DateTime.tryParse(map['trialEndsAt'] as String)
          : null,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
