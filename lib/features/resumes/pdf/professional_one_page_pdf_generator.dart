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
    required this.pageWidths,
    required this.pageHeights,
    required this.summaryInSidebar,
  });

  final Uint8List bytes;
  final int pageCount;
  final OnePageMetrics metrics;
  final OnePagePlan plan;
  final double pageWidth;
  final double pageHeight;
  final List<double> pageWidths;
  final List<double> pageHeights;

  /// Falso cuando el resumen completo se dibujó en la columna principal.
  final bool summaryInSidebar;

  bool get fitsOnOnePage => pageCount == 1;
}

const _accentBar = 3.5;

/// Genera el PDF A4.
///
/// El caso que cabe se queda en dos páginas: barra completa y contenido
/// principal en la primera; barra reducida y certificaciones en la segunda.
/// Si el resumen no cabe en la barra, se compacta el espacio y, en último
/// caso, el texto completo pasa a la columna principal sin duplicarse.
/// El contenido que aun así supera la hoja continúa en páginas A4 siguientes.
///
/// El sidebar nunca se recorta en silencio: los bloques que no caben (p. ej.
/// Habilidades) pasan a la barra de las páginas siguientes.
Future<OnePagePdfResult> buildProfessionalOnePage(Resume resume) async {
  final theme = await ResumePdfFonts.theme();
  final photo = await loadResumeProfileImage(resume);
  final plan = OnePagePlan.fromResume(resume, hasPhotoImage: photo != null);
  final palette = OnePagePalette.fromColorHex(resume.colorHex);
  final sidebarWidth = PdfPageFormat.a4.width * OnePageMetrics.sidebarFraction;
  final mainWidth = PdfPageFormat.a4.width - sidebarWidth;
  final usable = PdfPageFormat.a4.height - _accentBar;
  final choice = await _chooseLayout(
    theme: theme,
    plan: plan,
    palette: palette,
    photo: photo,
    sidebarWidth: sidebarWidth,
    mainWidth: mainWidth,
    usable: usable,
  );
  final metrics = choice.metrics;
  final packed = await _packSidebarPages(
    theme: theme,
    plan: plan,
    metrics: metrics,
    palette: palette,
    photo: photo,
    summaryInSidebar: choice.summaryInSidebar,
    sidebarWidth: sidebarWidth,
    usable: usable,
  );
  final document = pw.Document(theme: theme);

  if (!choice.paginate) {
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (_) => _pageBody(
          sidebar: packed.sidebarFor(0),
          main: buildOnePageColumns(
            plan: plan,
            metrics: metrics,
            palette: palette,
            photo: photo,
            summaryInSidebar: choice.summaryInSidebar,
          ).main,
          palette: palette,
          sidebarWidth: sidebarWidth,
        ),
      ),
    );
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (_) => _pageBody(
          sidebar: packed.sidebarFor(1),
          main: buildOnePageSecondMain(
            plan: plan,
            metrics: metrics,
            palette: palette,
          ),
          palette: palette,
          sidebarWidth: sidebarWidth,
        ),
      ),
    );
  } else {
    await _addFlowPages(
      document: document,
      theme: theme,
      palette: palette,
      sidebarWidth: sidebarWidth,
      innerWidth: mainWidth - metrics.mainPad * 2,
      innerHeight: usable - metrics.mainPad * 2,
      pieces: onePagePrimaryPieces(
        plan: plan,
        metrics: metrics,
        palette: palette,
        includeSummary: !choice.summaryInSidebar && plan.summary != null,
      ),
      sidebars: packed,
      padding: metrics.mainPad,
      startPageIndex: 0,
    );
    final afterPrimary = document.document.pdfPageList.pages.length;
    await _addFlowPages(
      document: document,
      theme: theme,
      palette: palette,
      sidebarWidth: sidebarWidth,
      innerWidth: mainWidth - metrics.mainPad * 2,
      innerHeight: usable - metrics.mainPad * 2,
      pieces: onePageCertificationPieces(
        plan: plan,
        metrics: metrics,
        palette: palette,
      ),
      sidebars: packed,
      padding: metrics.mainPad,
      startPageIndex: afterPrimary,
    );
  }

  // Si el sidebar necesita más hojas que el contenido principal, añade páginas
  // con columna principal vacía para no perder Habilidades u otras secciones.
  final pagesSoFar = document.document.pdfPageList.pages.length;
  for (var index = pagesSoFar; index < packed.pageCount; index++) {
    _addPackedPage(
      document: document,
      palette: palette,
      sidebar: packed.sidebarFor(index),
      sidebarWidth: sidebarWidth,
      padding: metrics.mainPad,
      children: const [],
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
    pageWidths: [for (final page in pages) page.pageFormat.width],
    pageHeights: [for (final page in pages) page.pageFormat.height],
    summaryInSidebar: choice.summaryInSidebar && plan.summary != null,
  );
}

