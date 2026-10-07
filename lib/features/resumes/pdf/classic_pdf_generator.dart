import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../models/resume.dart';
import '../data/resume_pdf_image.dart';
import 'pdf_fonts.dart';
import 'pdf_widgets.dart';

/// Plantilla Free — Clásico (cabecera navy + contenido MultiPage).
Future<Uint8List> generateClassicPdf(Resume resume) async {
  final pdf = pw.Document(theme: await ResumePdfFonts.theme());
  final accent = PdfColor.fromInt(resume.colorHex);
  final header = PdfColor.fromInt(0xFF20354B);
  final text = PdfColor.fromInt(0xFF333333);
  final profileImage = await loadResumeProfileImage(resume);

  final children = <pw.Widget>[
    pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: pw.BoxDecoration(
        color: header,
        border: pw.Border(left: pw.BorderSide(color: accent, width: 6)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (!resume.ocultarFoto && profileImage != null) ...[
            pw.Container(
              width: 64,
              height: 64,
              margin: const pw.EdgeInsets.only(right: 14),
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
                  resume.nombre.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                    letterSpacing: 1.1,
                  ),
                ),
                if (resume.datosPersonales.isNotEmpty) ...[
                  pw.SizedBox(height: 6),
                  pw.Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    children: resume.datosPersonales
                        .map(
                          (d) => pw.Text(
                            d.value,
                            style: const pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.white,
                            ),
                          ),
                        )
                        .toList(),
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
      margin: const pw.EdgeInsets.all(32),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Pág. ${context.pageNumber}/${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
        ),
      ),
      build: (_) => children,
    ),
  );

  return pdf.save();
}
