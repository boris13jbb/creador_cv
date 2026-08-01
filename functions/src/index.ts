import * as admin from "firebase-admin";
import {setGlobalOptions} from "firebase-functions/v2";
import {FUNCTIONS_REGION} from "./config";

admin.initializeApp();
setGlobalOptions({region: FUNCTIONS_REGION});

export {createCheckoutSession} from "./createCheckoutSession";
export {createPortalSession} from "./createPortalSession";
export {stripeWebhook} from "./stripeWebhook";
export {syncResumeUsage} from "./syncResumeUsage";
export {onResumeUsageChanged} from "./resumeUsageTriggers";

export {
  mapSubscriptionToEntitlement,
  freeAfterCancel,
} from "./entitlements";

export {
  isAlreadyExistsError,
  isHandledBillingEvent,
  shouldProcessClaim,
} from "./idempotency";

export {
  FREE_MAX_CVS,
  canCreateResume,
  isProEntitlement,
} from "./planLimits";
