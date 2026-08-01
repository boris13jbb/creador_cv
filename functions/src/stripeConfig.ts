import {defineSecret, defineString} from "firebase-functions/params";

/** Secretos Stripe (Firebase Functions secrets). No hardcodear valores. */
export const stripeSecretKey = defineSecret("STRIPE_SECRET_KEY");
export const stripeWebhookSecret = defineSecret("STRIPE_WEBHOOK_SECRET");

/** Price ID del plan Pro (p. ej. price_...). Configurable sin redeploy de secretos. */
export const stripePriceId = defineString("STRIPE_PRICE_ID", {default: ""});

export const checkoutSuccessUrl = defineString("CHECKOUT_SUCCESS_URL", {
  default: "https://example.com/pricing?checkout=success",
});

export const checkoutCancelUrl = defineString("CHECKOUT_CANCEL_URL", {
  default: "https://example.com/pricing?checkout=cancel",
});

export const portalReturnUrl = defineString("PORTAL_RETURN_URL", {
  default: "https://example.com/pricing",
});
