# Plan de actualización profesional — CV Maker (`creador_cv`)

**Fecha de auditoría (Fase 0):** 2026-07-31  
**Repositorio:** https://github.com/boris13jbb/creador_cv  
**Rama auditada:** `main` @ `2328bb3` (working tree limpio)  
**Estado de la Fase 0:** COMPLETADO CON ADVERTENCIAS  
**Estado general (2026-08-01):** Fases 0–7 implementadas en código. Deploy Firebase/Stripe/Hosting y firma Android upload **requieren autorización y secretos del operador** (ver `docs/PUBLISHING.md`).

---

## 1. Línea base del entorno

| Elemento | Valor |
|----------|--------|
| Flutter | 3.44.2 (stable) |
| Dart | 3.12.2 |
| `flutter doctor` | Sin issues |
| SDK `pubspec` | `^3.8.1` (compatible) |
| Proyecto Firebase | `cvmaker-saas-jb` |
| Plataformas configuradas | Android, Web, Windows (iOS presente; sin `GoogleService-Info.plist` en el inventario auditado) |
| Estado comercial anunciado | Free / Pro + trial 14 días |

### Comandos ejecutados

| Comando | Resultado |
|---------|-----------|
| `flutter --version` / `dart --version` | OK |
| `flutter doctor -v` | OK, sin issues |
| `flutter pub get` | OK |
| `flutter pub outdated` | 20 dependencias directas/transitivas resolubles a versiones más nuevas; `share_plus` 7→13 es salto mayor |
| `dart format --output=none --set-exit-if-changed .` | **FAIL** (exit 1): 25 archivos desalineados con el formateador |
| `flutter analyze` | **OK** con 7 *info* (sin error ni warning) |
| `flutter test` | **OK** (1 test trivial: `expect(true, isTrue)`) |

### Inventario estructural actual

```text
lib/
├── main.dart
├── firebase_options.dart
├── models/resume.dart
├── theme/app_theme.dart
├── services/
│   ├── db_service.dart          ← solo cloud
│   ├── db_service_io.dart       ← código legado / no usado por DBService
│   ├── db_service_web.dart      ← código legado / no usado por DBService
│   └── resume_pdf_service.dart  ← ~992 líneas, 4 plantillas
├── saas/
│   ├── config/
│   ├── models/
│   ├── providers/
│   └── services/                ← Auth REST, Firestore REST, perfiles
└── screens/                     ← auth, home, editor, cuenta, pricing

firestore.rules                  ← existe
storage.rules                    ← NO existe
functions/                       ← NO existe
.github/workflows/               ← NO existe
```

---

## 2. Diagnóstico real

La aplicación es funcional como MVP: autenticación email/password, CRUD de CV en Firestore, generación PDF con 4 diseños, pantalla de planes y Payment Link opcional de Stripe. **No está lista como SaaS seguro**: los privilegios Pro son modificables desde el cliente, los límites Free solo se validan en Flutter, Windows puede degradar un perfil Pro a Free, las fotos no se sincronizan entre dispositivos, no hay backend de facturación ni CI.

Provider se mantiene como estado inicial; no se recomienda una migración completa de arquitectura en un solo paso.

---

## 3. Problemas clasificados

### P0 — Crítico (bloquea SaaS / seguridad / pérdida de datos)

