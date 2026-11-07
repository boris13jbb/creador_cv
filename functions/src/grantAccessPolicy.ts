/**
 * Política de ventana temporal para concesiones admin_grant (CV Maker).
 *
 * Semántica: grantStartsAt <= now < grantExpiresAt (cuando hay límites).
 * - Habitual/legado (sin fechas ni modality=temporary): vigente hasta revocación.
 * - Temporal con fechas inválidas: deniega (fail-closed).
 * - Revocación: source != admin_grant (p. ej. admin_revoke) ⇒ no activo.
 */

export type ParsedInstant =
  | {kind: "absent"}
  | {kind: "invalid"}
  | {kind: "ok"; ms: number};

/** Acepta ISO string, Date, Firestore Timestamp-like ({seconds}|{_seconds}). */
export function parseGrantInstant(value: unknown): ParsedInstant {
  if (value === undefined || value === null) return {kind: "absent"};
  if (typeof value === "string") {
    const trimmed = value.trim();
    if (!trimmed) return {kind: "invalid"};
    const ms = Date.parse(trimmed);
    return Number.isFinite(ms) ? {kind: "ok", ms} : {kind: "invalid"};
  }
  if (value instanceof Date) {
    const ms = value.getTime();
    return Number.isFinite(ms) ? {kind: "ok", ms} : {kind: "invalid"};
  }
  if (typeof value === "object") {
    const o = value as Record<string, unknown>;
    const seconds =
      typeof o.seconds === "number"
        ? o.seconds
        : typeof o._seconds === "number"
          ? o._seconds
          : null;
    const nanos =
      typeof o.nanoseconds === "number"
        ? o.nanoseconds
        : typeof o._nanoseconds === "number"
          ? o._nanoseconds
          : 0;
    if (seconds !== null) {
      const ms = seconds * 1000 + Math.floor(nanos / 1e6);
      return Number.isFinite(ms) ? {kind: "ok", ms} : {kind: "invalid"};
    }
    if (typeof (o as {toDate?: () => Date}).toDate === "function") {
      try {
        const d = (o as {toDate: () => Date}).toDate();
        const ms = d.getTime();
        return Number.isFinite(ms) ? {kind: "ok", ms} : {kind: "invalid"};
      } catch {
        return {kind: "invalid"};
      }
    }
  }
  return {kind: "invalid"};
}

function firstInstant(
  ...values: unknown[]
): ParsedInstant {
  let sawInvalid = false;
  for (const v of values) {
    if (v === undefined) continue;
    const p = parseGrantInstant(v);
    if (p.kind === "absent") continue;
    if (p.kind === "invalid") {
      sawInvalid = true;
      continue;
    }
    return p;
  }
  return sawInvalid ? {kind: "invalid"} : {kind: "absent"};
}

export function isTemporalAdminGrant(data: Record<string, unknown>): boolean {
  if (data.grantModality === "temporary") return true;
  const start = firstInstant(data.grantStartsAtTs, data.grantStartsAt);
  const end = firstInstant(data.grantExpiresAtTs, data.grantExpiresAt);
  return start.kind !== "absent" || end.kind !== "absent";
}

/**
 * ¿La cortesía admin_grant autoriza Pro en `now`?
 * No aplica a suscripciones Stripe u otras fuentes.
 */
export function isAdminGrantActiveInWindow(
  data: Record<string, unknown> | undefined | null,
  now: Date = new Date(),
): boolean {
  if (!data) return false;
  if (data.source !== "admin_grant") return false;
  if (String(data.plan || "").toLowerCase() !== "pro") return false;
  if (String(data.subscriptionStatus || "").toLowerCase() !== "active") {
    return false;
  }

  const nowMs = now.getTime();
  const start = firstInstant(data.grantStartsAtTs, data.grantStartsAt);
  const end = firstInstant(data.grantExpiresAtTs, data.grantExpiresAt);
  const temporal = isTemporalAdminGrant(data);

  if (!temporal) {
    // Cortesía habitual / legado sin ventana.
    return true;
  }

  if (start.kind === "invalid" || end.kind === "invalid") {
    return false;
  }
  // Temporal exige vencimiento explícito válido.
  if (end.kind === "absent") {
    return false;
  }
  if (start.kind === "ok" && nowMs < start.ms) {
    return false;
  }
  if (nowMs >= end.ms) {
    return false;
  }
  return true;
}

/** True si el grant temporal ya venció (mantenimiento); no incluye programados. */
export function isAdminGrantPastExpiry(
  data: Record<string, unknown> | undefined | null,
  now: Date = new Date(),
): boolean {
  if (!data || data.source !== "admin_grant") return false;
  const end = firstInstant(data.grantExpiresAtTs, data.grantExpiresAt);
  if (end.kind === "ok") return now.getTime() >= end.ms;
  if (end.kind === "invalid" && isTemporalAdminGrant(data)) return true;
  return false;
}
