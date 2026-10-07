# DEVELOPMENT STATUS â€” CV Maker (`creador_cv`)

**Fecha de auditorÃ­a:** 2026-10-06
**Repositorio:** https://github.com/boris13jbb/creador_cv
**Rama auditada:** `main` @ `cac5784` (+ working tree local con cambios no commitados)
**Auditor:** Fase 0 (solo lectura / documentaciÃ³n; sin implementaciÃ³n de fases)

---

## Estado general

| Ãrea | Estado |
|------|--------|
| **Producto / cÃ³digo base** | **PARCIAL** â€” MVP SaaS avanzado en cÃ³digo; no listo para comercializaciÃ³n |
| **Seguridad (cÃ³digo)** | **PARCIAL** â€” reglas y modelo sÃ³lidos; deploy/ops incompletos |
| **Stripe billing (producciÃ³n)** | **BLOQUEADO** â€” cÃ³digo listo; export/deploy/secretos pendientes |
| **Super Admin** | **PARCIAL** â€” WIP local grande sin commit ni CI verde |
| **Tests locales** | **COMPLETADO** (unit/widget limitados) |
| **CI/CD** | **BLOQUEADO** â€” falla en `dart format` en `main` |
| **PublicaciÃ³n** | **PENDIENTE** â€” hosting/firma/tienda/ops |
| **Go-Live** | **PENDIENTE** â€” ver `docs/GO_LIVE.md` |

**Veredicto global:** el proyecto **no estÃ¡ listo para producciÃ³n comercial**. El cÃ³digo de producto es sustancialmente mÃ¡s maduro que el MVP inicial (Fases 0â€“7 documentadas), pero hay **trabajo local sin publicar**, **CI rojo**, **billing Stripe no desplegado por defecto**, y huecos de producto (duplicar CV, a11y, E2E, Unicode PDF, firma Android).

---

## 1. Estado Git

| Ãtem | Valor |
|------|--------|
| Rama actual | `main` (sincronizada con `origin/main`) |
| HEAD | `cac5784` â€” *feat: panel superadmin y grants Pro de cortesÃ­a* |
| Ahead/behind remoto | 0 / 0 |
| Stash | vacÃ­o |
| Commits en `main` (recientes) | Superadmin, branding, plantillas/offline, docs go-live, billing/rules, upgrade SaaS, initial |

### Trabajo local NO commitado (CRÃTICO â€” no descartar)

**Modificados (11):**

- `.firebaserc` â€” asigna `default: cvmaker-saas-jb`
- `docs/SUPER_ADMIN.md`, `super_admin/README.md`
- `functions/src/adminApi.ts`, `functions/src/index.ts`, `functions/tsconfig.json`
- `lib/main.dart` â€” arranque tolerante a fallo Firebase nativo en Windows/Linux REST
- `super_admin/lib/main.dart`, login, dashboard, `admin_api_service.dart`

**Sin trackear (12):** controller, theme, formatters, widgets del panel admin.

**Diff aproximado:** +1304 / âˆ’755 lÃ­neas (mayormente Super Admin UI + API unificada `adminConsole`).

### Riesgo Git

- Se estÃ¡ trabajando **directamente sobre `main`** (viola regla de flujo).
- Antes de cualquier implementaciÃ³n: crear `feature/...` o `fix/...` **preservando** estos cambios (`git switch -c ...` sin perder el working tree).

---

## 2. Estado Flutter

| Check | Resultado |
|-------|-----------|
| Flutter | 3.44.2 stable / Dart 3.12.2 |
| `flutter doctor -v` | Sin issues |
| `flutter analyze` | **OK** â€” *No issues found* |
| `flutter test` | **OK** â€” 34 tests passed |
| `dart format --set-exit-if-changed` | **FAIL** â€” 4 archivos app desalineados (+ mÃ¡s en `super_admin` segÃºn CI) |
| SDK `pubspec` | `^3.8.1` (compatible) |
| Archivos Dart (`lib/`) | 62 |
| Pantalla editor | `nuevo_cv_screen.dart` â‰ˆ **1184** lÃ­neas (god widget) |

