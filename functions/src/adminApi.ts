import {onRequest} from "firebase-functions/v2/https";
import {HttpsError} from "firebase-functions/v2/https";
import {logger} from "firebase-functions";
import * as admin from "firebase-admin";
import {
  isPermissionDeniedError,
  requireSuperAdmin,
} from "./adminAuth";
import {
  buildAdminGrant,
  expireGrantIfNeeded,
  resolveUserByEmailOrUid,
  revokeAdminGrant,
  writeAdminAudit,
  writeAdminGrant,
  isActiveAdminGrant,
} from "./adminGrants";
import {isUnauthenticatedError, jsonError} from "./auth";
import {FUNCTIONS_REGION} from "./runtime";

const db = () => admin.firestore();

function handleAdminError(
  res: import("express").Response,
  e: unknown,
): void {
  if (isUnauthenticatedError(e)) {
    jsonError(res, 401, "unauthenticated", "No autenticado.");
    return;
  }
  if (isPermissionDeniedError(e)) {
    jsonError(res, 403, "permission-denied", "Se requiere rol superadmin.");
    return;
  }
  if (e instanceof HttpsError) {
    const status =
      e.code === "invalid-argument"
        ? 400
        : e.code === "not-found"
          ? 404
          : 400;
    jsonError(res, status, e.code, e.message);
    return;
  }
  const message = e instanceof Error ? e.message : "Error interno.";
  if (
    message.includes("no user record") ||
    message.includes("There is no user")
  ) {
    jsonError(res, 404, "not-found", "Usuario no encontrado.");
    return;
  }
  logger.error("adminApi error", e);
  jsonError(res, 500, "internal", message);
}

async function loadUserSnapshot(uid: string) {
  await expireGrantIfNeeded(uid);

  const [authUser, userDoc, entitlementDoc, usageDoc, billingDoc] =
    await Promise.all([
      admin.auth().getUser(uid),
      db().collection("users").doc(uid).get(),
      db().collection("entitlements").doc(uid).get(),
      db().collection("usage").doc(uid).get(),
      db().collection("billingCustomers").doc(uid).get(),
    ]);

  const entitlement = entitlementDoc.data() ?? null;
  const usage = usageDoc.data() ?? null;
  const profile = userDoc.data() ?? null;
  const billing = billingDoc.data() ?? null;

  return {
    uid: authUser.uid,
    email: authUser.email ?? null,
    displayName:
      (profile?.displayName as string | undefined) ||
      authUser.displayName ||
      null,
    emailVerified: authUser.emailVerified,
    disabled: authUser.disabled,
    createdAt: authUser.metadata.creationTime ?? null,
    lastSignInAt: authUser.metadata.lastSignInTime ?? null,
    profile,
    entitlement,
    usage: {
      resumeCount: (usage?.resumeCount as number | undefined) ?? 0,
      updatedAt: (usage?.updatedAt as string | undefined) ?? null,
    },
    billing: billing
      ? {
        stripeCustomerId: billing.stripeCustomerId ?? null,
        stripeSubscriptionId: billing.stripeSubscriptionId ?? null,
      }
      : null,
    isPro:
      entitlement?.plan === "pro" &&
      (entitlement?.subscriptionStatus === "active" ||
        entitlement?.subscriptionStatus === "trialing") &&
      (entitlement?.source !== "admin_grant" ||
        isActiveAdminGrant(entitlement as Record<string, unknown>)),
    hasAdminGrant: isActiveAdminGrant(
      entitlement as Record<string, unknown> | undefined,
    ),
  };
}

/**
 * POST /adminGrantPro
 * Body: { email? | uid?, note?, expiresAt? }
 */
export const adminGrantPro = onRequest(
  {region: FUNCTIONS_REGION, cors: true},
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
      const adminUser = await requireSuperAdmin(req);
      const body = (req.body ?? {}) as {
        email?: string;
        uid?: string;
        note?: string;
        expiresAt?: string;
      };

      const target = await resolveUserByEmailOrUid({
        email: body.email,
        uid: body.uid,
      });

      const grant = buildAdminGrant({
        uid: target.uid,
        adminUid: adminUser.uid,
        note: body.note,
        expiresAt: body.expiresAt,
      });
      await writeAdminGrant(grant);
      const auditId = await writeAdminAudit({
        action: "grant",
        targetUid: target.uid,
        targetEmail: target.email,
        adminUid: adminUser.uid,
        adminEmail: adminUser.email ?? null,
        note: grant.grantNote,
        grantExpiresAt: grant.grantExpiresAt,
      });

      const user = await loadUserSnapshot(target.uid);
      res.status(200).json({ok: true, auditId, user});
    } catch (e) {
      handleAdminError(res, e);
    }
  },
);

/**
 * POST /adminRevokeGrant
 * Body: { email? | uid?, note? }
 */
