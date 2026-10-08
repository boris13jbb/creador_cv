import '../../../../core/utils/url_validators.dart';
import '../../../../models/resume.dart';

/// Línea de texto. No es un chip, una tarjeta ni una insignia.
class OnePageTextItem {
  const OnePageTextItem({required this.primary, this.secondary});

  final String primary;
  final String? secondary;
}

/// Experiencia, proyecto, estudio o certificación listos para maquetar.
class OnePageEntry {
  const OnePageEntry({
    required this.title,
    this.trailing,
    this.subtitle,
    this.paragraphs = const [],
    this.bullets = const [],
    this.dateAbove = false,
  });

  final String title;
  final String? trailing;
  final String? subtitle;
  final List<String> paragraphs;
  final List<String> bullets;

  /// La fecha va encima del título, como en certificaciones compactas.
  final bool dateAbove;
}

/// Cómo se pintan competencias, aptitudes e idiomas.
enum OnePagePresentation { text }

/// Reparto fijo de la plantilla. No altera el modelo [Resume].
class OnePagePlan {
  const OnePagePlan({
    required this.name,
    required this.profession,
    required this.showPhoto,
    required this.contactLines,
    required this.summary,
    required this.aptitudes,
    required this.skills,
    required this.projects,
    required this.experience,
    required this.education,
    required this.certifications,
    required this.languages,
  });

  final String name;
  final String? profession;
  final bool showPhoto;
  final List<String> contactLines;
  final String? summary;
  final List<OnePageTextItem> aptitudes;
  final List<OnePageTextItem> skills;
  final List<OnePageEntry> projects;
  final List<OnePageEntry> experience;
  final List<OnePageEntry> education;
  final List<OnePageEntry> certifications;
  final List<OnePageTextItem> languages;

  static const summaryTitle = 'Resumen profesional';
  static const aptitudesTitle = 'Aptitudes';
  static const skillsTitle = 'Habilidades';
  static const projectsTitle = 'Proyectos';
  static const experienceTitle = 'Experiencia laboral';
  static const educationTitle = 'Educación';
  static const certificationsTitle = 'Certificaciones y cursos';
  static const languagesTitle = 'Idiomas';

  static const skillPresentation = OnePagePresentation.text;
  static const aptitudePresentation = OnePagePresentation.text;
  static const languagePresentation = OnePagePresentation.text;

  List<String> get sidebarTitles => [
    if (summary != null) summaryTitle,
    if (aptitudes.isNotEmpty) aptitudesTitle,
    if (skills.isNotEmpty) skillsTitle,
  ];

  List<String> get mainTitles => [
    if (projects.isNotEmpty) projectsTitle,
    if (experience.isNotEmpty) experienceTitle,
    if (education.isNotEmpty) educationTitle,
    if (certifications.isNotEmpty) certificationsTitle,
    if (languages.isNotEmpty) languagesTitle,
  ];

  /// Cada sección visible lleva contenido junto al título.
  bool get titlesHaveLead =>
      (summary == null || summary!.trim().isNotEmpty) &&
      aptitudes.every((item) => item.primary.trim().isNotEmpty) &&
      skills.every((item) => item.primary.trim().isNotEmpty) &&
      projects.every((entry) => entry.title.trim().isNotEmpty) &&
      experience.every((entry) => entry.title.trim().isNotEmpty) &&
      education.every((entry) => entry.title.trim().isNotEmpty) &&
      certifications.every((entry) => entry.title.trim().isNotEmpty) &&
      languages.every((item) => item.primary.trim().isNotEmpty);

