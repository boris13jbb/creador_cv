import 'dart:typed_data';

import 'package:creador_cv/features/resumes/pdf/professional_one_page_pdf_generator.dart';
import 'package:creador_cv/features/resumes/pdf/resume_pdf_service.dart';
import 'package:creador_cv/features/resumes/pdf/one_page/one_page_metrics.dart';
import 'package:creador_cv/features/resumes/pdf/one_page/one_page_plan.dart';
import 'package:creador_cv/models/resume.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';

Resume _base({
  String nombre = 'Ana Pérez',
  String perfil = '',
  List<PersonalData> datos = const [],
  List<Skill> competencias = const [],
  List<Skill> idiomas = const [],
  List<Experience> experiencia = const [],
  List<Education> formacion = const [],
  List<Project> projects = const [],
  List<Certification> certifications = const [],
  List<Aptitude> aptitudes = const [],
  Uint8List? fotoBytes,
  bool ocultarFoto = false,
  int colorHex = 0xFF0E7490,
}) {
  return Resume(
    id: 'one-page',
    nombre: nombre,
    perfil: perfil,
    datosPersonales: datos,
    competencias: competencias,
    idiomas: idiomas,
    experiencia: experiencia,
    formacion: formacion,
    projects: projects,
    certifications: certifications,
    aptitudes: aptitudes,
    fotoBytes: fotoBytes,
    ocultarFoto: ocultarFoto,
    colorHex: colorHex,
    designIndex: 4,
  );
}

Resume _minimal() {
  return _base(
    datos: const [
      PersonalData(label: 'Email', value: 'ana@empresa.com', icon: 'email'),
      PersonalData(label: 'Teléfono', value: '+593 99 000 0000', icon: 'phone'),
    ],
    formacion: const [
      Education(
        titulo: 'Ingeniería en Sistemas',
        institucion: 'Universidad Técnica',
        anio: '2018',
      ),
    ],
  );
}

Resume _complete({Uint8List? fotoBytes, int certifications = 6}) {
  return _base(
    nombre: 'Juan Gabriel Burbano Bonifaz',
    perfil:
        'Ingeniero en Tecnologías de la Información con más de 10 años de experiencia en el sector industrial textil, combinando soporte técnico de producción con formación continua y práctica activa en desarrollo de software.',
    datos: const [
      PersonalData(
        label: 'Profesión',
        value: 'Ingeniero en Tecnologías de la Información',
        icon: 'work',
      ),
      PersonalData(label: 'Ubicación', value: 'Ecuador', icon: 'place'),
      PersonalData(label: 'Teléfono', value: '+5939999112007', icon: 'phone'),
      PersonalData(
        label: 'Email',
        value: 'boris13jbb@gmail.com',
        icon: 'email',
      ),
    ],
    competencias: const [
      Skill(nombre: 'Flutter: aplicaciones móviles y escritorio', nivel: 5),
      Skill(nombre: 'Firebase', nivel: 4),
      Skill(nombre: 'SQL', nivel: 4),
    ],
    idiomas: const [
      Skill(nombre: 'Español', nivel: 5),
      Skill(nombre: 'Inglés', nivel: 3),
    ],
    experiencia: const [
      Experience(
        cargo: 'Desarrollador independiente',
        empresa: 'Práctica profesional',
        periodo: '2016 - Actual',
        logros: [
          'Desarrollo de aplicaciones y herramientas con buenas prácticas.',
          'Integración de APIs y seguimiento de avances.',
        ],
      ),
    ],
    formacion: const [
      Education(
        titulo: 'Ingeniero en Tecnologías de la Información',
        institucion: 'Universidad Técnica del Norte',
        anio: '2016',
      ),
      Education(
        titulo: 'Bachiller en Ciencias de Comercio',
        institucion: 'Colegio Nacional Calacalí',
        anio: '2008',
      ),
    ],
    projects: const [
      Project(
        id: 'p1',
        name: 'CotaPro',
        description:
            'Aplicación Flutter para generación de cotizaciones y presupuestos.',
        technologies: ['Flutter', 'Drift'],
        startDate: '2024',
        isOngoing: true,
      ),
      Project(
        id: 'p2',
        name: 'NotaPro',
        description: 'Aplicación de escritorio para gestión de notas.',
        technologies: ['Flutter', 'SQLite'],
        startDate: '2023',
        endDate: '2024',
      ),
      Project(
        id: 'p3',
        name: 'Control de Desperdicios',
        description:
            'Formulario VBA para Excel orientado al control de desperdicios textiles.',
        technologies: ['VBA', 'Excel'],
        startDate: '2022',
        endDate: '2023',
      ),
    ],
    certifications: [
      for (var i = 0; i < certifications; i++)
        Certification(
          id: 'c$i',
          name: 'Certificación profesional $i',
          institution: 'Academia $i',
          date: '202${i % 6}',
        ),
    ],
    aptitudes: const [
      Aptitude(id: 'a1', name: 'Proactivo y comprometido'),
      Aptitude(id: 'a2', name: 'Trabajo en equipo'),
      Aptitude(id: 'a3', name: 'Comunicación'),
      Aptitude(id: 'a4', name: 'Adaptabilidad'),
    ],
    fotoBytes: fotoBytes,
  );
}

