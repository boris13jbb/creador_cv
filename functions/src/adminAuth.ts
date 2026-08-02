import {HttpsError} from "firebase-functions/v2/https";
import type {Request} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

export type SuperAdminIdentity = {
  uid: string;
  email?: string;
};

/**
 * Exige Bearer Firebase ID token con custom claim `superadmin: true`.
 */
export async function requireSuperAdmin(
  req: Request,
): Promise<SuperAdminIdentity> {
  const header = req.get("Authorization") || "";
  const match = header.match(/^Bearer\s+(.+)$/i);
  if (!match) {
    throw new HttpsError("unauthenticated", "Falta Authorization Bearer.");
  }

  let decoded: admin.auth.DecodedIdToken;
  try {
    decoded = await admin.auth().verifyIdToken(match[1]);
  } catch {
    throw new HttpsError("unauthenticated", "Token inválido o expirado.");
  }

  if (decoded.superadmin !== true) {
    throw new HttpsError(
      "permission-denied",
      "Se requiere rol superadmin.",
    );
  }

  return {uid: decoded.uid, email: decoded.email};
}

export function isPermissionDeniedError(e: unknown): boolean {
  return (
    (e instanceof HttpsError && e.code === "permission-denied") ||
    (e as {code?: string}).code === "permission-denied"
  );
}
