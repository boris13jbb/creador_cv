import * as admin from "firebase-admin";

export type UsageDoc = {
  uid: string;
  resumeCount: number;
  schemaVersion: 1;
  updatedAt: string;
};

/**
 * Recuenta CVs reales y escribe `usage/{uid}` (solo Admin SDK).
 * Autocorrección ante carreras o deletes fallidos.
 */
export async function refreshResumeUsage(
  uid: string,
  db: admin.firestore.Firestore = admin.firestore(),
): Promise<UsageDoc> {
  const agg = await db.collection(`users/${uid}/resumes`).count().get();
  const resumeCount = agg.data().count;
  const doc: UsageDoc = {
    uid,
    resumeCount,
    schemaVersion: 1,
    updatedAt: new Date().toISOString(),
  };
  await db.doc(`usage/${uid}`).set(doc, {merge: true});
  return doc;
}
