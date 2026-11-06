import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../core/utils/url_validators.dart';
import '../../../models/resume.dart';

pw.Widget pdfBulletDot(PdfColor color, {double size = 6}) => pw.Container(
  width: size,
  height: size,
  decoration: pw.BoxDecoration(color: color, shape: pw.BoxShape.circle),
);

pw.Widget pdfSectionTitle(String title, PdfColor color, {double size = 14}) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        title.toUpperCase(),
        style: pw.TextStyle(
          fontSize: size,
          fontWeight: pw.FontWeight.bold,
          color: color,
          letterSpacing: 1.1,
        ),
      ),
      pw.SizedBox(height: 4),
      pw.Container(height: 2, width: 36, color: color),
      pw.SizedBox(height: 10),
    ],
  );
}

/// Cabecera de experiencia (cargo, fechas, empresa). Siempre indivisible.
pw.Widget pdfExperienceHeader(
  Experience e,
  PdfColor accent,
  PdfColor text, {
  double titleSize = 12,
}) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Text(
              e.cargo,
              style: pw.TextStyle(
                fontSize: titleSize,
                fontWeight: pw.FontWeight.bold,
                color: text,
              ),
            ),
          ),
          pw.Text(
            e.periodo,
            style: pw.TextStyle(
              fontSize: 10,
              color: accent,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 2),
      pw.Text(
        e.empresa,
        style: pw.TextStyle(
          fontSize: 11,
          fontStyle: pw.FontStyle.italic,
          color: accent,
        ),
      ),
    ],
  );
}

pw.Widget pdfExperienceLogro(String logro, PdfColor text) {
  final clean = logro.trim();
  // Un logro breve cabe entero y no debe partirse. Uno más alto que el
  // espacio útil usa span: la fila horizontal no puede continuar de página.
  if (clean.length > 900) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(left: 8, bottom: 2),
      child: pw.Text(
        '• $clean',
        style: pw.TextStyle(fontSize: 10, color: text, height: 1.25),
        overflow: pw.TextOverflow.span,
      ),
    );
  }
  return pw.Padding(
    padding: const pw.EdgeInsets.only(left: 8, bottom: 2),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 4,
          height: 4,
          margin: const pw.EdgeInsets.only(top: 3, right: 6),
          decoration: pw.BoxDecoration(color: text, shape: pw.BoxShape.circle),
        ),
        pw.Expanded(
          child: pw.Text(clean, style: pw.TextStyle(fontSize: 10, color: text)),
        ),
      ],
    ),
  );
}

/// Flujo multipágina de una experiencia: cabecera unida; logros pueden continuar.
List<pw.Widget> pdfExperienceFlow(
  Experience e,
  PdfColor accent,
  PdfColor text, {
  double titleSize = 12,
}) {
  final logros = e.logros.where((l) => l.trim().isNotEmpty).toList();
  return [
    pdfKeepTogether(
      pw.Padding(
        padding: pw.EdgeInsets.only(bottom: logros.isEmpty ? 12 : 6),
        child: pdfExperienceHeader(e, accent, text, titleSize: titleSize),
      ),
    ),
    for (var i = 0; i < logros.length; i++)
      pw.Padding(
        padding: pw.EdgeInsets.only(bottom: i == logros.length - 1 ? 12 : 0),
        child: pdfExperienceLogro(logros[i], text),
      ),
  ];
}

/// Bloque compacto (p. ej. miniaturas). Para MultiPage preferir [pdfExperienceFlow].
///
/// Solo mantiene junta la cabecera; los logros quedan fuera del [Inseparable]
/// para no superar la altura de una página.
pw.Widget pdfExperienceBlock(
  Experience e,
  PdfColor accent,
  PdfColor text, {
  double titleSize = 12,
}) {
  final logros = e.logros.where((l) => l.trim().isNotEmpty).toList();
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 12),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pdfKeepTogether(
          pdfExperienceHeader(e, accent, text, titleSize: titleSize),
        ),
        if (logros.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          for (final logro in logros) pdfExperienceLogro(logro, text),
        ],
      ],
    ),
  );
}

