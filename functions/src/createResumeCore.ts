/**
 * Creación atómica de CV Free/Pro con transacción Firestore.
 * El límite Free se evalúa con un query bloqueado dentro de la TX.
 */

import * as admin from "firebase-admin";
import {createHash} from "node:crypto";
import {FREE_MAX_CVS, isProEntitlement} from "./planLimits";
import {
  buildResumeDocument,
  parseIdempotencyKey,
  type ResumeCreateInput,
} from "./resumePayload";

export class CreateResumeError extends Error {
  constructor(
    readonly code:
      | "unauthenticated"
      | "invalid-argument"
      | "resource-exhausted"
      | "permission-denied"
      | "internal",
    message: string,
  ) {
    super(message);
    this.name = "CreateResumeError";
  }
}

export type CreateResumeResult = {
  created: boolean;
  resumeId: string;
  resumeCount: number;
  isPro: boolean;
  idempotentReplay: boolean;
};

function idempotencyDocId(uid: string, key: string): string {
  return createHash("sha256")
    .update(`${uid}:${key}`)
    .digest("hex")
    .slice(0, 40);
}

function usageCountOf(
  snap: FirebaseFirestore.DocumentSnapshot,
  fallback: number,
): number {
  const n = snap.data()?.resumeCount;
  return typeof n === "number" && Number.isFinite(n) && n >= 0 ? n : fallback;
}

/**
 * Crea un CV bajo `uid` (nunca toma uid del payload).
 * Idempotencia: mismo resumeId o misma idempotencyKey no duplica.
 */
export async function createResumeAtomic(input: {
  uid: string;
  resumeId: string;
  resume: unknown;
  idempotencyKey?: unknown;
  db?: admin.firestore.Firestore;
  now?: Date;
}): Promise<CreateResumeResult> {
  const uid = input.uid;
  if (!uid) {
    throw new CreateResumeError("unauthenticated", "No autenticado.");
  }

  let resumeId: string;
  let doc: ResumeCreateInput;
  let idemKey: string | null;
  try {
    resumeId = String(input.resumeId || "").trim();
    idemKey = parseIdempotencyKey(input.idempotencyKey);
    doc = buildResumeDocument({
      uid,
      resumeId,
      resume: input.resume,
      nowIso: (input.now ?? new Date()).toISOString(),
    });
  } catch (e) {
    throw new CreateResumeError(
      "invalid-argument",
      e instanceof Error ? e.message : "Payload inválido.",
    );
  }

  // Clave por defecto = id del CV (reintento de red con el mismo id).
  const effectiveIdemKey = idemKey ?? `resume:${resumeId}`;
  const db = input.db ?? admin.firestore();
  const resumeRef = db.doc(`users/${uid}/resumes/${resumeId}`);
  const entRef = db.doc(`entitlements/${uid}`);
  const usageRef = db.doc(`usage/${uid}`);
  const idemRef = db.doc(
    `resumeCreateIdempotency/${idempotencyDocId(uid, effectiveIdemKey)}`,
  );
  const resumesCol = db.collection(`users/${uid}/resumes`);

  try {
    return await db.runTransaction(async (tx) => {
      // --- Lecturas (todas antes de escrituras) ---
      const idemSnap = await tx.get(idemRef);
      const resumeSnap = await tx.get(resumeRef);
      const entSnap = await tx.get(entRef);
      const usageSnap = await tx.get(usageRef);
      // Free: hasta 4 docs basta para saber si ya hay 3. Pro: señal de truncado.
      const listSnap = await tx.get(
        resumesCol.select().limit(FREE_MAX_CVS + 1),
      );

      let mappedResumeSnap: FirebaseFirestore.DocumentSnapshot | null = null;
      let mappedResumeId: string | null = null;
      if (idemSnap.exists) {
        const mapped = String(idemSnap.data()?.resumeId || "").trim();
        if (mapped && mapped !== resumeId) {
          mappedResumeId = mapped;
          mappedResumeSnap = await tx.get(
            db.doc(`users/${uid}/resumes/${mapped}`),
          );
        } else if (mapped === resumeId) {
          mappedResumeId = resumeId;
          mappedResumeSnap = resumeSnap;
        }
      }

      const entData = entSnap.exists
        ? (entSnap.data() as Record<string, unknown>)
        : null;
      const isPro = isProEntitlement(entData, input.now ?? new Date());
      const listed = listSnap.size;
      const listedExact = listed < FREE_MAX_CVS + 1;

      // --- Escrituras ---
      const finishIdempotent = (existingId: string): CreateResumeResult => {
        const resumeCount = isPro
          ? Math.max(usageCountOf(usageSnap, listed), listed)
          : listedExact
            ? listed
            : Math.max(usageCountOf(usageSnap, FREE_MAX_CVS), FREE_MAX_CVS);
        tx.set(idemRef, {
          uid,
          resumeId: existingId,
          createdAt: doc.createdAt,
          updatedAt: doc.updatedAt,
        });
        tx.set(
          usageRef,
          {
            uid,
            resumeCount,
            schemaVersion: 1,
            updatedAt: doc.updatedAt,
            updatedBy: "createResume_idempotent",
          },
          {merge: true},
        );
        return {
          created: false,
          resumeId: existingId,
          resumeCount,
          isPro,
          idempotentReplay: true,
        };
      };

      if (mappedResumeSnap?.exists && mappedResumeId) {
        return finishIdempotent(mappedResumeId);
      }
      if (resumeSnap.exists) {
        return finishIdempotent(resumeId);
      }

      if (!isPro && listed >= FREE_MAX_CVS) {
        throw new CreateResumeError(
          "resource-exhausted",
          `Límite del plan Free: máximo ${FREE_MAX_CVS} CVs.`,
        );
      }

      const nextCount = isPro
        ? usageCountOf(usageSnap, listed) + 1
        : listed + 1;

      tx.set(resumeRef, doc);
      tx.set(
        usageRef,
        {
          uid,
          resumeCount: nextCount,
          schemaVersion: 1,
          updatedAt: doc.updatedAt,
          updatedBy: "createResume",
        },
        {merge: true},
      );
      tx.set(idemRef, {
        uid,
        resumeId,
        createdAt: doc.createdAt,
        updatedAt: doc.updatedAt,
      });

      return {
        created: true,
        resumeId,
        resumeCount: nextCount,
        isPro,
        idempotentReplay: false,
      };
    });
  } catch (e) {
    if (e instanceof CreateResumeError) throw e;
    throw new CreateResumeError(
      "internal",
      e instanceof Error ? e.message : "No se pudo crear el CV.",
    );
  }
}
