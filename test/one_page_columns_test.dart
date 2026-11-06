import 'package:creador_cv/features/resumes/pdf/one_page/one_page_metrics.dart';
import 'package:creador_cv/features/resumes/pdf/one_page/one_page_plan.dart';
import 'package:creador_cv/features/resumes/pdf/one_page/one_page_sections.dart';
import 'package:creador_cv/features/resumes/pdf/professional_one_page_pdf_generator.dart';
import 'package:creador_cv/models/resume.dart';
import 'package:flutter_test/flutter_test.dart';

import 'one_page_visual_check_test.dart';

void main() {
  final metrics = OnePageMetrics.forLevel(2);

  test('ocho proyectos de altura similar se reparten cuatro y cuatro', () {
    final heights = List<double>.filled(8, 40);
    final split = splitIndexForBalance(heights);
    expect(split, 4);
    expect(heights.sublist(0, split), hasLength(4));
    expect(heights.sublist(split), hasLength(4));
  });

  test('un número impar de proyectos no parte la tarjeta del medio', () {
    final split = splitIndexForBalance(List<double>.filled(5, 20));
    expect(split, 3);
    expect(split + (5 - split), 5);
  });

  test('dieciséis certificaciones se equilibran por altura', () {
    final heights = [
      ...List<double>.filled(7, 30),
      ...List<double>.filled(9, 22),
    ];
    expect(splitIndexForBalance(heights), 7);
  });

  test('certificaciones impares conservan todos los elementos', () {
    final heights = List<double>.filled(9, 18);
    final split = splitIndexForBalance(heights);
    expect(heights.sublist(0, split).length + heights.sublist(split).length, 9);
  });

  test('certificación con institución y sin horas', () {
    final plan = OnePagePlan.fromResume(
      Resume(
        id: 'c',
        nombre: 'Ana',
        perfil: '',
        datosPersonales: const [],
        competencias: const [],
        idiomas: const [],
        experiencia: const [],
        formacion: const [],
        certifications: const [
          Certification(
            id: 'c1',
            name: 'Cloud Foundations',
            institution: 'AWS Academy',
            date: '2023',
          ),
        ],
      ),
      hasPhotoImage: false,
    );
    expect(plan.certifications.single.subtitle, 'AWS Academy');
    expect(plan.certifications.single.hours, isNull);
    expect(plan.certifications.single.trailing, '2023');
  });

  test('certificación con horas y sin institución', () {
    final plan = OnePagePlan.fromResume(
      Resume(
        id: 'c',
        nombre: 'Ana',
        perfil: '',
        datosPersonales: const [],
        competencias: const [],
        idiomas: const [],
        experiencia: const [],
        formacion: const [],
        certifications: const [
          Certification(
            id: 'c1',
            name: 'Apps con Flutter',
            description: '40 horas',
            date: '2025',
          ),
        ],
      ),
      hasPhotoImage: false,
    );
    final course = plan.certifications.single;
    expect(course.subtitle, isNull);
    expect(course.hours, '40 h');
    expect(course.paragraphs, isEmpty);
  });

  test('la duración se muestra como horas cortas junto a la institución', () {
    final plan = OnePagePlan.fromResume(
      Resume(
        id: 'c',
        nombre: 'Ana',
        perfil: '',
        datosPersonales: const [],
        competencias: const [],
        idiomas: const [],
        experiencia: const [],
        formacion: const [],
        certifications: const [
          Certification(
            id: 'c1',
            name: 'Apps con Flutter',
            institution: 'ECN LATAM Academy',
            description: '240 horas',
            date: 'may-jun 2026',
          ),
          Certification(
            id: 'c2',
            name: 'Informática Forense',
            institution: 'Academia Progenios',
            description: '6h',
            date: '2025',
          ),
        ],
      ),
      hasPhotoImage: false,
    );
    expect(plan.certifications[0].hours, '240 h');
    expect(plan.certifications[0].subtitle, 'ECN LATAM Academy');
    expect(plan.certifications[0].paragraphs, isEmpty);
    expect(plan.certifications[1].hours, '6 h');
    expect(plan.certifications[1].paragraphs, isEmpty);
  });

  test('una frase con horas no pierde palabras ni las duplica', () {
    const description = 'Curso de 40 horas con evaluación práctica.';
    final plan = OnePagePlan.fromResume(
      Resume(
        id: 'c',
        nombre: 'Ana',
        perfil: '',
        datosPersonales: const [],
        competencias: const [],
        idiomas: const [],
        experiencia: const [],
        formacion: const [],
        certifications: const [
          Certification(
            id: 'c1',
            name: 'Operación de redes',
            institution: 'Centro de formación',
            date: '2024',
            description: description,
          ),
        ],
      ),
      hasPhotoImage: false,
    );
    final course = plan.certifications.single;
    final painted = [
      course.subtitle,
      if (course.hours != null) course.hours,
      ...course.paragraphs,
    ].whereType<String>().join('\n');
    expect(course.subtitle, 'Centro de formación');
    expect(painted, contains('40 horas'));
    expect(painted, contains('Curso de'));
    expect(painted, contains('con evaluación práctica'));
    expect(painted, isNot(contains('Curso de con evaluación')));
    expect('40 horas'.allMatches(painted), hasLength(1));
    expect(course.paragraphs.single, description);
  });

  test('títulos largos aumentan la altura estimada y no se descartan', () {
    final entry = OnePageEntry(
      title:
          'Congreso Internacional de Ingeniería Aplicada y Tecnologías Innovadoras',
      paragraphs: const [
        'Descripción extensa del proyecto con alcance de producción, reportes, seguimiento y documentación técnica para una institución pública.',
      ],
    );
    final short = OnePageEntry(title: 'Nota');
    expect(
      estimateOnePageEntryHeight(entry, metrics),
      greaterThan(estimateOnePageEntryHeight(short, metrics)),
    );
    expect(entry.title, contains('Congreso'));
    expect(entry.paragraphs.single, contains('institución pública'));
  });

  test('sin idiomas no reserva la sección', () {
    final plan = OnePagePlan.fromResume(
      referenceResume().copyWith(idiomas: const []),
      hasPhotoImage: false,
    );
    expect(plan.languages, isEmpty);
    expect(plan.sidebarTitles, isNot(contains(OnePagePlan.languagesTitle)));
  });

  test('idiomas distintos quedan en una sola línea', () {
    final plan = OnePagePlan.fromResume(referenceResume(), hasPhotoImage: true);
    expect(plan.languages.map((item) => item.primary), [
      'Español — Nativo',
      'Inglés — Intermedio',
    ]);
    expect(plan.languages.every((item) => item.secondary == null), isTrue);
    expect(plan.sidebarTitles, contains(OnePagePlan.languagesTitle));
    expect(plan.mainTitles, isNot(contains(OnePagePlan.languagesTitle)));
  });

  test('secciones vacías no generan títulos', () {
    final plan = OnePagePlan.fromResume(
      referenceResume(
        projects: false,
        certifications: false,
        aptitudes: false,
      ).copyWith(idiomas: const [], competencias: const [], perfil: ''),
      hasPhotoImage: false,
    );
    expect(plan.projects, isEmpty);
    expect(plan.certifications, isEmpty);
    expect(plan.aptitudes, isEmpty);
    expect(plan.languages, isEmpty);
    expect(plan.skills, isEmpty);
    expect(plan.summary, isNull);
    expect(plan.sidebarTitles, isEmpty);
    expect(plan.mainTitles, contains(OnePagePlan.experienceTitle));
  });

  test(
    'el CV de referencia conserva proyectos y certificaciones sin duplicar',
    () async {
      final resume = referenceResume();
      final result = await buildProfessionalOnePage(resume);
      expect(result.pageCount, 2);
      expect(result.summaryInSidebar, isTrue);
      expect(result.plan.projects, hasLength(8));
      expect(result.plan.certifications, hasLength(8));
      expect(
        result.plan.projects.map((item) => item.title).toSet(),
        hasLength(8),
      );
      expect(
        result.plan.certifications.map((item) => item.title).toSet(),
        hasLength(8),
      );
      expect(result.metrics.nameSize, 20);
      expect(result.metrics.bodySize, 9.5);
      final split = splitIndexForBalance([
        for (final project in result.plan.projects)
          estimateOnePageEntryHeight(project, result.metrics),
      ]);
      expect(split, inInclusiveRange(3, 5));
    },
  );
}
