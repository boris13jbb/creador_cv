/// Lógica pura de límites Free/Pro (testeable sin Firebase).
abstract final class PlanLimits {
  static const int freeMaxCvs = 3;

  static int maxCvsFor({required bool isPro}) => isPro ? 999999 : freeMaxCvs;

  /// `true` si se puede crear un CV más dados [currentCount] documentos.
  static bool canCreateResume({
    required int currentCount,
    required bool isPro,
  }) {
    if (currentCount < 0) return false;
    return currentCount < maxCvsFor(isPro: isPro);
  }

  static String limitReachedMessage({required bool isPro}) {
    final max = maxCvsFor(isPro: isPro);
    final plan = isPro ? 'Pro' : 'Free';
    return 'Límite del plan $plan: máximo $max CVs. Mejora tu plan para continuar.';
  }
}
