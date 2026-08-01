/**
 * Helpers puros de idempotencia / errores Firestore (testeables sin Admin SDK).
 */

export function isAlreadyExistsError(e: unknown): boolean {
  const err = e as {code?: number | string};
  return err.code === 6 || err.code === "already-exists";
}

/** Tipos de evento Stripe que mutan entitlements. */
export const BILLING_EVENT_TYPES = [
  "checkout.session.completed",
  "customer.subscription.created",
  "customer.subscription.updated",
  "customer.subscription.deleted",
  "invoice.paid",
  "invoice.payment_failed",
] as const;

export type BillingEventType = (typeof BILLING_EVENT_TYPES)[number];

export function isHandledBillingEvent(type: string): boolean {
  return (BILLING_EVENT_TYPES as readonly string[]).includes(type);
}

/**
 * Decide si un evento ya reclamado debe cortocircuitar el handler.
 * `claimed === false` ⇒ duplicado.
 */
export function shouldProcessClaim(claimed: boolean): boolean {
  return claimed === true;
}
