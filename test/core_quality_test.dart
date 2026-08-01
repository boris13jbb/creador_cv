import 'dart:typed_data';

import 'package:creador_cv/core/errors/app_exception.dart';
import 'package:creador_cv/core/utils/json_list_codec.dart';
import 'package:creador_cv/features/resumes/data/resume_photo_service.dart';
import 'package:creador_cv/features/resumes/pdf/resume_pdf_service.dart';
import 'package:creador_cv/models/resume.dart';
import 'package:creador_cv/saas/config/plan_limits.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

Resume _longResume({int experiences = 12}) {
  return Resume(
    id: 'long-1',
    nombre: 'Carlos Ramirez',
    perfil: 'Perfil profesional extenso. ' * 20,
    datosPersonales: const [
      PersonalData(label: 'Email', value: 'carlos@empresa.com', icon: 'email'),
    ],
    competencias: List.generate(
      8,
      (i) => Skill(nombre: 'Skill $i', nivel: 3 + (i % 3)),
    ),
    idiomas: const [
      Skill(nombre: 'Espanol', nivel: 5),
      Skill(nombre: 'Ingles', nivel: 4),
    ],
    experiencia: List.generate(
      experiences,
      (i) => Experience(
        cargo: 'Ingeniero $i',
        empresa: 'Empresa $i',
        periodo: '201$i - 202$i',
        logros: [
          'Logro detallado numero uno del rol $i con texto suficiente.',
          'Logro detallado numero dos del rol $i con texto suficiente.',
          'Logro detallado numero tres del rol $i con texto suficiente.',
        ],
      ),
    ),
    formacion: List.generate(
      4,
      (i) => Education(
        titulo: 'Titulo $i',
        institucion: 'Universidad $i',
        anio: '201$i',
      ),
    ),
    colorHex: 0xFF0B1F3A,
    designIndex: 1,
    ocultarFoto: true,
  );
}

Uint8List _tinyJpeg({int size = 40}) {
  final image = img.Image(width: size, height: size);
  img.fill(image, color: img.ColorRgb8(20, 120, 180));
  return Uint8List.fromList(img.encodeJpg(image, quality: 90));
}

void main() {
  group('ErrorMapper', () {
    test('preserva AppException', () {
      const err = ValidationAppException('Campo requerido');
      expect(ErrorMapper.map(err), same(err));
      expect(ErrorMapper.messageOf(err), 'Campo requerido');
    });

    test('detecta permission y network', () {
      expect(
        ErrorMapper.map(Exception('permission-denied')),
        isA<PermissionAppException>(),
      );
      expect(
        ErrorMapper.map(Exception('SocketException network')),
        isA<NetworkAppException>(),
      );
    });
  });

  group('JsonListCodec', () {
    test('lee lista nativa y JSON-string', () {
      final native = JsonListCodec.decodeObjectList([
        {'a': 1},
      ]);
      expect(native.single['a'], 1);

      final legacy = JsonListCodec.decodeObjectList('[{"b":2}]');
      expect(legacy.single['b'], 2);
      expect(JsonListCodec.decodeObjectList(null), isEmpty);
      expect(JsonListCodec.decodeObjectList(''), isEmpty);
    });
  });

  group('PlanLimits', () {
    test('Free bloquea al llegar a 3', () {
      expect(PlanLimits.canCreateResume(currentCount: 2, isPro: false), isTrue);
      expect(
        PlanLimits.canCreateResume(currentCount: 3, isPro: false),
        isFalse,
      );
      expect(
        PlanLimits.canCreateResume(currentCount: 100, isPro: true),
        isTrue,
      );
      expect(PlanLimits.limitReachedMessage(isPro: false), contains('Free'));
    });
  });

  group('ResumePhotoService.processBytes', () {
    test('comprime y puede recortar cuadrado', () {
      final raw = _tinyJpeg(size: 120);
      final out = ResumePhotoService.instance.processBytes(
        raw,
        squareCrop: true,
      );
      expect(out.bytes.length, greaterThan(0));
      expect(out.bytes.length, lessThanOrEqualTo(raw.lengthInBytes * 2));
      expect(out.contentType, 'image/jpeg');

      final decoded = img.decodeJpg(out.bytes)!;
      expect(decoded.width, decoded.height);
      expect(decoded.width, lessThanOrEqualTo(ResumePhotoService.maxEdge));
    });

    test('rechaza vacio', () {
      expect(
        () => ResumePhotoService.instance.processBytes(Uint8List(0)),
        throwsA(isA<ValidationAppException>()),
      );
    });
  });

  group('PDF multipagina y flags', () {
    test('CV largo genera PDF sustancial (posible multi-page)', () async {
      final bytes = await ResumePdfService.generateResumePdf(
        _longResume(experiences: 14),
        isPro: true,
      );
      expect(bytes.length, greaterThan(1500));
      expect(String.fromCharCodes(bytes.take(5)), contains('%PDF'));
    });

    test('ocultarExperiencia reduce contenido', () async {
      final base = _longResume(experiences: 6);
      final hidden = Resume(
        id: base.id,
        nombre: base.nombre,
        perfil: base.perfil,
        datosPersonales: base.datosPersonales,
        competencias: base.competencias,
        idiomas: base.idiomas,
        experiencia: base.experiencia,
        formacion: base.formacion,
        colorHex: base.colorHex,
        designIndex: 0,
        ocultarExperiencia: true,
        ocultarFoto: true,
      );
      final a = await ResumePdfService.generateResumePdf(base, isPro: true);
      final b = await ResumePdfService.generateResumePdf(hidden, isPro: true);
      expect(b.length, lessThan(a.length));
    });
  });
}
