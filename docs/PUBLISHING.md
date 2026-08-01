# Publicación — CV Maker (Fase 7)

Checklist para publicar **sin subir secretos al repo**.

## Branding aplicado
- Nombre visible: **CV Maker** (Android label, iOS display name, PWA, web title)
- Application ID: `com.brs.creador_cv`
- Colores PWA: navy `#0B1F3A`
- Legal: `/privacy`, `/terms` (assets + `docs/legal/`)

## CI (GitHub Actions)
- `.github/workflows/ci.yml` — format, analyze, test Flutter + Functions + build web smoke
- `.github/workflows/build.yml` — APK **debug** y Windows release (manual / tags `v*`)
- Artifacts: solo `coverage/lcov.info`, `build/web`, APK debug, Windows Release — **sin** `.env`, keystores ni DSN

## Android release (firma real)
1. Genera keystore **fuera del git**:
   ```powershell
   keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. Copia `android/key.properties.example` → `android/key.properties` y rellena (ignorado por git).
3. `flutter build appbundle --release` solo firmará si existe `key.properties`.
4. **Ya no** se usa la firma debug en release (P1-08).

Sin `key.properties`, el build release queda **sin** `signingConfig` (no cae a debug).

## Web / PWA / Hosting
```powershell
flutter build web --release
# Solo con autorización de deploy:
firebase deploy --only hosting --project cvmaker-saas-jb
```
`firebase.json` apunta `hosting.public` a `build/web`.

## iOS
- `CFBundleDisplayName` = CV Maker
- `ITSAppUsesNonExemptEncryption` = false (export compliance básico)
- Revisar Privacy Nutrition Labels en App Store Connect con la política de `docs/legal/PRIVACY.md`

## Secretos (nunca en artifacts)
| Secreto | Dónde |
|---------|--------|
| Stripe keys / webhook | Firebase Functions secrets |
| Sentry DSN | `--dart-define` / GitHub Actions secrets (si se usa) |
| Android keystore | Máquina local / Play App Signing |
| `key.properties` | local, gitignored |

## Checklist pre-tienda
- [ ] Keystore de upload creado y respaldado
- [ ] Privacy / Terms revisados por asesoría si aplica
- [ ] Stripe live + webhook producción
- [ ] Reglas Firestore/Storage desplegadas
- [ ] Iconos launcher personalizados (opcional: `flutter_launcher_icons`)
- [ ] Capturas de tienda
- [ ] CI verde en `main`

## Comandos de verificación local
```powershell
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
cd functions; npm test
flutter build web --release
```
