# Arquitectura Fase 2

## Estructura

```text
lib/
├── core/
│   ├── errors/
│   ├── routing/          # go_router
│   ├── theme/
│   ├── utils/            # JsonListCodec
│   └── widgets/          # AsyncBody
├── features/
│   ├── auth/
│   ├── account/
│   └── resumes/          # repository, fotos, PDF image helper
├── saas/                 # auth/entitlements (Fase 1)
├── screens/              # UI (migración gradual hacia features/*/presentation)
├── models/
└── main.dart
```

## Datos

- `Resume.schemaVersion = 2`
- Lectura dual: JSON-string legacy **o** listas/mapas nativos
- Escritura nativa (`toFirestoreMap`)
- Campos foto: `fotoUrl`, `fotoStoragePath` (+ `fotoPath` legacy)
- Paginación: `ResumeRepository.listPage`
- Timestamps: `updatedAt` ISO + `updatedAtServer` (SDK)

## Fotos

1. Selección (`image_picker`)
2. Recorte cuadrado opcional + compresión (`image`)
3. Subida a Storage (SDK o REST en Windows)
4. Guardado de URL en Firestore
5. Compatibilidad temporal con data-URI / rutas locales
6. Borrado de objeto Storage al eliminar CV

## Navegación

`go_router` con redirect por sesión y verificación de correo.

## Código eliminado

- `db_service_io.dart`, `db_service_web.dart`
- Dependencias: `sqflite*`, `shared_preferences`
