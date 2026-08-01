# Seguridad Firebase — Fase 1

## Cambios de modelo

| Colección | Lectura cliente | Escritura cliente |
|-----------|-----------------|-------------------|
| `users/{uid}` | Dueño | Solo perfil editable (`displayName`, `email`, `updatedAt`, `schemaVersion`) |
| `entitlements/{uid}` | Dueño | **Create una vez** (Free bootstrap o migración legacy). Update/delete: **denegado** |
| `users/{uid}/resumes/{id}` | Dueño | Dueño; **create Free** exige `usage/{uid}.resumeCount < 3` o Pro activo |
| `usage/{uid}` | Dueño | **Denegado** (solo Admin SDK / Functions) |
| `billingCustomers/{uid}` | Dueño | **Denegado** (solo Admin SDK) |
| `billingEvents/{eventId}` | Nadie | **Denegado** (idempotencia webhook Stripe) |

Los campos `plan` y `subscriptionStatus` **ya no se escriben** desde el cliente en `users`.

## Límites Free en servidor

1. Function HTTP `syncResumeUsage` (Bearer) recuenta CVs y escribe `usage/{uid}`.
2. Trigger `onResumeUsageChanged` mantiene el contador tras create/update/delete.
3. Reglas: Free solo puede **create** si no hay `usage` o `resumeCount < 3`; Pro (`entitlements` active/trialing) sin tope.
4. Cliente: sync al login (best-effort) y antes de crear un CV nuevo Free.

**Despliega Functions y rules juntos.** Sin `syncResumeUsage`, el contador no se materializa vía HTTP.

```powershell
firebase deploy --only functions:syncResumeUsage,functions:onResumeUsageChanged,firestore:rules --project cvmaker-saas-jb
```

## Despliegue (requiere tu autorización explícita)

```powershell
cd D:\creador_cv
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'  # JDK 21+
# Preferible: rules + límites servidor en el mismo paso
firebase deploy --only firestore:rules,storage,functions:syncResumeUsage,functions:onResumeUsageChanged --project cvmaker-saas-jb
```

**No se ha desplegado nada en esta fase.** Hasta desplegar:
- La app sigue usable con fallback local de entitlements.
- La seguridad reforzada **no** está activa en producción.
- Tras el deploy, el primer arranque migra Pro legacy a `entitlements` cuando aplique.

## Emuladores y pruebas de reglas

Requiere **JDK 21+** (p. ej. el JBR de Android Studio).

```powershell
cd D:\creador_cv
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
$env:Path = "$env:JAVA_HOME\bin;$env:Path"
npm --prefix firestore/tests install
firebase emulators:exec --only firestore "npm --prefix firestore/tests test" --project cvmaker-saas-jb
```

Resultado: **15/15 pruebas de reglas aprobadas** en emulador (incluye límites Free/`usage`).

## Sesión Windows/Linux (REST)

- Tokens en `flutter_secure_storage` (nunca contraseñas).
- Refresh automático del `idToken` antes de caducar.
- Si el refresh falla → cierre de sesión.
- Perfil: **GET antes de crear**; no se sobrescribe un doc existente (protege Pro).
- Entitlements: create solo si no existen; migración copia plan legacy del doc `users` si aplica.

## Verificación de correo

Tras login/registro, `AuthGate` exige correo verificado antes del home.

## Eliminación de cuenta

Borra resumes + perfil `users` + cuenta Auth.  
`entitlements` y `billingCustomers` requieren Admin SDK (Functions, Fase 5) para limpieza completa.

## Activar Pro

Ya **no** se debe editar `users/{uid}.plan` desde la consola como flujo oficial.  
Flujo correcto (Fase 5): webhook Stripe → Admin SDK escribe `entitlements/{uid}`.
Ver [STRIPE_BILLING.md](STRIPE_BILLING.md).

Migración temporal de Pro legacy: al abrir la app, si `users` aún tiene `plan: pro` y no existe entitlement, el cliente puede crear `entitlements` con `source: legacy_migration` **una sola vez** (reglas lo validan contra el doc legacy).
