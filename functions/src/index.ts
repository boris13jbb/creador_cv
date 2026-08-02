import * as admin from "firebase-admin";
import {setGlobalOptions} from "firebase-functions/v2";
import {FUNCTIONS_REGION} from "./runtime";

admin.initializeApp();
setGlobalOptions({region: FUNCTIONS_REGION});

/**
 * Entrada por defecto sin secretos Stripe (Secret Manager no requerido).
 * Para billing: exporta también desde `billing.ts` o reactiva las líneas en
 * docs/STRIPE_BILLING.md tras crear STRIPE_SECRET_KEY / STRIPE_WEBHOOK_SECRET.
 */
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

/** Panel superadmin: grants Pro de cortesía + monitoreo (claim superadmin). */
export {
  adminGrantPro,
  adminRevokeGrant,
  adminGetUser,
  adminListUsers,
  adminGetMetrics,
} from "./adminApi";
