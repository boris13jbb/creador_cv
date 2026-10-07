import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../models/resume.dart';
import '../data/resume_pdf_image.dart';
import 'pdf_fonts.dart';
import 'pdf_widgets.dart';

/// Plantilla Pro — Ejecutivo (corporativo + MultiPage).
Future<Uint8List> generateExecutivePdf(Resume resume) async {
  final pdf = pw.Document(theme: await ResumePdfFonts.theme());
  final primary = PdfColor.fromInt(resume.colorHex);
  final secondary = PdfColor.fromInt(0xFF4A4A4A);
  final lightGray = PdfColor.fromInt(0xFFF5F5F5);
  final text = PdfColor.fromInt(0xFF333333);
  final profileImage = await loadResumeProfileImage(resume);

  final children = <pw.Widget>[
    pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (!resume.ocultarFoto)
          pw.Container(
            width: 88,
            height: 110,
            margin: const pw.EdgeInsets.only(right: 16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: primary, width: 2),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: profileImage != null
                ? pw.Image(profileImage, fit: pw.BoxFit.cover)
                : pw.Container(color: PdfColors.grey300),
          ),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                resume.nombre.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  color: primary,
                  letterSpacing: 1.4,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                color: lightGray,
                child: pw.Text(
                  'PERFIL EJECUTIVO',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: secondary,
                  ),
                ),
              ),
              if (resume.datosPersonales.isNotEmpty) ...[
                pw.SizedBox(height: 10),
                pw.Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: resume.datosPersonales
                      .map(
                        (d) => pw.Row(
                          mainAxisSize: pw.MainAxisSize.min,
                          children: [
                            pdfBulletDot(secondary, size: 5),
                            pw.SizedBox(width: 5),
                            pw.Text(
                              d.value,
                              style: pw.TextStyle(fontSize: 9, color: text),
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
      ],
    ),
    pw.SizedBox(height: 18),
    pw.Container(height: 2, color: primary),
    pw.SizedBox(height: 14),
    ...buildResumeContentBlocks(
      resume: resume,
      accent: primary,
      text: text,
      profileImage: profileImage,
      showPhotoInline: false,
      compactHeader: true,
    ),
  ];

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      footer: (context) => pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: lightGray, width: 1)),
        ),
        padding: const pw.EdgeInsets.only(top: 6),
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Página ${context.pageNumber} de ${context.pagesCount}',
          style: pw.TextStyle(fontSize: 8, color: secondary),
        ),
      ),
      build: (_) => children,
    ),
  );

  return pdf.save();
}