### Plataformas

| Plataforma | Config | Notas |
|------------|--------|-------|
| Android | SÃ­ | Release requiere `key.properties` (ejemplo existe; archivo real ausente) |
| Web | SÃ­ | Hosting apuntado a `build/web` |
| Windows | SÃ­ | Auth/Firestore vÃ­a REST; cambio local en `main.dart` |
| iOS | Parcial | Presente; revisar `GoogleService-Info.plist` / App Store |
| Desktop macOS/Linux | Limitado | Opciones Firebase definidas; no prioritario |

---

## 3. Estado Firebase

| Pieza | Estado cÃ³digo | Estado ops |
|-------|---------------|------------|
| Auth email/password | Presente | Proyecto `cvmaker-saas-jb` |
| VerificaciÃ³n email | Presente (`AuthGate` / router) | Depende de config Auth |
| Firestore rules | Endurecidas (owner, entitlements create-once, usage read-only, billing/admin denegados) | Docs indican rules desplegadas parcialmente (2026-08-01) |
| Storage rules | Owner + imagen &lt;5MB + nombre `photo.*` | Activar Storage + deploy |
| Functions usage | `syncResumeUsage`, `onResumeUsageChanged` exportados | IAM Eventarc puede bloquear deploy |
| Functions billing Stripe | CÃ³digo en `billing.ts` / checkout / portal / webhook | **NO exportados** en `index.ts` por defecto |
| Functions admin | `adminGrantPro`, `adminConsole` (WIP local) | Deploy requiere auth |
| Emulators | Configurados en `firebase.json` | Suite rules en `firestore/tests` |
| Ãndices | `firestore.indexes.json` | Verificar queries `orderBy` en prod |

### Modelo de datos (resumen)

- `users/{uid}` â€” perfil editable (sin plan)
- `entitlements/{uid}` â€” plan/status (cliente: create Free/legacy una vez; update denegado)
- `usage/{uid}` â€” contador CVs (solo Admin SDK)
- `users/{uid}/resumes/{id}` â€” CVs
- `billingCustomers`, `billingEvents`, `adminAuditLogs`, `plans`

---

## 4. Estado Stripe

| Flujo | CÃ³digo | ProducciÃ³n |
|-------|--------|------------|
| Checkout Session | `createCheckoutSession.ts` + `BillingService` | **BLOQUEADO** (no export / secrets) |
| Customer Portal | `createPortalSession.ts` | **BLOQUEADO** |
| Webhook firmado + idempotencia | `stripeWebhook.ts` + `billingEvents` | **BLOQUEADO** |
| Mapeo entitlement | Tests unitarios OK | â€” |
| Payment Link fallback | `STRIPE_PAYMENT_LINK` dart-define (vacÃ­o por defecto) | Opcional temporal |
| `BILLING_BACKEND_ENABLED` | default `true` | FallarÃ¡ en cliente si Functions billing no existen |

**ConclusiÃ³n:** arquitectura correcta (cliente no escribe Pro). ActivaciÃ³n comercial depende de Secret Manager + export en `index.ts` + deploy + webhook Stripe. **REQUIERE DECISIÃ“N / ACCIÃ“N DEL OPERADOR** (no inventar price IDs ni secretos).

---

## 5. Estado SaaS (Free / Pro / Entitlements)

| Capacidad | Cliente | Servidor |
|-----------|---------|----------|
| LÃ­mite Free 3 CVs | `PlanLimits` + sync usage | Rules `canCreateResumeDoc` + Functions usage |
| Plantillas Free/Pro | `CvTemplates` + UI candado + PDF fallback | No en rules (enforcement PDF/UI) |
| Bootstrap Free | `client_bootstrap` | Rules validan |
| MigraciÃ³n legacy Pro | `legacy_migration` | Rules contrastan con `users.plan` |
| Grant admin | Panel + Functions | `source: admin_grant` + auditorÃ­a |
| Trial 14 dÃ­as | Campos existen | Stripe `trialing` mapeado; trial â€œsoftâ€ legacy a revisar |