| ID | Problema | Evidencia / archivos | Confirmado |
|----|----------|----------------------|------------|
| P0-01 | Reglas Firestore permiten `write` completo en `users/{userId}` | `firestore.rules` L11–12: `allow read, write: if isOwner(userId)` | Sí |
| P0-02 | Un usuario puede autoasignarse Pro escribiendo `plan` / `subscriptionStatus` | Mismo punto + `UserProfileService.setPlan` + `SAAS.md` documenta edición manual | Sí |
| P0-03 | Límite de 3 CV solo en cliente | `cloud_resume_repository.dart` L48–56 / L63–71; reglas no cuentan documentos | Sí |
| P0-04 | Windows/REST sobrescribe perfil existente con Free | `auth_controller.dart` `_ensureRestProfile` siempre construye `SubscriptionPlan.free` y hace `upsertUserProfile` sin leer el doc previo | Sí |
| P0-05 | Sesión REST solo en memoria; no hay persistencia segura | `AuthService._restSession`; sin `flutter_secure_storage` ni restauración al arrancar | Sí |
| P0-06 | Stripe Payment Link no activa suscripción automáticamente | `pricing_screen.dart` solo abre URL; sin webhook / Functions | Sí |
| P0-07 | Fotos: ruta local o Base64; no sincronizan entre dispositivos | `nuevo_cv_screen.dart` L124–126; PDF lee `File(path)` o `data:` | Sí |
| P0-08 | Plantillas Pro no bloqueadas | `canAllDesigns` definido en `saas_config.dart` pero **nunca usado**; UI ofrece 4 diseños a todos | Sí |
| P0-09 | iOS sin permiso de fotos | `ios/Runner/Info.plist` sin `NSPhotoLibraryUsageDescription` / `NSCameraUsageDescription` | Sí |

### P1 — Alto (calidad, integridad, cumplimiento)

| ID | Problema | Archivos | Confirmado |
|----|----------|----------|------------|
| P1-01 | `IdentityToolkitClient.refresh` existe y no se usa | `identity_toolkit_client.dart` L67–89 | Sí |
| P1-02 | Preview PDF guarda el CV sin confirmación | `nuevo_cv_screen.dart` `_generarPreview` L166–177 | Sí |
| P1-03 | `Expanded` dentro de `Wrap` (layout inválido) | `_buildDesignOption` retorna `Expanded` usado como hijo de `Wrap` L201–208 / L359–380 | Sí |
| P1-04 | `TextEditingController` creado en `build` | L278: `controller: TextEditingController(text: data.value)` | Sí |
| P1-05 | Controllers de `_nombreController` / `_perfilController` sin `dispose` | `NuevoCvScreen` no implementa `dispose` | Sí |
| P1-06 | PDF de una sola página (`pw.Page`); riesgo de overflow con contenido largo | `resume_pdf_service.dart` (4 generadores) | Sí |
| P1-07 | Trial 14 días se escribe pero no se aplica ni expira | `trialEndsAt` en perfil; `isPro` no consulta trial | Sí |
| P1-08 | Android release firma con debug | `android/app/build.gradle.kts` L32–36 | Sí |
| P1-09 | `firebase_storage` en `pubspec` sin integración de aplicación | Sin imports en `lib/`; sin `storage.rules` | Sí |
| P1-10 | Fallo de `Firebase.initializeApp` se traga en silencio | `main.dart` L15–21; no hay pantalla de error de init | Sí |
| P1-11 | Sin verificación de email, eliminación de cuenta ni exportación GDPR | Auth screens / `account_screen.dart` | Sí |
| P1-12 | Sin portal de cliente Stripe ni historial de pagos | Solo Payment Link | Sí |

### P2 — Medio (deuda técnica / escalabilidad / publicación)

| ID | Problema | Archivos | Confirmado |
|----|----------|----------|------------|
| P2-01 | Listas del modelo como JSON string en Firestore | `resume.dart` `toMap`/`fromMap` con `jsonEncode`/`jsonDecode` | Sí |
| P2-02 | Carga de todos los CV sin paginación | `obtenerResumes` / `listResumes` | Sí |
| P2-03 | `NuevoCvScreen` (~569 líneas) y `ResumePdfService` (~992 líneas) monolíticos | Misma responsabilidad excesiva | Sí |
| P2-04 | Código muerto: `db_service_io.dart`, `db_service_web.dart`; deps locales (`sqflite*`) probablemente residuales | `db_service.dart` solo delega a cloud | Sí |
| P2-05 | Test actual no valida funcionalidad real | `test/widget_test.dart` | Sí |
| P2-06 | Sin GitHub Actions | No existe `.github/` | Sí |
| P2-07 | Web con metadatos genéricos de Flutter | `web/index.html`, `web/manifest.json` | Sí |
| P2-08 | 25 archivos sin `dart format` | Deuda de formato en línea base | Sí |
| P2-09 | 7 infos del analizador (API deprecadas `Color.value`, `DropdownButtonFormField.value`, `toList` innecesario) | `nuevo_cv_screen.dart`, `resume_pdf_service.dart` | Sí |
| P2-10 | Dependencias desactualizadas (`share_plus`, FlutterFire, `flutter_lints`) | `flutter pub outdated` | Sí |
| P2-11 | Sin accesibilidad explícita (Semantics / focus / contraste revisado) | Búsqueda sin matches de Semantics en `lib/` | Sí |
| P2-12 | Índices Firestore vacíos; `orderBy('updatedAt')` puede fallar si faltan campos en docs antiguos | `firestore.indexes.json`, repositorio cloud | Sí |

