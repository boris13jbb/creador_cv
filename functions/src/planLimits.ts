/** Límites Free/Pro alineados con `lib/saas/config/plan_limits.dart`. */

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

export function isProEntitlement(data: {
  plan?: string;
  subscriptionStatus?: string;
} | null | undefined): boolean {
  if (!data) return false;
  const plan = (data.plan || "").toLowerCase();
  const status = (data.subscriptionStatus || "").toLowerCase();
  return plan === "pro" && (status === "active" || status === "trialing");
}
