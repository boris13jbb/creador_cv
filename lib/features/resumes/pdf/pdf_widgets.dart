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

pw.Widget pdfExperienceBlock(
  Experience e,
  PdfColor accent,
  PdfColor text, {
  double titleSize = 12,
}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 12),
    child: pw.Column(
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
        if (e.logros.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          ...e.logros.map(
            (logro) => pw.Padding(
              padding: const pw.EdgeInsets.only(left: 8, bottom: 2),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: 4,
                    height: 4,
                    margin: const pw.EdgeInsets.only(top: 3, right: 6),
                    decoration: pw.BoxDecoration(
                      color: text,
                      shape: pw.BoxShape.circle,
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      logro,
                      style: pw.TextStyle(fontSize: 10, color: text),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

pw.Widget pdfEducationBlock(Education f, PdfColor text) {
  return pw.Padding(
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
        pw.Text(f.institucion, style: pw.TextStyle(fontSize: 10, color: text)),
      ],
    ),
  );
}

pw.Widget pdfSkillChip(String name, PdfColor border, PdfColor text) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(right: 6, bottom: 6),
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: border),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
    ),
    child: pw.Text(name, style: pw.TextStyle(fontSize: 9, color: text)),
  );
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
    blocks.add(
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pdfSectionTitle('Perfil profesional', accent),
          pw.Text(
            resume.perfil,
            style: pw.TextStyle(fontSize: 10, color: text, lineSpacing: 2),
            textAlign: pw.TextAlign.justify,
          ),
          pw.SizedBox(height: 14),
        ],
      ),
    );
  }

  if (!resume.ocultarExperiencia && resume.experiencia.isNotEmpty) {
    blocks.add(pdfSectionTitle('Experiencia laboral', accent));
    for (final e in resume.experiencia) {
      blocks.add(pdfExperienceBlock(e, accent, text));
    }
    blocks.add(pw.SizedBox(height: 8));
  }

  if (!resume.ocultarFormacion && resume.formacion.isNotEmpty) {
    blocks.add(pdfSectionTitle('Formación académica', accent));
    for (final f in resume.formacion) {
      blocks.add(pdfEducationBlock(f, text));
    }
    blocks.add(pw.SizedBox(height: 8));
  }

  if (!resume.ocultarCompetencias && resume.competencias.isNotEmpty) {
    blocks.add(
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pdfSectionTitle('Competencias', accent),
          pw.Wrap(
            children: resume.competencias
                .map((s) => pdfSkillChip(s.nombre, accent, text))
                .toList(),
          ),
          pw.SizedBox(height: 12),
        ],
      ),
    );
  }

  if (!resume.ocultarIdiomas && resume.idiomas.isNotEmpty) {
    blocks.add(
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pdfSectionTitle('Idiomas', accent),
          ...resume.idiomas.map((s) => pdfSkillDots(s.nombre, s.nivel, accent)),
          pw.SizedBox(height: 12),
        ],
      ),
    );
  }

  if (!resume.ocultarProyectos && resume.projects.isNotEmpty) {
    blocks.add(pdfSectionTitle('Proyectos', accent));
    for (final p in resume.projects) {
      blocks.add(pdfProjectBlock(p, accent, text));
    }
    blocks.add(pw.SizedBox(height: 8));
  }

  if (!resume.ocultarCertificaciones && resume.certifications.isNotEmpty) {
    blocks.add(pdfSectionTitle('Certificaciones y cursos', accent));
    for (final c in resume.certifications) {
      blocks.add(pdfCertificationBlock(c, accent, text));
    }
    blocks.add(pw.SizedBox(height: 8));
  }

  if (!resume.ocultarAptitudes && resume.aptitudes.isNotEmpty) {
    blocks.add(
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pdfSectionTitle('Aptitudes', accent),
          pw.Wrap(
            children: resume.aptitudes
                .map((a) => pdfSkillChip(a.name, accent, text))
                .toList(),
          ),
          pw.SizedBox(height: 8),
        ],
      ),
    );
  }

  return blocks;
}

pw.Widget pdfProjectBlock(Project p, PdfColor accent, PdfColor text) {
  final period = p.periodLabel;
  final techs = p.technologies.where((t) => t.trim().isNotEmpty).toList();
  final url = p.url?.trim();
  final repo = p.repositoryUrl?.trim();

  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 12),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
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
        ),
        if (p.description.trim().isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Text(
            p.description.trim(),
            style: pw.TextStyle(fontSize: 10, color: text, lineSpacing: 2),
          ),
        ],
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
      ],
    ),
  );
}

pw.Widget pdfCertificationBlock(
  Certification c,
  PdfColor accent,
  PdfColor text,
) {
  final meta = <String>[];
  if (c.institution.trim().isNotEmpty) meta.add(c.institution.trim());
  if (c.date != null && c.date!.trim().isNotEmpty) meta.add(c.date!.trim());

  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 10),
    child: pw.Column(
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
        if (meta.isNotEmpty) ...[
          pw.SizedBox(height: 2),
          pw.Text(
            meta.join(' · '),
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
        if (c.description != null && c.description!.trim().isNotEmpty) ...[
          pw.SizedBox(height: 2),
          pw.Text(
            c.description!.trim(),
            style: pw.TextStyle(fontSize: 9, color: text),
          ),
        ],
      ],
    ),
  );
}