### P3 — Bajo (mejora / polish)

| ID | Problema | Notas |
|----|----------|-------|
| P3-01 | Colores hardcodeados en pantallas (`Colors.orange`, etc.) fuera del design system | `home_screen.dart`, `pricing_screen.dart` |
| P3-02 | Navegación solo con `MaterialPageRoute`; sin `go_router` | Escalado de deep links / web |
| P3-03 | Mezcla de naming ES/EN (`NuevoCvScreen` vs `ResumePdfService`) | Criterio a unificar gradualmente |
| P3-04 | `obtenerResume` descarga todos y filtra en cliente | Ineficiente |
| P3-05 | Catch vacíos al cargar imágenes PDF | Ocultan fallos reales |
| P3-06 | Branding inconsistente (`CV Maker` / `creador_cv` / `Creador Cv`) | iOS display name vs web title |

### Verificación de la lista conocida (1–25)

| # | Hallazgo conocido | Estado en código |
|---|-------------------|------------------|
| 1–2 | Reglas / auto-Pro | **Confirmado** |
| 3 | Límite solo cliente | **Confirmado** |
| 4 | Windows sobrescribe a Free | **Confirmado** |
| 5 | Sesión REST insegura / no persistida | **Confirmado** |
| 6 | Refresh token no usado | **Confirmado** |
| 7–8 | Stripe sin webhook/portal | **Confirmado** |
| 9–10 | Fotos / Storage | **Confirmado** |
| 11 | Plantillas Pro sin bloqueo | **Confirmado** |
| 12 | Preview guarda sin confirmación | **Confirmado** |
| 13 | `Expanded` en `Wrap` | **Confirmado** |
| 14–15 | Controllers en build / sin dispose | **Confirmado** |
| 16 | God classes | **Confirmado** |
| 17 | PDF overflow | **Confirmado** (riesgo alto; no se ejecutó test de PDF largo en Fase 0) |
| 18 | Listas JSON | **Confirmado** |
| 19 | Sin paginación | **Confirmado** |
| 20 | Test trivial | **Confirmado** |
| 21 | Sin Actions | **Confirmado** |
| 22 | Firma debug release | **Confirmado** |
| 23 | Web genérico | **Confirmado** |
| 24 | Permisos iOS fotos | **Confirmado** (faltan) |
| 25 | Trial 14 días incompleto | **Confirmado** |

---

## 4. Archivos afectados (mapa de impacto)

### Seguridad / Auth / Billing
- `firestore.rules`
- `lib/saas/services/user_profile_service.dart`
- `lib/saas/providers/auth_controller.dart`
- `lib/saas/services/auth_service.dart`
- `lib/saas/services/identity_toolkit_client.dart`
- `lib/saas/services/firestore_rest_client.dart`
- `lib/saas/models/saas_user_profile.dart`
- `lib/saas/config/saas_config.dart`
- `lib/screens/account/pricing_screen.dart`
- `SAAS.md` (documentación de bypass manual)

### Datos / Fotos / PDF
- `lib/models/resume.dart`
- `lib/saas/services/cloud_resume_repository.dart`
- `lib/screens/nuevo_cv_screen.dart`
- `lib/services/resume_pdf_service.dart`
- `lib/services/db_service*.dart`
- (nuevo) `storage.rules`, capa Storage

### UI / Plataformas / CI
- `lib/screens/**`, `lib/theme/app_theme.dart`
- `android/app/build.gradle.kts`
- `ios/Runner/Info.plist`
- `web/index.html`, `web/manifest.json`
- (nuevo) `.github/workflows/**`, `functions/**`

