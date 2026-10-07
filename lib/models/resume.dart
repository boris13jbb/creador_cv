import 'dart:typed_data';

import '../core/utils/json_list_codec.dart';

/// Modelo de CV con serialización retrocompatible (JSON-string legacy + listas nativas).
class Resume {
  static const int currentSchemaVersion = 2;

  final String id;
  final String nombre;

  /// Ruta local o data-URI legacy. Preferir [fotoUrl] para sync multi-dispositivo.
  final String? fotoPath;

  /// URL pública/descargable en Firebase Storage.
  final String? fotoUrl;

  /// Ruta del objeto en Storage (para borrado de huérfanos).
  final String? fotoStoragePath;

  /// Bytes locales en memoria (no se serializan). Usados para preview/PDF
  /// antes de subir a Storage o cuando la red falla.
  final Uint8List? fotoBytes;
  final String perfil;
  final List<PersonalData> datosPersonales;
  final List<Skill> competencias;
  final List<Skill> idiomas;
  final List<Experience> experiencia;
  final List<Education> formacion;
  final int colorHex;
  final int designIndex;
  final bool ocultarFoto;
  final bool ocultarPerfil;
  final bool ocultarExperiencia;
  final bool ocultarFormacion;
  final bool ocultarCompetencias;
  final bool ocultarIdiomas;
  final int schemaVersion;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Resume({
    required this.id,
    required this.nombre,
    this.fotoPath,
    this.fotoUrl,
    this.fotoStoragePath,
    this.fotoBytes,
    required this.perfil,
    required this.datosPersonales,
    required this.competencias,
    required this.idiomas,
    required this.experiencia,
    required this.formacion,
    this.colorHex = 0xFF607D8B,
    this.designIndex = 0,
    this.ocultarFoto = false,
    this.ocultarPerfil = false,
    this.ocultarExperiencia = false,
    this.ocultarFormacion = false,
    this.ocultarCompetencias = false,
    this.ocultarIdiomas = false,
    this.schemaVersion = currentSchemaVersion,
    this.createdAt,
    this.updatedAt,
  });

  /// Mejor fuente de foto para UI/PDF (remota > legacy).
  String? get effectivePhotoRef {
    if (fotoUrl != null && fotoUrl!.isNotEmpty) return fotoUrl;
    if (fotoPath != null && fotoPath!.isNotEmpty) return fotoPath;
    return null;
  }

  bool get hasRemotePhoto => fotoUrl != null && fotoUrl!.isNotEmpty;

  bool get hasPhotoBytes => fotoBytes != null && fotoBytes!.isNotEmpty;

  Resume copyWith({
    String? id,
    String? nombre,
    String? fotoPath,
    String? fotoUrl,
    String? fotoStoragePath,
    Uint8List? fotoBytes,
    String? perfil,
    List<PersonalData>? datosPersonales,
    List<Skill>? competencias,
    List<Skill>? idiomas,
    List<Experience>? experiencia,
    List<Education>? formacion,
    int? colorHex,
    int? designIndex,
    bool? ocultarFoto,
    bool? ocultarPerfil,
    bool? ocultarExperiencia,
    bool? ocultarFormacion,
    bool? ocultarCompetencias,
    bool? ocultarIdiomas,
    int? schemaVersion,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearFotoPath = false,
    bool clearFotoUrl = false,
    bool clearFotoStoragePath = false,
    bool clearFotoBytes = false,
  }) {
    return Resume(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      fotoPath: clearFotoPath ? null : (fotoPath ?? this.fotoPath),
      fotoUrl: clearFotoUrl ? null : (fotoUrl ?? this.fotoUrl),
      fotoStoragePath: clearFotoStoragePath
          ? null
          : (fotoStoragePath ?? this.fotoStoragePath),
      fotoBytes: clearFotoBytes ? null : (fotoBytes ?? this.fotoBytes),
      perfil: perfil ?? this.perfil,
      datosPersonales: datosPersonales ?? this.datosPersonales,
      competencias: competencias ?? this.competencias,
      idiomas: idiomas ?? this.idiomas,
      experiencia: experiencia ?? this.experiencia,
      formacion: formacion ?? this.formacion,
      colorHex: colorHex ?? this.colorHex,
      designIndex: designIndex ?? this.designIndex,
      ocultarFoto: ocultarFoto ?? this.ocultarFoto,
      ocultarPerfil: ocultarPerfil ?? this.ocultarPerfil,
      ocultarExperiencia: ocultarExperiencia ?? this.ocultarExperiencia,
      ocultarFormacion: ocultarFormacion ?? this.ocultarFormacion,
      ocultarCompetencias: ocultarCompetencias ?? this.ocultarCompetencias,
      ocultarIdiomas: ocultarIdiomas ?? this.ocultarIdiomas,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Mapa para Firestore schema v2 (listas nativas, sin Base64 gigante obligatorio).
  Map<String, dynamic> toFirestoreMap({required String userId}) {
    final now = DateTime.now().toIso8601String();
    return {
      'id': id,
      'nombre': nombre,
      'fotoPath': _legacyFotoPathForWrite(),
      'fotoUrl': fotoUrl,
      'fotoStoragePath': fotoStoragePath,
      'perfil': perfil,
      'datosPersonales': datosPersonales.map((d) => d.toMap()).toList(),
      'competencias': competencias.map((s) => s.toMap()).toList(),
      'idiomas': idiomas.map((s) => s.toMap()).toList(),
      'experiencia': experiencia.map((e) => e.toMap()).toList(),
      'formacion': formacion.map((f) => f.toMap()).toList(),
      'colorHex': colorHex,
      'designIndex': designIndex,
      'ocultarFoto': ocultarFoto,
      'ocultarPerfil': ocultarPerfil,
      'ocultarExperiencia': ocultarExperiencia,
      'ocultarFormacion': ocultarFormacion,
      'ocultarCompetencias': ocultarCompetencias,
      'ocultarIdiomas': ocultarIdiomas,
      'schemaVersion': currentSchemaVersion,
      'userId': userId,
      'createdAt': createdAt?.toIso8601String() ?? now,
      'updatedAt': now,
    };
  }

  /// Compat: no reescribe Base64 enorme si ya hay foto remota.
  String? _legacyFotoPathForWrite() {
    if (hasRemotePhoto) return null;
    if (fotoPath == null) return null;
    // Evita documentos >1MiB: no persistir data-URI largos si hay alternativa.
    if (fotoPath!.startsWith('data:') && fotoPath!.length > 200000) {
      return null;
    }
    return fotoPath;
  }

  /// @Deprecated: preferir [toFirestoreMap]. Se mantiene para export JSON.
  Map<String, dynamic> toMap() => toFirestoreMap(userId: '');

  static bool _asBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) return v == '1' || v.toLowerCase() == 'true';
    return false;
  }