pw.Widget pdfEducationBlock(Education f, PdfColor text) {
  return pdfKeepTogether(
    pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  f.titulo,
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: text,
                  ),
                ),
              ),
              pw.Text(f.anio, style: pw.TextStyle(fontSize: 10, color: text)),
            ],
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            f.institucion,
            style: pw.TextStyle(fontSize: 10, color: text),
          ),
        ],
      ),
    ),
  );
}

/// Línea de competencia sin recuadro. Si el texto trae «categoría: detalle»,
/// la categoría queda en negrita y el detalle en el renglón siguiente.
pw.Widget pdfCompetencyLine(String raw, PdfColor text) {
  final trimmed = raw.trim();
  final split = trimmed.indexOf(':');
  final hasCategory = split > 0 && split < 72;
  final category = hasCategory ? trimmed.substring(0, split).trim() : trimmed;
  final detail = hasCategory ? trimmed.substring(split + 1).trim() : '';

  return pw.Container(
    padding: const pw.EdgeInsets.only(bottom: 8),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          category,
          style: pw.TextStyle(
            fontSize: 10.5,
            fontWeight: pw.FontWeight.bold,
            color: text,
          ),
        ),
        if (detail.isNotEmpty) ...[
          pw.SizedBox(height: 1),
          pw.Text(
            detail,
            style: pw.TextStyle(fontSize: 10, height: 1.25, color: text),
          ),
        ],
      ],
    ),
  );
}

/// Agrupa widgets pequeños para que [pw.MultiPage] no los parta.
///
/// Usa [pw.Inseparable] (`canSpan: false`). No envolver bloques más altos
/// que una página: el motor lanza [PdfException].
pw.Widget pdfKeepTogether(pw.Widget child) => pw.Inseparable(child: child);

/// Mantiene el título junto a las primeras entradas.
///
/// [pw.Column] es SpanningWidget y puede dejar el encabezado solo al final
/// de la página. [pw.Inseparable] evita ese huérfano; el resto de entradas
/// sigue pudiendo fluir a la página siguiente.
List<pw.Widget> pdfSectionWithLead(
  pw.Widget heading,
  List<pw.Widget> entries, {
  int keep = 1,
}) {
  if (entries.isEmpty) return [pdfKeepTogether(heading)];
  final headCount = entries.length < keep ? entries.length : keep;
  return [
    pdfKeepTogether(
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [heading, ...entries.take(headCount)],
      ),
    ),
    ...entries.skip(headCount),
  ];
}

pw.Widget pdfSkillDots(String name, int level, PdfColor color) {
  final safe = level.clamp(0, 5);
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 6),
    child: pw.Row(
      children: [
        pw.Expanded(
          child: pw.Text(name, style: pw.TextStyle(fontSize: 9, color: color)),
        ),
        ...List.generate(5, (i) {
          return pw.Container(
            width: 7,
            height: 7,
            margin: const pw.EdgeInsets.only(left: 3),
            decoration: pw.BoxDecoration(
              shape: pw.BoxShape.circle,
              color: i < safe ? color : PdfColors.grey300,
            ),
          );
        }),
      ],
    ),
  );
}