  factory OnePagePlan.fromResume(Resume resume, {required bool hasPhotoImage}) {
    final profession = _professionOf(resume);
    return OnePagePlan(
      name: resume.nombre.trim(),
      profession: profession,
      showPhoto: hasPhotoImage && !resume.ocultarFoto,
      contactLines: _contactLines(resume, profession: profession),
      summary: (!resume.ocultarPerfil && resume.perfil.trim().isNotEmpty)
          ? resume.perfil.trim()
          : null,
      aptitudes: resume.ocultarAptitudes
          ? const []
          : [
              for (final aptitude in resume.aptitudes)
                if (aptitude.name.trim().isNotEmpty) _aptitude(aptitude),
            ],
      skills: resume.ocultarCompetencias
          ? const []
          : [
              for (final skill in resume.competencias)
                if (skill.nombre.trim().isNotEmpty)
                  _splitCategory(skill.nombre),
            ],
      projects: resume.ocultarProyectos
          ? const []
          : [
              for (final project in resume.projects)
                if (project.name.trim().isNotEmpty) _project(project),
            ],
      experience: resume.ocultarExperiencia
          ? const []
          : [
              for (final job in resume.experiencia)
                if (job.cargo.trim().isNotEmpty ||
                    job.empresa.trim().isNotEmpty)
                  _experience(job),
            ],
      education: resume.ocultarFormacion
          ? const []
          : [
              for (final study in resume.formacion)
                if (study.titulo.trim().isNotEmpty ||
                    study.institucion.trim().isNotEmpty)
                  _education(study),
            ],
      certifications: resume.ocultarCertificaciones
          ? const []
          : [
              for (final course in resume.certifications)
                if (course.name.trim().isNotEmpty) _certification(course),
            ],
      languages: resume.ocultarIdiomas
          ? const []
          : [
              for (final language in resume.idiomas)
                if (language.nombre.trim().isNotEmpty) _language(language),
            ],
    );
  }
}

const _levelLabels = <int, String>{
  1: 'Principiante',
  2: 'Básico',
  3: 'Intermedio',
  4: 'Avanzado',
  5: 'Experto',
};

const _professionLabels = {
  'profesion',
  'cargo',
  'puesto',
  'titulo',
  'titulo profesional',
  'ocupacion',
  'oficio',
  'rol',
  'headline',
};

const _nameLabels = {'nombre', 'name', 'nombre completo'};

const _bareContactLabels = {
  'email',
  'correo',
  'correo electronico',
  'telefono',
  'phone',
  'celular',
  'movil',
  'whatsapp',
  'direccion',
  'ubicacion',
  'ciudad',
  'pais',
  'linkedin',
  'web',
  'sitio',
  'sitio web',
  'github',
  'portfolio',
};

String? _professionOf(Resume resume) {
  for (final data in resume.datosPersonales) {
    final value = data.value.trim();
    if (value.isEmpty) continue;
    if (_professionLabels.contains(_fold(data.label))) return value;
  }
  return null;
}

List<String> _contactLines(Resume resume, {required String? profession}) {
  final lines = <String>[];
  for (final data in resume.datosPersonales) {
    final value = data.value.trim();
    if (value.isEmpty) continue;
    final label = _fold(data.label);
    if (_professionLabels.contains(label) && value == profession) continue;
    if (_nameLabels.contains(label) && _fold(value) == _fold(resume.nombre)) {
      continue;
    }
    if (_bareContactLabels.contains(label) || label.isEmpty) {
      lines.add(value);
    } else {
      final rawLabel = data.label.trim();
      lines.add(rawLabel.isEmpty ? value : '$rawLabel: $value');
    }
  }
  return lines;
}

OnePageTextItem _aptitude(Aptitude aptitude) {
  final description = aptitude.description?.trim() ?? '';
  final level = aptitude.level;
  final extra = <String>[
    if (description.isNotEmpty) description,
    if (level != null) 'Nivel $level',
  ];
  return OnePageTextItem(
    primary: aptitude.name.trim(),
    secondary: extra.isEmpty ? null : extra.join(' · '),
  );
}

OnePageTextItem _splitCategory(String raw) {
  final trimmed = raw.trim();
  final split = trimmed.indexOf(':');
  final hasCategory = split > 0 && split < 72;
  if (!hasCategory) return OnePageTextItem(primary: trimmed);
  final detail = trimmed.substring(split + 1).trim();
  return OnePageTextItem(
    primary: trimmed.substring(0, split).trim(),
    secondary: detail.isEmpty ? null : detail,
  );
}

