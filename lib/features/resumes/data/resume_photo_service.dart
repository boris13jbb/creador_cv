import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:universal_io/io.dart';
import '../../../core/errors/app_exception.dart';
import '../../../models/resume.dart';
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
      try {
        return await _uploadRest(path: path, photo: photo);
      } catch (restError) {
        throw _mapUploadFailure(e, restError);
      }
    }
  }

  /// Token de Auth nativo o REST (Android/iOS/Web usan nativo).
  Future<String> _authBearerToken() => AuthService.instance.getIdToken();

  Future<UploadedPhoto> _uploadRest({
    required String path,
    required ProcessedPhoto photo,
  }) async {
    final idToken = await _authBearerToken();
    final bucket = Firebase.app().options.storageBucket;
    if (bucket == null || bucket.isEmpty) {
      throw const StorageAppException(
        'Storage bucket no configurado. Activa Firebase Storage en la consola.',
      );
    }
    final encodedName = Uri.encodeComponent(path);
    final uri = Uri.parse(
      'https://firebasestorage.googleapis.com/v0/b/$bucket/o'
      '?uploadType=media&name=$encodedName',
    );
    final res = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': photo.contentType,
      },
      body: photo.bytes,
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      debugPrint('Storage REST ${res.statusCode}: ${res.body}');
      throw _storageHttpException(res.statusCode, res.body);
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final token = body['downloadTokens'] as String?;
    final downloadUrl = token == null
        ? 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$encodedName?alt=media'
        : 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$encodedName?alt=media&token=$token';
    return UploadedPhoto(downloadUrl: downloadUrl, storagePath: path);
  }

  StorageAppException _storageHttpException(int statusCode, String body) {
    final lower = body.toLowerCase();
    if (statusCode == 404 || lower.contains('not found')) {
      return const StorageAppException(
        'Firebase Storage no está disponible (bucket 404). '
        'Activa Storage en la consola y despliega storage.rules.',
      );
    }
    if (statusCode == 401 || statusCode == 403) {
      return const StorageAppException(
        'Sin permiso para subir la foto. Revisa sesión y reglas de Storage.',
      );
    }
    return StorageAppException('No se pudo subir la foto ($statusCode).');
  }

  StorageAppException _mapUploadFailure(Object sdkError, Object restError) {
    if (restError is StorageAppException) return restError;
    final combined = '$sdkError $restError'.toLowerCase();
    if (combined.contains('object-not-found') ||
        combined.contains('not found') ||
        combined.contains('-13010') ||
        combined.contains('404')) {
      return const StorageAppException(
        'Firebase Storage no está disponible (bucket 404). '
        'Activa Storage en la consola y despliega storage.rules.',
      );
    }
    if (combined.contains('unauthorized') ||
        combined.contains('permission') ||
        combined.contains('403')) {
      return const StorageAppException(
        'Sin permiso para subir la foto. Revisa sesión y reglas de Storage.',
      );
    }
    return StorageAppException(
      'No se pudo subir la foto: ${restError.toString().replaceFirst('Exception: ', '')}',
    );
  }

  Future<void> deleteIfExists(String? storagePath) async {
    if (storagePath == null || storagePath.isEmpty) return;
    try {
      if (saasUseRestBackend) {
        final idToken = await _authBearerToken();
        final bucket = Firebase.app().options.storageBucket;
        if (bucket == null) return;
        final uri = Uri.parse(
          'https://firebasestorage.googleapis.com/v0/b/$bucket/o/${Uri.encodeComponent(storagePath)}',
        );
        await http.delete(uri, headers: {'Authorization': 'Bearer $idToken'});
        return;
      }
      await FirebaseStorage.instance.ref(storagePath).delete();
    } catch (e) {
      debugPrint('deleteIfExists: $e');
    }
  }

  /// Carga bytes de la foto del CV: memoria → Storage autenticado → URL/archivo.
  Future<Uint8List?> loadBytesForResume(Resume resume) async {
    if (resume.hasPhotoBytes) return resume.fotoBytes;

    final storagePath = resume.fotoStoragePath;
    if (storagePath != null && storagePath.isNotEmpty) {
      try {
        final fromStorage = await _downloadStorageObject(storagePath);
        if (fromStorage != null && fromStorage.isNotEmpty) return fromStorage;
      } catch (e) {
        debugPrint('loadBytesForResume storage: $e');
      }
    }

    return loadBytes(resume.effectivePhotoRef);
  }

  Future<Uint8List?> _downloadStorageObject(String path) async {
    if (saasUseRestBackend) {
      final idToken = await _authBearerToken();
      final bucket = Firebase.app().options.storageBucket;
      if (bucket == null || bucket.isEmpty) return null;
      final uri = Uri.parse(
        'https://firebasestorage.googleapis.com/v0/b/$bucket/o/${Uri.encodeComponent(path)}?alt=media',
      );
      final res = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $idToken'},
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return Uint8List.fromList(res.bodyBytes);
      }
      return null;
    }
    return FirebaseStorage.instance.ref(path).getData(maxSourceBytes);
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