/// Construye bloques de contenido respetando flags `ocultar*`.
List<pw.Widget> buildResumeContentBlocks({
  required Resume resume,
  required PdfColor accent,
  required PdfColor text,
  required pw.ImageProvider? profileImage,
  bool showPhotoInline = true,
  bool compactHeader = false,
}) {
  final blocks = <pw.Widget>[];

  if (!compactHeader) {
    blocks.add(
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (showPhotoInline && !resume.ocultarFoto && profileImage != null)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 12),
              child: pw.Container(
                width: 72,
                height: 72,
                child: pw.ClipOval(
                  child: pw.Image(profileImage, fit: pw.BoxFit.cover),
                ),
              ),
            ),
          pw.Text(
            resume.nombre.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
              color: accent,
              letterSpacing: 1.2,
            ),
          ),
          if (resume.datosPersonales.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Wrap(
              spacing: 12,
              runSpacing: 4,
              children: resume.datosPersonales
                  .map(
                    (d) => pw.Text(
                      d.value,
                      style: pw.TextStyle(fontSize: 9, color: text),
                    ),
                  )
                  .toList(),
            ),
          ],
          pw.SizedBox(height: 16),
        ],
      ),
    );
  }

  if (!resume.ocultarPerfil && resume.perfil.trim().isNotEmpty) {
    // Título con espacio mínimo; el texto usa span para no romper páginas largas.
    blocks.add(pw.NewPage(freeSpace: 88));
    blocks.add(pdfKeepTogether(pdfSectionTitle('Perfil profesional', accent)));
    blocks.add(
      pw.Text(
        resume.perfil,
        style: pw.TextStyle(fontSize: 10, color: text, lineSpacing: 2),
        textAlign: pw.TextAlign.justify,
        overflow: pw.TextOverflow.span,
      ),
    );
    blocks.add(pw.SizedBox(height: 14));
  }

  if (!resume.ocultarExperiencia && resume.experiencia.isNotEmpty) {
    final entries = <pw.Widget>[
      for (final e in resume.experiencia) ...pdfExperienceFlow(e, accent, text),
    ];
    blocks.addAll(
      pdfSectionWithLead(
        pdfSectionTitle('Experiencia laboral', accent),
        entries,
      ),
    );
    blocks.add(pw.SizedBox(height: 8));
  }

  if (!resume.ocultarFormacion && resume.formacion.isNotEmpty) {
    final entries = [
      for (final f in resume.formacion) pdfEducationBlock(f, text),
    ];
    blocks.addAll(
      pdfSectionWithLead(
        pdfSectionTitle('Formación académica', accent),
        entries,
      ),
    );
    blocks.add(pw.SizedBox(height: 8));
  }

  if (!resume.ocultarCompetencias && resume.competencias.isNotEmpty) {
    blocks.addAll(
      pdfCompetenciesSection(
        title: 'Competencias',
        accent: accent,
        text: text,
        skills: resume.competencias,
      ),
    );
  }

  if (!resume.ocultarIdiomas && resume.idiomas.isNotEmpty) {
    final lines = resume.idiomas
        .map((s) => pdfKeepTogether(pdfSkillDots(s.nombre, s.nivel, accent)))
        .toList();
    blocks.addAll(
      pdfSectionWithLead(pdfSectionTitle('Idiomas', accent), lines),
    );
    blocks.add(pw.SizedBox(height: 12));
  }

  if (!resume.ocultarProyectos && resume.projects.isNotEmpty) {
    blocks.addAll(
      pdfProjectsSection(
        title: 'Proyectos',
        accent: accent,
        text: text,
        projects: resume.projects,
      ),
    );
  }

  if (!resume.ocultarCertificaciones && resume.certifications.isNotEmpty) {
    blocks.addAll(
      pdfCertificationsSection(
        title: 'Certificaciones y cursos',
        accent: accent,
        text: text,
        certifications: resume.certifications,
      ),
    );
  }

  if (!resume.ocultarAptitudes && resume.aptitudes.isNotEmpty) {
    blocks.addAll(
      pdfAptitudesSection(
        title: 'Aptitudes',
        accent: accent,
        text: text,
        aptitudes: resume.aptitudes,
        style: pdfAptitudeStyleFor(resume.designIndex),
      ),
    );
  }

  return blocks;
}

/// Umbral heurístico: un cuerpo más largo no cabe con seguridad a media columna
/// A4 (~10 pt). Esos ítems pasan a ancho completo y texto con span.
const int pdfTwoColumnMaxBodyChars = 1400;

bool pdfLooksTooTallForHalfColumn(String? body) {
  final text = (body ?? '').trim();
  return text.length > pdfTwoColumnMaxBodyChars;
}

pw.Widget _projectHeader(Project p, PdfColor accent, PdfColor text) {
  final period = p.periodLabel;
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        child: pw.Text(
          p.name,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: text,
          ),
        ),
      ),
      if (period.isNotEmpty)
        pw.Text(
          period,
          style: pw.TextStyle(
            fontSize: 10,
            color: accent,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
    ],
  );
}

