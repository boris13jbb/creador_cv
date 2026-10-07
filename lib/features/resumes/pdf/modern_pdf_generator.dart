import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../models/resume.dart';
import '../data/resume_pdf_image.dart';
import 'pdf_fonts.dart';
import 'pdf_widgets.dart';

/// Plantilla Free — Moderno (banda de acento + MultiPage).
Future<Uint8List> generateModernPdf(Resume resume) async {
  final pdf = pw.Document(theme: await ResumePdfFonts.theme());
  final accent = PdfColor.fromInt(resume.colorHex);
  final dark = PdfColor.fromInt(0xFF2C2E3E);
  final text = PdfColor.fromInt(0xFF2A2A2A);
  final profileImage = await loadResumeProfileImage(resume);

  final children = <pw.Widget>[
    pw.Container(
      width: double.infinity,
      color: dark,
      padding: const pw.EdgeInsets.fromLTRB(20, 22, 20, 18),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(
              vertical: 14,
              horizontal: 16,
            ),
            color: accent,
            child: pw.Row(
              children: [
                if (!resume.ocultarFoto && profileImage != null) ...[
                  pw.Container(
                    width: 56,
                    height: 56,
                    margin: const pw.EdgeInsets.only(right: 12),
                    decoration: pw.BoxDecoration(
                      shape: pw.BoxShape.circle,
                      border: pw.Border.all(color: PdfColors.white, width: 2),
                    ),
                    child: pw.ClipOval(
                      child: pw.Image(profileImage, fit: pw.BoxFit.cover),
                    ),
                  ),
                ],
                pw.Expanded(
                  child: pw.Text(
                    resume.nombre.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (resume.datosPersonales.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Wrap(
              spacing: 14,
              runSpacing: 6,
              children: resume.datosPersonales
                  .map(
                    (d) => pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pdfBulletDot(accent, size: 5),
                        pw.SizedBox(width: 5),
                        pw.Text(
                          d.value,
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.white,
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    ),
    pw.SizedBox(height: 18),
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
      margin: const pw.EdgeInsets.all(28),
      footer: (context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          '${context.pageNumber} / ${context.pagesCount}',
          style: pw.TextStyle(fontSize: 8, color: dark),
        ),
      ),
      build: (_) => children,
    ),
  );

  return pdf.save();
}
