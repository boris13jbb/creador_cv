# SaaS — CV Maker

## Stack
- Firebase Auth (email/password) + verificación de correo
- Cloud Firestore (perfil, entitlements, CVs por usuario)
- Firebase Storage (fotos de perfil)
- Planes Free / Pro (derechos en `entitlements/{uid}`)
- Stripe Checkout + webhook + Customer Portal ([docs/STRIPE_BILLING.md](docs/STRIPE_BILLING.md))

## Observabilidad y pruebas
- [docs/OBSERVABILITY.md](docs/OBSERVABILITY.md) — Sentry opcional vía `SENTRY_DSN`
- [docs/TESTING.md](docs/TESTING.md) — comandos y mapa de cobertura
- [docs/PUBLISHING.md](docs/PUBLISHING.md) — CI, firma Android, Hosting, checklist tienda
- [docs/GO_LIVE.md](docs/GO_LIVE.md) — checklist operativa post Fases 0–7 (deploy/secrets)
- [docs/SERVER_LIMITS.md](docs/SERVER_LIMITS.md) — límites Free en servidor (`usage` + Functions)
- Legal: [docs/legal/PRIVACY.md](docs/legal/PRIVACY.md), [docs/legal/TERMS.md](docs/legal/TERMS.md)

## Proyecto Firebase
- ID: `cvmaker-saas-jb`
- Consola: https://console.firebase.google.com/project/cvmaker-saas-jb

## Seguridad
Ver [docs/FIREBASE_SECURITY.md](docs/FIREBASE_SECURITY.md).

Colecciones clave:
- `users/{uid}` — perfil editable (sin privilegios)
- `entitlements/{uid}` — plan y estado (cliente no puede elevar; Stripe webhook escribe Pro)
- `usage/{uid}` — contador de CVs (solo Functions/Admin; reglas Free lo leen)
- `users/{uid}/resumes/{id}` — CVs del usuario
- `billingCustomers/{uid}` — mapeo Stripe customer (solo backend)
- `billingEvents/{eventId}` — idempotencia webhook (solo backend)

## Desplegar (solo con autorización)
```powershell
cd D:\creador_cv
firebase deploy --only firestore:rules,storage --project cvmaker-saas-jb
# Tras configurar secretos Stripe:
firebase deploy --only functions --project cvmaker-saas-jb
```

## Ejecutar
```powershell
flutter pub get
flutter run -d windows
flutter run -d windows `
  --dart-define=BILLING_BACKEND_ENABLED=true `
  --dart-define=BILLING_FUNCTIONS_BASE_URL=https://us-central1-cvmaker-saas-jb.cloudfunctions.net
```

Fallback temporal Payment Link (opcional):
```powershell
--dart-define=STRIPE_PAYMENT_LINK=https://buy.stripe.com/XXXX
```

## Planes
| Plan | Límite |
|------|--------|
| Free | 3 CVs + diseños Clásico/Moderno |
| Pro | Ilimitados + todos los diseños |

## Activar Pro
1. Usuario pulsa **Mejorar a Pro** → Checkout Session (Functions).
2. Stripe envía webhook firmado → Admin SDK escribe `entitlements` con `source: stripe`.
3. Usuario pulsa actualizar plan en pantalla Planes.

**No** edites `plan` desde el cliente.
