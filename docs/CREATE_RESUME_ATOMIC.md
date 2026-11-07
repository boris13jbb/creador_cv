# Creación atómica de CV (`createResume`)

## Problema

Con create directo en Firestore, un usuario Free con 2 CV podía lanzar dos
`setDoc` concurrentes, ambos pasando Rules con `resumeCount = 2`, y terminar
con 4 CV.

## Solución

1. Cloud Function HTTP `createResume` (Admin SDK) ejecuta una **transacción**:
   - Lee entitlement, usage, lista de resumes (límite Free) e idempotencia.
   - Si Free y ya hay ≥ 3 CV → `resource-exhausted`.
   - Crea el documento y actualiza `usage/{uid}` en la misma TX.
2. Firestore Rules: **solo Pro** puede `create` directo. Free queda denegado.
3. Flutter (`CloudResumeRepository`): create Free → `CreateResumeService`.

## Idempotencia

- Clave por defecto: `resume:{resumeId}`.
- Colección `resumeCreateIdempotency/*` (solo Admin SDK).
- Reintento de red con el mismo id/clave no duplica el CV.

## Contador

- Autoridad en create: query transaccional + escritura de `usage`.
- `refreshResumeUsage` / triggers: reconciliación con query en TX (no
  `count()` + `set` suelto para colecciones pequeñas).
- El límite Free **no** depende de un `usage` stale: la Function cuenta docs.

## Transición / versiones antiguas

Orden seguro (sin ejecutar aquí):

1. Desplegar Functions (`createResume`, `syncResumeUsage`, triggers).
2. Publicar app Flutter que use `createResume` para Free.
3. Desplegar Rules que deniegan create Free directo.

Si se despliegan Rules antes que la app nueva, usuarios Free con app antigua
recibirán `permission-denied` al crear. Mitigación: forzar actualización o
mantener Rules permisivas solo hasta alcanzar masa de versión nueva
(no recomendado: reabre la carrera). Preferir app primero o release coordinado.

## Pruebas

```bash
firebase emulators:exec --only firestore "npm --prefix functions run test:concurrency"
firebase emulators:exec --only firestore "npm --prefix firestore/tests test"
```
