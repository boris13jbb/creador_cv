import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:universal_io/io.dart';
import '../../../core/errors/app_exception.dart';
import '../../../saas/config/saas_platform.dart';
import '../../../saas/services/auth_service.dart';

class ProcessedPhoto {
  final Uint8List bytes;
  final String contentType;
  final String extension;

  const ProcessedPhoto({
    required this.bytes,
    this.contentType = 'image/jpeg',
    this.extension = 'jpg',
  });
}

class UploadedPhoto {
  final String downloadUrl;
  final String storagePath;

  const UploadedPhoto({required this.downloadUrl, required this.storagePath});
}

/// Selección/procesado/carga de fotografías de CV en Firebase Storage.
class ResumePhotoService {
  ResumePhotoService._();
  static final ResumePhotoService instance = ResumePhotoService._();

  static const int maxSourceBytes = 8 * 1024 * 1024;
  static const int maxEdge = 1024;
  static const int jpegQuality = 78;

  /// Valida, recorta al centro (cuadrado) y comprime a JPEG.
  ProcessedPhoto processBytes(Uint8List source, {bool squareCrop = true}) {
    if (source.isEmpty) {
      throw const ValidationAppException('La imagen está vacía.');
    }
    if (source.lengthInBytes > maxSourceBytes) {
      throw const ValidationAppException(
        'La imagen supera 8 MB. Elige una más liviana.',
      );
    }

    final decoded = img.decodeImage(source);
    if (decoded == null) {
      throw const ValidationAppException(
        'Formato de imagen no válido. Usa JPG, PNG o WebP.',
      );
    }

    var work = decoded;
    if (squareCrop) {
      final side = work.width < work.height ? work.width : work.height;
      final x = (work.width - side) ~/ 2;
      final y = (work.height - side) ~/ 2;
      work = img.copyCrop(work, x: x, y: y, width: side, height: side);
    }

    if (work.width > maxEdge || work.height > maxEdge) {
      work = img.copyResize(
        work,
        width: work.width >= work.height ? maxEdge : null,
        height: work.height > work.width ? maxEdge : null,
      );
    }

    final jpg = Uint8List.fromList(img.encodeJpg(work, quality: jpegQuality));
    return ProcessedPhoto(bytes: jpg);
  }

  String storagePathFor({required String uid, required String resumeId}) =>
      'users/$uid/resumes/$resumeId/photo.jpg';

  Future<UploadedPhoto> upload({
    required String uid,
    required String resumeId,
    required ProcessedPhoto photo,
  }) async {
    final path = storagePathFor(uid: uid, resumeId: resumeId);
    if (saasUseRestBackend) {
      return _uploadRest(path: path, photo: photo);
    }
    try {
      final ref = FirebaseStorage.instance.ref(path);
      await ref.putData(
        photo.bytes,
        SettableMetadata(contentType: photo.contentType),
      );
      final url = await ref.getDownloadURL();
      return UploadedPhoto(downloadUrl: url, storagePath: path);
    } catch (e) {
      debugPrint('Storage SDK upload falló, intentando REST: $e');
      return _uploadRest(path: path, photo: photo);
    }
  }

  Future<UploadedPhoto> _uploadRest({
    required String path,
    required ProcessedPhoto photo,
  }) async {
    final session = await AuthService.instance.ensureValidRestToken();
    final bucket = Firebase.app().options.storageBucket;
    if (bucket == null || bucket.isEmpty) {
      throw const StorageAppException('Storage bucket no configurado.');
    }
    final encodedName = Uri.encodeComponent(path);
    final uri = Uri.parse(
      'https://firebasestorage.googleapis.com/v0/b/$bucket/o'
      '?uploadType=media&name=$encodedName',
    );
    final res = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer ${session.idToken}',
        'Content-Type': photo.contentType,
      },
      body: photo.bytes,
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      debugPrint('Storage REST ${res.statusCode}: ${res.body}');
      throw StorageAppException(
        'No se pudo subir la foto (${res.statusCode}).',
      );
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final token = body['downloadTokens'] as String?;
    final downloadUrl = token == null
        ? 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$encodedName?alt=media'
        : 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$encodedName?alt=media&token=$token';
    return UploadedPhoto(downloadUrl: downloadUrl, storagePath: path);
  }

  Future<void> deleteIfExists(String? storagePath) async {
    if (storagePath == null || storagePath.isEmpty) return;
    try {
      if (saasUseRestBackend) {
        final session = await AuthService.instance.ensureValidRestToken();
        final bucket = Firebase.app().options.storageBucket;
        if (bucket == null) return;
        final uri = Uri.parse(
          'https://firebasestorage.googleapis.com/v0/b/$bucket/o/${Uri.encodeComponent(storagePath)}',
        );
        await http.delete(
          uri,
          headers: {'Authorization': 'Bearer ${session.idToken}'},
        );
        return;
      }
      await FirebaseStorage.instance.ref(storagePath).delete();
    } catch (e) {
      debugPrint('deleteIfExists: $e');
    }
  }

  /// Carga bytes desde URL remota, data-URI o archivo local.
  Future<Uint8List?> loadBytes(String? ref) async {
    if (ref == null || ref.isEmpty) return null;
    try {
      if (ref.startsWith('data:')) {
        return base64Decode(ref.split(',').last);
      }
      if (ref.startsWith('http://') || ref.startsWith('https://')) {
        final res = await http.get(Uri.parse(ref));
        if (res.statusCode >= 200 && res.statusCode < 300) {
          return res.bodyBytes;
        }
        return null;
      }
      if (!kIsWeb) {
        final file = File(ref);
        if (await file.exists()) return await file.readAsBytes();
      }
    } catch (e) {
      debugPrint('loadBytes: $e');
    }
    return null;
  }
}
