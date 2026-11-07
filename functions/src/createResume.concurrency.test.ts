/**
 * Pruebas de concurrencia de createResumeAtomic contra Firestore Emulator.
 *
 * Requiere: FIRESTORE_EMULATOR_HOST (p. ej. via firebase emulators:exec)
 */
import test from "node:test";
import assert from "node:assert/strict";
import * as admin from "firebase-admin";
import {createResumeAtomic, CreateResumeError} from "./createResumeCore";
import {refreshResumeUsage} from "./usageStore";

const PROJECT = process.env.GCLOUD_PROJECT || "cvmaker-saas-jb";

function requireEmulator(): void {
  if (!process.env.FIRESTORE_EMULATOR_HOST) {
    throw new Error(
      "FIRESTORE_EMULATOR_HOST no definido. Usa firebase emulators:exec.",
    );
  }
}

let _db: admin.firestore.Firestore | null = null;

function initAdmin(): admin.firestore.Firestore {
  requireEmulator();
  if (_db) return _db;
  if (admin.apps.length === 0) {
    admin.initializeApp({projectId: PROJECT});
  }
  _db = admin.firestore();
  _db.settings({ignoreUndefinedProperties: true});
  return _db;
}

function resumePayload(nombre: string): Record<string, unknown> {
  return {
    nombre,
    perfil: "Perfil",
    designIndex: 0,
    colorHex: "#1A73E8",
    schemaVersion: 3,
    datosPersonales: [],
    competencias: [],
    idiomas: [],
    experiencia: [],
    formacion: [],
    projects: [],
    certifications: [],
    aptitudes: [],
  };
}

async function seedFreeUser(
  db: admin.firestore.Firestore,
  uid: string,
  existingIds: string[],
): Promise<void> {
  await db.doc(`entitlements/${uid}`).set({
    uid,
    plan: "free",
    subscriptionStatus: "active",
    source: "client_bootstrap",
    schemaVersion: 1,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  });
  for (const id of existingIds) {
    await db.doc(`users/${uid}/resumes/${id}`).set({
      id,
      nombre: id,
      userId: uid,
      updatedAt: new Date().toISOString(),
      schemaVersion: 3,
    });
  }
  if (existingIds.length > 0) {
    await db.doc(`usage/${uid}`).set({
      uid,
      resumeCount: existingIds.length,
      schemaVersion: 1,
      updatedAt: new Date().toISOString(),
    });
  }
}

