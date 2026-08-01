# Límites Free en servidor

Tope Free: **3 CVs** (`FREE_MAX_CVS` / `PlanLimits.freeMaxCvs`).

## Piezas

| Pieza | Rol |
|-------|-----|
| `usage/{uid}` | Contador `resumeCount` (solo Admin/Functions escribe) |
| `POST syncResumeUsage` | Recuenta CVs reales y materializa `usage` |
| `onResumeUsageChanged` | Trigger Firestore: re-sync tras write en resumes |
| Reglas create | Free: `resumeCount < 3`; Pro active/trialing: sin tope |
| Cliente | Sync al login + antes de crear CV Free |

## Deploy (con autorización)

```powershell
cd D:\creador_cv
firebase deploy --only functions:syncResumeUsage,functions:onResumeUsageChanged,firestore:rules --project cvmaker-saas-jb
```

Orden seguro: Functions primero (o el mismo comando), luego que los usuarios abran la app (sync al login).

## Pruebas

```powershell
cd D:\creador_cv\functions
npm test

# Reglas (JDK 21+):
firebase emulators:exec --only firestore "npm --prefix firestore/tests test" --project cvmaker-saas-jb
```