---

## 5. Plan por fases

| Fase | Nombre | Objetivo | Entregables clave |
|------|--------|----------|-------------------|
| **0** | Auditoría y línea base | Este documento + métricas | `docs/PROFESSIONAL_UPGRADE_PLAN.md` |
| **1** | Seguridad, autenticación y sesiones | Separar entitlements; reglas estrictas; sesión REST segura; no degradar Pro en Windows | `entitlements/{uid}`, reglas, secure storage, refresh token, export/delete account |
| **2** | Arquitectura y datos | Modularización gradual + fotos Storage + schemaVersion + paginación | `lib/core`, `lib/features`, migración retrocompatible |
| **3** | Rediseño UI/UX | Design system, responsive, a11y, corrección Expanded/controllers | Tokens, layouts móvil/tablet/desktop |
| **4** | Editor y PDF profesional | Autosave, preview sin guardar, plantillas Free/Pro reales, MultiPage | Generadores PDF separados, galería |
| **5** | Stripe SaaS real | Checkout + webhook + portal + entitlements server-side | `functions/`, docs Stripe/Firebase |
| **6** | Pruebas, rendimiento, observabilidad | Cobertura crítica ≥80% lógica clave + Sentry | unit/widget/rules/PDF/webhook |
| **7** | CI/CD, branding, publicación | Actions, firmas, privacidad, PWA | workflows, store/web metadata |

**Regla de avance:** cada fase termina con verificaciones, reporte y espera de `CONTINUAR`.

---

## 6. Riesgos técnicos

1. **Migración de reglas:** restringir escritura de `plan` puede romper clientes antiguos que llamen `setPlan` o el upsert REST de perfil completo.
2. **Degradación Pro en Windows:** ya hay riesgo de datos reales si un usuario Pro abre la app Windows antes de la corrección.
3. **Fotos Base64 grandes:** pueden superar límites de documento Firestore (~1 MiB); migrar a Storage es urgente.
4. **JSON strings → arrays nativos:** requiere lectura dual (`String` o `List`) para no romper CV existentes.
5. **Índice / `orderBy('updatedAt')`:** docs sin campo fallarán o quedarán fuera de resultados.
6. **Actualización mayor de `share_plus` / FlutterFire:** debe hacerse con checklist de breaking changes.
7. **Deploy no autorizado:** reglas/Functions/Hosting no se despliegan sin aprobación explícita.
8. **Payment Link vs Checkout Session:** cambiar el flujo de cobro requiere configuración real de Stripe (precios, webhook secret).

---

## 7. Estrategia de migración de datos

### Principios
- No borrar documentos existentes.
- Lectura retrocompatible primero; escritura en formato nuevo después.
- `schemaVersion` en perfiles, entitlements y resumes (empezar en `1`).
- Timestamps: preferir `FieldValue.serverTimestamp()` manteniendo parseo de ISO8601 antiguo.

### Usuarios / planes
1. Crear colección `entitlements/{uid}` (solo Admin SDK escribe).
2. Backfill: copiar `plan`, `subscriptionStatus`, `trialEndsAt` desde `users/{uid}` hacia entitlements (script Functions one-shot o migración controlada).
3. Cliente: leer entitlements; dejar de escribir `plan` en `users`.
4. Reglas: `users` update solo campos de perfil editable (`displayName`, preferencias); deny de campos de suscripción.

### Resumes
1. Lectura: si el campo es `String`, `jsonDecode`; si es `List`, mapear directo.
2. Escritura nueva: arrays/maps nativos + `schemaVersion`.
3. Fotos: si `fotoPath` es local/`data:`, subir a Storage en próximo guardado y guardar `fotoUrl` + `fotoStoragePath`; conservar campo antiguo temporalmente.

### Windows REST
1. Antes de upsert de perfil: **GET** del documento; si existe, no pisar `plan`/entitlements.
2. Tras entitlements: el cliente REST no escribe derechos.

---

## 8. Criterios de aceptación (producto final)

Estado al cierre de código (Fases 0–7 + go-live docs). Ver `docs/GO_LIVE.md` para deploy.

