import {onRequest} from "firebase-functions/v2/https";
import {logger} from "firebase-functions";
import Stripe from "stripe";
import {FUNCTIONS_REGION} from "./runtime";
import {stripeSecretKey, stripeWebhookSecret} from "./stripeConfig";
import {
  applySubscriptionSnapshot,
  claimStripeEvent,
  createStripe,
  markCanceled,
  uidFromCustomerId,
} from "./stripeStore";

/**
 * Webhook Stripe (raw body + firma).
 * Eventos: checkout.session.completed, customer.subscription.*, invoice.*
 */
export const stripeWebhook = onRequest(
  {
    region: FUNCTIONS_REGION,
    cors: false,
    secrets: [stripeSecretKey, stripeWebhookSecret],
  },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }

    const stripe = createStripe(stripeSecretKey.value());
    const signature = req.get("stripe-signature");
    if (!signature) {
      res.status(400).send("Missing stripe-signature");
      return;
    }

    let event: Stripe.Event;
    try {
      event = stripe.webhooks.constructEvent(
        req.rawBody,
        signature,
        stripeWebhookSecret.value(),
      );
    } catch (err) {
      logger.warn("Webhook signature failed", err);
      res.status(400).send("Invalid signature");
      return;
    }

    const claimed = await claimStripeEvent(event.id, event.type);
    if (!claimed) {
      logger.info("Evento ya procesado", {id: event.id, type: event.type});
      res.json({received: true, duplicate: true});
      return;
    }

    try {
      switch (event.type) {
        case "checkout.session.completed": {
          const session = event.data.object as Stripe.Checkout.Session;
          const uid =
            session.client_reference_id ||
            session.metadata?.firebaseUid ||
            null;
          if (!uid) {
            logger.warn("checkout sin uid", {sessionId: session.id});
            break;
          }
          if (session.mode === "subscription" && session.subscription) {
            const subId =
              typeof session.subscription === "string"
                ? session.subscription
                : session.subscription.id;
            const sub = await stripe.subscriptions.retrieve(subId);
            await applySubscriptionSnapshot({uid, subscription: sub});
          }
          break;
        }
        case "customer.subscription.created":
        case "customer.subscription.updated": {
          const sub = event.data.object as Stripe.Subscription;
          const uid =
            sub.metadata?.firebaseUid ||
            (await uidFromCustomerId(
              typeof sub.customer === "string"
                ? sub.customer
                : sub.customer.id,
            ));
          if (!uid) {
            logger.warn("subscription sin uid", {subId: sub.id});
            break;
          }
          await applySubscriptionSnapshot({uid, subscription: sub});
          break;
        }
        case "customer.subscription.deleted": {
          const sub = event.data.object as Stripe.Subscription;
          const uid =
            sub.metadata?.firebaseUid ||
            (await uidFromCustomerId(
              typeof sub.customer === "string"
                ? sub.customer
                : sub.customer.id,
            ));
          if (!uid) break;
          await markCanceled(uid);
          break;
        }
        case "invoice.paid":
        case "invoice.payment_failed": {
          const invoice = event.data.object as Stripe.Invoice;
          const subRef = invoice.subscription;
          if (!subRef) break;
          const subId = typeof subRef === "string" ? subRef : subRef.id;
          const sub = await stripe.subscriptions.retrieve(subId);
          const customerId =
            typeof invoice.customer === "string"
              ? invoice.customer
              : invoice.customer?.id;
          const uid =
            sub.metadata?.firebaseUid ||
            (customerId ? await uidFromCustomerId(customerId) : null);
          if (!uid) break;
          if (event.type === "invoice.payment_failed") {
            await applySubscriptionSnapshot({
              uid,
              subscription: Object.assign(sub, {status: "past_due"}),
            });
          } else {
            await applySubscriptionSnapshot({uid, subscription: sub});
          }
          break;
        }
        default:
          logger.info("Evento ignorado", {type: event.type});
      }

      res.json({received: true});
    } catch (e) {
      logger.error("Webhook handler failed", e);
      // No re-claim: permitir reintento Stripe borrando el evento manualmente si hace falta.
      res.status(500).send("Webhook handler error");
    }
  },
);