**Hueco conocido (documentado):** si no existe doc `usage`, Free puede crear hasta que Functions sincronicen (transiciÃ³n consciente). Mitigado tras sync/trigger.

---

## 6. Estado Super Admin

| Ãtem | Estado |
|------|--------|
| Claim `superadmin` | Modelo documentado + script set-superadmin |
| API unificada `adminConsole` | WIP local (reemplaza exports granulares) |
| Panel Flutter `super_admin/` | RediseÃ±o UI/estado/widgets **no commitado** |
| AuditorÃ­a `adminAuditLogs` | Solo Admin SDK |
| Hub externo | Docs mencionan `plataforma_admin` como hub recomendado |
| AutorizaciÃ³n | Bearer + claim; `invoker: public` Gen2 por CORS (riesgo aceptado si claim estricto) |

**No mergear/desplegar** este WIP sin rama, tests, format y autorizaciÃ³n.

---

## 7. Estado PDF / plantillas

| Ãtem | Estado |
|------|--------|
| Plantillas | ClÃ¡sico, Moderno (Free); Ejecutivo, Creativo (Pro) |
| GeneraciÃ³n | MultiPage + tests por plantilla |
| Miniaturas | Widget + tests |
| Compartir | `Share.shareXFiles` en preview |
| Unicode (Ã±, acentos) | **Riesgo:** Helvetica sin Unicode (warnings en tests) |
| TipografÃ­as embebidas | Pendiente mejora |

---

## 8. Estado UI / UX / Editor

| Capacidad | Estado |
|-----------|--------|
| Auth (login/register/forgot/verify) | Presente |
| Home / historial CVs | Presente |
| Editor + secciones + foto | Presente (monolito grande) |
| Autosave (debounce 3s, dirty/saving/saved/error) | Presente |
| Preview / export PDF | Presente |
| Pricing / upgrade | Presente |
| Account: export JSON / delete account | Presente (limpieza billing/entitlements vÃ­a Admin incompleta) |
| Duplicar CV | **FALTANTE** |
| Reordenar secciones (drag) | **FALTANTE** (sin `ReorderableList`) |
| Empty/loading/error states | Parcial (`AsyncBody`, skeletons) |
| Responsive shell | Tokens/shell presentes; QA dispositivos pendiente |
| Open Graph / SEO social | **FALTANTE** en `web/index.html` |

---

## 9. Estado Tests

| Suite | Resultado |
|-------|-----------|
| Flutter unit/widget (9 archivos, 34 tests) | PASS local |
| Functions (14 tests) | PASS local (`tsc` + node:test) |
| Firestore rules emulator | Existe suite; no re-ejecutada en esta sesiÃ³n |
| Storage rules tests | **PENDIENTE** |
| Integration / E2E | **AUSENTE** (`integration_test/` no existe) |
| Webhook firma real Stripe | No en CI (requiere secrets) |
| Cobertura formal â‰¥80% lÃ³gica clave | No medida en esta sesiÃ³n |

---

## 10. Estado CI/CD

| Workflow | Rol | Estado remoto |
|----------|-----|---------------|
| `ci.yml` | format + analyze + test + functions + build web | **FAIL** Ãºltimos 5 runs |
| `build.yml` | APK debug + Windows (manual/tags) | No bloqueante |

**Causa raÃ­z CI:** `dart format --output=none --set-exit-if-changed .` falla en:

- `lib/features/templates/cv_template_thumbnail.dart`
- `lib/saas/providers/auth_controller.dart`
- `lib/saas/services/cloud_resume_repository.dart`
- `lib/screens/nuevo_cv_screen.dart`
- (+ archivos `super_admin/` en el commit remoto)

Analyze/test **no llegan a ejecutarse** en Actions por el fallo de format.

