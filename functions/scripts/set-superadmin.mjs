/**
 * Asigna o quita el custom claim `superadmin: true` a un usuario Auth.
 *
 * Uso (desde carpeta functions, con Application Default Credentials
 * o GOOGLE_APPLICATION_CREDENTIALS apuntando a una service account):
 *
 *   node scripts/set-superadmin.mjs --email tu@correo.com
 *   node scripts/set-superadmin.mjs --uid ABC123
 *   node scripts/set-superadmin.mjs --email tu@correo.com --revoke
 *
 * El usuario debe volver a iniciar sesión (o refresh token) para ver el claim.
 */
import {initializeApp, applicationDefault} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";

initializeApp({credential: applicationDefault()});

function arg(name) {
  const i = process.argv.indexOf(name);
  if (i === -1) return null;
  return process.argv[i + 1] ?? null;
}

const email = arg("--email");
const uid = arg("--uid");
const revoke = process.argv.includes("--revoke");

if (!email && !uid) {
  console.error("Indica --email o --uid");
  process.exit(1);
}

const auth = getAuth();
const user = email ? await auth.getUserByEmail(email) : await auth.getUser(uid);
const claims = {...(user.customClaims || {})};

if (revoke) {
  delete claims.superadmin;
} else {
  claims.superadmin = true;
}

await auth.setCustomUserClaims(user.uid, claims);
console.log(
  revoke
    ? `Revocado superadmin → ${user.uid} (${user.email || "sin email"})`
    : `OK superadmin → ${user.uid} (${user.email || "sin email"})`,
);
console.log("El usuario debe cerrar sesión y volver a entrar.");