class _LayoutChoice {
  const _LayoutChoice({
    required this.metrics,
    required this.summaryInSidebar,
    required this.paginate,
  });

  final OnePageMetrics metrics;
  final bool summaryInSidebar;
  final bool paginate;
}

/// Sidebars empaquetados: la página 0 lleva lo que cabe; el resto continúa sin
/// recortar ni duplicar bloques del cuerpo.
class _PackedSidebars {
  const _PackedSidebars({required this.pages, required this.identityOnly});

  final List<pw.Widget> pages;
  final pw.Widget identityOnly;

  int get pageCount => pages.length;

  pw.Widget sidebarFor(int index) {
    if (index < pages.length) return pages[index];
    return identityOnly;
  }
}

Future<_LayoutChoice> _chooseLayout({
  required pw.ThemeData theme,
  required OnePagePlan plan,
  required OnePagePalette palette,
  required pw.ImageProvider? photo,
  required double sidebarWidth,
  required double mainWidth,
  required double usable,
}) async {
  for (final summaryInSidebar in [true, false]) {
    if (!summaryInSidebar && plan.summary == null) continue;
    for (var level = 2; level <= OnePageMetrics.maxLevel; level++) {
      final metrics = OnePageMetrics.forLevel(level);
      if (summaryInSidebar &&
          !await _summaryFitsAloneInSidebar(
            theme: theme,
            plan: plan,
            metrics: metrics,
            palette: palette,
            photo: photo,
            sidebarWidth: sidebarWidth,
            usable: usable,
          )) {
        break;
      }
      final packed = await _packSidebarPages(
        theme: theme,
        plan: plan,
        metrics: metrics,
        palette: palette,
        photo: photo,
        summaryInSidebar: summaryInSidebar,
        sidebarWidth: sidebarWidth,
        usable: usable,
      );
      // Dos páginas fijas solo si el cuerpo cabe en una barra y el resto en la
      // de continuación (sin necesitar una tercera hoja solo para el sidebar).
      if (packed.pageCount > 2) continue;

      final columns = buildOnePageColumns(
        plan: plan,
        metrics: metrics,
        palette: palette,
        photo: photo,
        summaryInSidebar: summaryInSidebar,
      );
      final mainHeight = await _measure(
        theme: theme,
        child: columns.main,
        width: mainWidth,
      );
      final certificationsHeight = await _measure(
        theme: theme,
        child: buildOnePageSecondMain(
          plan: plan,
          metrics: metrics,
          palette: palette,
        ),
        width: mainWidth,
      );
      final firstSidebarHeight = await _measure(
        theme: theme,
        child: packed.sidebarFor(0),
        width: sidebarWidth,
      );
      final secondSidebarHeight = await _measure(
        theme: theme,
        child: packed.sidebarFor(1),
        width: sidebarWidth,
      );
      if (firstSidebarHeight <= usable &&
          secondSidebarHeight <= usable &&
          mainHeight <= usable &&
          certificationsHeight <= usable) {
        return _LayoutChoice(
          metrics: metrics,
          summaryInSidebar: summaryInSidebar,
          paginate: false,
        );
      }
    }
    if (plan.summary == null) break;
  }

  for (final summaryInSidebar in [true, false]) {
    if (!summaryInSidebar && plan.summary == null) continue;
    for (var level = 2; level <= OnePageMetrics.maxLevel; level++) {
      final metrics = OnePageMetrics.forLevel(level);
      if (summaryInSidebar &&
          !await _summaryFitsAloneInSidebar(
            theme: theme,
            plan: plan,
            metrics: metrics,
            palette: palette,
            photo: photo,
            sidebarWidth: sidebarWidth,
            usable: usable,
          )) {
        break;
      }
      final packed = await _packSidebarPages(
        theme: theme,
        plan: plan,
        metrics: metrics,
        palette: palette,
        photo: photo,
        summaryInSidebar: summaryInSidebar,
        sidebarWidth: sidebarWidth,
        usable: usable,
      );
      final firstHeight = await _measure(
        theme: theme,
        child: packed.sidebarFor(0),
        width: sidebarWidth,
      );
      if (firstHeight <= usable) {
        return _LayoutChoice(
          metrics: metrics,
          summaryInSidebar: summaryInSidebar,
          paginate: true,
        );
      }
    }
  }
  return _LayoutChoice(
    metrics: OnePageMetrics.forLevel(OnePageMetrics.maxLevel),
    summaryInSidebar: false,
    paginate: true,
  );
}

