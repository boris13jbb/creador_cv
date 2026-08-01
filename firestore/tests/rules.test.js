/**
 * Pruebas de reglas Firestore con Firebase Emulator.
 *
 * Requisitos:
 *   firebase emulators:start --only firestore
 *   cd firestore/tests && npm install && npm test
 *
 * O en una sola terminal (desde la raíz del repo):
 *   firebase emulators:exec --only firestore "npm --prefix firestore/tests test"
 */
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';
import assert from 'node:assert/strict';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc, deleteDoc } from 'firebase/firestore';

const __dirname = dirname(fileURLToPath(import.meta.url));
const PROJECT_ID = 'cvmaker-saas-jb';
const rules = readFileSync(join(__dirname, '../../firestore.rules'), 'utf8');

let testEnv;

function nowIso() {
  return new Date().toISOString();
}

function freeEntitlement(uid) {
  return {
    uid,
    plan: 'free',
    subscriptionStatus: 'active',
    trialEndsAt: nowIso(),
    source: 'client_bootstrap',
    schemaVersion: 1,
    createdAt: nowIso(),
    updatedAt: nowIso(),
  };
}

function userProfile(uid) {
  return {
    uid,
    email: `${uid}@example.com`,
    displayName: 'Usuario Test',
    schemaVersion: 1,
    createdAt: nowIso(),
    updatedAt: nowIso(),
  };
}

function resume(uid, id = 'cv1') {
  return {
    id,
    nombre: 'CV Demo',
    userId: uid,
    updatedAt: nowIso(),
    perfil: 'Perfil',
    fotoPath: null,
    datosPersonales: '[]',
    competencias: '[]',
    idiomas: '[]',
    experiencia: '[]',
    formacion: '[]',
    colorHex: 0,
    designIndex: 0,
    ocultarFoto: 0,
    ocultarPerfil: 0,
    ocultarExperiencia: 0,
    ocultarFormacion: 0,
    ocultarCompetencias: 0,
    ocultarIdiomas: 0,
  };
}

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules, host: '127.0.0.1', port: 8080 },
  });
});

test.after(async () => {
  await testEnv?.cleanup();
});

test.beforeEach(async () => {
  await testEnv.clearFirestore();
});

test('owner puede crear y leer su perfil editable', async () => {
  const uid = 'user_a';
  const ctx = testEnv.authenticatedContext(uid);
  const db = ctx.firestore();
  await assertSucceeds(setDoc(doc(db, 'users', uid), userProfile(uid)));
  await assertSucceeds(getDoc(doc(db, 'users', uid)));
});

test('owner no puede escribir plan en users', async () => {
  const uid = 'user_b';
  const ctx = testEnv.authenticatedContext(uid);
  const db = ctx.firestore();
  await assertFails(
    setDoc(doc(db, 'users', uid), {
      ...userProfile(uid),
      plan: 'pro',
      subscriptionStatus: 'active',
    }),
  );
});

test('owner no puede actualizar plan en users legacy', async () => {
  const uid = 'user_c';
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users', uid), {
      ...userProfile(uid),
      plan: 'free',
      subscriptionStatus: 'active',
    });
  });
  const db = testEnv.authenticatedContext(uid).firestore();
  await assertFails(
    updateDoc(doc(db, 'users', uid), {
      plan: 'pro',
      updatedAt: nowIso(),
    }),
  );
});

test('entitlements: bootstrap free permitido una vez', async () => {
  const uid = 'user_d';
  const db = testEnv.authenticatedContext(uid).firestore();
  await assertSucceeds(setDoc(doc(db, 'entitlements', uid), freeEntitlement(uid)));
  await assertSucceeds(getDoc(doc(db, 'entitlements', uid)));
});

test('entitlements: no se puede crear Pro vía bootstrap', async () => {
  const uid = 'user_e';
  const db = testEnv.authenticatedContext(uid).firestore();
  await assertFails(
    setDoc(doc(db, 'entitlements', uid), {
      ...freeEntitlement(uid),
      plan: 'pro',
      source: 'client_bootstrap',
    }),
  );
});

test('entitlements: update y delete denegados al cliente', async () => {
  const uid = 'user_f';
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'entitlements', uid), freeEntitlement(uid));
  });
  const db = testEnv.authenticatedContext(uid).firestore();
  await assertFails(
    updateDoc(doc(db, 'entitlements', uid), {
      plan: 'pro',
      updatedAt: nowIso(),
    }),
  );
  await assertFails(deleteDoc(doc(db, 'entitlements', uid)));
});