- [x] Usuario no puede autoasignarse Pro (reglas + ausencia de API cliente). **Deploy rules pendiente.**
- [x] Stripe activa/cancela planes vía webhook idempotente. **Código listo; secrets + deploy Functions pendientes.**
- [x] Plan Pro se conserva en Windows y resto de plataformas. (código; QA Windows post-deploy)
- [x] Sesión REST se restaura y renueva con refresh token; logout si es inválido.
- [x] Fotos visibles entre dispositivos vía Storage. **Deploy storage.rules pendiente.**
- [x] CV solo legibles/escribibles por el dueño. **Deploy rules pendiente.**
- [x] CV antiguos siguen abriéndose (migración dual).
- [x] Límites Free validados en servidor (reglas Callable/Functions). **Código listo (`usage` + `syncResumeUsage` + trigger); deploy Functions+rules pendiente.**
- [x] Plantillas Pro realmente bloqueadas.
- [x] PDF multipágina sin overflow en CV largos. (Helvetica/tildes = mejora tipográfica pendiente)
- [x] `flutter analyze` sin errores; tests críticos en verde.
- [x] UI usable 360px → desktop; a11y básica.
- [x] Android release no usa firma debug. **Keystore del operador pendiente.**
- [x] Sin secretos en el repo; docs de setup completas.

---

## 9. Lista de pruebas necesarias

### Unitarias
- Serialización `Resume` (JSON string legacy + arrays nativos).
- `SaasUserProfile.isPro` / trial expiry.
- Límites Free/Pro.
- Mapeo errores Auth REST/nativo.

### Reglas (Emulator)
- Owner puede CRUD resumes propios.
- No owner denegado.
- Usuario no puede escribir `entitlements`.
- Usuario no puede cambiar `plan` en `users`.
- Storage: solo paths del uid.

### Widget / integración
- Login / registro / forgot password.
- Crear → editar → listar → eliminar CV.
- Preview sin guardar vs guardar.
- Bloqueo plantilla Pro en Free.
- Expanded/layout selector diseños sin crash.

### PDF
- CV vacío, medio y >2 páginas A4/Letter.
- Sin foto / Base64 / URL remota.

### Billing
- Webhook firmado (checkout.session.completed, invoice.paid, customer.subscription.deleted, payment_failed).
- Idempotencia por `event.id`.
- Portal session.

### Plataforma / CI
- Format + analyze + test en Actions.
- Build web / apk debug / windows (cuando runner permita).
- No secretos en artifacts.

---

## 10. Correcciones mínimas aplicadas en Fase 0

Ninguna. El análisis y los tests ejecutan sin errores de compilación. La deuda de `dart format` (25 archivos) y los 7 *info* del analizador se abordan en fases posteriores para no mezclar reformateo masivo con la auditoría.

---

## 11. Dependencias — notas de actualización

| Paquete | Actual | Observación |
|---------|--------|-------------|
| `firebase_*` | 4.7 / 6.4 / 6.3 / 13.1 | Actualizables de forma coordinada |
| `share_plus` | 7.2.x | Latest 13.x — breaking; planificar en Fase 2/6 |
| `flutter_lints` | 5.0 | Latest 6.x |
| `sqlite3_flutter_libs` / `sqflite*` | presentes | Candidatos a eliminación si se confirma código muerto |
| `firebase_storage` | presente | Integrar en Fase 2 o retirar hasta entonces |
| Falta | — | `go_router`, `flutter_secure_storage`, `sentry_flutter`, `image`/`flutter_image_compress` (según diseño Fase 2–6) |

---

## 12. Decisiones pendientes del producto (requieren input del usuario)

1. Nombre comercial definitivo y dominio público.
2. Precio real Pro y si se mantiene trial 14 días (Stripe Trial vs mensaje marketing).
3. Cuáles de las 4 plantillas son Free vs Pro.
4. Autorización para desplegar reglas / Functions / Hosting.
5. Credenciales Stripe (test/live) y DSN Sentry (solo vía env, nunca en repo).
6. Keystore Android release (fuera de Git).

---

*Documento generado en Fase 0. No implementa cambios de arquitectura. Siguiente: Fase 1 tras autorización `CONTINUAR`.*
