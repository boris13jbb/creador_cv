import 'dart:typed_data';

import '../core/utils/json_list_codec.dart';

/// Modelo de CV con serialización retrocompatible (JSON-string legacy + listas nativas).
class Resume {
  static const int currentSchemaVersion = 3;

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

  /// Secciones profesionales opcionales (vacío = no se muestran en PDF).
  final List<Project> projects;
  final List<Certification> certifications;
  final List<Aptitude> aptitudes;

  final int colorHex;
  final int designIndex;
  final bool ocultarFoto;
  final bool ocultarPerfil;
  final bool ocultarExperiencia;
  final bool ocultarFormacion;
  final bool ocultarCompetencias;
  final bool ocultarIdiomas;
  final bool ocultarProyectos;
  final bool ocultarCertificaciones;
  final bool ocultarAptitudes;
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
    this.projects = const [],
    this.certifications = const [],
    this.aptitudes = const [],
    this.colorHex = 0xFF607D8B,
    this.designIndex = 0,
    this.ocultarFoto = false,
    this.ocultarPerfil = false,
    this.ocultarExperiencia = false,
    this.ocultarFormacion = false,
    this.ocultarCompetencias = false,
    this.ocultarIdiomas = false,
    this.ocultarProyectos = false,
    this.ocultarCertificaciones = false,
    this.ocultarAptitudes = false,
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
    List<Project>? projects,
    List<Certification>? certifications,
    List<Aptitude>? aptitudes,
    int? colorHex,
    int? designIndex,
    bool? ocultarFoto,
    bool? ocultarPerfil,
    bool? ocultarExperiencia,
    bool? ocultarFormacion,
    bool? ocultarCompetencias,
    bool? ocultarIdiomas,
    bool? ocultarProyectos,
    bool? ocultarCertificaciones,
    bool? ocultarAptitudes,
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
      projects: projects ?? this.projects,
      certifications: certifications ?? this.certifications,
      aptitudes: aptitudes ?? this.aptitudes,
      colorHex: colorHex ?? this.colorHex,
      designIndex: designIndex ?? this.designIndex,
      ocultarFoto: ocultarFoto ?? this.ocultarFoto,
      ocultarPerfil: ocultarPerfil ?? this.ocultarPerfil,
      ocultarExperiencia: ocultarExperiencia ?? this.ocultarExperiencia,
      ocultarFormacion: ocultarFormacion ?? this.ocultarFormacion,
      ocultarCompetencias: ocultarCompetencias ?? this.ocultarCompetencias,
      ocultarIdiomas: ocultarIdiomas ?? this.ocultarIdiomas,
      ocultarProyectos: ocultarProyectos ?? this.ocultarProyectos,
      ocultarCertificaciones:
          ocultarCertificaciones ?? this.ocultarCertificaciones,
      ocultarAptitudes: ocultarAptitudes ?? this.ocultarAptitudes,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Mapa para Firestore schema v3 (listas nativas, sin Base64 gigante obligatorio).
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
      'projects': projects.map((p) => p.toMap()).toList(),
      'certifications': certifications.map((c) => c.toMap()).toList(),
      'aptitudes': aptitudes.map((a) => a.toMap()).toList(),
      'colorHex': colorHex,
      'designIndex': designIndex,
      'ocultarFoto': ocultarFoto,
      'ocultarPerfil': ocultarPerfil,
      'ocultarExperiencia': ocultarExperiencia,
      'ocultarFormacion': ocultarFormacion,
      'ocultarCompetencias': ocultarCompetencias,
      'ocultarIdiomas': ocultarIdiomas,
      'ocultarProyectos': ocultarProyectos,
      'ocultarCertificaciones': ocultarCertificaciones,
      'ocultarAptitudes': ocultarAptitudes,
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
    // CV antiguos sin estas claves → [].
    final projects = JsonListCodec.decodeObjectList(
      m['projects'],
    ).map(Project.fromMap).toList();
    final certifications = JsonListCodec.decodeObjectList(
      m['certifications'],
    ).map(Certification.fromMap).toList();
    final aptitudes = JsonListCodec.decodeObjectList(
      m['aptitudes'],
    ).map(Aptitude.fromMap).toList();

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
      projects: projects,
      certifications: certifications,
      aptitudes: aptitudes,
      colorHex: (m['colorHex'] as num?)?.toInt() ?? 0xFF607D8B,
      designIndex: (m['designIndex'] as num?)?.toInt() ?? 0,
      ocultarFoto: _asBool(m['ocultarFoto']),
      ocultarPerfil: _asBool(m['ocultarPerfil']),
      ocultarExperiencia: _asBool(m['ocultarExperiencia']),
      ocultarFormacion: _asBool(m['ocultarFormacion']),
      ocultarCompetencias: _asBool(m['ocultarCompetencias']),
      ocultarIdiomas: _asBool(m['ocultarIdiomas']),
      ocultarProyectos: _asBool(m['ocultarProyectos']),
      ocultarCertificaciones: _asBool(m['ocultarCertificaciones']),
      ocultarAptitudes: _asBool(m['ocultarAptitudes']),
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

/// Proyecto profesional (opcional en el CV).
class Project {
  final String id;
  final String name;
  final String description;
  final List<String> technologies;
  final String? url;
  final String? repositoryUrl;
  final String? startDate;
  final String? endDate;
  final bool isOngoing;

