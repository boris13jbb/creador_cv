/// Lógica pura de límites Free/Pro (testeable sin Firebase).
///
/// Alineada con `firestore.rules` (`freeUnderResumeLimit`) y
/// `functions/src/planLimits.ts`.
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

  /// Política de cupo Free (align createResume / usage).
  ///
  /// Rules ya no autorizan create Free directo; la Function cuenta docs en TX.
  /// Ausencia de `usage` ≠ cupo ilimitado.
  static bool freeRulesAllowCreate({
    required bool usageExists,
    required int? resumeCount,
  }) {
    if (!usageExists) return false;
    if (resumeCount == null || resumeCount < 0) return false;
    return resumeCount < freeMaxCvs;
  }

  static String planUnresolvedCreateMessage() =>
      'Estamos verificando tu plan. Inténtalo cuando termine la comprobación.';

  static String usageSyncRequiredMessage() =>
      'No se pudo verificar el límite de CVs. Revisa la conexión e inténtalo de nuevo.';

  static String limitReachedMessage({required bool isPro}) {
    final max = maxCvsFor(isPro: isPro);
    final plan = isPro ? 'Pro' : 'Free';
    return 'Límite del plan $plan: máximo $max CVs. Mejora tu plan para continuar.';
  }
}
