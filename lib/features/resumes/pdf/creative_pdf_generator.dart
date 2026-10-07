import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../models/resume.dart';
import '../data/resume_pdf_image.dart';
import 'pdf_fonts.dart';
import 'pdf_widgets.dart';

/// Plantilla Pro — Creativo (bloques de acento + MultiPage).
Future<Uint8List> generateCreativePdf(Resume resume) async {
  final pdf = pw.Document(theme: await ResumePdfFonts.theme());
  final accent = PdfColor.fromInt(resume.colorHex);
  final text = PdfColor.fromInt(0xFF333333);
  final soft = PdfColor.fromInt(0xFFF7F7F7);
  final profileImage = await loadResumeProfileImage(resume);

  final children = <pw.Widget>[
    pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        color: soft,
        border: pw.Border(bottom: pw.BorderSide(color: accent, width: 4)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(width: 10, height: 70, color: accent),
          pw.SizedBox(width: 14),
          if (!resume.ocultarFoto && profileImage != null) ...[
            pw.Container(
              width: 70,
              height: 70,
              margin: const pw.EdgeInsets.only(right: 14),
              decoration: pw.BoxDecoration(
                shape: pw.BoxShape.circle,
                border: pw.Border.all(color: accent, width: 2),
              ),
              child: pw.ClipOval(
                child: pw.Image(profileImage, fit: pw.BoxFit.cover),
              ),
            ),
          ],
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  resume.nombre,
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: accent,
                  ),
                ),
                if (resume.datosPersonales.isNotEmpty) ...[
                  pw.SizedBox(height: 6),
                  pw.Text(
                    resume.datosPersonales.map((d) => d.value).join('  ·  '),
                    style: pw.TextStyle(fontSize: 9, color: text),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
    pw.SizedBox(height: 16),
    ...buildResumeContentBlocks(
      resume: resume,
      accent: accent,
      text: text,
      profileImage: profileImage,
      showPhotoInline: false,
      compactHeader: true,
    ),
  ];

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(30),
      header: (context) {
        if (context.pageNumber == 1) return pw.SizedBox();
        return pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 12),
          padding: const pw.EdgeInsets.only(bottom: 6),
          decoration: pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: accent, width: 1.5)),
          ),
          child: pw.Text(
            resume.nombre,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: accent,
            ),
          ),
        );
      },
      footer: (context) => pw.Align(
        alignment: pw.Alignment.center,
        child: pw.Text(
          '${context.pageNumber}',
          style: pw.TextStyle(fontSize: 9, color: accent),
        ),
      ),
      build: (_) => children,
    ),
  );

  return pdf.save();
}
