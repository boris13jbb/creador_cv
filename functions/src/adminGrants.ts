/**
 * Grants Pro de cortesía (sin Stripe) y auditoría.
 * Solo mutables vía Admin SDK / estas Functions.
 */

import * as admin from "firebase-admin";

export type AdminGrantWrite = {
  uid: string;
  plan: "pro";
  subscriptionStatus: "active";
  trialEndsAt: null;
  source: "admin_grant";
  schemaVersion: 1;
  updatedAt: string;
  grantedBy: string;
  grantedAt: string;
  grantNote: string | null;
  grantExpiresAt: string | null;
};

export type AdminGrantAudit = {
  id: string;
  action: "grant" | "revoke" | "expire";
  targetUid: string;
  targetEmail: string | null;
  adminUid: string;
  adminEmail: string | null;
  note: string | null;
  grantExpiresAt: string | null;
  createdAt: string;
};

const db = () => admin.firestore();

export function buildAdminGrant(input: {
  uid: string;
  adminUid: string;
  note?: string | null;
  expiresAt?: string | null;
  now?: Date;
}): AdminGrantWrite {
  const now = input.now ?? new Date();
  const iso = now.toISOString();
  let grantExpiresAt: string | null = null;
  if (input.expiresAt) {
    const parsed = new Date(input.expiresAt);
    if (Number.isNaN(parsed.getTime())) {
      throw new Error("grantExpiresAt inválida (usa ISO-8601).");
    }
    if (parsed.getTime() <= now.getTime()) {
      throw new Error("grantExpiresAt debe ser una fecha futura.");
    }
    grantExpiresAt = parsed.toISOString();
  }

  return {
    uid: input.uid,
    plan: "pro",
    subscriptionStatus: "active",
    trialEndsAt: null,
    source: "admin_grant",
    schemaVersion: 1,
    updatedAt: iso,
    grantedBy: input.adminUid,
    grantedAt: iso,
    grantNote: input.note?.trim() || null,
    grantExpiresAt,
  };
}

export function isActiveAdminGrant(
  data: Record<string, unknown> | undefined,
  now = new Date(),
): boolean {
  if (!data) return false;
  if (data.source !== "admin_grant") return false;
  if (data.plan !== "pro") return false;
  if (data.subscriptionStatus !== "active") return false;
  const expires = data.grantExpiresAt as string | null | undefined;
  if (expires) {
    const t = new Date(expires).getTime();
    if (!Number.isNaN(t) && t <= now.getTime()) return false;
  }
  return true;
}

export async function writeAdminGrant(
  grant: AdminGrantWrite,
): Promise<void> {
  const ref = db().collection("entitlements").doc(grant.uid);
  const existing = await ref.get();
  await ref.set(
    {
      ...grant,
      createdAt: existing.exists
        ? (existing.data()?.createdAt ?? grant.updatedAt)
        : grant.updatedAt,
    },
    {merge: true},
  );
}

export async function revokeAdminGrant(uid: string, now = new Date()): Promise<void> {
  const iso = now.toISOString();
  const ref = db().collection("entitlements").doc(uid);
  const existing = await ref.get();
  await ref.set(
    {
      uid,
      plan: "free",
      subscriptionStatus: "active",
      trialEndsAt: null,
      source: "admin_revoke",
      schemaVersion: 1,
      updatedAt: iso,
      grantedBy: null,
      grantedAt: null,
      grantNote: null,
      grantExpiresAt: null,
      createdAt: existing.exists
        ? (existing.data()?.createdAt ?? iso)
        : iso,
    },
    {merge: true},
  );
}

export async function writeAdminAudit(
  entry: Omit<AdminGrantAudit, "id" | "createdAt"> & {createdAt?: string},
): Promise<string> {
  const ref = db().collection("adminAuditLogs").doc();
  const createdAt = entry.createdAt ?? new Date().toISOString();
  const payload: AdminGrantAudit = {
    id: ref.id,
    action: entry.action,
    targetUid: entry.targetUid,
    targetEmail: entry.targetEmail,
    adminUid: entry.adminUid,
    adminEmail: entry.adminEmail,
    note: entry.note,
    grantExpiresAt: entry.grantExpiresAt,
    createdAt,
  };
  await ref.set(payload);
  return ref.id;
}

export async function resolveUserByEmailOrUid(input: {
  email?: string;
  uid?: string;
}): Promise<{uid: string; email: string | null}> {
  if (input.uid?.trim()) {
    const user = await admin.auth().getUser(input.uid.trim());
    return {uid: user.uid, email: user.email ?? null};
  }
  if (input.email?.trim()) {
    const user = await admin.auth().getUserByEmail(input.email.trim());
    return {uid: user.uid, email: user.email ?? null};
  }
  throw new Error("Indica email o uid del cliente.");
}

/**
 * Si el grant expiró, lo revoca y registra auditoría del sistema.
 */
export async function expireGrantIfNeeded(
  uid: string,
  now = new Date(),
): Promise<boolean> {
  const snap = await db().collection("entitlements").doc(uid).get();
  const data = snap.data();
  if (!data || data.source !== "admin_grant") return false;
  if (isActiveAdminGrant(data, now)) return false;

  await revokeAdminGrant(uid, now);
  await writeAdminAudit({
    action: "expire",
    targetUid: uid,
    targetEmail: null,
    adminUid: "system",
    adminEmail: null,
    note: "Grant expirado automáticamente",
    grantExpiresAt: (data.grantExpiresAt as string) ?? null,
  });
  return true;
}