async function countResumes(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<number> {
  const snap = await db.collection(`users/${uid}/resumes`).count().get();
  return snap.data().count;
}

test("Caso A: Free crea 3 secuenciales y rechaza el 4º", async () => {
  const db = initAdmin();
  const uid = `free_seq_${Date.now()}`;
  await seedFreeUser(db, uid, []);

  for (let i = 1; i <= 3; i++) {
    const r = await createResumeAtomic({
      uid,
      resumeId: `cv${i}`,
      resume: resumePayload(`CV ${i}`),
      db,
    });
    assert.equal(r.created, true);
    assert.equal(r.resumeCount, i);
  }

  await assert.rejects(
    () =>
      createResumeAtomic({
        uid,
        resumeId: "cv4",
        resume: resumePayload("CV 4"),
        db,
      }),
    (e: unknown) =>
      e instanceof CreateResumeError && e.code === "resource-exhausted",
  );
  assert.equal(await countResumes(db, uid), 3);
});

test("Caso B: Free con 2 CV + 2 creates paralelos ⇒ exactamente 3", async () => {
  const db = initAdmin();
  const uid = `free_race2_${Date.now()}`;
  await seedFreeUser(db, uid, ["cv1", "cv2"]);

  const results = await Promise.allSettled([
    createResumeAtomic({
      uid,
      resumeId: "cvA",
      resume: resumePayload("A"),
      db,
    }),
    createResumeAtomic({
      uid,
      resumeId: "cvB",
      resume: resumePayload("B"),
      db,
    }),
  ]);

  const ok = results.filter((r) => r.status === "fulfilled");
  const fail = results.filter((r) => r.status === "rejected");
  assert.equal(ok.length, 1, `éxitos=${ok.length}`);
  assert.equal(fail.length, 1, `fallos=${fail.length}`);
  const rejected = fail[0] as PromiseRejectedResult;
  assert.ok(
    rejected.reason instanceof CreateResumeError &&
      rejected.reason.code === "resource-exhausted",
  );
  assert.equal(await countResumes(db, uid), 3);
});

test("Caso C: Free con 2 CV + 5 creates paralelos ⇒ máximo +1", async () => {
  const db = initAdmin();
  const uid = `free_race5_${Date.now()}`;
  await seedFreeUser(db, uid, ["cv1", "cv2"]);

  const results = await Promise.allSettled(
    Array.from({length: 5}, (_, i) =>
      createResumeAtomic({
        uid,
        resumeId: `cvX${i}`,
        resume: resumePayload(`X${i}`),
        db,
      }),
    ),
  );

  const ok = results.filter((r) => r.status === "fulfilled");
  assert.equal(ok.length, 1, `éxitos=${ok.length} (máx 1)`);
  assert.equal(await countResumes(db, uid), 3);
});

test("Caso D: Pro con >3 CV puede crear otro", async () => {
  const db = initAdmin();
  const uid = `pro_many_${Date.now()}`;
  await db.doc(`entitlements/${uid}`).set({
    uid,
    plan: "pro",
    subscriptionStatus: "active",
    source: "stripe",
    schemaVersion: 1,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  });
  for (let i = 1; i <= 4; i++) {
    await db.doc(`users/${uid}/resumes/cv${i}`).set({
      id: `cv${i}`,
      nombre: `CV ${i}`,
      userId: uid,
      updatedAt: new Date().toISOString(),
    });
  }
  await db.doc(`usage/${uid}`).set({
    uid,
    resumeCount: 4,
    schemaVersion: 1,
    updatedAt: new Date().toISOString(),
  });

  const r = await createResumeAtomic({
    uid,
    resumeId: "cv5",
    resume: resumePayload("CV 5"),
    db,
  });
  assert.equal(r.created, true);
  assert.equal(r.isPro, true);
  assert.equal(await countResumes(db, uid), 5);
});

test("Caso E: grant vigente Pro; grant vencido aplica Free", async () => {
  const db = initAdmin();
  const now = new Date("2026-11-06T12:00:00.000Z");

  const uidOk = `grant_ok_${Date.now()}`;
  await db.doc(`entitlements/${uidOk}`).set({
    uid: uidOk,
    plan: "pro",
    subscriptionStatus: "active",
    source: "admin_grant",
    grantModality: "temporary",
    grantStartsAt: "2026-11-01T00:00:00.000Z",
    grantExpiresAt: "2026-12-01T00:00:00.000Z",
    grantStartsAtTs: admin.firestore.Timestamp.fromDate(
      new Date("2026-11-01T00:00:00.000Z"),
    ),
    grantExpiresAtTs: admin.firestore.Timestamp.fromDate(
      new Date("2026-12-01T00:00:00.000Z"),
    ),
    schemaVersion: 1,
    createdAt: now.toISOString(),
    updatedAt: now.toISOString(),
  });
  for (const id of ["a", "b", "c"]) {
    await db.doc(`users/${uidOk}/resumes/${id}`).set({
      id,
      nombre: id,
      userId: uidOk,
      updatedAt: now.toISOString(),
    });
  }
  const proCreate = await createResumeAtomic({
    uid: uidOk,
    resumeId: "d",
    resume: resumePayload("D"),
    db,
    now,
  });
  assert.equal(proCreate.created, true);
  assert.equal(proCreate.isPro, true);

  const uidExp = `grant_exp_${Date.now()}`;
  await db.doc(`entitlements/${uidExp}`).set({
    uid: uidExp,
    plan: "pro",
    subscriptionStatus: "active",
    source: "admin_grant",
    grantModality: "temporary",
    grantExpiresAt: "2026-11-01T00:00:00.000Z",
    grantExpiresAtTs: admin.firestore.Timestamp.fromDate(
      new Date("2026-11-01T00:00:00.000Z"),
    ),
    schemaVersion: 1,
    createdAt: now.toISOString(),
    updatedAt: now.toISOString(),
  });
  for (const id of ["a", "b", "c"]) {
    await db.doc(`users/${uidExp}/resumes/${id}`).set({
      id,
      nombre: id,
      userId: uidExp,
      updatedAt: now.toISOString(),
    });
  }
  await assert.rejects(
    () =>
      createResumeAtomic({
        uid: uidExp,
        resumeId: "d",
        resume: resumePayload("D"),
        db,
        now,
      }),
    (e: unknown) =>
      e instanceof CreateResumeError && e.code === "resource-exhausted",
  );
});

test("Caso F: Free sin usage materializa y crea", async () => {
  const db = initAdmin();
  const uid = `free_nousage_${Date.now()}`;
  await seedFreeUser(db, uid, []);
  await db.doc(`usage/${uid}`).delete().catch(() => undefined);

  const r = await createResumeAtomic({
    uid,
    resumeId: "cv1",
    resume: resumePayload("Uno"),
    db,
  });
  assert.equal(r.created, true);
  assert.equal(r.resumeCount, 1);
  const usage = await db.doc(`usage/${uid}`).get();
  assert.equal(usage.exists, true);
  assert.equal(usage.data()?.resumeCount, 1);
});

test("Caso G: reintento con misma idempotencyKey no duplica", async () => {
  const db = initAdmin();
  const uid = `free_idem_${Date.now()}`;
  await seedFreeUser(db, uid, []);

  const key = "client-op-1";
  const first = await createResumeAtomic({
    uid,
    resumeId: "cv1",
    resume: resumePayload("Uno"),
    idempotencyKey: key,
    db,
  });
  assert.equal(first.created, true);

  const second = await createResumeAtomic({
    uid,
    resumeId: "cv1",
    resume: resumePayload("Uno otra vez"),
    idempotencyKey: key,
    db,
  });
  assert.equal(second.created, false);
  assert.equal(second.idempotentReplay, true);
  assert.equal(await countResumes(db, uid), 1);
});

test("Caso H: createResumeAtomic usa solo el uid del contexto", async () => {
  const db = initAdmin();
  const owner = `owner_${Date.now()}`;
  const attacker = `attacker_${Date.now()}`;
  await seedFreeUser(db, owner, []);
  await seedFreeUser(db, attacker, []);

  await createResumeAtomic({
    uid: attacker,
    resumeId: "stolen",
    resume: {
      ...resumePayload("Robo"),
      userId: owner, // intento de falsificar dueño
    },
    db,
  });

  const stolenUnderOwner = await db
    .doc(`users/${owner}/resumes/stolen`)
    .get();
  const underAttacker = await db
    .doc(`users/${attacker}/resumes/stolen`)
    .get();
  assert.equal(stolenUnderOwner.exists, false);
  assert.equal(underAttacker.exists, true);
  assert.equal(underAttacker.data()?.userId, attacker);
});

test("Caso I: refresh concurrente no deja crear un 4º Free", async () => {
  const db = initAdmin();
  const uid = `free_refresh_${Date.now()}`;
  await seedFreeUser(db, uid, ["cv1", "cv2"]);

  const [createSettled] = await Promise.all([
    Promise.allSettled([
      createResumeAtomic({
        uid,
        resumeId: "cv3",
        resume: resumePayload("Tres"),
        db,
      }),
      createResumeAtomic({
        uid,
        resumeId: "cv4",
        resume: resumePayload("Cuatro"),
        db,
      }),
    ]),
    refreshResumeUsage(uid, db),
    refreshResumeUsage(uid, db),
  ]);

  const ok = createSettled.filter((r) => r.status === "fulfilled");
  assert.equal(ok.length, 1);
  assert.equal(await countResumes(db, uid), 3);

  // Tras reconciliar, usage debe reflejar 3 y bloquear otro create.
  await refreshResumeUsage(uid, db);
  const usage = await db.doc(`usage/${uid}`).get();
  assert.equal(usage.data()?.resumeCount, 3);
  await assert.rejects(
    () =>
      createResumeAtomic({
        uid,
        resumeId: "cv5",
        resume: resumePayload("Cinco"),
        db,
      }),
    (e: unknown) =>
      e instanceof CreateResumeError && e.code === "resource-exhausted",
  );
});
