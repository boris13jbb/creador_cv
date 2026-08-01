# Observabilidad — CV Maker (Fase 6)

## Sentry (opcional)

Sin `SENTRY_DSN` la app **no** envía telemetría (seguro en local/CI).

```powershell
flutter run -d windows `
  --dart-define=SENTRY_DSN=https://PUBLIC_KEY@o0.ingest.sentry.io/0 `
  --dart-define=SENTRY_ENVIRONMENT=staging `
  --dart-define=SENTRY_RELEASE=creador_cv@1.0.0+1
```

**Nunca** commits el DSN en el repo. Usa secretos de CI / dart-define.

### Privacidad
- `sendDefaultPii = false`
- Sin screenshots ni view hierarchy
- `beforeSend` limpia `user`, `Authorization` y breadcrumbs con password/token

Código: `lib/core/observability/app_observability.dart`

## Logging
- Flutter: `debugPrint` + `AppObservability.captureException` en init Firebase / share PDF
- Functions: `firebase-functions` logger en checkout/portal/webhook

## Rendimiento (Fase 6)
- Cache de bytes PDF en preview (`ResumePreviewScreen`)
- `DISABLE_GOOGLE_FONTS_FETCH=true` para CI/release sin red de fuentes
- Compresión de fotos (max 1024px / JPEG 78) ya en `ResumePhotoService`
