import {HttpsError} from "firebase-functions/v2/https";
import type {Request} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

/**
 * Verifica Bearer Firebase ID token (SDK nativo o Identity Toolkit REST).
 */
export async function requireUidFromRequest(req: Request): Promise<{
  uid: string;
  email?: string;
}> {
  const header = req.get("Authorization") || "";
  const match = header.match(/^Bearer\s+(.+)$/i);
  if (!match) {
    throw new HttpsError("unauthenticated", "Falta Authorization Bearer.");
  }
  try {
    const decoded = await admin.auth().verifyIdToken(match[1]);
    return {uid: decoded.uid, email: decoded.email};
  } catch {
    throw new HttpsError("unauthenticated", "Token inválido o expirado.");
  }
}

export function isUnauthenticatedError(e: unknown): boolean {
  return (
    (e instanceof HttpsError && e.code === "unauthenticated") ||
    (e as {code?: string}).code === "unauthenticated"
  );
}

export function jsonError(
  res: import("express").Response,
  status: number,
  code: string,
  message: string,
): void {
  res.status(status).json({error: {code, message}});
}
