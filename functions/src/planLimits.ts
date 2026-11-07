/** Límites Free/Pro alineados con `lib/saas/config/plan_limits.dart`. */

import {isAdminGrantActiveInWindow} from "./grantAccessPolicy";

export const FREE_MAX_CVS = 3;

export function maxCvsFor(isPro: boolean): number {
  return isPro ? 999999 : FREE_MAX_CVS;
}

export function canCreateResume(input: {
  currentCount: number;
  isPro: boolean;
}): boolean {
  if (input.currentCount < 0) return false;
  return input.currentCount < maxCvsFor(input.isPro);
}

/**
 * ¿El entitlement autoriza Pro en este instante?
 * Suscripciones Stripe/legacy: plan+status.
 * admin_grant: ventana temporal (starts/expires) fail-closed.
 */
export function isProEntitlement(
  data: Record<string, unknown> | null | undefined,
  now: Date = new Date(),
): boolean {
  if (!data) return false;
  const plan = String(data.plan || "").toLowerCase();
  const status = String(data.subscriptionStatus || "").toLowerCase();
  if (plan !== "pro") return false;
  if (status !== "active" && status !== "trialing") return false;

  const source = String(data.source || "");
  if (source === "admin_grant") {
    return isAdminGrantActiveInWindow(data, now);
  }
  return true;
}