test('entitlements: migración legacy Pro permitida una vez', async () => {
  const uid = 'user_g';
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users', uid), {
      ...userProfile(uid),
      plan: 'pro',
      subscriptionStatus: 'active',
    });
  });
  const db = testEnv.authenticatedContext(uid).firestore();
  await assertSucceeds(
    setDoc(doc(db, 'entitlements', uid), {
      uid,
      plan: 'pro',
      subscriptionStatus: 'active',
      trialEndsAt: null,
      source: 'legacy_migration',
      schemaVersion: 1,
      createdAt: nowIso(),
      updatedAt: nowIso(),
    }),
  );
});

test('resumes: owner CRUD; otro usuario denegado', async () => {
  const owner = 'owner_1';
  const other = 'other_1';
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'usage', owner), {
      uid: owner,
      resumeCount: 0,
      schemaVersion: 1,
      updatedAt: nowIso(),
    });
  });
  const ownerDb = testEnv.authenticatedContext(owner).firestore();
  await assertSucceeds(
    setDoc(doc(ownerDb, 'users', owner, 'resumes', 'cv1'), resume(owner)),
  );
  await assertSucceeds(getDoc(doc(ownerDb, 'users', owner, 'resumes', 'cv1')));

  const otherDb = testEnv.authenticatedContext(other).firestore();
  await assertFails(getDoc(doc(otherDb, 'users', owner, 'resumes', 'cv1')));
  await assertFails(
    setDoc(doc(otherDb, 'users', owner, 'resumes', 'cv2'), resume(owner, 'cv2')),
  );
});

test('resumes Free: create permitido sin usage (transición hasta sync)', async () => {
  const uid = 'free_no_usage';
  const db = testEnv.authenticatedContext(uid).firestore();
  await assertSucceeds(
    setDoc(doc(db, 'users', uid, 'resumes', 'cv1'), resume(uid)),
  );
});

test('resumes Free: create denegado con resumeCount >= 3', async () => {
  const uid = 'free_full';
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'usage', uid), {
      uid,
      resumeCount: 3,
      schemaVersion: 1,
      updatedAt: nowIso(),
    });
    await setDoc(doc(ctx.firestore(), 'entitlements', uid), freeEntitlement(uid));
  });
  const db = testEnv.authenticatedContext(uid).firestore();
  await assertFails(
    setDoc(doc(db, 'users', uid, 'resumes', 'cv_new'), resume(uid, 'cv_new')),
  );
});

test('resumes Free: create permitido con resumeCount < 3', async () => {
  const uid = 'free_ok';
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'usage', uid), {
      uid,
      resumeCount: 2,
      schemaVersion: 1,
      updatedAt: nowIso(),
    });
  });
  const db = testEnv.authenticatedContext(uid).firestore();
  await assertSucceeds(
    setDoc(doc(db, 'users', uid, 'resumes', 'cv3'), resume(uid, 'cv3')),
  );
});

test('resumes Pro: create sin tope de usage', async () => {
  const uid = 'pro_user';
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'entitlements', uid), {
      ...freeEntitlement(uid),
      plan: 'pro',
      subscriptionStatus: 'active',
      source: 'stripe',
    });
    await setDoc(doc(ctx.firestore(), 'usage', uid), {
      uid,
      resumeCount: 50,
      schemaVersion: 1,
      updatedAt: nowIso(),
    });
  });
  const db = testEnv.authenticatedContext(uid).firestore();
  await assertSucceeds(
    setDoc(doc(db, 'users', uid, 'resumes', 'cv_pro'), resume(uid, 'cv_pro')),
  );
});

test('usage: lectura propia; escritura denegada', async () => {
  const uid = 'usage_rw';
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'usage', uid), {
      uid,
      resumeCount: 1,
      schemaVersion: 1,
      updatedAt: nowIso(),
    });
  });
  const db = testEnv.authenticatedContext(uid).firestore();
  await assertSucceeds(getDoc(doc(db, 'usage', uid)));
  await assertFails(
    setDoc(doc(db, 'usage', uid), {
      uid,
      resumeCount: 0,
      schemaVersion: 1,
      updatedAt: nowIso(),
    }),
  );
});

test('billingCustomers: lectura propia; escritura denegada', async () => {
  const uid = 'user_h';
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'billingCustomers', uid), {
      stripeCustomerId: 'cus_test',
    });
  });
  const db = testEnv.authenticatedContext(uid).firestore();
  await assertSucceeds(getDoc(doc(db, 'billingCustomers', uid)));
  await assertFails(
    setDoc(doc(db, 'billingCustomers', uid), { stripeCustomerId: 'hack' }),
  );
});

test('anónimo no puede leer datos privados', async () => {
  const uid = 'user_i';
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users', uid), userProfile(uid));
  });
  const db = testEnv.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(db, 'users', uid)));
});