**Nota entorno local Functions:** Node v24 vs engines `20` (EBADENGINE warning); CI usa Node 20. `npm audit` reportÃ³ 14 vulnerabilidades (1 critical) en dependencias Functions â€” revisar en fase seguridad/deps.

---

## 11. Seguridad

| Hallazgo | Severidad | Notas |
|----------|-----------|--------|
| Cliente no puede `update` entitlements | OK diseÃ±o | Create-once Free/legacy controlado |
| Rules owner en resumes/storage | OK | |
| Stripe secrets no en repo | OK | Solo nombres/params |
| Firebase **API keys cliente** en `firebase_options` / super_admin | Esperado | No son secretos de servidor; reforzar App Check si aplica |
| `adminConsole` invoker public | Medio | Mitigado por claim; monitorear abuso |
| EliminaciÃ³n cuenta incompleta (billing leftovers) | Medio | Documentado |
| Bypass Free sin `usage` temporal | Medio | Documentado |
| Vulnerabilidades npm Functions | Medio/Alto | `npm audit` |
| SECRET DETECTADO (sk/whsec reales) | **No** | No se hallaron secretos Stripe reales en el Ã¡rbol |

---

## 12. Rendimiento

No se midieron mÃ©tricas en runtime en esta auditorÃ­a. Observaciones estÃ¡ticas:

- Editor monolÃ­tico (~1184 LOC) â†’ riesgo de rebuilds costosos
- PaginaciÃ³n de resumes documentada en arquitectura (`listPage`) â€” verificar uso en UI
- PDF generation en isolate no auditado
- Fotos: compresiÃ³n/recorte presentes
- Web bundle: smoke build en CI (bloqueado por format)

---

## 13. Accesibilidad

| Ãtem | Estado |
|------|--------|
| `Semantics` | Uso mÃ­nimo (auth scaffold, gallery) |
| Contraste / focus / teclado | No auditado formalmente |
| Lectores de pantalla en editor | DÃ©bil |

---

## 14. PublicaciÃ³n

| Canal | Estado |
|-------|--------|
| Web Hosting | Config listo; deploy no autorizado / pendiente |
| Dominio / SEO / OG | Parcial (meta description sÃ­; OG no) |
| Android AAB firmado | Pendiente keystore + `key.properties` |
| Play Console / Data Safety | Pendiente |
| Desktop store | **REQUIERE DECISIÃ“N DEL USUARIO** (Â¿publicar Windows?) |
| Legal | Textos Privacy/Terms; **REQUIERE REVISIÃ“N LEGAL** antes de tiendas |

---

## 15. Bugs / defectos confirmados

| ID | Severidad | DescripciÃ³n |
|----|-----------|-------------|
| B-01 | Alta (proceso) | CI en `main` roto por format desde al menos 5 pushes |
| B-02 | Media | PDF Helvetica sin Unicode â†’ riesgo Ã±/acentos mal renderizados |
| B-03 | Media | Stripe Functions no exportadas â†’ upgrade real falla en prod sin deploy billing |
| B-04 | Baja/Media | Format local inconsistente (misma causa que CI) |
| B-05 | Media | Trabajo Super Admin WIP solo local â†’ riesgo de pÃ©rdida / divergencia |
| B-06 | Baja | Node local 24 â‰  engines 20 Functions |

*(Bugs P0 histÃ³ricos del plan 2026-07-31 aparecen mitigados en cÃ³digo actual; no reabrir sin evidencia.)*

---

## 16. Deuda tÃ©cnica

1. `NuevoCvScreen` god widget (~1184 lÃ­neas) â€” mezclar UI + autosave + foto + validaciÃ³n
2. MigraciÃ³n gradual `screens/` â†’ `features/*/presentation` incompleta
3. Dual path Auth SDK vs REST (Windows) â€” complejo pero necesario
4. Format no aplicado en Ã¡rbol â†’ CI rojo
5. Dependencias desactualizadas (`share_plus` 7â†’13, Sentry 8â†’9, etc.)
6. Docs `PROFESSIONAL_UPGRADE_PLAN.md` desfasado vs cÃ³digo actual (histÃ³rico Ãºtil, no fuente de verdad)
7. npm audit Functions
8. Sin integration_test
9. Super Admin: dos narrativas (panel local vs hub `plataforma_admin`)

