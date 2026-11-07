import * as admin from "firebase-admin";
import {FREE_MAX_CVS} from "./planLimits";

export type UsageDoc = {
  uid: string;
  resumeCount: number;
  schemaVersion: 1;
  updatedAt: string;
  updatedBy?: string;
};

/**
 * Recuenta CVs y escribe `usage/{uid}` dentro de una transacción.
 *
 * Usa un query transaccional (no count()+set suelto) para que una creación
 * concurrente invalide la TX y se reintente con el conteo actualizado.
 *
 * Para usuarios con muchos CV (Pro), si el listado llega al tope de lectura
 * usa agregación fuera de TX solo como aproximación administrativa; el límite
 * Free nunca depende de ese atajo (createResume consulta ≤ FREE_MAX_CVS+1).
 */
export async function refreshResumeUsage(
  uid: string,
  db: admin.firestore.Firestore = admin.firestore(),
): Promise<UsageDoc> {
  const usageRef = db.doc(`usage/${uid}`);
  const resumesCol = db.collection(`users/${uid}/resumes`);
  const scanLimit = Math.max(FREE_MAX_CVS + 1, 100);

  try {
    return await db.runTransaction(async (tx) => {
      await tx.get(usageRef);
      const listSnap = await tx.get(resumesCol.select().limit(scanLimit));
      if (listSnap.size >= scanLimit) {
        // Demasiados docs para reconciliar en TX: señal para fallback.
        throw new Error("USAGE_RECOUNT_TOO_LARGE");
      }
      const resumeCount = listSnap.size;
      const doc: UsageDoc = {
        uid,
        resumeCount,
        schemaVersion: 1,
        updatedAt: new Date().toISOString(),
        updatedBy: "refreshResumeUsage_tx",
      };
      tx.set(usageRef, doc, {merge: true});
      return doc;
    });
  } catch (e) {
    if (!(e instanceof Error) || e.message !== "USAGE_RECOUNT_TOO_LARGE") {
      throw e;
    }
  }

  // Fallback Pro/denso: agregación + escritura. No se usa para autorizar Free.
  const agg = await resumesCol.count().get();
  const resumeCount = agg.data().count;
  const doc: UsageDoc = {
    uid,
    resumeCount,
    schemaVersion: 1,
    updatedAt: new Date().toISOString(),
    updatedBy: "refreshResumeUsage_agg",
  };
  await usageRef.set(doc, {merge: true});
  return doc;
}
