import 'dart:convert';

class Resume {
  final String id;
  final String nombre;
  final String? fotoPath;
  final String perfil;
  final List<PersonalData> datosPersonales;
  final List<Skill> competencias;
  final List<Skill> idiomas;
  final List<Experience> experiencia;
  final List<Education> formacion;
  final int colorHex;
  final int designIndex; // 0 para Clásico, 1 para Moderno (el nuevo)
  final bool ocultarFoto;
  final bool ocultarPerfil;
  final bool ocultarExperiencia;
  final bool ocultarFormacion;
  final bool ocultarCompetencias;
  final bool ocultarIdiomas;

  Resume({
    required this.id,
    required this.nombre,
    this.fotoPath,
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
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'nombre': nombre,
        'fotoPath': fotoPath,
        'perfil': perfil,
        'datosPersonales': jsonEncode(datosPersonales.map((d) => d.toMap()).toList()),
        'competencias': jsonEncode(competencias.map((s) => s.toMap()).toList()),
        'idiomas': jsonEncode(idiomas.map((s) => s.toMap()).toList()),
        'experiencia': jsonEncode(experiencia.map((e) => e.toMap()).toList()),
        'formacion': jsonEncode(formacion.map((f) => f.toMap()).toList()),
        'colorHex': colorHex,
        'designIndex': designIndex,
        'ocultarFoto': ocultarFoto ? 1 : 0,
        'ocultarPerfil': ocultarPerfil ? 1 : 0,
        'ocultarExperiencia': ocultarExperiencia ? 1 : 0,
        'ocultarFormacion': ocultarFormacion ? 1 : 0,
        'ocultarCompetencias': ocultarCompetencias ? 1 : 0,
        'ocultarIdiomas': ocultarIdiomas ? 1 : 0,
      };

  static Resume fromMap(Map<String, dynamic> m) {
    List<PersonalData> dp = [];
    if (m['datosPersonales'] != null) {
      final list = jsonDecode(m['datosPersonales'] as String) as List;
      dp = list.map((e) => PersonalData.fromMap(e as Map)).toList();
    }
    List<Skill> comp = [];
    if (m['competencias'] != null) {
      final list = jsonDecode(m['competencias'] as String) as List;
      comp = list.map((e) => Skill.fromMap(e as Map)).toList();
    }
    List<Skill> idi = [];
    if (m['idiomas'] != null) {
      final list = jsonDecode(m['idiomas'] as String) as List;
      idi = list.map((e) => Skill.fromMap(e as Map)).toList();
    }
    List<Experience> exp = [];
    if (m['experiencia'] != null) {
      final list = jsonDecode(m['experiencia'] as String) as List;
      exp = list.map((e) => Experience.fromMap(e as Map)).toList();
    }
    List<Education> form = [];
    if (m['formacion'] != null) {
      final list = jsonDecode(m['formacion'] as String) as List;
      form = list.map((e) => Education.fromMap(e as Map)).toList();
    }
    return Resume(
      id: m['id'] as String,
      nombre: m['nombre'] as String,
      fotoPath: m['fotoPath'] as String?,
      perfil: m['perfil'] as String,
      datosPersonales: dp,
      competencias: comp,
      idiomas: idi,
      experiencia: exp,
      formacion: form,
      colorHex: m['colorHex'] as int? ?? 0xFF607D8B,
      designIndex: m['designIndex'] as int? ?? 0,
      ocultarFoto: (m['ocultarFoto'] as int? ?? 0) == 1,
      ocultarPerfil: (m['ocultarPerfil'] as int? ?? 0) == 1,
      ocultarExperiencia: (m['ocultarExperiencia'] as int? ?? 0) == 1,
      ocultarFormacion: (m['ocultarFormacion'] as int? ?? 0) == 1,
      ocultarCompetencias: (m['ocultarCompetencias'] as int? ?? 0) == 1,
      ocultarIdiomas: (m['ocultarIdiomas'] as int? ?? 0) == 1,
    );
  }
}

class PersonalData {
  final String label;
  final String value;
  final String icon;

  PersonalData({required this.label, required this.value, required this.icon});

  Map<String, dynamic> toMap() => {'label': label, 'value': value, 'icon': icon};
  static PersonalData fromMap(Map m) => PersonalData(
        label: m['label'] as String? ?? '',
        value: m['value'] as String? ?? '',
        icon: m['icon'] as String? ?? 'info',
      );
}

class Skill {
  final String nombre;
  final int nivel;

  Skill({required this.nombre, required this.nivel});

  Map<String, dynamic> toMap() => {'nombre': nombre, 'nivel': nivel};
  static Skill fromMap(Map m) => Skill(
        nombre: m['nombre'] as String? ?? '',
        nivel: (m['nivel'] as num?)?.toInt() ?? 3,
      );
}

class Experience {
  final String cargo;
  final String empresa;
  final String periodo;
  final List<String> logros;

  Experience({
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
  static Experience fromMap(Map m) => Experience(
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

  Education({
    required this.titulo,
    required this.institucion,
    required this.anio,
  });

  Map<String, dynamic> toMap() => {
        'titulo': titulo,
        'institucion': institucion,
        'anio': anio,
      };
  static Education fromMap(Map m) => Education(
        titulo: m['titulo'] as String? ?? '',
        institucion: m['institucion'] as String? ?? '',
        anio: m['anio'] as String? ?? '',
      );
}
