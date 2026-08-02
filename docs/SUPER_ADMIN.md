# Super Admin — monitoreo y Pro de cortesía

Panel separado (`super_admin/`) para que el superadministrador:

1. Monitoree usuarios, planes y uso de CVs.
2. Otorgue acceso **Pro gratis** a clientes concretos (sin Stripe).
3. Revogue ese acceso cuando corresponda.

La app de usuarios (`creador_cv`) **no** incluye UI de administración.

## Modelo

| Concepto | Detalle |
|----------|---------|
| Claim Auth | `superadmin: true` (custom claim Firebase Auth) |
| Entitlement | `plan: pro`, `subscriptionStatus: active`, `source: admin_grant` |
| Auditoría | `adminAuditLogs/{id}` (solo Admin SDK) |
| Stripe | Un grant activo **no** se degrada si Stripe cancela; un Pro de pago limpia metadatos de cortesía |

Campos extra en `entitlements/{uid}`:

- `grantedBy`, `grantedAt`, `grantNote`, `grantExpiresAt` (opcional ISO-8601)

## Functions HTTP (Bearer + claim)

| Endpoint | Acción |
|----------|--------|
| `adminGrantPro` | Otorga Pro de cortesía (`email` o `uid`, `note?`, `expiresAt?`) |
| `adminRevokeGrant` | Quita el grant |
| `adminGetUser` | Detalle de cliente |
| `adminListUsers` | Listado paginado Auth + plan/usage |
| `adminGetMetrics` | Conteos + auditoría reciente |

## 1. Desplegar Functions y rules

```powershell
cd D:\creador_cv
firebase deploy --only functions:adminGrantPro,functions:adminRevokeGrant,functions:adminGetUser,functions:adminListUsers,functions:adminGetMetrics,firestore:rules --project cvmaker-saas-jb
```

## 2. Asignar rol superadmin

Requiere credenciales de Admin SDK (ADC o `GOOGLE_APPLICATION_CREDENTIALS`):

```powershell
cd D:\creador_cv\functions
# Ejemplo con service account descargada de Firebase Console → Project settings → Service accounts
$env:GOOGLE_APPLICATION_CREDENTIALS = "D:\ruta\serviceAccount.json"
node scripts/set-superadmin.mjs --email tu-admin@correo.com
```

El usuario debe **cerrar sesión y volver a entrar** (o “Reintentar claims” en el panel).

Revocar:

```powershell
node scripts/set-superadmin.mjs --email tu-admin@correo.com --revoke
```

## 3. Ejecutar el panel

```powershell
cd D:\creador_cv\super_admin
flutter pub get
flutter run -d chrome `
  --dart-define=ADMIN_FUNCTIONS_BASE_URL=https://us-central1-cvmaker-saas-jb.cloudfunctions.net
```

## 4. Uso operativo

1. Entra con la cuenta que tiene `superadmin`.
2. Revisa métricas (usuarios Auth, Pro, Free, grants).
3. Busca un cliente por **email** o **UID**.
4. Pulsa **Dar Pro gratis** (opcional: nota).
5. El cliente ve Pro en la app (y “cortesía admin” en Precios).
6. Para quitar el privilegio: **Revocar grant**.

## Seguridad

- Las Functions rechazan tokens sin `superadmin: true`.
- Firestore: `adminAuditLogs` sin lectura/escritura cliente.
- No abras listados globales de usuarios en rules de la app CV Maker.
- Limita cuántas cuentas tienen el claim (idealmente 1–2).

## Hosting opcional del panel

Puedes publicar `super_admin/build/web` en un sitio Hosting aparte (p. ej. `admin.tudominio.com`) con autenticación Firebase y sin indexación pública.