/// Si el resumen solo ya no cabe en la barra, debe pasar a la columna principal.
Future<bool> _summaryFitsAloneInSidebar({
  required pw.ThemeData theme,
  required OnePagePlan plan,
  required OnePageMetrics metrics,
  required OnePagePalette palette,
  required pw.ImageProvider? photo,
  required double sidebarWidth,
  required double usable,
}) async {
  if (plan.summary == null) return true;
  final summaryOnly = buildOnePageSidebarBodyBlocks(
    plan: plan,
    metrics: metrics,
    palette: palette,
    includeSummary: true,
  ).where((block) => block.id == 'summary' || block.id == 'contact');
  final height = await _measure(
    theme: theme,
    child: buildOnePageSidebarFromBodyBlocks(
      plan: plan,
      metrics: metrics,
      palette: palette,
      photo: photo,
      bodyBlocks: summaryOnly.toList(),
      compactIdentity: false,
    ),
    width: sidebarWidth,
  );
  return height <= usable - 10;
}

Future<_PackedSidebars> _packSidebarPages({
  required pw.ThemeData theme,
  required OnePagePlan plan,
  required OnePageMetrics metrics,
  required OnePagePalette palette,
  required pw.ImageProvider? photo,
  required bool summaryInSidebar,
  required double sidebarWidth,
  required double usable,
}) async {
  final body = buildOnePageSidebarBodyBlocks(
    plan: plan,
    metrics: metrics,
    palette: palette,
    includeSummary: summaryInSidebar,
  );
  final identityOnly = buildOnePageContinuationSidebar(
    plan: plan,
    metrics: metrics,
    palette: palette,
  );

  if (body.isEmpty) {
    return _PackedSidebars(
      pages: [
        buildOnePageSidebar(
          plan: plan,
          metrics: metrics,
          palette: palette,
          photo: photo,
          includeSummary: summaryInSidebar,
          bodyBlocks: const [],
        ),
        identityOnly,
      ],
      identityOnly: identityOnly,
    );
  }

  final pages = <pw.Widget>[];
  var remaining = List<OnePageSidebarBlock>.of(body);
  var isFirst = true;
  // Margen respecto a la altura útil: la medición en página infinita puede
  // infraestimar un poco frente al contenedor A4 real.
  final budget = usable - 10;

  while (remaining.isNotEmpty) {
    final packedForPage = <OnePageSidebarBlock>[];
    final photoForPage = isFirst ? photo : null;
    final compact = !isFirst;

    Future<double> heightWith(List<OnePageSidebarBlock> blocks) {
      return _measure(
        theme: theme,
        child: buildOnePageSidebarFromBodyBlocks(
          plan: plan,
          metrics: metrics,
          palette: palette,
          photo: photoForPage,
          bodyBlocks: blocks,
          compactIdentity: compact,
        ),
        width: sidebarWidth,
      );
    }

    // Garantiza progreso: si el primer bloque no cabe solo, se fuerza igual
    // (evita bucle infinito; el contenido extremo aún se pinta).
    while (remaining.isNotEmpty) {
      final candidate = [...packedForPage, remaining.first];
      final height = await heightWith(candidate);
      if (packedForPage.isNotEmpty && height > budget) break;
      packedForPage.add(remaining.removeAt(0));
      if (height > budget && packedForPage.length == 1) break;
    }

    if (packedForPage.isEmpty) break;

    pages.add(
      buildOnePageSidebarFromBodyBlocks(
        plan: plan,
        metrics: metrics,
        palette: palette,
        photo: photoForPage,
        bodyBlocks: packedForPage,
        compactIdentity: compact,
      ),
    );
    isFirst = false;
  }

  if (pages.isEmpty) {
    pages.add(
      buildOnePageSidebar(
        plan: plan,
        metrics: metrics,
        palette: palette,
        photo: photo,
        includeSummary: summaryInSidebar,
        bodyBlocks: const [],
      ),
    );
  }
  if (pages.length == 1) {
    pages.add(identityOnly);
  }

  return _PackedSidebars(pages: pages, identityOnly: identityOnly);
}

