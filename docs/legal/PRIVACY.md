# Política de privacidad — CV Maker

**Última actualización:** 31 de julio de 2026  
**Responsable:** operador de CV Maker (`boris13jb@gmail.com`)  
**Producto:** aplicación multiplataforma para crear y exportar currículums (CVs) en PDF.

Este documento describe qué datos tratamos y con qué finalidad. No sustituye asesoría legal externa; revísalo con un profesional antes de publicarlo en tiendas si lo requieres.

## 1. Datos que tratamos

| Categoría | Ejemplos | Finalidad |
|-----------|----------|-----------|
| Cuenta | Correo, nombre para mostrar, UID Firebase | Autenticación y perfil |
| Contenido del CV | Datos de contacto, experiencia, formación, foto | Crear, guardar y exportar el CV |
| Facturación | Estado de plan Free/Pro, IDs Stripe (customer/subscription) vía backend | Activar/cancelar suscripción |
| Técnicos | Logs de error opcionales (Sentry, si está configurado) | Diagnóstico y estabilidad |

## 2. Bases y encargados

- **Firebase (Google):** Authentication, Cloud Firestore, Cloud Storage, Cloud Functions.
- **Stripe:** pagos de suscripción Pro (no almacenamos el número completo de tarjeta en nuestros servidores).
- **Sentry (opcional):** solo si se configura `SENTRY_DSN`; se evita PII por defecto.

## 3. Conservación

- Mientras la cuenta exista, conservamos perfil, entitlements y CVs asociados.
- Al eliminar la cuenta desde la app se borran CVs y perfil de usuario; registros de facturación pueden permanecer accesibles solo al backend según política de Stripe/contabilidad.

## 4. Derechos

Puedes solicitar acceso, rectificación o eliminación contactando `boris13jb@gmail.com`, o usando **Exportar mis datos** / **Eliminar cuenta** en la app.

## 5. Menores

El servicio no está dirigido a menores de 16 años (o la edad digital mínima de tu jurisdicción).

## 6. Cambios

Publicaremos la fecha de actualización en este documento. El uso continuado tras cambios relevantes implica conocimiento de la nueva versión.
