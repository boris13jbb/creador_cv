import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:universal_io/io.dart';
import '../../../models/resume.dart';
import 'resume_photo_service.dart';

/// Carga única de imagen de perfil para plantillas PDF.
///
/// Prioridad: bytes en memoria → Storage autenticado → URL/archivo local.
Future<pw.ImageProvider?> loadResumeProfileImage(Resume resume) async {
  if (resume.hasPhotoBytes) {
    return pw.MemoryImage(resume.fotoBytes!);
  }

  try {
    final bytes = await ResumePhotoService.instance.loadBytesForResume(resume);
    if (bytes != null && bytes.isNotEmpty) {
      return pw.MemoryImage(bytes);
    }
  } catch (e) {
    debugPrint('loadResumeProfileImage: $e');
  }

  // Fallback legacy directo (por si loadBytesForResume no aplica).
  final ref = resume.effectivePhotoRef;
  if (ref == null || ref.isEmpty) return null;
  try {
    if (ref.startsWith('data:')) {
      final base64 = ref.split(',').last;
      return pw.MemoryImage(base64Decode(base64));
    }
    if (!kIsWeb) {
      final file = File(ref);
      if (await file.exists()) {
        return pw.MemoryImage(await file.readAsBytes());
      }
    }
  } catch (e) {
    debugPrint('loadResumeProfileImage fallback: $e');
  }
  return null;
}

pw.Widget defaultProfileAvatar({double size = 80}) {
  return pw.Container(
    width: size,
    height: size,
    decoration: pw.BoxDecoration(
      color: PdfColors.grey300,
      shape: pw.BoxShape.circle,
    ),
  );
}
