# Go-Live — CV Maker

**Fecha:** 2026-08-01  
**Alcance:** cierre operativo tras Fases 0–7 (código listo; operación pendiente de secretos/autorización).

## 1. Criterios de aceptación del plan

| Criterio | Estado en código | Pendiente operativo |
|----------|------------------|---------------------|
| No autoasignarse Pro | Listo (reglas + sin API cliente) | Deploy `firestore.rules` |
| Stripe activa/cancela vía webhook | Listo (`functions/`) | Secrets + deploy Functions + webhook |
| Pro se conserva en Windows | Listo (REST GET previo / entitlements) | Probar en Windows real post-deploy |
| Sesión REST + refresh | Listo (`flutter_secure_storage`) | — |
| Fotos multi-dispositivo (Storage) | Listo | Deploy `storage.rules` |
| CV solo del dueño | Listo (reglas) | Deploy rules |
| CV legacy abren (dual) | Listo + tests | — |
| Límites Free en servidor | Listo (`usage` + sync + trigger + rules) | Deploy Functions + rules juntos |
| Plantillas Pro bloqueadas | Listo (UI + PDF) | — |
| PDF MultiPage | Listo + tests | Tipografías Unicode (mejora) |
| analyze / tests verdes | Listo | CI en GitHub al hacer push |
| UI responsive | Listo (shell/tokens) | QA manual dispositivos |
| Android release ≠ debug | Listo (gradle) | Crear keystore + `key.properties` |
| Sin secretos en repo | Listo | Configurar secrets reales fuera del git |

## 2. Orden recomendado (tú ejecutas / autorizas)

### A. Commit y remoto
```powershell
# Cuando lo pidas explícitamente al agente, o tú mismo:
git add -A
git status
git commit  # mensaje convencional
git push -u origin HEAD
```
Tras el push, Actions (`ci.yml`) debe ponerse en verde.

### B. Firebase rules + Storage
```powershell
firebase deploy --only firestore:rules,storage --project cvmaker-saas-jb
```

### C. Stripe + Functions
1. Price Pro en Stripe Test → `price_...`
2. Secrets: `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`
3. Params: `STRIPE_PRICE_ID`, URLs success/cancel/portal
4. `firebase deploy --only functions --project cvmaker-saas-jb`
5. Webhook → `.../stripeWebhook` (eventos listados en `docs/STRIPE_BILLING.md`)
6. Probar tarjeta `4242…` y refresh de plan en la app

### D. Web Hosting (opcional)
```powershell
flutter build web --release
firebase deploy --only hosting --project cvmaker-saas-jb
```

### E. Android upload
Seguir `docs/PUBLISHING.md` (keystore + `key.properties`).

### F. Observabilidad (opcional)
`--dart-define=SENTRY_DSN=...`

## 3. Comandos de salud (local)

```powershell
cd D:\creador_cv
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
cd functions; npm test
```

## 4. Qué NO hacer aún sin autorización
- `firebase deploy` de rules/functions/hosting
- Commit/push (pide “haz commit” / “push” si lo quieres del agente)
- Subir keystores o pegar secretos en el chat/repo

## 5. Documentación de referencia
- `docs/PUBLISHING.md` — tiendas / CI / firma
- `docs/STRIPE_BILLING.md` — cobro
- `docs/FIREBASE_SECURITY.md` — reglas
- `docs/OBSERVABILITY.md` — Sentry
- `docs/TESTING.md` — pruebas
- `SAAS.md` — visión general
