import 'dart:typed_data';

import 'package:creador_cv/core/errors/app_exception.dart';
import 'package:creador_cv/features/resumes/data/resume_pdf_image.dart';
import 'package:creador_cv/features/resumes/data/resume_photo_service.dart';
import 'package:creador_cv/features/resumes/pdf/resume_pdf_service.dart';
import 'package:creador_cv/models/resume.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

Uint8List _jpeg({int width = 48, int height = 32, int orientation = 1}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(30, 90, 160));
  if (orientation != 1) {
    image.exif.imageIfd.orientation = orientation;
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: 90));
}

Uint8List _png() {
  final image = img.Image(width: 36, height: 24);
  img.fill(image, color: img.ColorRgb8(200, 80, 40));
  return Uint8List.fromList(img.encodePng(image));
}

Resume _resume({
  Uint8List? bytes,
  String? fotoUrl,
  String? fotoPath,
  String? fotoStoragePath,
  bool ocultarFoto = false,
}) {
  return Resume(
    id: 'cv-foto-aislado',
    nombre: 'Persona de prueba',
    perfil: 'Perfil de prueba',
    datosPersonales: const [],
    competencias: const [],
    idiomas: const [],
    experiencia: const [],
    formacion: const [],
    fotoBytes: bytes,
    fotoUrl: fotoUrl,
    fotoPath: fotoPath,
    fotoStoragePath: fotoStoragePath,
    ocultarFoto: ocultarFoto,
  );
}

