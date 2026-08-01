/**
 * Mapeo puro Stripe → entitlement (testeable sin red ni secretos).
 */

export type EntitlementWrite = {
  uid: string;
  plan: "free" | "pro";
  subscriptionStatus: string;
  trialEndsAt: string | null;
  source: "stripe";
  schemaVersion: 1;
  updatedAt: string;
  stripeCustomerId?: string;
  stripeSubscriptionId?: string;
  stripePriceId?: string;
};

const PRO_STATUSES = new Set(["active", "trialing"]);

export function mapSubscriptionToEntitlement(input: {
  uid: string;
  status: string;
  trialEndUnix?: number | null;
  customerId?: string | null;
  subscriptionId?: string | null;
  priceId?: string | null;
  now?: Date;
}): EntitlementWrite {
  const now = input.now ?? new Date();
  const status = (input.status || "incomplete").toLowerCase();
  const isPro = PRO_STATUSES.has(status);

  return {
    uid: input.uid,
    plan: isPro ? "pro" : "free",
    subscriptionStatus: status,
    trialEndsAt:
      typeof input.trialEndUnix === "number" && input.trialEndUnix > 0
        ? new Date(input.trialEndUnix * 1000).toISOString()
        : null,
    source: "stripe",
    schemaVersion: 1,
    updatedAt: now.toISOString(),
    ...(input.customerId ? {stripeCustomerId: input.customerId} : {}),
    ...(input.subscriptionId
      ? {stripeSubscriptionId: input.subscriptionId}
      : {}),
    ...(input.priceId ? {stripePriceId: input.priceId} : {}),
  };
}

export function freeAfterCancel(uid: string, now = new Date()): EntitlementWrite {
  return mapSubscriptionToEntitlement({
    uid,
    status: "canceled",
    now,
  });
}
