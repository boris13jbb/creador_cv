/// Planes y límites del SaaS CV Maker.
class SaasConfig {
  static const String productName = 'CV Maker';
  static const String freePlanId = 'free';
  static const String proPlanId = 'pro';

  static const int freeMaxCvs = 3;

  static const String stripePaymentLink = String.fromEnvironment(
    'STRIPE_PAYMENT_LINK',
    defaultValue: '',
  );

  static const String supportEmail = 'boris13jb@gmail.com';
}

enum SubscriptionPlan {
  free('free', 'Free'),
  pro('pro', 'Pro');

  const SubscriptionPlan(this.id, this.label);
  final String id;
  final String label;

  int get maxCvs => this == SubscriptionPlan.pro ? 999999 : SaasConfig.freeMaxCvs;

  bool get canAllDesigns => this == SubscriptionPlan.pro;

  static SubscriptionPlan fromId(String? id) {
    if (id == SaasConfig.proPlanId) return SubscriptionPlan.pro;
    return SubscriptionPlan.free;
  }
}
