/**
 * Validación y saneado del payload de CV para createResume (Admin SDK).
 * Alineado con límites de firestore.rules (validResumeKeys + strings).
 */

export type ResumeCreateInput = {
  id: string;
  nombre: string;
  userId: string;
  updatedAt: string;
  [key: string]: unknown;
};

const MAX_JSON_CHARS = 900_000;
const MAX_FOTO_PATH = 200_000;

function isPlainObject(v: unknown): v is Record<string, unknown> {
  return typeof v === "object" && v !== null && !Array.isArray(v);
}

function asString(v: unknown, max: number, field: string): string {
  if (typeof v !== "string") {
    throw new Error(`Campo "${field}" debe ser texto.`);
  }
  if (v.length > max) {
    throw new Error(`Campo "${field}" supera el tamaño permitido.`);
  }
  return v;
}

function asOptionalString(
  v: unknown,
  max: number,
  field: string,
): string | undefined {
  if (v === undefined || v === null) return undefined;
  return asString(v, max, field);
}

function asBool(v: unknown, field: string): boolean | undefined {
  if (v === undefined || v === null) return undefined;
  if (typeof v === "boolean") return v;
  throw new Error(`Campo "${field}" debe ser booleano.`);
}

function asInt(v: unknown, field: string): number | undefined {
  if (v === undefined || v === null) return undefined;
  if (typeof v === "number" && Number.isInteger(v)) return v;
  throw new Error(`Campo "${field}" debe ser entero.`);
}

function sanitizeList(
  v: unknown,
  field: string,
  maxItems: number,
): unknown[] | undefined {
  if (v === undefined || v === null) return undefined;
  if (!Array.isArray(v)) {
    throw new Error(`Campo "${field}" debe ser lista.`);
  }
  if (v.length > maxItems) {
    throw new Error(`Campo "${field}" tiene demasiados elementos.`);
  }
  return v.map((item, i) => {
    if (!isPlainObject(item)) {
      throw new Error(`Elemento inválido en "${field}[${i}]".`);
    }
    // Solo mapas JSON-safe; sin funciones ni undefined anidados profundos.
    return JSON.parse(JSON.stringify(item)) as Record<string, unknown>;
  });
}

/**
 * Valida el body del cliente y fuerza userId/id del contexto autenticado.
 */
export function buildResumeDocument(input: {
  uid: string;
  resumeId: string;
  resume: unknown;
  nowIso?: string;
}): ResumeCreateInput {
  if (input.resume == null || !isPlainObject(input.resume)) {
    throw new Error("Falta el objeto resume.");
  }
  const rawJson = JSON.stringify(input.resume);
  if (rawJson.length > MAX_JSON_CHARS) {
    throw new Error("El CV supera el tamaño máximo permitido.");
  }

  const resumeId = input.resumeId.trim();
  if (!resumeId || resumeId.includes("/") || resumeId.length > 80) {
    throw new Error("Identificador de CV inválido.");
  }

  const nowIso = input.nowIso ?? new Date().toISOString();
  const src = input.resume;

  const nombre = asString(src.nombre ?? "Sin nombre", 200, "nombre");
  const updatedAt = asOptionalString(src.updatedAt, 40, "updatedAt") ?? nowIso;
  const createdAt =
    asOptionalString(src.createdAt, 40, "createdAt") ?? nowIso;

  const out: ResumeCreateInput = {
    id: resumeId,
    nombre,
    userId: input.uid,
    updatedAt,
    createdAt,
    updatedAtServer: nowIso,
    createdAtServer: nowIso,
    schemaVersion: asInt(src.schemaVersion, "schemaVersion") ?? 3,
    perfil: asOptionalString(src.perfil, 5000, "perfil") ?? "",
    colorHex: asOptionalString(src.colorHex, 20, "colorHex") ?? "#1A73E8",
    designIndex: asInt(src.designIndex, "designIndex") ?? 0,
  };

  const fotoPath = asOptionalString(src.fotoPath, MAX_FOTO_PATH, "fotoPath");
  if (fotoPath !== undefined) out.fotoPath = fotoPath;
  const fotoUrl = asOptionalString(src.fotoUrl, 2000, "fotoUrl");
  if (fotoUrl !== undefined) out.fotoUrl = fotoUrl;
  const fotoStoragePath = asOptionalString(
    src.fotoStoragePath,
    500,
    "fotoStoragePath",
  );
  if (fotoStoragePath !== undefined) out.fotoStoragePath = fotoStoragePath;

  for (const flag of [
    "ocultarFoto",
    "ocultarPerfil",
    "ocultarExperiencia",
    "ocultarFormacion",
    "ocultarCompetencias",
    "ocultarIdiomas",
    "ocultarProyectos",
    "ocultarCertificaciones",
    "ocultarAptitudes",
  ] as const) {
    const b = asBool(src[flag], flag);
    if (b !== undefined) out[flag] = b;
  }

  const lists: Array<[string, number]> = [
    ["datosPersonales", 40],
    ["competencias", 80],
    ["idiomas", 40],
    ["experiencia", 40],
    ["formacion", 40],
    ["projects", 40],
    ["certifications", 40],
    ["aptitudes", 80],
  ];
  for (const [field, max] of lists) {
    const list = sanitizeList(src[field], field, max);
    if (list !== undefined) out[field] = list;
  }

  return out;
}

export function parseIdempotencyKey(raw: unknown): string | null {
  if (raw === undefined || raw === null) return null;
  if (typeof raw !== "string") {
    throw new Error("idempotencyKey debe ser texto.");
  }
  const key = raw.trim();
  if (!key) return null;
  if (key.length > 128) {
    throw new Error("idempotencyKey demasiado larga.");
  }
  if (!/^[A-Za-z0-9._:-]+$/.test(key)) {
    throw new Error("idempotencyKey tiene caracteres no permitidos.");
  }
  return key;
}
