import 'package:creador_cv/features/resumes/pdf/professional_one_page_pdf_generator.dart';
import 'package:creador_cv/models/resume.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';

import 'one_page_visual_check_test.dart';

const _longSummary = '''
Ingeniero con trayectoria en producción textil y desarrollo de software. El primer párrafo describe soporte de planta, mantenimiento de aplicaciones y coordinación con equipos de operación.

El segundo párrafo cubre proyectos de cotización, control de desperdicios, nómina y herramientas internas, con entregas en Flutter, bases de datos y hojas de cálculo.

El tercer párrafo resume formación continua en redes, ciberseguridad y plataformas en la nube, además de la disposición para seguir aportando en equipos de desarrollo.
''';

void main() {
  test('resumen corto permanece en la barra y cabe en dos páginas', () async {
    final result = await buildProfessionalOnePage(referenceResume());
    _expectA4(result, pages: 2);
    expect(result.summaryInSidebar, isTrue);
    expect(result.metrics.bodySize, greaterThanOrEqualTo(9));
    expect(result.plan.summary, contains('más de 10 años'));
  });

  test('resumen de varios párrafos se dibuja completo', () async {
    final resume = referenceResume().copyWith(perfil: _longSummary);
    final result = await buildProfessionalOnePage(resume);
    _expectA4(result);
    expect(result.plan.summary, contains('tercer párrafo'));
    expect(result.metrics.meetsReadability, isTrue);
    writeOnePageReviewPdf('one_page_long_summary', result.bytes);
  });

  test('resumen extenso con muchas aptitudes y habilidades', () async {
    final resume = referenceResume().copyWith(
      perfil: '$_longSummary\n$_longSummary',
      aptitudes: [
        for (var i = 0; i < 12; i++)
          Aptitude(
            id: 'apt-$i',
            name:
                'Aptitud profesional de seguimiento $i con criterio de equipo',
          ),
      ],
      competencias: [
        for (var i = 0; i < 8; i++)
          Skill(
            nombre:
                'Habilidad $i: aplicación de herramientas de desarrollo y soporte en planta',
            nivel: 4,
          ),
      ],
    );
    final result = await buildProfessionalOnePage(resume);
    _expectA4(result);
    expect(result.plan.aptitudes, hasLength(12));
    expect(result.plan.skills, hasLength(8));
    expect(result.plan.summary, contains('tercer párrafo'));
    expect(result.metrics.meetsReadability, isTrue);
    writeOnePageReviewPdf('one_page_dense_sidebar', result.bytes);
  });

  test('proyectos con descripción larga conservan el texto', () async {
    const description =
        'Descripción extensa del proyecto de control de planta, con módulos de registro, reportes de turno, seguimiento de lotes, integración con hojas de cálculo y revisión de indicadores de desperdicio durante varias temporadas de producción textil.';
    final resume = referenceResume().copyWith(
      projects: [
        for (var i = 0; i < 4; i++)
          Project(
            id: 'largo-$i',
            name: 'Proyecto largo $i',
            description: description,
            technologies: const ['Flutter', 'SQL'],
            startDate: '202$i',
          ),
      ],
    );
    final result = await buildProfessionalOnePage(resume);
    _expectA4(result);
    expect(
      result.plan.projects.first.paragraphs.join(' '),
      contains(description),
    );
    writeOnePageReviewPdf('one_page_long_projects', result.bytes);
  });

  test('certificaciones con título largo conservan el texto', () async {
    const title =
        'Certificación avanzada en operación de redes industriales, seguridad perimetral y soporte de plataformas de producción textil';
    final resume = referenceResume().copyWith(
      certifications: [
        for (var i = 0; i < 4; i++)
          Certification(
            id: 'cert-largo-$i',
            name: '$title $i',
            institution: 'Centro de formación profesional $i',
            date: '202$i',
            description: 'Curso de 40 horas con evaluación práctica.',
          ),
      ],
    );
    final result = await buildProfessionalOnePage(resume);
    _expectA4(result, pages: 2);
    expect(result.plan.certifications.first.title, contains(title));
    const description = 'Curso de 40 horas con evaluación práctica.';
    for (final course in result.plan.certifications) {
      final painted = [
        course.subtitle,
        if (course.hours != null) course.hours,
        ...course.paragraphs,
      ].whereType<String>().join('\n');
      expect(painted, contains('40 horas'));
      expect(painted, contains('Curso de'));
      expect(painted, contains('con evaluación práctica'));
      expect(painted, isNot(contains('Curso de con evaluación')));
      expect('40 horas'.allMatches(painted), hasLength(1));
      expect(course.paragraphs.single, description);
    }
    writeOnePageReviewPdf('one_page_long_certs', result.bytes);
  });

  test(
    'sin resumen no aparece la sección y el CV sigue en dos páginas',
    () async {
      final result = await buildProfessionalOnePage(
        referenceResume().copyWith(perfil: ''),
      );
      _expectA4(result, pages: 2);
      expect(result.plan.summary, isNull);
      expect(result.summaryInSidebar, isFalse);
    },
  );

  test('sin fotografía el PDF sigue en dos páginas A4', () async {
    final result = await buildProfessionalOnePage(
      referenceResume(photo: false),
    );
    _expectA4(result, pages: 2);
    expect(result.plan.showPhoto, isFalse);
    expect(result.summaryInSidebar, isTrue);
  });
}

void _expectA4(OnePagePdfResult result, {int? pages}) {
  expect(result.bytes[0], 0x25);
  if (pages != null) {
    expect(result.pageCount, pages);
  } else {
    expect(result.pageCount, greaterThanOrEqualTo(2));
  }
  expect(result.pageWidths, hasLength(result.pageCount));
  expect(result.pageHeights, hasLength(result.pageCount));
  for (final width in result.pageWidths) {
    expect(width, closeTo(PdfPageFormat.a4.width, 0.2));
  }
  for (final height in result.pageHeights) {
    expect(height, closeTo(PdfPageFormat.a4.height, 0.2));
  }
}
