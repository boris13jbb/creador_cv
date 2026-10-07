import 'dart:convert';
import 'dart:typed_data';
import 'package:creador_cv/models/resume.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Resume serialización retrocompatible', () {
    test('fotoBytes es efímero y no se serializa a Firestore', () {
      final r = Resume(
        id: 'foto-1',
        nombre: 'Test',
        perfil: 'P',
        fotoBytes: Uint8List.fromList([1, 2, 3, 4]),
        datosPersonales: const [],
        competencias: const [],
        idiomas: const [],
        experiencia: const [],
        formacion: const [],
      );
      expect(r.hasPhotoBytes, isTrue);
      final out = r.toFirestoreMap(userId: 'u');
      expect(out.containsKey('fotoBytes'), isFalse);
    });

    test('lee listas nativas schema v2', () {
      final map = {
        'id': '1',
        'nombre': 'Ana',
        'perfil': 'Dev',
        'schemaVersion': 2,
        'datosPersonales': [
          {'label': 'Email', 'value': 'a@b.com', 'icon': 'email'},
        ],
        'competencias': [
          {'nombre': 'Dart', 'nivel': 5},
        ],
        'idiomas': <Map<String, dynamic>>[],
        'experiencia': [
          {
            'cargo': 'Dev',
            'empresa': 'X',
            'periodo': '2024',
            'logros': ['A'],
          },
        ],
        'formacion': [
          {'titulo': 'Ing', 'institucion': 'U', 'anio': '2020'},
        ],
        'colorHex': 0xFF112233,
        'designIndex': 1,
        'ocultarFoto': false,
        'fotoUrl': 'https://example.com/p.jpg',
        'fotoStoragePath': 'users/u/resumes/1/photo.jpg',
      };

      final r = Resume.fromMap(map);
      expect(r.datosPersonales.single.value, 'a@b.com');
      expect(r.competencias.single.nombre, 'Dart');
      expect(r.experiencia.single.logros, ['A']);
      expect(r.hasRemotePhoto, isTrue);
      expect(r.schemaVersion, 2);
    });

    test('lee JSON-string legacy schema v1', () {
      final map = {
        'id': '2',
        'nombre': 'Luis',
        'perfil': 'PM',
        'datosPersonales': jsonEncode([
          {'label': 'Tel', 'value': '123', 'icon': 'phone'},
        ]),
        'competencias': jsonEncode([
          {'nombre': 'Scrum', 'nivel': 4},
        ]),
        'idiomas': jsonEncode([]),
        'experiencia': jsonEncode([]),
        'formacion': jsonEncode([]),
        'ocultarFoto': 1,
        'ocultarPerfil': 0,
        'fotoPath': 'data:image/jpeg;base64,abc',
      };

      final r = Resume.fromMap(map);
      expect(r.datosPersonales.single.label, 'Tel');
      expect(r.competencias.single.nivel, 4);
      expect(r.ocultarFoto, isTrue);
      expect(r.effectivePhotoRef!.startsWith('data:'), isTrue);
    });

    test('toFirestoreMap escribe listas nativas y limpia path si hay URL', () {
      final r = Resume(
        id: '3',
        nombre: 'Eva',
        perfil: 'UX',
        fotoPath: 'data:image/jpeg;base64,${'x' * 10}',
        fotoUrl: 'https://cdn/x.jpg',
        fotoStoragePath: 'users/u/resumes/3/photo.jpg',
        datosPersonales: const [
          PersonalData(label: 'Web', value: 'https://a.com', icon: 'link'),
        ],
        competencias: const [],
        idiomas: const [],
        experiencia: const [],
        formacion: const [],
      );

      final out = r.toFirestoreMap(userId: 'u');
      expect(out['datosPersonales'], isA<List>());
      expect(out['userId'], 'u');
      expect(out['schemaVersion'], Resume.currentSchemaVersion);
      expect(out['fotoPath'], isNull);
      expect(out['fotoUrl'], 'https://cdn/x.jpg');
      expect(out['ocultarFoto'], isA<bool>());
    });

    test('CV antiguo sin projects/certifications/aptitudes carga vacío', () {
      final map = {
        'id': 'legacy',
        'nombre': 'Muñoz Peña',
        'perfil': 'Educación',
        'datosPersonales': <Map<String, dynamic>>[],
        'competencias': <Map<String, dynamic>>[],
        'idiomas': <Map<String, dynamic>>[],
        'experiencia': <Map<String, dynamic>>[],
        'formacion': <Map<String, dynamic>>[],
      };
      final r = Resume.fromMap(map);
      expect(r.projects, isEmpty);
      expect(r.certifications, isEmpty);
      expect(r.aptitudes, isEmpty);
      expect(r.ocultarProyectos, isFalse);
    });

    test('CV nuevo serializa y deserializa secciones profesionales', () {
      final r = Resume(
        id: 'new-1',
        nombre: 'Gestión',
        perfil: 'Comunicación',
        datosPersonales: const [],
        competencias: const [],
        idiomas: const [],
        experiencia: const [],
        formacion: const [],
        projects: const [
          Project(
            id: 'p1',
            name: 'CotizaPro',
            description: 'Cotizaciones',
            technologies: ['Flutter'],
            startDate: '2025',
            isOngoing: true,
          ),
        ],
        certifications: const [
          Certification(
            id: 'c1',
            name: 'Prompt Engineering',
            institution: 'ECN',
            date: '2025',
          ),
        ],
        aptitudes: const [
          Aptitude(id: 'a1', name: 'Trabajo en equipo'),
          Aptitude(id: 'a2', name: 'Adaptabilidad', level: 5),
        ],
      );
      final out = r.toFirestoreMap(userId: 'u');
      final back = Resume.fromMap(Map<String, dynamic>.from(out));
      expect(back.projects.single.name, 'CotizaPro');
      expect(back.certifications.single.institution, 'ECN');
      expect(back.aptitudes.map((a) => a.name), [
        'Trabajo en equipo',
        'Adaptabilidad',
      ]);
      expect(out['projects'], isA<List>());
      expect(out['schemaVersion'], 3);
    });
  });
}
