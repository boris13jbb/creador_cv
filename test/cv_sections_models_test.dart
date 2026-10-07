import 'package:creador_cv/models/resume.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Project', () {
    test('fromJson / toJson roundtrip y defaults', () {
      final p = Project(
        id: 'p1',
        name: 'NotesPro',
        description: 'App desktop',
        technologies: const ['Flutter', 'Supabase'],
        url: 'https://example.com',
        repositoryUrl: 'https://github.com/x/y',
        startDate: '2024',
        isOngoing: true,
      );
      final mapped = Project.fromJson(p.toJson());
      expect(mapped, equals(p));
      expect(mapped.periodLabel, '2024 – Actualidad');
      expect(Project(id: 'x', name: 'Solo').description, '');
      expect(Project(id: 'x', name: 'Solo').technologies, isEmpty);
    });

    test('copyWith e igualdad', () {
      const a = Project(id: '1', name: 'A', description: 'd');
      final b = a.copyWith(name: 'B');
      expect(a == b, isFalse);
      expect(a.copyWith(name: 'A'), equals(a));
    });
  });

  group('Certification', () {
    test('fromJson / toJson y defaults', () {
      final c = Certification(
        id: 'c1',
        name: 'AWS Cloud Foundations',
        institution: 'AWS Academy',
        date: '2023',
        credentialId: 'ABC',
        credentialUrl: 'https://aws.amazon.com/cert',
      );
      expect(Certification.fromJson(c.toJson()), equals(c));
      expect(Certification(id: 'x', name: 'Curso').institution, '');
    });

    test('copyWith', () {
      const c = Certification(id: '1', name: 'X', institution: 'Y');
      expect(c.copyWith(institution: 'Z').institution, 'Z');
    });
  });

  group('Aptitude', () {
    test('fromJson / toJson y defaults', () {
      const a = Aptitude(
        id: 'a1',
        name: 'Liderazgo',
        level: 4,
        description: 'Equipos ágiles',
      );
      expect(Aptitude.fromJson(a.toJson()), equals(a));
      expect(const Aptitude(id: 'x', name: 'Comunicación').level, isNull);
    });

    test('copyWith clearLevel', () {
      const a = Aptitude(id: '1', name: 'Adaptabilidad', level: 3);
      expect(a.copyWith(clearLevel: true).level, isNull);
    });
  });
}