Future<void> _addFlowPages({
  required pw.Document document,
  required pw.ThemeData theme,
  required OnePagePalette palette,
  required double sidebarWidth,
  required double innerWidth,
  required double innerHeight,
  required List<OnePageFlowPiece> pieces,
  required _PackedSidebars sidebars,
  required double padding,
  required int startPageIndex,
}) async {
  if (pieces.isEmpty) return;
  final atoms = await _flatten(
    theme: theme,
    pieces: pieces,
    width: innerWidth,
    maxHeight: innerHeight,
  );
  var pageIndex = startPageIndex;
  var bucket = <pw.Widget>[];
  for (final atom in atoms) {
    final candidate = [...bucket, atom];
    final height = await _measure(
      theme: theme,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisSize: pw.MainAxisSize.min,
        children: candidate,
      ),
      width: innerWidth,
    );
    if (bucket.isNotEmpty && height > innerHeight) {
      _addPackedPage(
        document: document,
        palette: palette,
        sidebar: sidebars.sidebarFor(pageIndex),
        sidebarWidth: sidebarWidth,
        padding: padding,
        children: bucket,
      );
      pageIndex += 1;
      bucket = [atom];
    } else {
      bucket = candidate;
    }
  }
  if (bucket.isNotEmpty) {
    _addPackedPage(
      document: document,
      palette: palette,
      sidebar: sidebars.sidebarFor(pageIndex),
      sidebarWidth: sidebarWidth,
      padding: padding,
      children: bucket,
    );
  }
}

Future<List<pw.Widget>> _flatten({
  required pw.ThemeData theme,
  required List<OnePageFlowPiece> pieces,
  required double width,
  required double maxHeight,
}) async {
  final atoms = <pw.Widget>[];
  for (final piece in pieces) {
    final height = await _measure(
      theme: theme,
      child: piece.widget,
      width: width,
    );
    if (height <= maxHeight || piece.children.isEmpty) {
      atoms.add(piece.widget);
    } else {
      atoms.addAll(
        await _flatten(
          theme: theme,
          pieces: piece.children,
          width: width,
          maxHeight: maxHeight,
        ),
      );
    }
  }
  return atoms;
}

void _addPackedPage({
  required pw.Document document,
  required OnePagePalette palette,
  required pw.Widget sidebar,
  required double sidebarWidth,
  required double padding,
  required List<pw.Widget> children,
}) {
  document.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (_) => _pageBody(
        sidebar: sidebar,
        main: pw.Padding(
          padding: pw.EdgeInsets.all(padding),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisSize: pw.MainAxisSize.min,
            children: children,
          ),
        ),
        palette: palette,
        sidebarWidth: sidebarWidth,
      ),
    ),
  );
}

Future<double> _measure({
  required pw.ThemeData theme,
  required pw.Widget child,
  required double width,
}) async {
  final probe = pw.Document(theme: theme);
  probe.addPage(
    pw.Page(
      pageFormat: PdfPageFormat(width, double.infinity, marginAll: 0),
      margin: pw.EdgeInsets.zero,
      build: (_) => child,
    ),
  );
  await probe.save();
  return probe.document.pdfPageList.pages.first.pageFormat.height;
}

Future<Uint8List> generateProfessionalOnePagePdf(Resume resume) async {
  final result = await buildProfessionalOnePage(resume);
  return result.bytes;
}

pw.Widget _pageBody({
  required pw.Widget sidebar,
  required pw.Widget main,
  required OnePagePalette palette,
  required double sidebarWidth,
}) {
  return pw.SizedBox(
    width: PdfPageFormat.a4.width,
    height: PdfPageFormat.a4.height,
    child: pw.Column(
      children: [
        pw.Container(height: 3.5, color: palette.accent),
        pw.Expanded(
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Container(
                width: sidebarWidth,
                color: palette.sidebar,
                child: sidebar,
              ),
              pw.Expanded(
                child: pw.Container(color: PdfColors.white, child: main),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