OnePageTextItem _language(Skill skill) {
  final label = _levelLabels[skill.nivel.clamp(0, 5)];
  return OnePageTextItem(
    primary: skill.nombre.trim(),
    secondary: (label == null || label.isEmpty) ? null : label,
  );
}

OnePageEntry _experience(Experience experience) {
  final cargo = experience.cargo.trim();
  final empresa = experience.empresa.trim();
  return OnePageEntry(
    title: cargo.isEmpty ? empresa : cargo,
    trailing: experience.periodo.trim().isEmpty
        ? null
        : experience.periodo.trim(),
    subtitle: cargo.isEmpty || empresa.isEmpty ? null : empresa,
    bullets: [
      for (final logro in experience.logros)
        if (logro.trim().isNotEmpty) logro.trim(),
    ],
  );
}

OnePageEntry _education(Education education) {
  final titulo = education.titulo.trim();
  final institucion = education.institucion.trim();
  return OnePageEntry(
    title: titulo.isEmpty ? institucion : titulo,
    trailing: education.anio.trim().isEmpty ? null : education.anio.trim(),
    subtitle: titulo.isEmpty || institucion.isEmpty ? null : institucion,
  );
}

OnePageEntry _project(Project project) {
  final techs = [
    for (final tech in project.technologies)
      if (tech.trim().isNotEmpty) tech.trim(),
  ];
  final paragraphs = <String>[
    if (project.description.trim().isNotEmpty) project.description.trim(),
    if (techs.isNotEmpty) techs.join(' · '),
    if ((project.url ?? '').trim().isNotEmpty)
      shortenUrlForDisplay(project.url!.trim()),
    if ((project.repositoryUrl ?? '').trim().isNotEmpty)
      shortenUrlForDisplay(project.repositoryUrl!.trim()),
  ];
  final period = project.periodLabel.trim();
  return OnePageEntry(
    title: project.name.trim(),
    trailing: period.isEmpty ? null : period,
    paragraphs: paragraphs,
  );
}

OnePageEntry _certification(Certification certification) {
  final paragraphs = <String>[
    if ((certification.description ?? '').trim().isNotEmpty)
      certification.description!.trim(),
    if ((certification.expirationDate ?? '').trim().isNotEmpty)
      'Vence: ${certification.expirationDate!.trim()}',
    if ((certification.credentialId ?? '').trim().isNotEmpty)
      'Credencial: ${certification.credentialId!.trim()}',
    if ((certification.credentialUrl ?? '').trim().isNotEmpty)
      shortenUrlForDisplay(certification.credentialUrl!.trim()),
  ];
  final date = (certification.date ?? '').trim();
  final institution = certification.institution.trim();
  return OnePageEntry(
    title: certification.name.trim(),
    trailing: date.isEmpty ? null : date,
    subtitle: institution.isEmpty ? null : institution,
    paragraphs: paragraphs,
    dateAbove: date.isNotEmpty,
  );
}

String _fold(String input) {
  const accents = {
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    'ñ': 'n',
    'à': 'a',
    'è': 'e',
    'ì': 'i',
    'ò': 'o',
    'ù': 'u',
  };
  final buffer = StringBuffer();
  for (final rune in input.toLowerCase().runes) {
    final ch = String.fromCharCode(rune);
    final mapped = accents[ch];
    if (mapped != null) {
      buffer.write(mapped);
      continue;
    }
    if (RegExp(r'[a-z0-9 ]').hasMatch(ch)) buffer.write(ch);
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Parte un párrafo largo sin descartar texto.
///
/// El inicio viaja con el título. El resto sigue en el mismo bloque visual.
({String lead, String rest}) splitOnePageLead(String text) {
  final trimmed = text.trim();
  if (trimmed.length <= 280) return (lead: trimmed, rest: '');
  final window = trimmed.substring(80);
  final match = RegExp(r'[.!?]\s').firstMatch(window);
  final cut = match == null ? 220 : 80 + match.end;
  final safeCut = cut.clamp(40, trimmed.length);
  return (
    lead: trimmed.substring(0, safeCut).trim(),
    rest: trimmed.substring(safeCut).trim(),
  );
}
