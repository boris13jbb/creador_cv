import 'user_entitlement.dart';

/// Estado de suscripción que ve la app.
///
/// - [pending]: todavía no hay decisión fiable (carga en curso).
/// - [free] / [pro]: decisión confirmada.
/// - [error]: falló la verificación; no equivale a Free ni otorga Pro nuevo.
enum SubscriptionAccess { pending, free, pro, error }

extension SubscriptionAccessX on SubscriptionAccess {
  /// Free o Pro ya leídos del servidor (o bootstrap confirmado).
  bool get isConfirmed =>
      this == SubscriptionAccess.free || this == SubscriptionAccess.pro;

  /// Pendiente de red o error de lectura: no degradar ni elevar permisos.
  bool get isUnresolved =>
      this == SubscriptionAccess.pending || this == SubscriptionAccess.error;
}

/// Resuelve el acceso sin tratar una carga incompleta o fallida como Free.
///
/// [planUnconfirmed] es true cuando el último intento no pudo leer el
/// entitlement en el servidor y no hay uno confirmado en memoria.
SubscriptionAccess resolveSubscriptionAccess({
  required bool authenticated,
  required bool loading,
  required bool planUnconfirmed,
  required UserEntitlement? entitlement,
}) {
  if (!authenticated) return SubscriptionAccess.free;

  // Entitlement en memoria sin marca de no confirmado ⇒ decisión fiable.
  if (entitlement != null && !planUnconfirmed) {
    return entitlement.isPro ? SubscriptionAccess.pro : SubscriptionAccess.free;
  }

  // Fallo de lectura / sync: informar error, no fingir Free.
  if (planUnconfirmed) {
    return SubscriptionAccess.error;
  }

  // Primera carga o reintento en curso.
  if (loading || entitlement == null) {
    return SubscriptionAccess.pending;
  }

  return SubscriptionAccess.free;
}
