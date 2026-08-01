import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions";
import {FUNCTIONS_REGION} from "./config";
import {refreshResumeUsage} from "./usageStore";

/**
 * Tras create/update/delete de un CV, recuenta y actualiza `usage/{uid}`.
 * Update no cambia el conteo, pero el recuento mantiene consistencia barata.
 */
export const onResumeUsageChanged = onDocumentWritten(
  {
    document: "users/{uid}/resumes/{resumeId}",
    region: FUNCTIONS_REGION,
  },
  async (event) => {
    const uid = event.params.uid as string;
    if (!uid) return;
    try {
      await refreshResumeUsage(uid);
    } catch (e) {
      logger.error("onResumeUsageChanged", {uid, error: e});
      throw e;
    }
  },
);