---

## 17. Funcionalidades faltantes / incompletas

| Funcionalidad | Estado |
|---------------|--------|
| Registro / login / verify / forgot | Existe |
| CRUD CV + autosave + preview + PDF + share | Existe |
| Foto Storage | Existe |
| Free/Pro + lÃ­mites servidor | Existe (ops parcial) |
| Stripe Checkout/Portal/Webhook | CÃ³digo; **ops bloqueada** |
| Super Admin grants/mÃ©tricas | Existe + WIP UI |
| Duplicar CV | **Falta** |
| Reordenar secciones drag-and-drop | **Falta** |
| ExportaciÃ³n datos / borrado cuenta | Existe (limpieza billing parcial) |
| Privacy/Terms in-app | Existe |
| E2E / integration tests | **Falta** |
| App Check / rate limit admin | **Falta** / parcial |
| TipografÃ­as Unicode PDF | **Falta** |
| Open Graph | **Falta** |
| Firma Android release | **Falta** (ops) |

---

## 18. Riesgos

1. **PÃ©rdida del WIP Super Admin** si se limpia el working tree.
2. **Desarrollo en `main`** sin rama de feature.
3. **CI rojo** impide seÃ±al de calidad en remoto.
4. **Billing no desplegado** + cliente con backend enabled â†’ mala UX en upgrade.
5. **Deploy parcial** (rules sÃ­ / functions billing no) â†’ estados inconsistentes.
6. **Unicode PDF** en mercados hispanohablantes.
7. **Grant Free create sin usage** hasta sync.
8. **Cumplimiento legal** no validado por abogado.
9. Dependencias Functions con CVEs reportados por `npm audit`.

---

## 19. Plan de fases (ajustado post-auditorÃ­a)

Orden recomendado (prioridad seguridad â†’ estabilidad â†’ producto â†’ publicaciÃ³n):

| Fase | Objetivo | Prioridad |
|------|----------|-----------|
| **0** | AuditorÃ­a (este documento) | Hecha |
| **1** | EstabilizaciÃ³n: rama, preservar WIP, format, CI verde, smoke analyze/test | **INMEDIATA** |
| **2** | Cerrar/validar Super Admin WIP (API + panel) sin deploy prod | Alta |
| **3** | Seguridad ops: confirmar rules/storage/functions usage en proyecto; App Check opcional | Alta |
| **4** | SaaS hardening: usage sync, edge cases Free bypass, account deletion cleanup | Alta |
| **5** | Stripe: secrets test, export, deploy test, webhook E2E | Alta (ops) |
| **6** | Editor: extraer lÃ³gica, duplicar CV, reorder, validaciones | Media |
| **7** | Autosave: tests regresiÃ³n, conflictos red | Media |
| **8** | PDF Unicode + plantillas QA | Media |
| **9** | UX/UI responsive QA | Media |
| **10** | Testing E2E + ampliar unit | Alta |
| **11** | Rendimiento (medir primero) | Baja/Media |
| **12** | Accesibilidad | Media |
| **13** | Observabilidad Sentry prod | Media |
| **14** | Legal review | Alta (externa) |
| **15** | Web producciÃ³n | Alta |
| **16** | Android Play | Alta |
| **17** | Go-Live + auditorÃ­a final | Final |

---

## 20. PRIMERA FASE RECOMENDADA

### FASE 1 â€” EstabilizaciÃ³n del tren de desarrollo

**Objetivo:** dejar el repo en un estado seguro para iterar sin perder trabajo ni romper seÃ±ales de calidad.

**Alcance propuesto (tras tu autorizaciÃ³n):**