  const Project({
    required this.id,
    required this.name,
    this.description = '',
    this.technologies = const [],
    this.url,
    this.repositoryUrl,
    this.startDate,
    this.endDate,
    this.isOngoing = false,
  });

  Project copyWith({
    String? id,
    String? name,
    String? description,
    List<String>? technologies,
    String? url,
    String? repositoryUrl,
    String? startDate,
    String? endDate,
    bool? isOngoing,
    bool clearUrl = false,
    bool clearRepositoryUrl = false,
    bool clearStartDate = false,
    bool clearEndDate = false,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      technologies: technologies ?? this.technologies,
      url: clearUrl ? null : (url ?? this.url),
      repositoryUrl: clearRepositoryUrl
          ? null
          : (repositoryUrl ?? this.repositoryUrl),
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      isOngoing: isOngoing ?? this.isOngoing,
    );
  }

  /// Periodo legible para UI/PDF (p. ej. "2024 – Actualidad").
  String get periodLabel {
    final start = startDate?.trim() ?? '';
    if (isOngoing) {
      if (start.isEmpty) return 'Actualidad';
      return '$start – Actualidad';
    }
    final end = endDate?.trim() ?? '';
    if (start.isEmpty && end.isEmpty) return '';
    if (start.isEmpty) return end;
    if (end.isEmpty) return start;
    return '$start – $end';
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'description': description,
    'technologies': technologies,
    'url': url,
    'repositoryUrl': repositoryUrl,
    'startDate': startDate,
    'endDate': endDate,
    'isOngoing': isOngoing,
  };

  /// Alias JSON para tests / interoperabilidad.
  Map<String, dynamic> toJson() => toMap();

  static Project fromMap(Map<String, dynamic> m) {
    final techsRaw = m['technologies'];
    final techs = techsRaw is List
        ? techsRaw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
        : <String>[];
    return Project(
      id: m['id'] as String? ?? '',
      name: m['name'] as String? ?? '',
      description: m['description'] as String? ?? '',
      technologies: techs,
      url: m['url'] as String?,
      repositoryUrl: m['repositoryUrl'] as String?,
      startDate: m['startDate'] as String?,
      endDate: m['endDate'] as String?,
      isOngoing: Resume._asBool(m['isOngoing']),
    );
  }

