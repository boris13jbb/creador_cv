import {onRequest} from "firebase-functions/v2/https";
import {logger} from "firebase-functions";
import * as admin from "firebase-admin";
import {requireUidFromRequest, jsonError, isUnauthenticatedError} from "./auth";
import {FUNCTIONS_REGION} from "./runtime";
import {portalReturnUrl, stripeSecretKey} from "./stripeConfig";
import {createStripe, getOrCreateStripeCustomer} from "./stripeStore";

/**
 * POST /createPortalSession
 * Authorization: Bearer <Firebase ID token>
 * → { url }
 */
export const createPortalSession = onRequest(
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
      const snap = await admin
        .firestore()
        .collection("billingCustomers")
        .doc(uid)
        .get();
      let customerId = snap.data()?.stripeCustomerId as string | undefined;

      const stripe = createStripe(stripeSecretKey.value());
      if (!customerId) {
        customerId = await getOrCreateStripeCustomer({stripe, uid, email});
      }

      const body = (req.body ?? {}) as {returnUrl?: string};
      const portal = await stripe.billingPortal.sessions.create({
        customer: customerId,
        return_url: body.returnUrl || portalReturnUrl.value(),
      });

      res.status(200).json({url: portal.url});
    } catch (e: unknown) {
      logger.error("createPortalSession", e);
      if (isUnauthenticatedError(e)) {
        jsonError(res, 401, "unauthenticated", "No autenticado");
        return;
      }
      const message =
        e instanceof Error
          ? e.message
          : "No se pudo abrir el portal de cliente";
      jsonError(res, 500, "internal", message);
    }
  },
);