export const adminRevokeGrant = onRequest(
  {region: FUNCTIONS_REGION, cors: true},
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
      const adminUser = await requireSuperAdmin(req);
      const body = (req.body ?? {}) as {
        email?: string;
        uid?: string;
        note?: string;
      };

      const target = await resolveUserByEmailOrUid({
        email: body.email,
        uid: body.uid,
      });

      await revokeAdminGrant(target.uid);
      const auditId = await writeAdminAudit({
        action: "revoke",
        targetUid: target.uid,
        targetEmail: target.email,
        adminUid: adminUser.uid,
        adminEmail: adminUser.email ?? null,
        note: body.note?.trim() || null,
        grantExpiresAt: null,
      });

      const user = await loadUserSnapshot(target.uid);
      res.status(200).json({ok: true, auditId, user});
    } catch (e) {
      handleAdminError(res, e);
    }
  },
);

/**
 * POST /adminGetUser
 * Body: { email? | uid? }
 */
export const adminGetUser = onRequest(
  {region: FUNCTIONS_REGION, cors: true},
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
      await requireSuperAdmin(req);
      const body = (req.body ?? {}) as {email?: string; uid?: string};
      const target = await resolveUserByEmailOrUid(body);
      const user = await loadUserSnapshot(target.uid);
      res.status(200).json({user});
    } catch (e) {
      handleAdminError(res, e);
    }
  },
);

/**
 * POST /adminListUsers
 * Body: { pageToken?, maxResults? }
 * Lista usuarios Auth + resumen de entitlement/usage.
 */
export const adminListUsers = onRequest(
  {region: FUNCTIONS_REGION, cors: true},
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
      await requireSuperAdmin(req);
      const body = (req.body ?? {}) as {
        pageToken?: string;
        maxResults?: number;
      };
      const maxResults = Math.min(Math.max(body.maxResults ?? 25, 1), 50);

      const listed = await admin.auth().listUsers(maxResults, body.pageToken);
      const users = await Promise.all(
        listed.users.map(async (u) => {
          const [entSnap, usageSnap] = await Promise.all([
            db().collection("entitlements").doc(u.uid).get(),
            db().collection("usage").doc(u.uid).get(),
          ]);
          const entitlement = entSnap.data() ?? null;
          const usage = usageSnap.data() ?? null;
          return {
            uid: u.uid,
            email: u.email ?? null,
            displayName: u.displayName ?? null,
            emailVerified: u.emailVerified,
            disabled: u.disabled,
            createdAt: u.metadata.creationTime ?? null,
            lastSignInAt: u.metadata.lastSignInTime ?? null,
            plan: (entitlement?.plan as string | undefined) ?? "free",
            subscriptionStatus:
              (entitlement?.subscriptionStatus as string | undefined) ?? null,
            source: (entitlement?.source as string | undefined) ?? null,
            hasAdminGrant: isActiveAdminGrant(
              entitlement as Record<string, unknown> | undefined,
            ),
            resumeCount: (usage?.resumeCount as number | undefined) ?? 0,
          };
        }),
      );

      res.status(200).json({
        users,
        pageToken: listed.pageToken ?? null,
      });
    } catch (e) {
      handleAdminError(res, e);
    }
  },
);

/**
 * POST /adminGetMetrics
 * Conteos agregados para el panel de monitoreo.
 */
export const adminGetMetrics = onRequest(
  {region: FUNCTIONS_REGION, cors: true},
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
      await requireSuperAdmin(req);

      let authTotal = 0;
      let pageToken: string | undefined;
      do {
        const page = await admin.auth().listUsers(1000, pageToken);
        authTotal += page.users.length;
        pageToken = page.pageToken;
      } while (pageToken);

      // Escaneo de entitlements (evita índices compuestos; OK para paneles internos).
      const [entSnap, auditSnap] = await Promise.all([
        db().collection("entitlements").get(),
        db()
          .collection("adminAuditLogs")
          .orderBy("createdAt", "desc")
          .limit(20)
          .get(),
      ]);

      let proActive = 0;
      let freeEntitlements = 0;
      let adminGrantsActive = 0;
      for (const doc of entSnap.docs) {
        const data = doc.data() as Record<string, unknown>;
        if (data.plan === "free") freeEntitlements += 1;
        if (
          data.plan === "pro" &&
          (data.subscriptionStatus === "active" ||
            data.subscriptionStatus === "trialing")
        ) {
          proActive += 1;
        }
        if (isActiveAdminGrant(data)) adminGrantsActive += 1;
      }

      res.status(200).json({
        metrics: {
          authUsers: authTotal,
          proActive,
          freeEntitlements,
          adminGrantsActive,
        },
        recentAudit: auditSnap.docs.map((d) => d.data()),
      });
    } catch (e) {
      handleAdminError(res, e);
    }
  },
);
