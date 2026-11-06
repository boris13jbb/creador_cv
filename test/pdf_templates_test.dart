import 'dart:io';

import 'package:creador_cv/features/resumes/pdf/pdf_widgets.dart';
import 'package:creador_cv/features/resumes/pdf/resume_pdf_service.dart';
import 'package:creador_cv/features/templates/cv_templates.dart';
import 'package:creador_cv/models/resume.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pdf_text_extract.dart';

Resume _sample({
  int designIndex = 0,
  bool ocultarPerfil = false,
  int experiencias = 2,
}) {
  return Resume(
    id: 'test-1',
    nombre: 'Ana Pérez',
    perfil: ocultarPerfil
        ? ''
        : 'Ingeniera de software con 8 años de experiencia.',
    datosPersonales: const [
      PersonalData(label: 'Email', value: 'ana@empresa.com', icon: 'email'),
      PersonalData(label: 'Teléfono', value: '+34 600 000 000', icon: 'phone'),
    ],
    competencias: const [
      Skill(nombre: 'Dart', nivel: 5),
      Skill(nombre: 'Flutter', nivel: 5),
    ],
    idiomas: const [Skill(nombre: 'Español', nivel: 5)],
    experiencia: List.generate(
      experiencias,
      (i) => Experience(
        cargo: 'Dev $i',
        empresa: 'Empresa $i',
        periodo: '202$i - Actual',
        logros: [
          'Logro A del puesto $i con descripción extendida para forzar flujo multipágina.',
          'Logro B del puesto $i.',
        ],
      ),
    ),
    formacion: const [
      Education(
        titulo: 'Ingeniería Informática',
        institucion: 'Universidad',
        anio: '2016',
      ),
    ],
    colorHex: 0xFF0F766E,
    designIndex: designIndex,
    ocultarPerfil: ocultarPerfil,
  );
}

void _writeReviewPdf(String name, List<int> bytes) {
  final primary = File('build/$name.pdf');
  try {
    primary.writeAsBytesSync(bytes);
  } on FileSystemException {
    File('build/${name}_review.pdf').writeAsBytesSync(bytes);
  }
}

