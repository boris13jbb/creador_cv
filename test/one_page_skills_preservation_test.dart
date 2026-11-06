import 'dart:io';

import 'package:creador_cv/features/resumes/pdf/one_page/one_page_plan.dart';
import 'package:creador_cv/features/resumes/pdf/professional_one_page_pdf_generator.dart';
import 'package:creador_cv/features/resumes/pdf/resume_pdf_service.dart';
import 'package:creador_cv/models/resume.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';

import 'pdf_text_extract.dart';

Resume _baseOnePage({
  List<Skill> competencias = const [],
  int experiencias = 2,
  String perfil = 'Ingeniera de software con 8 años de experiencia.',
}) {
  return Resume(
    id: 'one-page-skills',
    nombre: 'Ana Pérez',
    perfil: perfil,
    datosPersonales: const [
      PersonalData(label: 'Email', value: 'ana@empresa.com', icon: 'email'),
      PersonalData(label: 'Teléfono', value: '+34 600 000 000', icon: 'phone'),
      PersonalData(
        label: 'Profesión',
        value: 'Ingeniera de Software',
        icon: 'work',
      ),
    ],
    competencias: competencias,
    idiomas: const [Skill(nombre: 'Español', nivel: 5)],
    experiencia: List.generate(
      experiencias,
      (i) => Experience(
        cargo: 'Dev $i',
        empresa: 'Empresa $i',
        periodo: '202$i - Actual',
        logros: ['Logro A del puesto $i.', 'Logro B del puesto $i.'],
      ),
    ),
    formacion: const [
      Education(
        titulo: 'Ingeniería Informática',
        institucion: 'Universidad',
        anio: '2016',
      ),
    ],
    projects: [
      Project(
        id: 'p0',
        name: 'Proyecto Alpha',
        description: 'Descripción del proyecto Alpha.',
        technologies: const ['Flutter'],
        startDate: '2022',
      ),
    ],
    certifications: [
      Certification(
        id: 'c0',
        name: 'Certificación Beta',
        institution: 'Academia',
        date: '2023',
        description: '40 horas',
      ),
    ],
    colorHex: 0xFF0F766E,
    designIndex: 4,
  );
}

Resume _denseWithMarkers() {
  return _baseOnePage(
    perfil: 'Ingeniera de software con 8 años de experiencia. ' * 8,
    experiencias: 6,
    competencias: [
      for (var i = 1; i <= 6; i++)
        Skill(
          nombre:
              'HABILIDAD_TEST_0$i: dominio práctico extendido en herramientas de planta',
          nivel: 4,
        ),
      ...List.generate(
        9,
        (i) => Skill(
          nombre: i.isEven
              ? 'Competencia $i: detalle técnico aplicado en planta'
              : 'NombreExtremadamenteLargoDeCompetenciaSinEspacios$i',
          nivel: 3,
        ),
      ),
      Skill(
        nombre: 'Categoría: ${'descripción extensa de competencia. ' * 40}',
        nivel: 5,
      ),
    ],
  ).copyWith(
    aptitudes: [
      for (var i = 0; i < 10; i++)
        Aptitude(
          id: 'a$i',
          name: 'Aptitud profesional $i con criterio de equipo y seguimiento',
        ),
    ],
    idiomas: const [
      Skill(nombre: 'Español', nivel: 5),
      Skill(nombre: 'Inglés', nivel: 4),
    ],
    projects: [
      for (var i = 0; i < 3; i++)
        Project(
          id: 'p$i',
          name: 'Proyecto $i',
          description: 'Descripción del proyecto $i con alcance amplio.',
          technologies: const ['Flutter', 'SQL'],
          startDate: '202$i',
        ),
    ],
    certifications: [
      for (var i = 0; i < 3; i++)
        Certification(
          id: 'c$i',
          name: 'Cert $i',
          institution: 'Academia',
          date: '202$i',
          description: '40 horas',
        ),
    ],
  );
}

void _expectA4(OnePagePdfResult result, {int? minPages}) {
  expect(result.bytes[0], 0x25);
  expect(result.pageCount, greaterThanOrEqualTo(minPages ?? 2));
  for (final width in result.pageWidths) {
    expect(width, closeTo(PdfPageFormat.a4.width, 0.5));
  }
  for (final height in result.pageHeights) {
    expect(height, closeTo(PdfPageFormat.a4.height, 0.5));
  }
}

