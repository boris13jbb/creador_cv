# Pruebas — CV Maker (Fase 6)

## Comandos locales

```powershell
# Flutter
cd D:\creador_cv
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter test --coverage

# Cloud Functions (mapeo Stripe + idempotencia)
cd D:\creador_cv\functions
npm test

# Reglas Firestore (requiere Java + emulators)
cd D:\creador_cv
firebase emulators:exec --only firestore --project demo-test "npm --prefix firestore/tests test"
```

## Mapa de cobertura crítica

| Módulo | Tests | Estado |
|--------|-------|--------|
| Serialización Resume | `resume_serialization_test.dart` | OK |
| Entitlements / perfil writable | `saas_security_models_test.dart` | OK |
| Plantillas Free/Pro + PDF | `pdf_templates_test.dart` | OK |
| PDF largo / flags ocultar | `core_quality_test.dart` | OK |
| ErrorMapper / JsonListCodec / fotos / límites | `core_quality_test.dart` | OK |
| Billing config / Sentry off-by-default | `billing_config_test.dart`, `observability_test.dart` | OK |
| Stripe map + idempotencia | `functions` node tests | OK |
| Firestore rules | `firestore/tests/rules.test.js` | OK (emulator) |
| Widget login/CRUD E2E | — | Pendiente Fase 7 / integration_test |
| Webhook firma real Stripe | — | Requiere secretos + deploy (no en CI sin secrets) |
| Storage rules | — | Pendiente suite dedicada |

## Criterio ≥80% lógica clave

“Lógica clave” en Fase 6 = modelos SaaS, límites, plantillas, PDF facade, ErrorMapper, codec JSON, photo process, mapeo/idempotencia Stripe.

Medición sugerida:

```powershell
flutter test --coverage
# Revisar coverage/lcov.info sobre lib/saas/models, lib/saas/config, lib/features/templates, lib/core/errors, lib/core/utils, lib/features/resumes/pdf
```

CI formal (Actions) = **Fase 7**.