  static Project fromJson(Map<String, dynamic> m) => fromMap(m);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Project &&
        other.id == id &&
        other.name == name &&
        other.description == description &&
        _listEq(other.technologies, technologies) &&
        other.url == url &&
        other.repositoryUrl == repositoryUrl &&
        other.startDate == startDate &&
        other.endDate == endDate &&
        other.isOngoing == isOngoing;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    description,
    Object.hashAll(technologies),
    url,
    repositoryUrl,
    startDate,
    endDate,
    isOngoing,
  );
}

/// Certificación, curso, diplomado o formación complementaria.
class Certification {
  final String id;
  final String name;
  final String institution;
  final String? date;
  final String? expirationDate;
  final String? credentialId;
  final String? credentialUrl;
  final String? description;

  const Certification({
    required this.id,
    required this.name,
    this.institution = '',
    this.date,
    this.expirationDate,
    this.credentialId,
    this.credentialUrl,
    this.description,
  });

  Certification copyWith({
    String? id,
    String? name,
    String? institution,
    String? date,
    String? expirationDate,
    String? credentialId,
    String? credentialUrl,
    String? description,
    bool clearDate = false,
    bool clearExpirationDate = false,
    bool clearCredentialId = false,
    bool clearCredentialUrl = false,
    bool clearDescription = false,
  }) {
    return Certification(
      id: id ?? this.id,
      name: name ?? this.name,
      institution: institution ?? this.institution,
      date: clearDate ? null : (date ?? this.date),
      expirationDate: clearExpirationDate
          ? null
          : (expirationDate ?? this.expirationDate),
      credentialId: clearCredentialId
          ? null
          : (credentialId ?? this.credentialId),
      credentialUrl: clearCredentialUrl
          ? null
          : (credentialUrl ?? this.credentialUrl),
      description: clearDescription ? null : (description ?? this.description),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'institution': institution,
    'date': date,
    'expirationDate': expirationDate,
    'credentialId': credentialId,
    'credentialUrl': credentialUrl,
    'description': description,
  };

  Map<String, dynamic> toJson() => toMap();

  static Certification fromMap(Map<String, dynamic> m) => Certification(
    id: m['id'] as String? ?? '',
    name: m['name'] as String? ?? '',
    institution: m['institution'] as String? ?? '',
    date: m['date'] as String?,
    expirationDate: m['expirationDate'] as String?,
    credentialId: m['credentialId'] as String?,
    credentialUrl: m['credentialUrl'] as String?,
    description: m['description'] as String?,
  );

  static Certification fromJson(Map<String, dynamic> m) => fromMap(m);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Certification &&
        other.id == id &&
        other.name == name &&
        other.institution == institution &&
        other.date == date &&
        other.expirationDate == expirationDate &&
        other.credentialId == credentialId &&
        other.credentialUrl == credentialUrl &&
        other.description == description;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    institution,
    date,
    expirationDate,
    credentialId,
    credentialUrl,
    description,
  );
}

/// Aptitud / soft skill (nivel opcional).
class Aptitude {
  final String id;
  final String name;
  final int? level;
  final String? description;

  const Aptitude({
    required this.id,
    required this.name,
    this.level,
    this.description,
  });

  Aptitude copyWith({
    String? id,
    String? name,
    int? level,
    String? description,
    bool clearLevel = false,
    bool clearDescription = false,
  }) {
    return Aptitude(
      id: id ?? this.id,
      name: name ?? this.name,
      level: clearLevel ? null : (level ?? this.level),
      description: clearDescription ? null : (description ?? this.description),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'level': level,
    'description': description,
  };

  Map<String, dynamic> toJson() => toMap();

  static Aptitude fromMap(Map<String, dynamic> m) => Aptitude(
    id: m['id'] as String? ?? '',
    name: m['name'] as String? ?? '',
    level: (m['level'] as num?)?.toInt(),
    description: m['description'] as String?,
  );

  static Aptitude fromJson(Map<String, dynamic> m) => fromMap(m);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Aptitude &&
        other.id == id &&
        other.name == name &&
        other.level == level &&
        other.description == description;
  }

  @override
  int get hashCode => Object.hash(id, name, level, description);
}

bool _listEq(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