1. Crear rama `fix/ci-format-and-branch-hygiene` (o similar) **desde el working tree actual** (no descartar WIP).
2. Aplicar `dart format` a app + `super_admin`.
3. Verificar `flutter analyze`, `flutter test`, `functions` `npm test`.
4. Asegurar que CI pueda pasar format/analyze/test en esa rama.
5. Documentar estado del WIP Super Admin (quÃ© falta para merge).
6. **No** deploy Firebase/Stripe. **No** push/PR sin autorizaciÃ³n.

**Fuera de alcance Fase 1:** nuevas features de producto, refactor masivo del editor, Stripe live.

---

## Decisiones que REQUIEREN AL USUARIO

1. Â¿Publicar Windows/desktop en tiendas o solo Web+Android?
2. Â¿Super Admin oficial = `super_admin/` del repo o hub `plataforma_admin`?
3. Â¿CuÃ¡ndo autorizar deploy Functions billing (test vs live)?
4. Â¿RevisiÃ³n legal externa de Privacy/Terms antes de Play Store?
5. AutorizaciÃ³n para commit/push/PR de la Fase 1.

---

## Comandos ejecutados en esta auditorÃ­a

```text
git status / branch / log / diff --stat
flutter doctor -v          â†’ OK
flutter analyze            â†’ OK (No issues found)
flutter test               â†’ OK (34 passed)
dart format --set-exit-if-changed â†’ FAIL (4 archivos app)
cd functions && npm ci && npm test && npm run build â†’ OK (14 passed)
gh run list                â†’ CI failure (format)
```

*(Se revirtieron cambios accidentales de `dart format` sobre archivos limpios para no alterar el working tree del usuario.)*

---

## PrÃ³ximo paso (actualizado tras Fase 1)

Fase 1 local **COMPLETADA**. Esperar autorizaciÃ³n para **commit / push / PR** (no hechos).
Siguiente fase recomendada: **Fase 2 â€” cerrar/validar Super Admin WIP** (sin deploy prod).

---

## FASE 1 â€” ESTABILIZACIÃ“N

**Estado:** COMPLETADA (local)
**Fecha:** 2026-10-06
**Alcance:** proteger WIP, salir de `main`, format, analyze, tests, documentar CI. Sin deploy, sin Stripe ops, sin features nuevas.

### Rama

```text
fix/fase-1-estabilizacion-ci
```

Creada con `git switch -c` desde el working tree de `main` @ `cac5784`.
`main` y `origin/main` permanecen en `cac5784` (sin commits nuevos en `main`).

### Inventario WIP (preservado)

| Archivo | Estado | Â¿WIP importante? | AcciÃ³n |
|---------|--------|-----------------:|--------|
| `.firebaserc` | modified | SÃ­ | preservar |
| `docs/SUPER_ADMIN.md` | modified | SÃ­ | preservar |
| `docs/DEVELOPMENT_STATUS.md` | untracked | SÃ­ | preservar |
| `functions/src/adminApi.ts` | modified | SÃ­ (`adminConsole`) | preservar |
| `functions/src/index.ts` | modified | SÃ­ | preservar |
| `functions/tsconfig.json` | modified | SÃ­ | preservar |
| `lib/main.dart` | modified | SÃ­ (REST Windows) | preservar |
| `super_admin/**` (mod + nuevos widgets/theme/state) | modified/untracked | SÃ­ | preservar |
| `lib/.../cv_template_thumbnail.dart` | modified (Fase 1) | No (solo format) | format CI |
| `lib/saas/providers/auth_controller.dart` | modified (Fase 1) | No (solo format) | format CI |
| `lib/saas/services/cloud_resume_repository.dart` | modified (Fase 1) | No (solo format) | format CI |
| `lib/screens/nuevo_cv_screen.dart` | modified (Fase 1) | No (solo format) | format CI |
| `.cursor/` | untracked | No (IDE) | ignorar / no commit |

### Cambios realizados (Fase 1)