List<pw.Widget> _projectMeta(Project p, PdfColor accent) {
  final techs = p.technologies.where((t) => t.trim().isNotEmpty).toList();
  final url = p.url?.trim();
  final repo = p.repositoryUrl?.trim();
  return [
    if (techs.isNotEmpty) ...[
      pw.SizedBox(height: 4),
      pw.Text(
        techs.join(' · '),
        style: pw.TextStyle(
          fontSize: 9,
          fontStyle: pw.FontStyle.italic,
          color: accent,
        ),
      ),
    ],
    if (url != null && url.isNotEmpty) ...[
      pw.SizedBox(height: 2),
      pw.Text(
        shortenUrlForDisplay(url),
        style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
      ),
    ],
    if (repo != null && repo.isNotEmpty) ...[
      pw.SizedBox(height: 2),
      pw.Text(
        shortenUrlForDisplay(repo),
        style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
      ),
    ],
  ];
}

/// Tarjeta compacta para filas de dos columnas (cuerpo acotado).
pw.Widget pdfProjectBlock(Project p, PdfColor accent, PdfColor text) {
  final description = p.description.trim();
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 12),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _projectHeader(p, accent, text),
        if (description.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Text(
            description,
            style: pw.TextStyle(fontSize: 10, color: text, lineSpacing: 2),
          ),
        ],
        ..._projectMeta(p, accent),
      ],
    ),
  );
}

/// Flujo a ancho completo: cabecera unida; descripción larga puede continuar.
List<pw.Widget> pdfProjectFlow(Project p, PdfColor accent, PdfColor text) {
  final description = p.description.trim();
  final meta = _projectMeta(p, accent);
  return [
    pdfKeepTogether(
      pw.Padding(
        padding: pw.EdgeInsets.only(bottom: description.isEmpty ? 12 : 4),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [_projectHeader(p, accent, text)],
        ),
      ),
    ),
    if (description.isNotEmpty)
      pw.Text(
        description,
        style: pw.TextStyle(fontSize: 10, color: text, lineSpacing: 2),
        overflow: pw.TextOverflow.span,
      ),
    if (meta.isNotEmpty)
      pdfKeepTogether(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 12),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: meta,
          ),
        ),
      )
    else
      pw.SizedBox(height: 12),
  ];
}

pw.Widget _certificationHeader(
  Certification c,
  PdfColor accent,
  PdfColor text,
) {
  final meta = pdfCertificationMetaLine(
    institution: c.institution,
    description: c.description,
    date: c.date,
  );
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        c.name,
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          color: text,
        ),
      ),
      if (meta != null) ...[
        pw.SizedBox(height: 2),
        pw.Text(
          meta,
          style: pw.TextStyle(
            fontSize: 10,
            fontStyle: pw.FontStyle.italic,
            color: accent,
          ),
        ),
      ],
      if (c.expirationDate != null && c.expirationDate!.trim().isNotEmpty)
        pw.Text(
          'Expira: ${c.expirationDate!.trim()}',
          style: pw.TextStyle(fontSize: 9, color: text),
        ),
      if (c.credentialId != null && c.credentialId!.trim().isNotEmpty)
        pw.Text(
          'Credential ID: ${c.credentialId!.trim()}',
          style: pw.TextStyle(fontSize: 9, color: text),
        ),
      if (c.credentialUrl != null && c.credentialUrl!.trim().isNotEmpty)
        pw.Text(
          shortenUrlForDisplay(c.credentialUrl!),
          style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
    ],
  );
}

String _certificationBody(Certification c) {
  final hours = pdfDurationLabel(c.description);
  return hours == null ? (c.description?.trim() ?? '') : '';
}

pw.Widget pdfCertificationBlock(
  Certification c,
  PdfColor accent,
  PdfColor text,
) {
  final description = _certificationBody(c);
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 10),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _certificationHeader(c, accent, text),
        if (description.isNotEmpty) ...[
          pw.SizedBox(height: 2),
          pw.Text(description, style: pw.TextStyle(fontSize: 9, color: text)),
        ],
      ],
    ),
  );
}

