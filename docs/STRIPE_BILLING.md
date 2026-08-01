# Stripe Billing — CV Maker (Fase 5)

Backend real: **Checkout Session + Customer Portal + Webhook idempotente** que escribe `entitlements/{uid}` con Admin SDK.

**No se despliegan Functions ni secretos sin tu autorización explícita.**

## Despliegue de Functions (estado)

La entrada `index.ts` **no** exporta Stripe por defecto (evita exigir Secret Manager al desplegar límites Free).

### 1) Límites Free (`syncResumeUsage`, `onResumeUsageChanged`)

Requiere IAM de Eventarc/PubSub/Cloud Run. Si el CLI falla, en Cloud Console (cuenta Owner) aplica:

```text
roles/iam.serviceAccountTokenCreator → service-ACCOUNT@gcp-sa-pubsub.iam.gserviceaccount.com
roles/run.invoker → PROJECT_NUMBER-compute@developer.gserviceaccount.com
roles/eventarc.eventReceiver → PROJECT_NUMBER-compute@developer.gserviceaccount.com
```

O instala Google Cloud SDK y reintenta el deploy.

### 2) Billing Stripe

1. Activa [Secret Manager API](https://console.developers.google.com/apis/api/secretmanager.googleapis.com/overview?project=cvmaker-saas-jb).
2. Crea secretos `STRIPE_SECRET_KEY` y `STRIPE_WEBHOOK_SECRET`.
3. Re-exporta desde `index.ts` los símbolos de `billing.ts` (o apunta `main` a `lib/billing.js` en un codebase aparte).
4. `firebase deploy --only functions:createCheckoutSession,functions:createPortalSession,functions:stripeWebhook`

## Arquitectura

| Pieza | Rol |
|-------|-----|
| `createCheckoutSession` | HTTP POST autenticado → URL Stripe Checkout |
| `createPortalSession` | HTTP POST autenticado → Customer Portal |
| `stripeWebhook` | Eventos firmados → actualiza `entitlements` + `billingCustomers` |
| `billingEvents/{eventId}` | Idempotencia (create-once) |
| Cliente Flutter | `BillingService` + pantalla Planes |

Cliente **nunca** escribe `plan: pro`. Solo el webhook (o Admin) muta privilegios.

## Prerrequisitos Stripe (tú configuras)

1. Cuenta Stripe (modo test primero).
2. Producto + Price recurrente (mensual). Copia el `price_...`.
3. Activar Customer Portal en Dashboard → Settings → Billing → Customer portal.

## Secretos y parámetros (nombres, sin valores en repo)

```text
STRIPE_SECRET_KEY          # sk_test_... / sk_live_...
STRIPE_WEBHOOK_SECRET      # whsec_... (endpoint del webhook)
STRIPE_PRICE_ID            # price_...
CHECKOUT_SUCCESS_URL       # URL de retorno tras pago
CHECKOUT_CANCEL_URL
PORTAL_RETURN_URL
```

### Configurar en Firebase (cuando autorices deploy)

```powershell
cd D:\creador_cv\functions
npm install
npm run build
npm test

# Secretos (te pedirá el valor de forma interactiva)
firebase functions:secrets:set STRIPE_SECRET_KEY --project cvmaker-saas-jb
firebase functions:secrets:set STRIPE_WEBHOOK_SECRET --project cvmaker-saas-jb

# Parámetros (params / .env de Functions v2)
firebase functions:config:set  # legacy — preferir params en deploy:
# O definir al desplegar:
# firebase deploy --only functions --project cvmaker-saas-jb
# y setear params en Google Cloud / firebase functions:params
```

Con Functions v2 `defineString`, puedes usar `.env` local para emulador (ver `functions/.env.example`) y en producción:

```powershell
# Ejemplo de params en consola GCP / firebase.json params — documenta el Price ID:
# STRIPE_PRICE_ID=price_XXXX
# CHECKOUT_SUCCESS_URL=https://tu-dominio/pricing?checkout=success
# CHECKOUT_CANCEL_URL=https://tu-dominio/pricing?checkout=cancel
# PORTAL_RETURN_URL=https://tu-dominio/pricing
```

## Webhook

URL (tras deploy):

```text
https://us-central1-cvmaker-saas-jb.cloudfunctions.net/stripeWebhook
```

Eventos a suscribir:

- `checkout.session.completed`
- `customer.subscription.created`
- `customer.subscription.updated`
- `customer.subscription.deleted`
- `invoice.paid`
- `invoice.payment_failed`

## Deploy (solo con autorización)

```powershell
cd D:\creador_cv
firebase deploy --only functions,firestore:rules --project cvmaker-saas-jb
```

## Cliente Flutter

```powershell
flutter run -d windows `
  --dart-define=BILLING_BACKEND_ENABLED=true `
  --dart-define=BILLING_FUNCTIONS_BASE_URL=https://us-central1-cvmaker-saas-jb.cloudfunctions.net
```

Fallback opcional mientras Functions no estén en producción:

```powershell
--dart-define=STRIPE_PAYMENT_LINK=https://buy.stripe.com/XXXX
```

Tras pagar: en Planes → icono actualizar (o `refreshEntitlement`) para leer el entitlement escrito por el webhook.

## Pruebas locales de lógica

```powershell
cd D:\creador_cv\functions
npm test
```

Cubre mapeo `active/trialing → Pro`, `canceled/past_due → Free`.

## Checklist de activación

1. [ ] Crear Price Pro en Stripe
2. [ ] Set secrets + params
3. [ ] Deploy Functions + rules (autorizado)
4. [ ] Registrar webhook y copiar `whsec_`
5. [ ] Probar Checkout test card `4242...`
6. [ ] Verificar `entitlements/{uid}.plan == pro` y `source == stripe`
7. [ ] Probar cancelación vía Portal → plan Free
