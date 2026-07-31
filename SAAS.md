# SaaS — CV Maker

## Stack
- Firebase Auth (email/password)
- Cloud Firestore (CVs por usuario)
- Planes Free / Pro
- Stripe Payment Link (opcional)

## Proyecto Firebase
- ID: `cvmaker-saas-jb`
- Consola: https://console.firebase.google.com/project/cvmaker-saas-jb

## Estado de activación (2026-07-30)
- Billing: activo
- Firestore `(default)` nam5: creado
- Auth Email/Password: activo
- Reglas de seguridad: desplegadas

## Activar
Ya está activado. Si recreas el entorno:
```bash
cd D:\creador_cv
firebase deploy --only firestore:rules --project cvmaker-saas-jb
```

Ejecutar:
```bash
flutter run -d windows
flutter run -d windows --dart-define=STRIPE_PAYMENT_LINK=https://buy.stripe.com/XXXX
```

## Planes
| Plan | Límite |
|------|--------|
| Free | 3 CVs |
| Pro | Ilimitados + todos los diseños |

## Activar Pro manual
Firestore → `users/{uid}` → `plan: pro`, `subscriptionStatus: active`
