import 'package:creador_cv/features/resumes/pdf/classic_pdf_generator.dart';
import 'package:creador_cv/features/resumes/pdf/creative_pdf_generator.dart';
import 'package:creador_cv/features/resumes/pdf/executive_pdf_generator.dart';
import 'package:creador_cv/features/resumes/pdf/modern_pdf_generator.dart';
import 'package:creador_cv/features/resumes/pdf/one_page/one_page_plan.dart';
import 'package:creador_cv/features/resumes/pdf/professional_one_page_pdf_generator.dart';
import 'package:creador_cv/models/resume.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';

import 'one_page_visual_check_test.dart';
import 'pdf_text_extract.dart';

const _visibleId = 'CRED-VISIBLE-4410';
const _spacedId = 'CRED  INTERNO-91';
const _longId = 'CRED-LARGO-7781-QX-SECTOR-NORTE-UNICO-2024';

Resume _resume({
  String? credentialId,
  String name = 'Curso de prueba',
  String description = 'Descripción del curso de prueba.',
}) {
  return Resume(
    id: 'cv-credencial',
    nombre: 'Persona de prueba',
    perfil: 'Perfil ficticio para comprobar el identificador.',
    datosPersonales: const [
      PersonalData(label: 'Email', value: 'persona@example.com', icon: 'email'),
    ],
    competencias: const [],
    idiomas: const [],
    experiencia: const [
      Experience(
        cargo: 'Cargo de prueba',
        empresa: 'Empresa de prueba',
        periodo: '2020 - 2024',
        logros: ['Logro de prueba.'],
      ),
    ],
    formacion: const [
      Education(
        titulo: 'Título de prueba',
        institucion: 'Instituto de prueba',
        anio: '2019',
      ),
    ],
    certifications: [
      Certification(
        id: 'c1',
        name: name,
        institution: 'Centro de prueba',
        date: '2024',
        expirationDate: '2027',
        credentialId: credentialId,
        credentialUrl: 'https://example.com/verificar',
        description: description,
      ),
      const Certification(
        id: 'c2',
        name: 'Curso sin identificador',
        institution: 'Otro centro',
        date: '2023',
        credentialId: '   ',
      ),
    ],
    designIndex: 4,
  );
}

void main() {
  test('muestra el identificador solo cuando tiene texto', () {
    expect(onePageCredentialLine(null), isNull);
    expect(onePageCredentialLine(''), isNull);
    expect(onePageCredentialLine('   '), isNull);
    expect(
      onePageCredentialLine('  $_visibleId  '),
      'Credential ID: $_visibleId',
    );
    expect(onePageCredentialLine(_spacedId), 'Credential ID: $_spacedId');
  });

  test('One Page conserva el identificador sin confundirlo ni duplicarlo', () {
    final plan = OnePagePlan.fromResume(
      _resume(credentialId: '  $_longId  '),
      hasPhotoImage: false,
    );

    expect(plan.certifications, hasLength(2));
    final withId = plan.certifications.first;
    final withoutId = plan.certifications.last;

    expect(withId.title, 'Curso de prueba');
    expect(withId.subtitle, 'Centro de prueba');
    expect(withId.hours, isNull);
    expect(withId.paragraphs.where((line) => line.contains(_longId)), [
      'Credential ID: $_longId',
    ]);
    expect(withId.paragraphs, contains('Vence: 2027'));
    expect(withId.paragraphs, contains('example.com/verificar'));
    expect(withId.paragraphs, contains('Descripción del curso de prueba.'));
    expect(
      withoutId.paragraphs.any((line) => line.contains('Credential ID')),
      isFalse,
    );
  });

  test('una certificación larga conserva nombre e identificador', () {
    const longName =
        'Programa ficticio de arquitectura de software y verificación documental';
    final plan = OnePagePlan.fromResume(
      _resume(credentialId: _longId, name: longName),
      hasPhotoImage: false,
    );
    final entry = plan.certifications.first;
    expect(entry.title, longName);
    expect(entry.paragraphs, contains('Credential ID: $_longId'));
  });

  test('las cinco plantillas imprimen el identificador una sola vez', () async {
    final resume = _resume(credentialId: _visibleId);
    final generators = <int, Future<List<int>> Function(Resume)>{
      0: (item) => generateClassicPdf(item.copyWith(designIndex: 0)),
      1: (item) => generateModernPdf(item.copyWith(designIndex: 1)),
      2: (item) => generateExecutivePdf(item.copyWith(designIndex: 2)),
      3: (item) => generateCreativePdf(item.copyWith(designIndex: 3)),
      4: (item) =>
          generateProfessionalOnePagePdf(item.copyWith(designIndex: 4)),
    };

    for (final entry in generators.entries) {
      final bytes = await entry.value(resume);
      final text = await extractPdfTextWithPyMuPdf(
        bytes,
        saveAs: 'build/credential_design_${entry.key}.pdf',
      );
      expect(text, isNotNull, reason: 'plantilla ${entry.key}');
      final collapsed = collapsePdfText(text!);
      expect(collapsed.split(_visibleId).length - 1, 1);
      expect(collapsed.contains('CredentialID:$_visibleId'), isTrue);
      expect(collapsed.contains('Cursosinidentificador'), isTrue);
    }
  });

  test('sin identificador útil no imprime el rótulo', () async {
    final bytes = await generateProfessionalOnePagePdf(
      _resume(credentialId: ' \n '),
    );
    final text = await extractPdfTextWithPyMuPdf(
      bytes,
      saveAs: 'build/credential_empty.pdf',
    );
    expect(text, isNotNull);
    expect(collapsePdfText(text!).contains('CredentialID'), isFalse);
  });

  test('el fixture denso sigue en dos páginas A4', () async {
    final base = referenceResume();
    final withId = base.copyWith(
      certifications: [
        for (var i = 0; i < base.certifications.length; i++)
          i == 0
              ? base.certifications[i].copyWith(credentialId: 'CRED-DENSO-1001')
              : base.certifications[i],
      ],
    );
    final plain = await buildProfessionalOnePage(base);
    final marked = await buildProfessionalOnePage(withId);

    for (final result in [plain, marked]) {
      expect(result.pageCount, 2);
      expect(result.pageWidths, hasLength(2));
      expect(result.pageHeights, hasLength(2));
      for (final width in result.pageWidths) {
        expect(width, closeTo(PdfPageFormat.a4.width, 0.2));
      }
      for (final height in result.pageHeights) {
        expect(height, closeTo(PdfPageFormat.a4.height, 0.2));
      }
    }

    final text = await extractPdfTextWithPyMuPdf(
      marked.bytes,
      saveAs: 'build/credential_dense.pdf',
    );
    expect(collapsePdfText(text!).split('CRED-DENSO-1001').length - 1, 1);
  });
}