  static DateTime? _asDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    // Timestamp Firestore vía map REST raro; ignorar.
    return null;
  }

  static Resume fromMap(Map<String, dynamic> m) {
    final dp = JsonListCodec.decodeObjectList(
      m['datosPersonales'],
    ).map(PersonalData.fromMap).toList();
    final comp = JsonListCodec.decodeObjectList(
      m['competencias'],
    ).map(Skill.fromMap).toList();
    final idi = JsonListCodec.decodeObjectList(
      m['idiomas'],
    ).map(Skill.fromMap).toList();
    final exp = JsonListCodec.decodeObjectList(
      m['experiencia'],
    ).map(Experience.fromMap).toList();
    final form = JsonListCodec.decodeObjectList(
      m['formacion'],
    ).map(Education.fromMap).toList();

    return Resume(
      id: m['id'] as String? ?? '',
      nombre: m['nombre'] as String? ?? '',
      fotoPath: m['fotoPath'] as String?,
      fotoUrl: m['fotoUrl'] as String?,
      fotoStoragePath: m['fotoStoragePath'] as String?,
      perfil: m['perfil'] as String? ?? '',
      datosPersonales: dp,
      competencias: comp,
      idiomas: idi,
      experiencia: exp,
      formacion: form,
      colorHex: (m['colorHex'] as num?)?.toInt() ?? 0xFF607D8B,
      designIndex: (m['designIndex'] as num?)?.toInt() ?? 0,
      ocultarFoto: _asBool(m['ocultarFoto']),
      ocultarPerfil: _asBool(m['ocultarPerfil']),
      ocultarExperiencia: _asBool(m['ocultarExperiencia']),
      ocultarFormacion: _asBool(m['ocultarFormacion']),
      ocultarCompetencias: _asBool(m['ocultarCompetencias']),
      ocultarIdiomas: _asBool(m['ocultarIdiomas']),
      schemaVersion: (m['schemaVersion'] as num?)?.toInt() ?? 1,
      createdAt: _asDate(m['createdAt']),
      updatedAt: _asDate(m['updatedAt']),
    );
  }
}

class PersonalData {
  final String label;
  final String value;
  final String icon;

  const PersonalData({
    required this.label,
    required this.value,
    required this.icon,
  });

  Map<String, dynamic> toMap() => {
    'label': label,
    'value': value,
    'icon': icon,
  };

  static PersonalData fromMap(Map<String, dynamic> m) => PersonalData(
    label: m['label'] as String? ?? '',
    value: m['value'] as String? ?? '',
    icon: m['icon'] as String? ?? 'info',
  );
}

class Skill {
  final String nombre;
  final int nivel;

  const Skill({required this.nombre, required this.nivel});

  Map<String, dynamic> toMap() => {'nombre': nombre, 'nivel': nivel};

  static Skill fromMap(Map<String, dynamic> m) => Skill(
    nombre: m['nombre'] as String? ?? '',
    nivel: (m['nivel'] as num?)?.toInt() ?? 3,
  );
}

class Experience {
  final String cargo;
  final String empresa;
  final String periodo;
  final List<String> logros;

  const Experience({
    required this.cargo,
    required this.empresa,
    required this.periodo,
    required this.logros,
  });

  Map<String, dynamic> toMap() => {
    'cargo': cargo,
    'empresa': empresa,
    'periodo': periodo,
    'logros': logros,
  };

  static Experience fromMap(Map<String, dynamic> m) => Experience(
    cargo: m['cargo'] as String? ?? '',
    empresa: m['empresa'] as String? ?? '',
    periodo: m['periodo'] as String? ?? '',
    logros: (m['logros'] as List?)?.map((e) => e.toString()).toList() ?? [],
  );
}

class Education {
  final String titulo;
  final String institucion;
  final String anio;

  const Education({
    required this.titulo,
    required this.institucion,
    required this.anio,
  });

  Map<String, dynamic> toMap() => {
    'titulo': titulo,
    'institucion': institucion,
    'anio': anio,
  };

  static Education fromMap(Map<String, dynamic> m) => Education(
    titulo: m['titulo'] as String? ?? '',
    institucion: m['institucion'] as String? ?? '',
    anio: m['anio'] as String? ?? '',
  );
}