List<pw.Widget> pdfCertificationFlow(
  Certification c,
  PdfColor accent,
  PdfColor text,
) {
  final description = _certificationBody(c);
  return [
    pdfKeepTogether(
      pw.Padding(
        padding: pw.EdgeInsets.only(bottom: description.isEmpty ? 10 : 2),
        child: _certificationHeader(c, accent, text),
      ),
    ),
    if (description.isNotEmpty)
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 10),
        child: pw.Text(
          description,
          style: pw.TextStyle(fontSize: 9, color: text),
          overflow: pw.TextOverflow.span,
        ),
      ),
  ];
}

pw.Widget pdfTwoColumnRow(pw.Widget left, pw.Widget? right, {double gap = 10}) {
  // Row horizontal: canSpan=false; toda la fila salta de página si no cabe.
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 2),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(child: left),
        pw.SizedBox(width: gap),
        pw.Expanded(child: right ?? pw.SizedBox()),
      ],
    ),
  );
}

/// Empareja tarjetas compactas; conserva el orden de lectura.
List<pw.Widget> pdfTwoColumnRows(List<pw.Widget> cards, {double gap = 10}) {
  if (cards.isEmpty) return const [];
  if (cards.length == 1) return [cards.single];
  return [
    for (final pair in pdfTwoColumnPairs(cards.length))
      pdfTwoColumnRow(
        cards[pair.$1],
        pair.$2 == null ? null : cards[pair.$2!],
        gap: gap,
      ),
  ];
}

/// Sección en dos columnas con escape a ancho completo si el cuerpo es excesivo.
///
/// Conserva el orden de los ítems: al encontrar uno demasiado alto, vacía el
/// buffer de pares y emite ese ítem a ancho completo (texto con span).
List<pw.Widget> pdfProjectsSection({
  required String title,
  required PdfColor accent,
  required PdfColor text,
  required List<Project> projects,
  double gap = 10,
}) {
  if (projects.isEmpty) return const [];
  final entries = <pw.Widget>[];
  final pending = <pw.Widget>[];

  void flushPending() {
    entries.addAll(pdfTwoColumnRows(pending, gap: gap));
    pending.clear();
  }

  for (final project in projects) {
    if (pdfLooksTooTallForHalfColumn(project.description)) {
      flushPending();
      entries.addAll(pdfProjectFlow(project, accent, text));
    } else {
      pending.add(pdfProjectBlock(project, accent, text));
    }
  }
  flushPending();

  return [
    ...pdfSectionWithLead(pdfSectionTitle(title, accent), entries),
    pw.SizedBox(height: 8),
  ];
}

List<pw.Widget> pdfCertificationsSection({
  required String title,
  required PdfColor accent,
  required PdfColor text,
  required List<Certification> certifications,
  double gap = 10,
}) {
  if (certifications.isEmpty) return const [];
  final entries = <pw.Widget>[];
  final pending = <pw.Widget>[];

  void flushPending() {
    entries.addAll(pdfTwoColumnRows(pending, gap: gap));
    pending.clear();
  }

  for (final course in certifications) {
    // La duración normalizada no cuenta como cuerpo largo.
    final body = _certificationBody(course);
    if (pdfLooksTooTallForHalfColumn(body)) {
      flushPending();
      entries.addAll(pdfCertificationFlow(course, accent, text));
    } else {
      pending.add(pdfCertificationBlock(course, accent, text));
    }
  }
  flushPending();

  return [
    ...pdfSectionWithLead(pdfSectionTitle(title, accent), entries),
    pw.SizedBox(height: 8),
  ];
}

/// API legada: empareja widgets ya construidos (sin heurística de altura).
List<pw.Widget> pdfTwoColumnSection({
  required String title,
  required PdfColor accent,
  required List<pw.Widget> cards,
  double gap = 10,
}) {
  if (cards.isEmpty) return const [];
  final rows = pdfTwoColumnRows(cards, gap: gap);
  return [
    ...pdfSectionWithLead(pdfSectionTitle(title, accent), rows),
    pw.SizedBox(height: 8),
  ];
}

