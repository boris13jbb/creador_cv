import 'dart:io';
import 'dart:typed_data';

import 'package:creador_cv/features/resumes/pdf/professional_one_page_pdf_generator.dart';
import 'package:creador_cv/features/resumes/pdf/resume_pdf_service.dart';
import 'package:creador_cv/models/resume.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';

/// CV equivalente al de la referencia visual: todas las secciones con texto real.
Resume referenceResume({
  bool photo = true,
  bool projects = true,
  bool certifications = true,
  bool aptitudes = true,
  bool profession = true,
}) {
  return Resume(
    id: 'visual-one-page',
    nombre: 'Juan Gabriel Burbano Bonifaz',
    perfil:
        'Ingeniero en Tecnologías de la Información con más de 10 años de experiencia en el sector industrial textil, combinando soporte técnico de producción con formación continua y práctica activa en desarrollo de software (aplicaciones móviles, web y de escritorio). Proactivo, comprometido con el trabajo en equipo y con una sólida trayectoria de aprendizaje autodidacta en tecnologías emergentes como inteligencia artificial aplicada, cloud computing y ciberseguridad. Busco seguir profesionalizándome y aportando al desarrollo de software.',
    datosPersonales: [
      if (profession)
        const PersonalData(
          label: 'Profesión',
          value: 'Ingeniero en Tecnologías de la Información',
          icon: 'work',
        ),
      const PersonalData(label: 'Ubicación', value: 'Ecuador', icon: 'place'),
      const PersonalData(
        label: 'Teléfono',
        value: '+5939999112007',
        icon: 'phone',
      ),
      const PersonalData(
        label: 'Email',
        value: 'boris13jbb@gmail.com',
        icon: 'email',
      ),
    ],
    competencias: const [
      Skill(nombre: 'Flutter: móvil, escritorio y web', nivel: 5),
      Skill(nombre: 'Firebase y Supabase', nivel: 4),
      Skill(nombre: 'SQL y modelado de datos', nivel: 4),
      Skill(nombre: 'Python y automatización', nivel: 3),
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
          'Desarrollo de aplicaciones y herramientas, aplicando buenas prácticas y tecnologías modernas.',
          'Integración de APIs, bases locales y sincronización para seguimiento de procesos.',
        ],
      ),
    ],
    formacion: const [
      Education(
        titulo: 'Ingeniero en Tecnologías de la Información',
        institucion: 'Universidad Técnica del Norte (UTN), Ibarra, Ecuador',
        anio: '2016',
      ),
      Education(
        titulo: 'Bachiller en Ciencias de Comercio y Administración',
        institucion: 'Colegio Nacional Calacalí',
        anio: '2008',
      ),
    ],
    projects: projects
        ? const [
            Project(
              id: 'p1',
              name: 'CotaPro',
              description:
                  'Aplicación Flutter para generación de cotizaciones y presupuestos.',
              technologies: ['Flutter'],
              startDate: '2024',
              isOngoing: true,
            ),
            Project(
              id: 'p2',
              name: 'NotaPro',
              description:
                  'Aplicación de escritorio (Windows) en Flutter para gestión de notas, con autenticación Supabase, almacenamiento offline-first (Drift/SQLite) y sincronización en la nube.',
              technologies: ['Flutter', 'Supabase', 'Drift'],
              startDate: '2023',
              endDate: '2024',
            ),
            Project(
              id: 'p3',
              name: 'Control de Desperdicios',
              description:
                  'Formulario VBA para Excel orientado al control de desperdicios textiles (tela, plástico y cartón) por turnos de producción.',
              technologies: ['VBA', 'Excel'],
              startDate: '2022',
              endDate: '2023',
            ),
            Project(
              id: 'p4',
              name: 'App de detección de defectos en tela',
              description:
                  'Aplicación Flutter (Android/iOS) con TensorFlow Lite para detección automática de defectos en denim.',
              technologies: ['Flutter', 'TensorFlow Lite'],
              startDate: '2023',
              endDate: '2024',
            ),
            Project(
              id: 'p5',
              name: 'Aplicación de nómina y roles de pago',
              description:
                  'Módulo de configuración y sincronización (Drift ORM, integración con Gmail) para gestión laboral.',
              technologies: ['Flutter', 'Drift'],
              startDate: '2022',
              endDate: '2023',
            ),
            Project(
              id: 'p6',
              name: 'CotaForge Academy',
              description:
                  'Visor de lecciones e-learning en HTML, con integración de YouTube API y seguimiento de progreso.',
              technologies: ['HTML', 'YouTube API'],
              startDate: '2024',
              endDate: '2025',
            ),
            Project(
              id: 'p7',
              name: 'Remontando',
              description:
                  'Juego multijugador de preguntas y respuestas en tiempo real con Socket.io.',
              technologies: ['Socket.io'],
              startDate: '2021',
              endDate: '2022',
            ),
            Project(
              id: 'p8',
              name: 'Sistema de gestión documental institucional',
              description:
                  'Expediente técnico para plataforma web (Laravel, Vue.js, PostgreSQL) para una institución pública del Ecuador.',
              technologies: ['Laravel', 'Vue.js', 'PostgreSQL'],
              startDate: '2020',
              endDate: '2021',
            ),
          ]
        : const [],
    certifications: certifications
        ? const [
            Certification(
              id: 'c1',
              name: 'Desarrollo de Apps Móviles usando IA + Flutter',
              institution: 'ECN LATAM Academy',
              date: 'May 2026 - Ene 2026',
            ),
            Certification(
              id: 'c2',
              name:
                  'Programa «10.000 Prompters Ecuador» (ingeniería de prompts en IA)',
              institution: 'Gobierno del Ecuador y Emiratos Árabes Unidos',
              date: '2025',
            ),
            Certification(
              id: 'c3',
              name:
                  'Congreso Internacional de Ingeniería Aplicada y Tecnologías Innovadoras (AENIT 2024)',
              institution: 'Universidad Técnica del Norte',
              date: '2024',
            ),
            Certification(
              id: 'c4',
              name: 'AWS Academy Graduate — AWS Academy Cloud Foundations',
              institution: 'AWS Academy',
              date: 'Ene 2023 - Jun 2023',
            ),
            Certification(
              id: 'c5',
              name: 'AWS Academy Graduate — Introduction to Cloud, Semestre 1',
              institution: 'AWS Academy',
              date: '2023',
            ),
            Certification(
              id: 'c6',
              name: 'AWS Academy Graduate — Introduction to Cloud, Semestre 2',
              institution: 'AWS Academy',
              date: '2023',
            ),
            Certification(
              id: 'c7',
              name: 'Fundamentos de Programación',
              institution: 'Formación continua',
              date: 'Ene 2021 - Dic 2021',
            ),
            Certification(
              id: 'c8',
              name: 'Introducción a la Seguridad Cibernética',
              institution: 'Cisco Networking Academy',
              date: 'Ene 2022 - Mar 2022',
            ),
          ]
        : const [],
    aptitudes: aptitudes
        ? const [
            Aptitude(
              id: 'a1',
              name: 'Proactivo y comprometido con los objetivos del equipo',
            ),
            Aptitude(
              id: 'a2',
              name: 'Trabajo en equipo, cooperación y compañerismo',
            ),
            Aptitude(
              id: 'a3',
              name: 'Puntualidad y adaptación rápida al ambiente laboral',
            ),
            Aptitude(
              id: 'a4',
              name: 'Comunicación clara y aprendizaje continuo',
            ),
          ]
        : const [],
    fotoBytes: photo ? _portrait() : null,
    colorHex: 0xFF0E7490,
    designIndex: 4,
  );
}