1. Rama `fix/fase-1-estabilizacion-ci` con WIP intacto.
2. `dart format` **solo** en los 4 archivos de `lib/` que rompÃ­an CI (mismo set que Actions).
3. `super_admin` ya cumplÃ­a format (0 cambios).
4. Validaciones locales verdes (ver tabla abajo).
5. `npm audit` documentado; **sin** upgrades masivos.
6. Unicode PDF confirmado como riesgo; **sin** refactor (pendiente fase PDF).
7. Workflows CI revisados: no se modificÃ³ `.github/workflows/`.

### Validaciones

| ValidaciÃ³n | Resultado |
|------------|-----------|
| `dart format --set-exit-if-changed .` | **PASS** |
| `flutter analyze` (app) | **PASS** â€” No issues found |
| `flutter analyze` (`super_admin/`) | **PASS** â€” No issues found |
| `flutter test` | **PASS** â€” 34 passed |
| `functions` `npm test` | **PASS** â€” 14 passed |
| `functions` `npm run build` | **PASS** |
| `git diff --check` | **PASS** |
| `npm audit` (functions) | **14 vulns** (11 mod, 2 high, 1 critical) â€” no corregidas en Fase 1 |

### CI

| Ãtem | Detalle |
|------|---------|
| Causa del rojo en `main` | `dart format` fallaba en 4 archivos `lib/` (+ historicamente `super_admin` en commit remoto; WIP local ya formateado) |
| CorrecciÃ³n | Format aplicado a esos 4 archivos |
| Workflow | `ci.yml`: format â†’ analyze â†’ test (+ coverage); functions `npm test`; build-web smoke |
| Ajuste workflow | **Ninguno** (comandos locales alineados) |
| SeÃ±al remota | CI verde en remoto **requiere** push/PR autorizado (triggers: push/PR a `main`/`master`) |

### npm audit (resumen, sin upgrades)

| Paquete | Severidad | Tipo | Fix sugerido por npm |
|---------|-----------|------|----------------------|
| `proxy-addr` | critical | transitiva (express) | `npm audit fix` |
| `@fastify/busboy` | high | transitiva | `npm audit fix` |
| `@grpc/grpc-js` | high | transitiva | `npm audit fix` |
| `qs` (+ body-parser/express) | moderate | transitiva | `npm audit fix` |
| `uuid` (+ gaxios/google-gax/firebase-adminâ€¦) | moderate | transitiva vÃ­a `firebase-admin` | `audit fix --force` â†’ breaking (`firebase-admin@14`) |

**DecisiÃ³n Fase 1:** no aplicar fixes automÃ¡ticos; diferir a fase de dependencias.

### PDF / Unicode (solo documentaciÃ³n)

- Generadores usan tipografÃ­a **por defecto** del paquete `pdf` â†’ Helvetica (sin Unicode).
- Archivos: `classic_pdf_generator.dart`, `modern_pdf_generator.dart`, `executive_pdf_generator.dart`, `creative_pdf_generator.dart`, `pdf_widgets.dart`.
- No hay `PdfGoogleFonts` / Noto / OpenSans embebidas.
- Tests pasan pero emiten warning Helvetica Unicode.
- **PENDIENTE PARA FASE PDF/TEMPLATES.**

### Riesgos pendientes

- WIP aÃºn **sin commit** (solo en working tree de la rama local).
- CI remoto aÃºn no re-ejecutado (falta push/PR).
- Vulnerabilidades npm Functions.
- Stripe billing no exportado / no desplegado.
- Unicode PDF.
- DecisiÃ³n Super Admin vs hub externo.
- `.cursor/` no debe entrar en commits.

### PrÃ³xima fase recomendada

**Fase 2 â€” Super Admin:** cerrar/validar WIP del panel + `adminConsole` (tests, docs, decisiÃ³n hub), sin deploy producciÃ³n.
Antes o en paralelo: autorizaciÃ³n de **commit + push + PR** de esta rama para confirmar CI verde en GitHub.