void main() {
  final service = ResumePhotoService.instance;

  group('selección y procesado de fotografía', () {
    test('acepta JPG y deja una vista previa JPEG', () {
      final out = service.processGalleryPick(_jpeg(), squareCrop: false);
      expect(out, isNotNull);
      final preview = img.decodeJpg(out!.bytes);
      expect(preview, isNotNull);
      expect(preview!.width, greaterThan(0));
      expect(out.contentType, 'image/jpeg');
    });

    test('acepta JPEG con la misma decodificación', () {
      final out = service.processBytes(_jpeg(), squareCrop: false);
      expect(img.decodeJpg(out.bytes), isNotNull);
    });

    test('acepta PNG y lo convierte a JPEG', () {
      final out = service.processBytes(_png(), squareCrop: false);
      expect(img.decodeJpg(out.bytes), isNotNull);
      expect(out.extension, 'jpg');
    });

    test('cancelar el selector no modifica la fotografía', () {
      final actual = const CvPhotoDraft(
        fotoUrl: 'https://example.invalid/photo.jpg',
        ocultarFoto: true,
      );
      expect(service.processGalleryPick(null, squareCrop: true), isNull);
      expect(actual.bytes, isNull);
      expect(actual.fotoUrl, 'https://example.invalid/photo.jpg');
    });

    test('rechaza un archivo inválido con mensaje claro', () {
      expect(
        () => service.processBytes(Uint8List.fromList([1, 2, 3, 4, 5])),
        throwsA(
          isA<ValidationAppException>().having(
            (e) => e.message,
            'message',
            contains('JPG'),
          ),
        ),
      );
    });

    test('un archivo inexistente no inventa una fotografía', () async {
      final bytes = await service.loadBytes(r'C:\no-existe\cv-foto-prueba.jpg');
      expect(bytes, isNull);
    });

    test('rechaza un origen mayor al límite antes de decodificar', () {
      expect(
        () => service.processBytes(
          Uint8List(ResumePhotoService.maxSourceBytes + 1),
        ),
        throwsA(isA<ValidationAppException>()),
      );
    });

    test('reduce una fotografía grande y cabe en la regla de Storage', () {
      final raw = _jpeg(width: 1400, height: 900);
      final out = service.processBytes(raw, squareCrop: false);
      final decoded = img.decodeJpg(out.bytes)!;
      expect(decoded.width, lessThanOrEqualTo(ResumePhotoService.maxEdge));
      expect(decoded.height, lessThanOrEqualTo(ResumePhotoService.maxEdge));
      expect(out.bytes.length, lessThan(5 * 1024 * 1024));
      expect(
        service.storagePathFor(uid: 'uid-prueba', resumeId: 'cv-foto-aislado'),
        'users/uid-prueba/resumes/cv-foto-aislado/photo.jpg',
      );
    });

    test('aplica la orientación EXIF antes de guardar', () {
      final out = service.processBytes(
        _jpeg(width: 40, height: 16, orientation: 6),
        squareCrop: false,
      );
      final decoded = img.decodeJpg(out.bytes)!;
      expect(decoded.width, 16);
      expect(decoded.height, 40);
    });
  });

  group('editor, persistencia y PDF', () {
    test('una carga tardía no reemplaza la foto recién elegida', () {
      final selected = const CvPhotoDraft(
        fotoUrl: 'https://example.invalid/vieja.jpg',
        ocultarFoto: true,
      ).accept(service.processBytes(_jpeg(), squareCrop: false));
      final lateLoad = selected.withLoadedBytes(_jpeg(width: 8, height: 8));
      expect(lateLoad.bytes, selected.bytes);
      expect(lateLoad.pendingUploadBytes, selected.pendingUploadBytes);
      expect(lateLoad.ocultarFoto, isFalse);
      expect(selected.hasStoredReference, isTrue);
    });

    test(
      'ocultar la foto la deja fuera del PDF aunque existan bytes',
      () async {
        final bytes = service.processBytes(_jpeg(), squareCrop: false).bytes;
        final visible = await ResumePdfService.generateResumePdf(
          _resume(bytes: bytes),
          isPro: true,
        );
        final hidden = await ResumePdfService.generateResumePdf(
          _resume(bytes: bytes, ocultarFoto: true),
          isPro: true,
        );
        expect(visible.length, greaterThan(hidden.length));
      },
    );

    test('la vista previa se conserva al cambiar de sección', () {
      final processed = service.processBytes(_jpeg(), squareCrop: true);
      final seleccionado = const CvPhotoDraft(
        ocultarFoto: true,
      ).accept(processed);
      final mismaPantalla = seleccionado;
      expect(mismaPantalla.bytes, processed.bytes);
      expect(mismaPantalla.pendingUploadBytes, processed.bytes);
      expect(mismaPantalla.ocultarFoto, isFalse);
    });

    test('guarda y recupera la referencia de la fotografía', () {
      final map = _resume(
        fotoUrl: 'https://example.invalid/users/uid/photo.jpg',
        fotoStoragePath: 'users/uid/resumes/cv-foto-aislado/photo.jpg',
      ).toFirestoreMap(userId: 'uid-prueba');
      final restored = Resume.fromMap(map);
      expect(restored.fotoUrl, 'https://example.invalid/users/uid/photo.jpg');
      expect(restored.hasRemotePhoto, isTrue);
      expect(restored.fotoBytes, isNull);
    });

    test('un CV antiguo sin fotografía sigue abriéndose', () async {
      final restored = Resume.fromMap({
        'id': 'cv-antiguo',
        'nombre': 'CV antiguo',
        'perfil': '',
      });
      expect(restored.fotoUrl, isNull);
      expect(restored.hasPhotoBytes, isFalse);
      expect(await loadResumeProfileImage(restored), isNull);
      final pdf = await ResumePdfService.generateResumePdf(
        restored,
        isPro: true,
      );
      expect(pdf.length, greaterThan(100));
    });

    test('el PDF incluye la fotografía en memoria', () async {
      final bytes = service.processBytes(_jpeg(), squareCrop: false).bytes;
      final withPhoto = await ResumePdfService.generateResumePdf(
        _resume(bytes: bytes),
        isPro: true,
      );
      final withoutPhoto = await ResumePdfService.generateResumePdf(
        _resume(),
        isPro: true,
      );
      expect(withPhoto.length, greaterThan(withoutPhoto.length));
    });

    test('quitar la fotografía no deja referencia ni recuadro', () async {
      final removed = CvPhotoDraft(
        bytes: _jpeg(),
        pendingUploadBytes: _jpeg(),
        fotoUrl: 'https://example.invalid/photo.jpg',
        fotoStoragePath: 'users/uid/resumes/cv-foto-aislado/photo.jpg',
      ).remove();
      final map = _resume(
        fotoUrl: removed.fotoUrl,
        fotoPath: removed.fotoPath,
        fotoStoragePath: removed.fotoStoragePath,
        ocultarFoto: removed.ocultarFoto,
      ).toFirestoreMap(userId: 'uid-prueba');
      expect(map['fotoUrl'], '');
      expect(map['fotoStoragePath'], '');
      expect(map['ocultarFoto'], isTrue);
      final restored = Resume.fromMap(map);
      expect(restored.hasRemotePhoto, isFalse);
      expect(await loadResumeProfileImage(restored), isNull);
    });
  });
}
