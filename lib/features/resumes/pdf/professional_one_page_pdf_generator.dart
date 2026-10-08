import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../models/resume.dart';
import '../data/resume_pdf_image.dart';
import 'one_page/one_page_metrics.dart';
import 'one_page/one_page_plan.dart';
import 'one_page/one_page_sections.dart';
import 'pdf_fonts.dart';

/// Resultado de la plantilla One Page, incluido el nivel de compactación.
class OnePagePdfResult {
  const OnePagePdfResult({
    required this.bytes,
    required this.pageCount,
    required this.metrics,
    required this.plan,
    required this.pageWidth,
    required this.pageHeight,
  });

  final Uint8List bytes;
  final int pageCount;
  final OnePageMetrics metrics;
  final OnePagePlan plan;
  final double pageWidth;
  final double pageHeight;

  bool get fitsOnOnePage => pageCount == 1;
}

/// Genera el PDF A4 de dos columnas.
///
/// Prueba los niveles 1 a 6 y se queda con el más holgado que cabe en una
/// página. Si ni el piso de legibilidad cabe, continúa en páginas siguientes
/// sin recortar texto ni bajar más la tipografía.
Future<OnePagePdfResult> buildProfessionalOnePage(Resume resume) async {
  final theme = await ResumePdfFonts.theme();
  final photo = await loadResumeProfileImage(resume);
  final plan = OnePagePlan.fromResume(resume, hasPhotoImage: photo != null);
  final palette = OnePagePalette.fromColorHex(resume.colorHex);
  final sidebarWidth = PdfPageFormat.a4.width * OnePageMetrics.sidebarFraction;

  OnePageMetrics? chosen;
  for (var level = 1; level <= OnePageMetrics.maxLevel; level++) {
    final metrics = OnePageMetrics.forLevel(level);
    final height = await _contentHeight(
      theme: theme,
      plan: plan,
      metrics: metrics,
      palette: palette,
      photo: photo,
      sidebarWidth: sidebarWidth,
    );
    if (height <= PdfPageFormat.a4.height + 0.75) {
      chosen = metrics;
      break;
    }
  }
  final metrics = chosen ?? OnePageMetrics.forLevel(OnePageMetrics.maxLevel);
  final singlePage = chosen != null;

  final columns = buildOnePageColumns(
    plan: plan,
    metrics: metrics,
    palette: palette,
    photo: photo,
  );
  final document = pw.Document(theme: theme);
  if (singlePage) {
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (_) => _pageBody(
          columns: columns,
          palette: palette,
          sidebarWidth: sidebarWidth,
        ),
      ),
    );
  } else {
    // El piso de legibilidad no cabe en A4. Se conserva todo el texto y se
    // continúa en páginas siguientes, sin bajar más la fuente ni recortar.
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (_) => buildOnePageOverflowFlow(
          plan: plan,
          metrics: metrics,
          palette: palette,
          photo: photo,
        ),
      ),
    );
  }

  final bytes = await document.save();
  final pages = document.document.pdfPageList.pages;
  final format = pages.first.pageFormat;
  return OnePagePdfResult(
    bytes: bytes,
    pageCount: pages.length,
    metrics: metrics,
    plan: plan,
    pageWidth: format.width,
    pageHeight: format.height,
  );
}

Future<Uint8List> generateProfessionalOnePagePdf(Resume resume) async {
  final result = await buildProfessionalOnePage(resume);
  return result.bytes;
}

pw.Widget _pageBody({
  required OnePageColumns columns,
  required OnePagePalette palette,
  required double sidebarWidth,
}) {
  return pw.SizedBox(
    width: PdfPageFormat.a4.width,
    height: PdfPageFormat.a4.height,
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          width: sidebarWidth,
          color: palette.sidebar,
          child: columns.sidebar,
        ),
        pw.Expanded(
          child: pw.Container(color: PdfColors.white, child: columns.main),
        ),
      ],
    ),
  );
}

/// Mide las dos columnas con altura libre y devuelve la más alta.
Future<double> _contentHeight({
  required pw.ThemeData theme,
  required OnePagePlan plan,
  required OnePageMetrics metrics,
  required OnePagePalette palette,
  required pw.ImageProvider? photo,
  required double sidebarWidth,
}) async {
  final columns = buildOnePageColumns(
    plan: plan,
    metrics: metrics,
    palette: palette,
    photo: photo,
  );
  final probe = pw.Document(theme: theme);
  probe.addPage(
    pw.Page(
      pageFormat: PdfPageFormat(sidebarWidth, double.infinity, marginAll: 0),
      margin: pw.EdgeInsets.zero,
      build: (_) => columns.sidebar,
    ),
  );
  probe.addPage(
    pw.Page(
      pageFormat: PdfPageFormat(
        PdfPageFormat.a4.width - sidebarWidth,
        double.infinity,
        marginAll: 0,
      ),
      margin: pw.EdgeInsets.zero,
      build: (_) => columns.main,
    ),
  );
  await probe.save();
  final pages = probe.document.pdfPageList.pages;
  return math.max(pages[0].pageFormat.height, pages[1].pageFormat.height);
}
