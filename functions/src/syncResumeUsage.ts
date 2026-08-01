import {onRequest} from "firebase-functions/v2/https";
import {logger} from "firebase-functions";
import * as admin from "firebase-admin";
import {requireUidFromRequest, jsonError, isUnauthenticatedError} from "./auth";
import {FUNCTIONS_REGION} from "./config";
import {canCreateResume, isProEntitlement} from "./planLimits";
import {refreshResumeUsage} from "./usageStore";

/**
 * POST /syncResumeUsage
 * Authorization: Bearer <Firebase ID token>
 * → { resumeCount, isPro, canCreate }
 *
 * Recuenta CVs y materializa `usage/{uid}` para que las reglas Firestore
 * puedan aplicar el límite Free en el servidor.
 */
export const syncResumeUsage = onRequest(
  {
    region: FUNCTIONS_REGION,
    cors: true,
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
      const {uid} = await requireUidFromRequest(req);
      const usage = await refreshResumeUsage(uid);
      const entSnap = await admin.firestore().doc(`entitlements/${uid}`).get();
      const isPro = isProEntitlement(
        entSnap.exists ? (entSnap.data() as {plan?: string; subscriptionStatus?: string}) : null,
      );
      const canCreate = canCreateResume({
        currentCount: usage.resumeCount,
        isPro,
      });

      res.status(200).json({
        resumeCount: usage.resumeCount,
        isPro,
        canCreate,
      });
    } catch (e: unknown) {
      logger.error("syncResumeUsage", e);
      if (isUnauthenticatedError(e)) {
        jsonError(res, 401, "unauthenticated", "No autenticado");
        return;
      }
      const message =
        e instanceof Error ? e.message : "No se pudo sincronizar el uso de CVs";
      jsonError(res, 500, "internal", message);
    }
  },
);