Future<String> _requirePdfText(
  List<int> bytes, {
  required String saveAs,
}) async {
  final text = await extractPdfTextWithPyMuPdf(bytes, saveAs: saveAs);
  expect(
    text,
    isNotNull,
    reason: 'Se requiere Python + PyMuPDF para verificar el texto del PDF.',
  );
  return text!;
}

void main() {
  group('One Page preserva Habilidades', () {
    test('cero habilidades no muestra la sección ni falla', () async {
      final result = await buildProfessionalOnePage(
        _baseOnePage(competencias: const []),
      );
      _expectA4(result);
      expect(result.plan.skills, isEmpty);
      final text = await _requirePdfText(
        result.bytes,
        saveAs: 'build/one_page_skills_zero.pdf',
      );
      expect(text.contains('HABILIDADES'), isFalse);
      expect(text.contains('Proyecto Alpha'), isTrue);
      expect(text.contains('Beta'), isTrue);
    });

    test('una habilidad aparece y el documento es A4 x2+', () async {
      final result = await buildProfessionalOnePage(
        _baseOnePage(
          competencias: const [Skill(nombre: 'HABILIDAD_TEST_SOLO', nivel: 5)],
        ),
      );
      _expectA4(result);
      expect(result.plan.skills, hasLength(1));
      final text = await _requirePdfText(
        result.bytes,
        saveAs: 'build/one_page_skills_one.pdf',
      );
      final collapsed = collapsePdfText(text);
      expect(text.contains('HABILIDADES'), isTrue);
      expect(collapsed.contains('HABILIDAD_TEST_SOLO'), isTrue);
      expect('HABILIDAD_TEST_SOLO'.allMatches(collapsed).length, 1);
    });

    test('varias habilidades e impar conservan orden y contenido', () async {
      final skills = [
        for (var i = 1; i <= 5; i++)
          Skill(nombre: 'HABILIDAD_TEST_0$i', nivel: 4),
      ];
      final result = await buildProfessionalOnePage(
        _baseOnePage(competencias: skills),
      );
      _expectA4(result);
      expect(result.plan.skills, hasLength(5));
      final text = await _requirePdfText(
        result.bytes,
        saveAs: 'build/one_page_skills_odd.pdf',
      );
      final collapsed = collapsePdfText(text);
      for (var i = 1; i <= 5; i++) {
        expect(collapsed.contains('HABILIDAD_TEST_0$i'), isTrue);
        expect('HABILIDAD_TEST_0$i'.allMatches(collapsed).length, 1);
      }
    });

    test(
      'CV denso conserva todas las HABILIDAD_TEST_* y no las duplica',
      () async {
        final resume = _denseWithMarkers();
        final result = await buildProfessionalOnePage(resume);
        _expectA4(result);
        expect(result.plan.skills, hasLength(16));

        Directory('build').createSync(recursive: true);
        File(
          'build/habilidades_dense_repro.pdf',
        ).writeAsBytesSync(result.bytes);

        final text = await _requirePdfText(
          result.bytes,
          saveAs: 'build/one_page_skills_dense.pdf',
        );
        final collapsed = collapsePdfText(text);

        expect(text.contains('HABILIDADES'), isTrue);
        final markers = [for (var i = 1; i <= 6; i++) 'HABILIDAD_TEST_0$i'];
        for (final marker in markers) {
          expect(
            collapsed.contains(marker),
            isTrue,
            reason: 'Falta $marker en el PDF denso',
          );
          expect(
            marker.allMatches(collapsed).length,
            1,
            reason: 'Duplicado inesperado de $marker',
          );
        }
        expect(collapsed.contains('Competencia8'), isTrue);
        expect(collapsed.contains('Categor'), isTrue);
        expect(text.contains('Proyecto'), isTrue);
        expect(text.contains('Cert'), isTrue);
      },
    );

    test('servicio ResumePdfService One Page denso no omite marcas', () async {
      final bytes = await ResumePdfService.generateResumePdf(
        _denseWithMarkers(),
        isPro: true,
      );
      expect(bytes.length, greaterThan(1500));
      final text = await _requirePdfText(
        bytes,
        saveAs: 'build/one_page_skills_dense_service.pdf',
      );
      final collapsed = collapsePdfText(text);
      for (var i = 1; i <= 6; i++) {
        expect(collapsed.contains('HABILIDAD_TEST_0$i'), isTrue);
      }
      expect(OnePagePlan.skillsTitle.toUpperCase(), 'HABILIDADES');
    });
  });
}
