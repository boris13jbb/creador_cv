import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:universal_io/io.dart';
import '../../../models/resume.dart';

/// Carga única de imagen de perfil para plantillas PDF.
Future<pw.ImageProvider?> loadResumeProfileImage(Resume resume) async {
  final ref = resume.effectivePhotoRef;
  if (ref == null || ref.isEmpty) return null;
  try {
    if (ref.startsWith('data:')) {
      final base64 = ref.split(',').last;
      return pw.MemoryImage(base64Decode(base64));
    }
    if (ref.startsWith('http://') || ref.startsWith('https://')) {
      final res = await http.get(Uri.parse(ref));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return pw.MemoryImage(res.bodyBytes);
      }
      return null;
    }
    if (!kIsWeb) {
      final file = File(ref);
      if (await file.exists()) {
        return pw.MemoryImage(await file.readAsBytes());
      }
    }
  } catch (_) {}
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
