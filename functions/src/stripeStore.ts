import {
  freeAfterCancel,
  mapSubscriptionToEntitlement,
  type EntitlementWrite,
} from "./entitlements";
import {isAlreadyExistsError} from "./idempotency";
import * as admin from "firebase-admin";
import Stripe from "stripe";

const db = () => admin.firestore();

export function createStripe(secretKey: string): Stripe {
  return new Stripe(secretKey, {
    typescript: true,
  });
}

export async function getOrCreateStripeCustomer(params: {
  stripe: Stripe;
  uid: string;
  email?: string;
}): Promise<string> {
  const ref = db().collection("billingCustomers").doc(params.uid);
  const snap = await ref.get();
  const existing = snap.data()?.stripeCustomerId as string | undefined;
  if (existing) return existing;

  const customer = await params.stripe.customers.create({
    email: params.email,
    metadata: {firebaseUid: params.uid},
  });

  await ref.set(
    {
      uid: params.uid,
      stripeCustomerId: customer.id,
      email: params.email ?? null,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    },
    {merge: true},
  );

  return customer.id;
}

export async function uidFromCustomerId(
  customerId: string,
): Promise<string | null> {
  const byDoc = await db()
    .collection("billingCustomers")
    .where("stripeCustomerId", "==", customerId)
    .limit(1)
    .get();
  if (!byDoc.empty) {
    return byDoc.docs[0].id;
  }
  return null;
}

export async function writeEntitlement(data: EntitlementWrite): Promise<void> {
  const ref = db().collection("entitlements").doc(data.uid);
  const existing = await ref.get();
  const payload: Record<string, unknown> = {
    ...data,
    createdAt: existing.exists
      ? (existing.data()?.createdAt ?? data.updatedAt)
      : data.updatedAt,
  };
  await ref.set(payload, {merge: true});
}

export async function applySubscriptionSnapshot(params: {
  uid: string;
  subscription: Stripe.Subscription;
}): Promise<void> {
  const sub = params.subscription;
  const priceId = sub.items.data[0]?.price?.id ?? null;
  const customerId =
    typeof sub.customer === "string" ? sub.customer : sub.customer?.id;

  await writeEntitlement(
    mapSubscriptionToEntitlement({
      uid: params.uid,
      status: sub.status,
      trialEndUnix: sub.trial_end,
      customerId,
      subscriptionId: sub.id,
      priceId,
    }),
  );

  if (customerId) {
    await db()
      .collection("billingCustomers")
      .doc(params.uid)
      .set(
        {
          uid: params.uid,
          stripeCustomerId: customerId,
          stripeSubscriptionId: sub.id,
          updatedAt: new Date().toISOString(),
        },
        {merge: true},
      );
  }
}

export async function markCanceled(uid: string): Promise<void> {
  await writeEntitlement(freeAfterCancel(uid));
}

/**
 * Idempotencia: crea billingEvents/{eventId}. Si ya existe, retorna false.
 */
export async function claimStripeEvent(eventId: string, type: string): Promise<boolean> {
  const ref = db().collection("billingEvents").doc(eventId);
  try {
    await ref.create({
      id: eventId,
      type,
      processedAt: new Date().toISOString(),
    });
    return true;
  } catch (e: unknown) {
    if (isAlreadyExistsError(e)) return false;
    throw e;
  }
}
