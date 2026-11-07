import {onRequest} from "firebase-functions/v2/https";
import {logger} from "firebase-functions";
import {FUNCTIONS_REGION} from "./runtime";
import {requireUidFromRequest, jsonError, isUnauthenticatedError} from "./auth";
import {expireGrantIfNeeded} from "./adminGrants";
import {createResumeAtomic, CreateResumeError} from "./createResumeCore";
import {refreshResumeUsage} from "./usageStore";

/**
 * POST /createResume
 * Authorization: Bearer <Firebase ID token>
 * Body: { resumeId, resume, idempotencyKey? }
 *
 * Crea el CV en una transacción atómica (límite Free incluido).
 * El UID sale solo del token; nunca del body.
 */
export const createResume = onRequest(
  {
    region: FUNCTIONS_REGION,
    cors: true,
    invoker: "public",
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
      await expireGrantIfNeeded(uid);

      const body = (req.body ?? {}) as Record<string, unknown>;
      const resumeId = String(body.resumeId ?? "").trim();
      if (!resumeId) {
        jsonError(res, 400, "invalid-argument", "Falta resumeId.");
        return;
      }

      const result = await createResumeAtomic({
        uid,
        resumeId,
        resume: body.resume,
        idempotencyKey: body.idempotencyKey,
      });

      // Pro con muchos CV: reconciliar contador tras la TX (no bloquea el límite Free).
      if (result.isPro && result.created) {
        void refreshResumeUsage(uid).catch((e) =>
          logger.warn("createResume refreshUsage", e),
        );
      }

      res.status(result.created ? 201 : 200).json({
        resumeId: result.resumeId,
        created: result.created,
        resumeCount: result.resumeCount,
        isPro: result.isPro,
        idempotentReplay: result.idempotentReplay,
      });
    } catch (e: unknown) {
      logger.error("createResume", e);
      if (isUnauthenticatedError(e)) {
        jsonError(res, 401, "unauthenticated", "No autenticado");
        return;
      }
      if (e instanceof CreateResumeError) {
        const status =
          e.code === "resource-exhausted"
            ? 429
            : e.code === "invalid-argument"
              ? 400
              : e.code === "permission-denied"
                ? 403
                : e.code === "unauthenticated"
                  ? 401
                  : 500;
        jsonError(res, status, e.code, e.message);
        return;
      }
      const message =
        e instanceof Error ? e.message : "No se pudo crear el CV";
      jsonError(res, 500, "internal", message);
    }
  },
);