void main() {
  group('columnas y duraciones reutilizables', () {
    test('cero elementos no generan pares', () {
      expect(pdfTwoColumnPairs(0), isEmpty);
    });

    test('un elemento queda solo a la izquierda', () {
      expect(pdfTwoColumnPairs(1), [(0, null)]);
    });

    test('dos elementos forman una pareja', () {
      expect(pdfTwoColumnPairs(2), [(0, 1)]);
    });

    test('tres elementos dejan el último solo', () {
      expect(pdfTwoColumnPairs(3), [(0, 1), (2, null)]);
    });

    test('cuatro elementos forman dos parejas equilibradas', () {
      expect(pdfTwoColumnPairs(4), [(0, 1), (2, 3)]);
    });

    test('normaliza duraciones exclusivas a horas cortas', () {
      expect(pdfDurationLabel('40 horas'), '40 h');
      expect(pdfDurationLabel('240 horas'), '240 h');
      expect(pdfDurationLabel('40 h'), '40 h');
      expect(pdfDurationLabel('240 h'), '240 h');
      expect(pdfDurationLabel('240 H'), '240 h');
      expect(pdfDurationLabel('  1 hora.  '), '1 h');
      expect(pdfDurationLabel('6h'), '6 h');
    });

    test('no normaliza descripciones con texto adicional', () {
      expect(pdfDurationLabel('Curso de 40 horas'), isNull);
      expect(
        pdfDurationLabel('Curso de 40 horas con evaluación práctica.'),
        isNull,
      );
      expect(pdfDurationLabel(''), isNull);
      expect(pdfDurationLabel(null), isNull);
      expect(pdfDurationLabel('   '), isNull);
    });

    test('meta de certificación sin separadores huérfanos', () {
      expect(
        pdfCertificationMetaLine(
          institution: 'Academia Tech',
          description: '240 horas',
        ),
        'Academia Tech · 240 h',
      );
      expect(pdfCertificationMetaLine(description: '40 horas'), '40 h');
      expect(
        pdfCertificationMetaLine(institution: 'AWS Academy', date: '2024'),
        'AWS Academy · 2024',
      );
      expect(
        pdfCertificationMetaLine(
          institution: '',
          description: 'Curso completo',
          date: '',
        ),
        isNull,
      );
      expect(
        pdfCertificationMetaLine(
          institution: 'Academia',
          description: 'Curso de 40 horas con evaluación',
          date: '2025',
        ),
        'Academia · 2025',
      );
    });

    test('pdfSplitIndexForBalance sigue disponible para One Page', () {
      expect(pdfSplitIndexForBalance(List<double>.filled(8, 20)), 4);
      expect(pdfSplitIndexForBalance(const [30, 30, 30, 22, 22, 22, 22]), 3);
    });
  });

  group('CvTemplates acceso Free/Pro', () {
    test('Free no puede usar Ejecutivo, Creativo ni One Page', () {
      expect(CvTemplates.canUseDesign(0, isPro: false), isTrue);
      expect(CvTemplates.canUseDesign(1, isPro: false), isTrue);
      expect(CvTemplates.canUseDesign(2, isPro: false), isFalse);
      expect(CvTemplates.canUseDesign(3, isPro: false), isFalse);
      expect(CvTemplates.canUseDesign(4, isPro: false), isFalse);
    });

    test('resolveDesignIndex cae a Clásico para Free+Pro', () {
      expect(
        CvTemplates.resolveDesignIndex(3, isPro: false),
        CvTemplates.freeFallbackIndex,
      );
      expect(CvTemplates.resolveDesignIndex(3, isPro: true), 3);
    });

    test('Pro puede usar todas', () {
      for (final t in CvTemplates.all) {
        expect(CvTemplates.canUseDesign(t.designIndex, isPro: true), isTrue);
      }
    });
  });

  group('ResumePdfService MultiPage', () {
    test('genera PDF no vacío para cada plantilla (Pro)', () async {
      for (final t in CvTemplates.all) {
        final bytes = await ResumePdfService.generateResumePdf(
          _sample(designIndex: t.designIndex, experiencias: 8),
          isPro: true,
        );
        expect(bytes.length, greaterThan(500), reason: t.name);
        expect(bytes[0], 0x25); // %PDF
      }
    });

    test('Free con diseño Pro genera fallback Clásico', () async {
      final proBytes = await ResumePdfService.generateResumePdf(
        _sample(designIndex: 2),
        isPro: true,
      );
      final freeBytes = await ResumePdfService.generateResumePdf(
        _sample(designIndex: 2),
        isPro: false,
      );
      expect(freeBytes.length, greaterThan(500));
      // No deben ser idénticos (plantillas distintas).
      expect(
        freeBytes.length != proBytes.length || freeBytes != proBytes,
        isTrue,
      );
    });

    test('respeta ocultarPerfil', () async {
      final visible = await ResumePdfService.generateResumePdf(
        _sample(ocultarPerfil: false),
        isPro: true,
      );
      final hidden = await ResumePdfService.generateResumePdf(
        _sample(ocultarPerfil: true),
        isPro: true,
      );
      expect(visible.length, isNot(equals(hidden.length)));
    });

    test('PDF sin nuevas secciones no falla', () async {
      final bytes = await ResumePdfService.generateResumePdf(
        _sample(),
        isPro: true,
      );
      expect(bytes.length, greaterThan(500));
    });

    test('PDF con proyectos certificaciones y aptitudes', () async {
      final rich = _sample(designIndex: 1).copyWith(
        projects: const [
          Project(
            id: 'p1',
            name: 'Sistema de gestión',
            description: 'Plataforma SaaS con Flutter y NestJS.',
            technologies: ['Flutter', 'NestJS', 'MySQL'],
            url: 'https://example.com/app',
            startDate: '2025',
            isOngoing: true,
          ),
          Project(
            id: 'p2',
            name: 'Control de planta',
            description: 'Reportes de turno y seguimiento de lotes.',
            technologies: ['Flutter', 'SQL'],
            startDate: '2024',
          ),
        ],
        certifications: const [
          Certification(
            id: 'c1',
            name: 'AWS Cloud Practitioner',
            institution: 'Amazon Web Services',
            date: '2026',
            credentialId: 'XXXXX',
          ),
          Certification(
            id: 'c2',
            name: 'Apps con Flutter',
            institution: 'ECN LATAM Academy',
            description: '240 horas',
            date: '2025',
          ),
        ],
        aptitudes: const [
          Aptitude(id: 'a1', name: 'Liderazgo'),
          Aptitude(id: 'a2', name: 'Comunicación'),
          Aptitude(id: 'a3', name: 'Trabajo en equipo'),
        ],
      );
      final empty = await ResumePdfService.generateResumePdf(
        _sample(designIndex: 1),
        isPro: true,
      );
      final withSections = await ResumePdfService.generateResumePdf(
        rich,
        isPro: true,
      );
      expect(withSections.length, greaterThan(empty.length));
      expect(withSections[0], 0x25);
      expect(
        pdfCertificationMetaLine(
          institution: 'ECN LATAM Academy',
          description: '240 horas',
          date: '2025',
        ),
        'ECN LATAM Academy · 240 h · 2025',
      );
    });

    test(
      'proyectos y certificaciones salen en dos columnas en cada plantilla',
      () async {
        final rich = _sample().copyWith(
          projects: List.generate(
            4,
            (i) => Project(
              id: 'p$i',
              name: 'Proyecto $i',
              description: 'Descripción del proyecto $i con alcance real.',
              technologies: const ['Flutter'],
              startDate: '202$i',
            ),
          ),
          certifications: List.generate(
            4,
            (i) => Certification(
              id: 'c$i',
              name: 'Certificación $i',
              institution: 'Academia $i',
              description: i.isEven ? '40 horas' : 'Curso completo',
              date: '202$i',
            ),
          ),
        );
        for (final index in const [0, 1, 2, 3]) {
          final bytes = await ResumePdfService.generateResumePdf(
            rich.copyWith(designIndex: index),
            isPro: true,
          );
          expect(bytes.length, greaterThan(800), reason: 'design $index');
          _writeReviewPdf('two_cols_design_$index', bytes);
        }
      },
    );

    test('número impar y textos largos no rompen la paginación', () async {
      final odd = _sample(experiencias: 1).copyWith(
        projects: List.generate(
          5,
          (i) => Project(
            id: 'p$i',
            name: 'Proyecto largo $i con título extendido de validación',
            description:
                'Descripción extensa del proyecto $i con alcance de planta, '
                    'reportes, sincronización y seguimiento de indicadores. ' *
                3,
            technologies: const ['Flutter', 'Firebase', 'SQL'],
            startDate: '202$i',
          ),
        ),
        certifications: List.generate(
          7,
          (i) => Certification(
            id: 'c$i',
            name: 'Certificación avanzada $i en redes industriales y seguridad',
            institution: 'Centro de formación profesional $i',
            description: i == 0 ? '240 horas' : 'Curso con evaluación práctica',
            date: '202$i',
          ),
        ),
      );
      for (final index in const [0, 1, 2, 3]) {
        final bytes = await ResumePdfService.generateResumePdf(
          odd.copyWith(designIndex: index),
          isPro: true,
        );
        expect(bytes.length, greaterThan(1500), reason: 'design $index');
        expect(bytes[0], 0x25);
        _writeReviewPdf('two_cols_odd_$index', bytes);
      }
    });

    test('PDF Unicode genera sin excepción', () async {
      final unicode = _sample().copyWith(
        nombre: 'Juan Muñoz Peña',
        perfil: 'Educación, comunicación y gestión de equipos.',
        projects: const [
          Project(
            id: 'u1',
            name: 'Aplicación de nómina',
            description: 'Módulo de sincronización y roles de pago.',
          ),
        ],
        aptitudes: const [Aptitude(id: 'u2', name: 'Resolución de problemas')],
      );
      final bytes = await ResumePdfService.generateResumePdf(
        unicode,
        isPro: true,
      );
      expect(bytes.length, greaterThan(500));
    });

    test('PDF largo con tres secciones no vacío', () async {
      final long = _sample(experiencias: 10).copyWith(
        projects: List.generate(
          5,
          (i) => Project(
            id: 'p$i',
            name: 'Proyecto $i',
            description: 'Descripción extendida del proyecto $i. ' * 4,
            technologies: ['Flutter', 'Dart', 'Firebase'],
            startDate: '202$i',
          ),
        ),
        certifications: List.generate(
          6,
          (i) => Certification(
            id: 'c$i',
            name: 'Certificación $i',
            institution: 'Academia $i',
            date: '202$i',
          ),
        ),
        aptitudes: List.generate(
          8,
          (i) => Aptitude(id: 'a$i', name: 'Aptitud $i'),
        ),
      );
      final bytes = await ResumePdfService.generateResumePdf(long, isPro: true);
      expect(bytes.length, greaterThan(2000));
    });

    test('huérfanos: título cerca del final con muchas experiencias', () async {
      // Fuerza saltos de página cerca de títulos de sección.
      final crowded = _sample(experiencias: 14).copyWith(
        formacion: List.generate(
          6,
          (i) => Education(
            titulo: 'Formación $i en tecnologías aplicadas',
            institucion: 'Instituto $i',
            anio: '201$i',
          ),
        ),
        competencias: List.generate(
          10,
          (i) => Skill(nombre: 'Competencia $i: detalle técnico', nivel: 4),
        ),
        projects: List.generate(
          5,
          (i) => Project(
            id: 'hp$i',
            name: 'Proyecto $i',
            description: 'Alcance corto del proyecto $i.',
            technologies: const ['Flutter'],
            startDate: '202$i',
          ),
        ),
        certifications: List.generate(
          5,
          (i) => Certification(
            id: 'hc$i',
            name: 'Certificación $i',
            institution: 'Academia $i',
            description: i == 0 ? '240 horas' : 'Curso completo',
            date: '202$i',
          ),
        ),
        aptitudes: List.generate(
          6,
          (i) => Aptitude(id: 'ha$i', name: 'Aptitud $i'),
        ),
      );
      for (final index in const [0, 1, 2, 3]) {
        final bytes = await ResumePdfService.generateResumePdf(
          crowded.copyWith(designIndex: index),
          isPro: true,
        );
        expect(bytes.length, greaterThan(2000), reason: 'design $index');
        expect(bytes[0], 0x25);
        _writeReviewPdf('orphan_crowded_$index', bytes);
      }
    });

    test('huérfanos: experiencia con logros largos sigue generando', () async {
      final longLogros = _sample(experiencias: 3).copyWith(
        experiencia: List.generate(
          3,
          (i) => Experience(
            cargo: 'Ingeniero $i',
            empresa: 'Empresa $i',
            periodo: '202$i - Actual',
            logros: [
              'Logro extenso $i con detalle de planta, reportes y sincronización. ' *
                  8,
              'Segundo logro $i con indicadores y seguimiento de calidad. ' * 6,
              'Tercer logro $i.',
            ],
          ),
        ),
      );
      for (final index in const [0, 1, 2, 3]) {
        final bytes = await ResumePdfService.generateResumePdf(
          longLogros.copyWith(designIndex: index),
          isPro: true,
        );
        expect(bytes.length, greaterThan(1500), reason: 'design $index');
        _writeReviewPdf('orphan_long_exp_$index', bytes);
      }
    });

    test('huérfanos: CV mínimo y One Page siguen válidos', () async {
      final minimal = Resume(
        id: 'min',
        nombre: 'Min User',
        perfil: '',
        datosPersonales: const [],
        competencias: const [],
        idiomas: const [],
        experiencia: const [],
        formacion: const [],
        colorHex: 0xFF0F766E,
        designIndex: 0,
        ocultarPerfil: true,
      );
      final minBytes = await ResumePdfService.generateResumePdf(
        minimal,
        isPro: true,
      );
      expect(minBytes.length, greaterThan(200));

      final onePage = await ResumePdfService.generateResumePdf(
        _sample(designIndex: 4, experiencias: 6).copyWith(
          projects: List.generate(
            3,
            (i) => Project(
              id: 'op$i',
              name: 'Proyecto One Page $i',
              description: 'Descripción $i',
              startDate: '202$i',
            ),
          ),
          certifications: List.generate(
            3,
            (i) => Certification(
              id: 'oc$i',
              name: 'Cert $i',
              institution: 'Inst $i',
              description: '40 horas',
              date: '202$i',
            ),
          ),
        ),
        isPro: true,
      );
      expect(onePage.length, greaterThan(500));
      _writeReviewPdf('orphan_one_page', onePage);
    });

    test(
      'estrés: proyecto y certificación con cuerpo enorme no lanzan',
      () async {
        final huge = 'Bloque de texto extremo para media columna A4. ' * 120;
        expect(pdfLooksTooTallForHalfColumn(huge), isTrue);
        expect(pdfLooksTooTallForHalfColumn('corto'), isFalse);

        final stress = _sample(experiencias: 2).copyWith(
          perfil: 'Perfil extenso de validación. ' * 200,
          projects: [
            const Project(
              id: 's0',
              name: 'Proyecto compacto',
              description: 'Descripción breve en dos columnas.',
              technologies: ['Flutter'],
              startDate: '2020',
            ),
            Project(
              id: 's1',
              name: 'Proyecto extremo',
              description: huge,
              technologies: const ['Flutter', 'Firebase'],
              startDate: '2021',
            ),
            const Project(
              id: 's2',
              name: 'Otro compacto',
              description: 'Segundo breve.',
              startDate: '2022',
            ),
          ],
          certifications: [
            Certification(
              id: 'sc0',
              name: 'Certificación extrema',
              institution: 'Academia',
              description: huge,
              date: '2023',
            ),
            const Certification(
              id: 'sc1',
              name: 'Cert corta',
              institution: 'AWS',
              description: '40 horas',
              date: '2024',
            ),
          ],
        );

        for (final index in const [0, 1, 2, 3]) {
          final bytes = await ResumePdfService.generateResumePdf(
            stress.copyWith(designIndex: index),
            isPro: true,
          );
          expect(bytes.length, greaterThan(2500), reason: 'design $index');
          expect(bytes[0], 0x25);
          _writeReviewPdf('stress_tall_$index', bytes);
        }
      },
    );

    test(
      'estrés: muchos logros y desbalance de alturas en dos columnas',
      () async {
        final unbalanced = _sample(experiencias: 1).copyWith(
          experiencia: [
            Experience(
              cargo: 'Lead',
              empresa: 'Planta',
              periodo: '2018 - Actual',
              logros: List.generate(
                25,
                (i) => 'Logro $i con detalle operativo y métricas. ' * 12,
              ),
            ),
          ],
          projects: [
            const Project(
              id: 'u0',
              name: 'Corto A',
              description: 'Uno.',
              startDate: '2020',
            ),
            Project(
              id: 'u1',
              name: 'Largo B',
              description: 'Descripción intermedia. ' * 40,
              startDate: '2021',
            ),
            const Project(
              id: 'u2',
              name: 'Corto C',
              description: 'Tres.',
              startDate: '2022',
            ),
            Project(
              id: 'u3',
              name: 'Muy largo D',
              description: 'Texto para forzar ancho completo. ' * 100,
              startDate: '2023',
            ),
          ],
        );

        for (final index in const [0, 1, 2, 3]) {
          final bytes = await ResumePdfService.generateResumePdf(
            unbalanced.copyWith(designIndex: index),
            isPro: true,
          );
          expect(bytes.length, greaterThan(2000), reason: 'design $index');
          _writeReviewPdf('stress_unbalanced_$index', bytes);
        }

        final onePageHeavy = await ResumePdfService.generateResumePdf(
          unbalanced.copyWith(designIndex: 4),
          isPro: true,
        );
        expect(onePageHeavy.length, greaterThan(500));
        _writeReviewPdf('stress_one_page_heavy', onePageHeavy);
      },
    );
  });

  group('Competencias en dos columnas', () {
    test('pdfCompetencyBody toma el detalle tras los dos puntos', () {
      expect(pdfCompetencyBody('Flutter'), 'Flutter');
      expect(
        pdfCompetencyBody('Backend: APIs REST y colas'),
        'APIs REST y colas',
      );
      expect(pdfCompetencyBody(''), '');
    });

    test('cero competencias no rompe ninguna plantilla', () async {
      final empty = _sample().copyWith(competencias: const []);
      for (final index in const [0, 1, 2, 3, 4]) {
        final bytes = await ResumePdfService.generateResumePdf(
          empty.copyWith(designIndex: index),
          isPro: true,
        );
        expect(bytes.length, greaterThan(400), reason: 'design $index');
      }
    });

    test('una, dos, tres y cuatro competencias generan PDF', () async {
      for (final count in const [1, 2, 3, 4]) {
        final resume = _sample().copyWith(
          competencias: List.generate(
            count,
            (i) => Skill(nombre: 'Competencia $i', nivel: 4),
          ),
        );
        for (final index in const [0, 1, 2, 3]) {
          final bytes = await ResumePdfService.generateResumePdf(
            resume.copyWith(designIndex: index),
            isPro: true,
          );
          expect(
            bytes.length,
            greaterThan(500),
            reason: 'count=$count design=$index',
          );
        }
      }
    });

    test(
      'muchas competencias y nombres largos en las cinco plantillas',
      () async {
        final rich = _sample(experiencias: 6).copyWith(
          competencias: [
            ...List.generate(
              9,
              (i) => Skill(
                nombre: i.isEven
                    ? 'Competencia $i: detalle técnico aplicado en planta'
                    : 'NombreExtremadamenteLargoDeCompetenciaSinEspacios$i',
                nivel: 3 + (i % 3),
              ),
            ),
            Skill(
              nombre:
                  'Categoría: ${'descripción extensa de competencia. ' * 90}',
              nivel: 5,
            ),
          ],
        );
        for (final index in const [0, 1, 2, 3, 4]) {
          final bytes = await ResumePdfService.generateResumePdf(
            rich.copyWith(designIndex: index),
            isPro: true,
          );
          expect(bytes.length, greaterThan(1500), reason: 'design $index');
          expect(bytes[0], 0x25);
          _writeReviewPdf('competencias_cols_$index', bytes);
        }
      },
    );

    test('One Page con competencias conserva dos páginas A4', () async {
      final onePage = await ResumePdfService.generateResumePdf(
        _sample(designIndex: 4, experiencias: 5).copyWith(
          competencias: List.generate(
            8,
            (i) => Skill(nombre: 'Habilidad $i: dominio práctico', nivel: 4),
          ),
        ),
        isPro: true,
      );
      expect(onePage.length, greaterThan(800));
      _writeReviewPdf('competencias_one_page', onePage);
    });
  });

  group('aptitudes en dos columnas', () {
    test(
      'la distribución respeta pares y el último impar a ancho completo',
      () {
        expect(pdfAptitudePlacements(0), isEmpty);
        expect(pdfAptitudePlacements(1).single.fullWidth, isTrue);

        final two = pdfAptitudePlacements(2);
        expect(two, hasLength(1));
        expect(two.single.left, 0);
        expect(two.single.right, 1);
        expect(two.single.fullWidth, isFalse);

        final three = pdfAptitudePlacements(3);
        expect(three.map((row) => (row.left, row.right, row.fullWidth)), [
          (0, 1, false),
          (2, null, true),
        ]);

        final four = pdfAptitudePlacements(4);
        expect(four.every((row) => !row.fullWidth), isTrue);
        expect(four, hasLength(2));

        final seven = pdfAptitudePlacements(7);
        expect(seven, hasLength(4));
        expect(seven.take(3).every((row) => row.right != null), isTrue);
        expect(seven.last.fullWidth, isTrue);
        expect(seven.last.left, 6);

        final eight = pdfAptitudePlacements(8);
        expect(eight, hasLength(4));
        expect(eight.every((row) => row.right != null), isTrue);
      },
    );

    test('cero aptitudes no escribe la sección', () async {
      final bytes = await ResumePdfService.generateResumePdf(
        _sample(),
        isPro: true,
      );
      final text = await extractPdfTextWithPyMuPdf(
        bytes,
        saveAs: 'build/aptitudes_cero.pdf',
      );
      expect(text, isNotNull);
      expect(text!.toUpperCase().contains('APTITUDES'), isFalse);
    });

    test(
      'una, dos, tres, cuatro y siete aptitudes conservan el orden',
      () async {
        Future<void> check(int count) async {
          final names = [for (var i = 0; i < count; i++) 'AptitudOrdenada$i'];
          final resume = _sample().copyWith(
            aptitudes: [
              for (var i = 0; i < count; i++)
                Aptitude(
                  id: 'a$i',
                  name: names[i],
                  level: i == 0 ? 4 : null,
                  description: i == 1 ? 'Criterio de equipo' : null,
                ),
            ],
          );
          final bytes = await ResumePdfService.generateResumePdf(
            resume,
            isPro: true,
          );
          final text = collapsePdfText(
            (await extractPdfTextWithPyMuPdf(
              bytes,
              saveAs: 'build/aptitudes_n_$count.pdf',
            ))!,
          );
          expect(text.contains('APTITUDES'), isTrue);
          var cursor = text.indexOf('APTITUDES');
          for (final name in names) {
            final at = text.indexOf(name, cursor);
            expect(at, greaterThanOrEqualTo(0), reason: name);
            cursor = at + name.length;
          }
          if (count > 0) expect(text.contains('Nivel4'), isTrue);
          if (count > 1) expect(text.contains('Criteriodeequipo'), isTrue);
        }

        await check(1);
        await check(2);
        await check(3);
        await check(4);
        await check(7);
      },
    );

    test('nombres largos, nivel y CV denso en las cinco plantillas', () async {
      final dense = _sample(experiencias: 8).copyWith(
        perfil: 'Perfil profesional de continuidad. ' * 40,
        aptitudes: [
          for (var i = 0; i < 9; i++)
            Aptitude(
              id: 'd$i',
              name: i == 3
                  ? 'Aptitud con un nombre largo que debe seguir siendo legible en la columna'
                  : 'AptitudDensa$i',
              level: i.isEven ? 3 : null,
              description: i == 8 ? 'detalle ${'amplio ' * 80}' : null,
            ),
        ],
        projects: const [
          Project(
            id: 'p1',
            name: 'Proyecto Norte',
            description: 'Alcance real',
          ),
          Project(id: 'p2', name: 'Proyecto Sur', description: 'Alcance real'),
        ],
        certifications: const [
          Certification(
            id: 'c1',
            name: 'Curso Flutter',
            institution: 'Academia Tech',
            description: '240 horas',
          ),
        ],
      );
      for (final index in const [0, 1, 2, 3, 4]) {
        final bytes = await ResumePdfService.generateResumePdf(
          dense.copyWith(designIndex: index),
          isPro: true,
        );
        expect(bytes.length, greaterThan(1500), reason: 'design $index');
        final text = collapsePdfText(
          (await extractPdfTextWithPyMuPdf(
            bytes,
            saveAs: 'build/aptitudes_plantilla_$index.pdf',
          ))!,
        );
        for (var i = 0; i < 9; i++) {
          final mark = i == 3 ? 'Aptitudconunnombrelargo' : 'AptitudDensa$i';
          expect(text.contains(mark), isTrue, reason: 'design $index $mark');
        }
        expect(text.contains('Nivel3'), isTrue);
        expect(text.contains('AcademiaTech'), isTrue);
        expect(text.contains('240h'), isTrue);
        expect('APTITUDES'.allMatches(text).length, 1);
      }
    });
  });
}