Uint8List _jpeg() {
  final image = img.Image(width: 48, height: 48);
  img.fill(image, color: img.ColorRgb8(20, 90, 140));
  return Uint8List.fromList(img.encodeJpg(image));
}

void main() {
  test('CV mínimo cabe en una página A4', () async {
    final result = await buildProfessionalOnePage(_minimal());
    expect(result.bytes[0], 0x25);
    expect(result.pageCount, 1);
    expect(result.pageWidth, closeTo(PdfPageFormat.a4.width, 0.2));
    expect(result.pageHeight, closeTo(PdfPageFormat.a4.height, 0.2));
    expect(result.metrics.level, 1);
    expect(result.plan.mainTitles, isNot(contains(OnePagePlan.projectsTitle)));
    expect(
      result.plan.mainTitles,
      isNot(contains(OnePagePlan.certificationsTitle)),
    );
    expect(result.plan.showPhoto, isFalse);
    expect(result.plan.titlesHaveLead, isTrue);
  });

  test('CV profesional completo cabe en una página', () async {
    final result = await buildProfessionalOnePage(
      _complete(fotoBytes: _jpeg()),
    );
    expect(result.pageCount, 1);
    expect(result.plan.showPhoto, isTrue);
    expect(
      result.plan.profession,
      'Ingeniero en Tecnologías de la Información',
    );
    expect(result.plan.sidebarTitles, contains(OnePagePlan.summaryTitle));
    expect(result.plan.sidebarTitles, contains(OnePagePlan.aptitudesTitle));
    expect(result.plan.sidebarTitles, contains(OnePagePlan.skillsTitle));
    expect(result.plan.mainTitles, contains(OnePagePlan.projectsTitle));
    expect(result.plan.mainTitles, contains(OnePagePlan.experienceTitle));
    expect(result.plan.mainTitles, contains(OnePagePlan.educationTitle));
    expect(result.plan.mainTitles, contains(OnePagePlan.certificationsTitle));
    expect(result.plan.mainTitles, contains(OnePagePlan.languagesTitle));
    expect(result.metrics.meetsReadability, isTrue);
    expect(
      result.plan.contactLines,
      isNot(contains('Ingeniero en Tecnologías de la Información')),
    );
  });

  test('sin proyectos ni certificaciones no reserva esas secciones', () {
    final plan = OnePagePlan.fromResume(_minimal(), hasPhotoImage: false);
    expect(plan.projects, isEmpty);
    expect(plan.certifications, isEmpty);
    expect(plan.mainTitles, [OnePagePlan.educationTitle]);
  });

  test('sin foto no activa el bloque de fotografía', () {
    final plan = OnePagePlan.fromResume(
      _complete(
        fotoBytes: _jpeg(),
        certifications: 1,
      ).copyWith(ocultarFoto: true),
      hasPhotoImage: true,
    );
    expect(plan.showPhoto, isFalse);
  });

  test('con foto el PDF cambia y conserva la sección', () async {
    final without = await buildProfessionalOnePage(
      _complete(certifications: 2),
    );
    final withPhoto = await buildProfessionalOnePage(
      _complete(fotoBytes: _jpeg(), certifications: 2),
    );
    expect(withPhoto.plan.showPhoto, isTrue);
    expect(without.plan.showPhoto, isFalse);
    expect(withPhoto.bytes.length, greaterThan(without.bytes.length));
    expect(withPhoto.pageCount, 1);
  });

  test('texto largo no lanza y no baja del piso de legibilidad', () async {
    final long = _complete().copyWith(
      perfil: 'Experiencia amplia en producción y software. ' * 80,
      experiencia: [
        Experience(
          cargo: 'Líder de plataforma',
          empresa: 'Operación textil',
          periodo: '2014 - 2024',
          logros: [
            'Coordinación de mejoras continuas en planta y en sistemas. ' * 12,
            'Acompañamiento a equipos de producción y soporte. ' * 8,
          ],
        ),
      ],
    );
    final result = await buildProfessionalOnePage(long);
    expect(result.bytes.length, greaterThan(500));
    expect(result.metrics.meetsReadability, isTrue);
    expect(result.plan.summary, contains('Experiencia amplia'));
    if (result.pageCount > 1) {
      expect(result.metrics.level, OnePageMetrics.maxLevel);
    }
  });

  test('muchas certificaciones compactan respecto de un CV corto', () async {
    final light = await buildProfessionalOnePage(_minimal());
    final heavy = await buildProfessionalOnePage(
      _complete(certifications: 18).copyWith(
        projects: List.generate(
          6,
          (i) => Project(
            id: 'p$i',
            name: 'Proyecto de operación $i',
            description:
                'Descripción funcional del proyecto $i con alcance de producción, reportes y seguimiento.',
            technologies: const ['Flutter', 'Firebase'],
            startDate: '202$i',
          ),
        ),
      ),
    );
    expect(heavy.metrics.meetsReadability, isTrue);
    expect(
      heavy.metrics.level > light.metrics.level || heavy.pageCount > 1,
      isTrue,
    );
    if (heavy.pageCount > 1) {
      expect(heavy.metrics.level, OnePageMetrics.maxLevel);
    }
  });

  test('competencias y aptitudes son texto, no chips', () {
    final plan = OnePagePlan.fromResume(_complete(), hasPhotoImage: false);
    expect(OnePagePlan.skillPresentation, OnePagePresentation.text);
    expect(OnePagePlan.aptitudePresentation, OnePagePresentation.text);
    expect(OnePagePlan.languagePresentation, OnePagePresentation.text);
    expect(plan.skills.first.primary, 'Flutter');
    expect(plan.skills.first.secondary, contains('aplicaciones móviles'));
    expect(plan.aptitudes.first.primary, 'Proactivo y comprometido');
    expect(plan.titlesHaveLead, isTrue);
  });

  test('preview y PDF usan el mismo generador', () async {
    final resume = _complete(certifications: 3);
    final direct = await buildProfessionalOnePage(resume);
    final viaService = await ResumePdfService.generateResumePdf(
      resume,
      isPro: true,
    );
    expect(viaService[0], 0x25);
    expect(direct.pageCount, 1);
    expect(viaService.length, greaterThan(2000));
    final classic = await ResumePdfService.generateResumePdf(
      resume.copyWith(designIndex: 0),
      isPro: true,
    );
    expect(viaService.length, isNot(classic.length));
  });

  test('el ancho de sidebar es el 32 por ciento de A4', () {
    final sidebar = PdfPageFormat.a4.width * OnePageMetrics.sidebarFraction;
    final main = PdfPageFormat.a4.width - sidebar;
    expect(sidebar / PdfPageFormat.a4.width, closeTo(0.32, 0.001));
    expect(main / PdfPageFormat.a4.width, closeTo(0.68, 0.001));
  });
}
