import 'package:creador_cv/features/templates/cv_templates.dart';
import 'package:creador_cv/features/resumes/pdf/resume_pdf_service.dart';
import 'package:creador_cv/models/resume.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
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
        ],
        certifications: const [
          Certification(
            id: 'c1',
            name: 'AWS Cloud Practitioner',
            institution: 'Amazon Web Services',
            date: '2026',
            credentialId: 'XXXXX',
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
  });
}