/// Cuerpo usable para estimar altura de una competencia (`nombre` o detalle).
String pdfCompetencyBody(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  final split = trimmed.indexOf(':');
  if (split > 0 && split < 72) {
    final detail = trimmed.substring(split + 1).trim();
    return detail.isNotEmpty ? detail : trimmed;
  }
  return trimmed;
}

/// Competencias en dos columnas (orden L→R, luego abajo).
///
/// Ítems con cuerpo excesivo pasan a ancho completo con [TextOverflow.span]
/// para no romper [MultiPage]. El título viaja con la primera fila/entrada.
List<pw.Widget> pdfCompetenciesSection({
  required String title,
  required PdfColor accent,
  required PdfColor text,
  required List<Skill> skills,
  double gap = 10,
}) {
  final items = [
    for (final skill in skills)
      if (skill.nombre.trim().isNotEmpty) skill.nombre.trim(),
  ];
  if (items.isEmpty) return const [];

  final entries = <pw.Widget>[];
  final pending = <pw.Widget>[];

  void flushPending() {
    entries.addAll(pdfTwoColumnRows(pending, gap: gap));
    pending.clear();
  }

  for (final raw in items) {
    if (pdfLooksTooTallForHalfColumn(pdfCompetencyBody(raw))) {
      flushPending();
      entries.addAll(pdfCompetencyFlow(raw, text));
    } else {
      pending.add(pdfKeepTogether(pdfCompetencyLine(raw, text)));
    }
  }
  flushPending();

  return [
    ...pdfSectionWithLead(pdfSectionTitle(title, accent), entries),
    pw.SizedBox(height: 8),
  ];
}

/// Flujo a ancho completo para una competencia con texto muy largo.
List<pw.Widget> pdfCompetencyFlow(String raw, PdfColor text) {
  final trimmed = raw.trim();
  final split = trimmed.indexOf(':');
  final hasCategory = split > 0 && split < 72;
  final category = hasCategory ? trimmed.substring(0, split).trim() : trimmed;
  final detail = hasCategory ? trimmed.substring(split + 1).trim() : '';

  return [
    pdfKeepTogether(
      pw.Padding(
        padding: pw.EdgeInsets.only(bottom: detail.isEmpty ? 8 : 1),
        child: pw.Text(
          category,
          style: pw.TextStyle(
            fontSize: 10.5,
            fontWeight: pw.FontWeight.bold,
            color: text,
          ),
        ),
      ),
    ),
    if (detail.isNotEmpty)
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Text(
          detail,
          style: pw.TextStyle(fontSize: 10, height: 1.25, color: text),
          overflow: pw.TextOverflow.span,
        ),
      ),
  ];
}

/// Tope de una aptitud en media columna. Por encima va a ancho completo.
const int pdfAptitudeHalfColumnMaxChars = 320;

/// Identidad visual de la sección, alineada con la plantilla.
enum PdfAptitudeStyle { classic, modern, executive, creative }

PdfAptitudeStyle pdfAptitudeStyleFor(int designIndex) {
  switch (designIndex) {
    case 1:
      return PdfAptitudeStyle.modern;
    case 2:
      return PdfAptitudeStyle.executive;
    case 3:
      return PdfAptitudeStyle.creative;
    default:
      return PdfAptitudeStyle.classic;
  }
}

/// Una fila de aptitudes. [fullWidth] reserva el renglón completo al último impar.
class PdfAptitudePlacement {
  const PdfAptitudePlacement.pair(this.left, this.right) : fullWidth = false;

  const PdfAptitudePlacement.full(this.left) : right = null, fullWidth = true;

  final int left;
  final int? right;
  final bool fullWidth;
}