Uint8List _portrait() {
  final image = img.Image(width: 360, height: 360);
  img.fill(image, color: img.ColorRgb8(186, 198, 208));
  img.fillRect(
    image,
    x1: 0,
    y1: 210,
    x2: 359,
    y2: 359,
    color: img.ColorRgb8(28, 42, 58),
  );
  img.fillCircle(
    image,
    x: 180,
    y: 132,
    radius: 62,
    color: img.ColorRgb8(196, 156, 124),
  );
  return Uint8List.fromList(img.encodeJpg(image, quality: 85));
}

Future<void> _write(
  String name,
  Resume resume, {
  List<String> absentTitles = const [],
  bool expectPhoto = true,
  bool expectProfession = true,
}) async {
  final result = await buildProfessionalOnePage(resume);
  final via = await ResumePdfService.generateResumePdf(resume, isPro: true);
  File('build/$name.pdf').writeAsBytesSync(result.bytes);
  // ignore: avoid_print
  print(
    '$name pages=${result.pageCount} '
    'pt=${result.pageWidth.toStringAsFixed(2)}x${result.pageHeight.toStringAsFixed(2)} '
    'a4=${PdfPageFormat.a4.width.toStringAsFixed(2)}x${PdfPageFormat.a4.height.toStringAsFixed(2)} '
    'level=${result.metrics.level} '
    'body=${result.metrics.bodySize} title=${result.metrics.sectionSize} name=${result.metrics.nameSize} '
    'photo=${result.plan.showPhoto} '
    'titles=${result.plan.sidebarTitles.join("|")} / ${result.plan.mainTitles.join("|")} '
    'profession=${result.plan.profession ?? "-"} '
    'serviceBytes=${via.length} directBytes=${result.bytes.length}',
  );
  expect(result.pageCount, 1);
  expect(result.pageWidth, closeTo(PdfPageFormat.a4.width, 0.2));
  expect(result.pageHeight, closeTo(PdfPageFormat.a4.height, 0.2));
  expect(result.metrics.meetsReadability, isTrue);
  expect(via.length, result.bytes.length);
  expect(result.plan.showPhoto, expectPhoto);
  expect(result.plan.profession != null, expectProfession);
  final titles = [...result.plan.sidebarTitles, ...result.plan.mainTitles];
  for (final title in absentTitles) {
    expect(titles, isNot(contains(title)));
  }
}

void main() {
  test('validación visual One Page con CV de referencia', () async {
    await _write('one_page_full', referenceResume());
    await _write(
      'one_page_no_projects',
      referenceResume(projects: false),
      absentTitles: const ['Proyectos'],
    );
    await _write(
      'one_page_no_certs',
      referenceResume(certifications: false),
      absentTitles: const ['Certificaciones y cursos'],
    );
    await _write(
      'one_page_no_photo',
      referenceResume(photo: false),
      expectPhoto: false,
    );
    await _write(
      'one_page_no_aptitudes',
      referenceResume(aptitudes: false),
      absentTitles: const ['Aptitudes'],
    );
    await _write(
      'one_page_no_profession',
      referenceResume(profession: false),
      expectProfession: false,
    );
  });
}
