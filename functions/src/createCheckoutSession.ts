import {onRequest} from "firebase-functions/v2/https";
import {logger} from "firebase-functions";
import {requireUidFromRequest, jsonError, isUnauthenticatedError} from "./auth";
import {
  checkoutCancelUrl,
  checkoutSuccessUrl,
  FUNCTIONS_REGION,
  stripePriceId,
  stripeSecretKey,
} from "./config";
import {createStripe, getOrCreateStripeCustomer} from "./stripeStore";

/**
 * POST /createCheckoutSession
 * Authorization: Bearer <Firebase ID token>
 * Body opcional: { successUrl?, cancelUrl? }
 * → { url }
 */
export const createCheckoutSession = onRequest(
  {
    region: FUNCTIONS_REGION,
    cors: true,
    secrets: [stripeSecretKey],
  },
  async (req, res) => {
    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }
    if (req.method !== "POST") {
      jsonError(res, 405, "method-not-allowed", "Usa POST.");
      return;
    }

    try {
      const {uid, email} = await requireUidFromRequest(req);
      const priceId = stripePriceId.value();
      if (!priceId) {
        jsonError(
          res,
          500,
          "misconfigured",
          "STRIPE_PRICE_ID no está configurado en Functions.",
        );
        return;
      }

      const stripe = createStripe(stripeSecretKey.value());
      const customerId = await getOrCreateStripeCustomer({
        stripe,
        uid,
        email,
      });

      const body = (req.body ?? {}) as {
        successUrl?: string;
        cancelUrl?: string;
      };

      const session = await stripe.checkout.sessions.create({
        mode: "subscription",
        customer: customerId,
        line_items: [{price: priceId, quantity: 1}],
        success_url: body.successUrl || checkoutSuccessUrl.value(),
        cancel_url: body.cancelUrl || checkoutCancelUrl.value(),
        client_reference_id: uid,
        metadata: {firebaseUid: uid},
        subscription_data: {
          metadata: {firebaseUid: uid},
        },
        allow_promotion_codes: true,
      });

      if (!session.url) {
        jsonError(res, 500, "stripe-error", "Checkout sin URL.");
        return;
      }

      res.status(200).json({url: session.url, sessionId: session.id});
    } catch (e: unknown) {
      logger.error("createCheckoutSession", e);
      if (isUnauthenticatedError(e)) {
        jsonError(res, 401, "unauthenticated", "No autenticado");
        return;
      }
      const message =
        e instanceof Error
          ? e.message
          : "No se pudo crear la sesión de Checkout";
      jsonError(res, 500, "internal", message);
    }
  },
);