/// Lectura izquierda → derecha. Cero no genera filas. Una, o la última impar,
/// ocupa el ancho completo; el resto se empareja.
List<PdfAptitudePlacement> pdfAptitudePlacements(int count) {
  if (count <= 0) return const [];
  if (count == 1) return const [PdfAptitudePlacement.full(0)];
  final lastIsFull = count.isOdd;
  final paired = lastIsFull ? count - 1 : count;
  return [
    for (var index = 0; index < paired; index += 2)
      PdfAptitudePlacement.pair(index, index + 1),
    if (lastIsFull) PdfAptitudePlacement.full(count - 1),
  ];
}

String pdfAptitudeBody(Aptitude aptitude) {
  final description = aptitude.description?.trim() ?? '';
  if (description.isNotEmpty) return description;
  return '';
}

/// Aptitudes en dos columnas. No muestra la sección si no hay nombres.
///
/// El título viaja con la primera fila. Un texto largo sale del par y continúa
/// con span, para no lanzar [PdfException] ni recortar el nombre.
List<pw.Widget> pdfAptitudesSection({
  required String title,
  required PdfColor accent,
  required PdfColor text,
  required List<Aptitude> aptitudes,
  required PdfAptitudeStyle style,
  double gap = 12,
}) {
  final items = [
    for (final aptitude in aptitudes)
      if (aptitude.name.trim().isNotEmpty) aptitude,
  ];
  if (items.isEmpty) return const [];

  final entries = <pw.Widget>[];
  final pending = <Aptitude>[];

  void flushPending() {
    if (pending.isEmpty) return;
    entries.addAll(
      _aptitudeRows(
        pending,
        style: style,
        accent: accent,
        text: text,
        gap: gap,
      ),
    );
    pending.clear();
  }

  for (final aptitude in items) {
    if (pdfAptitudeBody(aptitude).length > pdfAptitudeHalfColumnMaxChars) {
      flushPending();
      entries.addAll(
        pdfAptitudeFlow(aptitude, style: style, accent: accent, text: text),
      );
    } else {
      pending.add(aptitude);
    }
  }
  flushPending();

  return [
    ...pdfSectionWithLead(pdfSectionTitle(title, accent), entries),
    pw.SizedBox(height: 8),
  ];
}

List<pw.Widget> _aptitudeRows(
  List<Aptitude> items, {
  required PdfAptitudeStyle style,
  required PdfColor accent,
  required PdfColor text,
  required double gap,
}) {
  return [
    for (final row in pdfAptitudePlacements(items.length))
      if (row.fullWidth)
        pdfAptitudeCard(
          items[row.left],
          style: style,
          accent: accent,
          text: text,
        )
      else
        pdfTwoColumnRow(
          pdfAptitudeCard(
            items[row.left],
            style: style,
            accent: accent,
            text: text,
          ),
          pdfAptitudeCard(
            items[row.right!],
            style: style,
            accent: accent,
            text: text,
          ),
          gap: gap,
        ),
  ];
}

/// Nombre, descripción y nivel guardado. No inventa una puntuación.
pw.Widget pdfAptitudeCard(
  Aptitude aptitude, {
  required PdfAptitudeStyle style,
  required PdfColor accent,
  required PdfColor text,
}) {
  final name = aptitude.name.trim();
  final description = aptitude.description?.trim() ?? '';
  final level = aptitude.level;
  final body = pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      if (style == PdfAptitudeStyle.executive)
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: _aptitudeName(name, text)),
            if (level != null) ...[
              pw.SizedBox(width: 6),
              _aptitudeLevel(level, accent),
            ],
          ],
        )
      else
        _aptitudeName(name, text),
      if (description.isNotEmpty) ...[
        pw.SizedBox(height: 2),
        pw.Text(
          description,
          style: pw.TextStyle(fontSize: 9, height: 1.25, color: text),
        ),
      ],
      if (level != null && style != PdfAptitudeStyle.executive) ...[
        pw.SizedBox(height: 2),
        _aptitudeLevel(level, accent),
      ],
    ],
  );

  final padded = pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 8, right: 4),
    child: body,
  );

  switch (style) {
    case PdfAptitudeStyle.classic:
      return padded;
    case PdfAptitudeStyle.modern:
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8, right: 4),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: 2,
              height: 28,
              margin: const pw.EdgeInsets.only(right: 6, top: 1),
              color: accent,
            ),
            pw.Expanded(child: body),
          ],
        ),
      );
    case PdfAptitudeStyle.executive:
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8, right: 6),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            body,
            pw.Container(height: 0.4, color: PdfColors.grey400),
          ],
        ),
      );
    case PdfAptitudeStyle.creative:
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8, right: 4),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: 5,
              height: 5,
              margin: const pw.EdgeInsets.only(right: 6, top: 4),
              color: accent,
            ),
            pw.Expanded(child: body),
          ],
        ),
      );
  }
}

pw.Widget _aptitudeName(String name, PdfColor text) {
  return pw.Text(
    name,
    style: pw.TextStyle(
      fontSize: 10.5,
      fontWeight: pw.FontWeight.bold,
      color: text,
      height: 1.2,
    ),
  );
}

pw.Widget _aptitudeLevel(int level, PdfColor accent) {
  return pw.Text(
    'Nivel $level',
    style: pw.TextStyle(fontSize: 8, color: accent, height: 1.2),
  );
}

/// Aptitud con descripción larga: el nombre queda junto y el texto continúa.
List<pw.Widget> pdfAptitudeFlow(
  Aptitude aptitude, {
  required PdfAptitudeStyle style,
  required PdfColor accent,
  required PdfColor text,
}) {
  final description = aptitude.description?.trim() ?? '';
  return [
    pdfKeepTogether(
      pdfAptitudeCard(
        Aptitude(id: aptitude.id, name: aptitude.name, level: aptitude.level),
        style: style,
        accent: accent,
        text: text,
      ),
    ),
    if (description.isNotEmpty)
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Text(
          description,
          style: pw.TextStyle(fontSize: 9, height: 1.25, color: text),
          overflow: pw.TextOverflow.span,
        ),
      ),
  ];
}

/// Índices de cada fila: (izquierda, derecha?). Orden de lectura natural.
List<(int, int?)> pdfTwoColumnPairs(int count) {
  if (count <= 0) return const [];
  final pairs = <(int, int?)>[];
  for (var index = 0; index < count; index += 2) {
    pairs.add((index, index + 1 < count ? index + 1 : null));
  }
  return pairs;
}

/// Índice del primer elemento de la columna derecha. Conserva el orden.
int pdfSplitIndexForBalance(List<double> heights) {
  if (heights.length <= 1) return heights.length;
  var best = (heights.length / 2).ceil();
  var bestDiff = _pdfHeightDiff(heights, best);
  for (var index = 1; index < heights.length; index++) {
    final diff = _pdfHeightDiff(heights, index);
    if (diff < bestDiff - 0.01) {
      bestDiff = diff;
      best = index;
    }
  }
  return best;
}

double _pdfHeightDiff(List<double> heights, int index) {
  final left = heights.take(index).fold<double>(0, (sum, item) => sum + item);
  final right = heights.skip(index).fold<double>(0, (sum, item) => sum + item);
  return (left - right).abs();
}

/// Si la descripción es solo la duración, la muestra como «240 h».
String? pdfDurationLabel(String? description) {
  final text = (description ?? '').trim();
  if (text.isEmpty) return null;
  final match = RegExp(
    r'^(\d+)\s*(horas?|h)\.?$',
    caseSensitive: false,
  ).firstMatch(text);
  if (match == null) return null;
  return '${match.group(1)} h';
}

/// Línea de institución, duración normalizada y fecha, sin separadores huérfanos.
String? pdfCertificationMetaLine({
  String? institution,
  String? description,
  String? date,
}) {
  final hours = pdfDurationLabel(description);
  final parts = <String>[
    if ((institution ?? '').trim().isNotEmpty) institution!.trim(),
    if (hours != null) hours,
    if ((date ?? '').trim().isNotEmpty) date!.trim(),
  ];
  if (parts.isEmpty) return null;
  return parts.join(' · ');
}
