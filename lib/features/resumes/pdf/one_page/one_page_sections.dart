import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../pdf_widgets.dart';
import 'one_page_metrics.dart';
import 'one_page_plan.dart';

/// Columnas de la plantilla. El título y el primer bloque van juntos.
class OnePageColumns {
  const OnePageColumns({required this.sidebar, required this.main});

  final pw.Widget sidebar;
  final pw.Widget main;
}

/// Bloque que se dibuja entero si cabe; si no, se sustituye por [children].
///
/// Así un resumen o una sección larga se parte entre páginas sin recortar texto.
class OnePageFlowPiece {
  const OnePageFlowPiece(this.widget, {this.children = const []});

  final pw.Widget widget;
  final List<OnePageFlowPiece> children;
}

/// Bloque atómico del sidebar que puede pasar a la página siguiente si no cabe.
class OnePageSidebarBlock {
  const OnePageSidebarBlock({required this.id, required this.widget});

  final String id;
  final pw.Widget widget;
}

OnePageColumns buildOnePageColumns({
  required OnePagePlan plan,
  required OnePageMetrics metrics,
  required OnePagePalette palette,
  required pw.ImageProvider? photo,
  bool summaryInSidebar = true,
}) {
  return OnePageColumns(
    sidebar: buildOnePageSidebar(
      plan: plan,
      metrics: metrics,
      palette: palette,
      photo: photo,
      includeSummary: summaryInSidebar,
    ),
    main: _main(plan, metrics, palette, includeSummary: !summaryInSidebar),
  );
}

/// Sidebar completo (identidad + cuerpo). Para CVs densos preferir el empaquetado
/// del generador, que reparte [buildOnePageSidebarBodyBlocks] entre páginas.
pw.Widget buildOnePageSidebar({
  required OnePagePlan plan,
  required OnePageMetrics metrics,
  required OnePagePalette palette,
  required pw.ImageProvider? photo,
  required bool includeSummary,
  List<OnePageSidebarBlock>? bodyBlocks,
}) {
  final body =
      bodyBlocks ??
      buildOnePageSidebarBodyBlocks(
        plan: plan,
        metrics: metrics,
        palette: palette,
        includeSummary: includeSummary,
      );
  return _sidebarColumn([
    ..._identityBlocks(plan, metrics, palette, photo, compact: false),
    for (final block in body) block.widget,
  ], metrics.sidebarPad);
}

/// Secciones del sidebar posteriores a la identidad, en orden de lectura.
///
/// Cada bloque es indivisible al empaquetar (título + primer contenido van
/// juntos). Las habilidades se emiten por filas de dos columnas.
List<OnePageSidebarBlock> buildOnePageSidebarBodyBlocks({
  required OnePagePlan plan,
  required OnePageMetrics metrics,
  required OnePagePalette palette,
  required bool includeSummary,
}) {
  final blocks = <OnePageSidebarBlock>[];
  if (plan.contactLines.isNotEmpty) {
    blocks.add(
      OnePageSidebarBlock(
        id: 'contact',
        widget: _titled(
          title: 'Contacto',
          blocks: [_contact(plan.contactLines, metrics, palette)],
          metrics: metrics,
          titleColor: palette.onSidebar,
          ruleColor: palette.onSidebarMuted,
        ),
      ),
    );
  }
  if (includeSummary && plan.summary != null) {
    blocks.add(
      OnePageSidebarBlock(
        id: 'summary',
        widget: _summarySection(
          plan.summary!,
          metrics,
          titleColor: palette.onSidebar,
          ruleColor: palette.onSidebarMuted,
          bodyColor: palette.onSidebarMuted,
        ),
      ),
    );
  }
  if (plan.aptitudes.isNotEmpty) {
    blocks.addAll(
      _titledItemBlocks(
        sectionId: 'aptitudes',
        title: OnePagePlan.aptitudesTitle,
        items: _sidebarAptitudeRows(
          plan.aptitudes,
          metrics,
          primary: palette.onSidebar,
          secondary: palette.onSidebarMuted,
          gap: (metrics.sidebarPad * 0.35).clamp(4.0, 8.0),
        ),
        metrics: metrics,
        titleColor: palette.onSidebar,
        ruleColor: palette.onSidebarMuted,
      ),
    );
  }
  if (plan.languages.isNotEmpty) {
    blocks.addAll(
      _titledItemBlocks(
        sectionId: 'languages',
        title: OnePagePlan.languagesTitle,
        items: [
          for (final item in plan.languages)
            _textItem(
              item,
              metrics,
              primary: palette.onSidebar,
              secondary: palette.onSidebarMuted,
              bullet: false,
            ),
        ],
        metrics: metrics,
        titleColor: palette.onSidebar,
        ruleColor: palette.onSidebarMuted,
      ),
    );
  }
  if (plan.skills.isNotEmpty) {
    // Competencias (Habilidades) en dos columnas: L→R y luego abajo.
    // Filas compactas van emparejadas; un cuerpo muy largo viaja solo para
    // poder partirse entre páginas sin recortar el nombre.
    final gap = (metrics.sidebarPad * 0.35).clamp(4.0, 8.0);
    final skillRows = <pw.Widget>[];
    OnePageTextItem? pending;
    void flushPair(OnePageTextItem left, OnePageTextItem? right) {
      skillRows.add(
        _pairRow(
          _textItem(
            left,
            metrics,
            primary: palette.onSidebar,
            secondary: palette.onSidebarMuted,
            bullet: false,
          ),
          right == null
              ? null
              : _textItem(
                  right,
                  metrics,
                  primary: palette.onSidebar,
                  secondary: palette.onSidebarMuted,
                  bullet: false,
                ),
          gap,
        ),
      );
    }

    for (final item in plan.skills) {
      final secondary = item.secondary ?? '';
      final tooTall = secondary.length > 280;
      if (tooTall) {
        if (pending != null) {
          flushPair(pending, null);
          pending = null;
        }
        // Nombre + trozos del detalle: el empaquetado puede pasar el resto
        // de página sin perder el título de la habilidad.
        skillRows.add(
          _textItem(
            OnePageTextItem(primary: item.primary),
            metrics,
            primary: palette.onSidebar,
            secondary: palette.onSidebarMuted,
            bullet: false,
          ),
        );
        for (final chunk in _wordChunks(secondary, 220)) {
          skillRows.add(
            pw.Padding(
              padding: pw.EdgeInsets.only(bottom: metrics.itemGap),
              child: pw.Text(
                chunk,
                style: pw.TextStyle(
                  fontSize: metrics.smallSize,
                  color: palette.onSidebarMuted,
                  height: metrics.textHeight,
                ),
              ),
            ),
          );
        }
        continue;
      }
      if (pending == null) {
        pending = item;
      } else {
        flushPair(pending, item);
        pending = null;
      }
    }
    if (pending != null) flushPair(pending, null);

    blocks.addAll(
      _titledItemBlocks(
        sectionId: 'skills',
        title: OnePagePlan.skillsTitle,
        items: skillRows,
        metrics: metrics,
        titleColor: palette.onSidebar,
        ruleColor: palette.onSidebarMuted,
      ),
    );
  }
  return blocks;
}

/// Título con el primer ítem; el resto sigue en bloques sueltos (misma sección).
List<OnePageSidebarBlock> _titledItemBlocks({
  required String sectionId,
  required String title,
  required List<pw.Widget> items,
  required OnePageMetrics metrics,
  required PdfColor titleColor,
  required PdfColor ruleColor,
}) {
  if (items.isEmpty) return const [];
  return [
    OnePageSidebarBlock(
      id: '${sectionId}_lead',
      widget: _titled(
        title: title,
        blocks: [items.first],
        metrics: metrics,
        titleColor: titleColor,
        ruleColor: ruleColor,
      ),
    ),
    for (var i = 1; i < items.length; i++)
      OnePageSidebarBlock(id: '${sectionId}_$i', widget: items[i]),
  ];
}

List<pw.Widget> _identityBlocks(
  OnePagePlan plan,
  OnePageMetrics metrics,
  OnePagePalette palette,
  pw.ImageProvider? photo, {
  required bool compact,
}) {
  final children = <pw.Widget>[];
  if (!compact && plan.showPhoto && photo != null) {
    children.add(_photo(photo, metrics.photoSize));
    children.add(pw.SizedBox(height: metrics.sectionGap));
  }
  children.add(
    pw.Text(
      _displayName(plan.name),
      style: pw.TextStyle(
        fontSize: metrics.sectionSize + (compact ? 2 : 3),
        fontWeight: pw.FontWeight.bold,
        color: palette.onSidebar,
        height: 1.05,
        letterSpacing: compact ? 0.3 : 0.35,
      ),
    ),
  );
  if (plan.profession != null) {
    children.add(pw.SizedBox(height: metrics.lineGap + 1));
    children.add(
      pw.Text(
        plan.profession!,
        style: pw.TextStyle(
          fontSize: metrics.smallSize,
          color: palette.onSidebarMuted,
          height: 1.2,
        ),
      ),
    );
  }
  children.add(pw.SizedBox(height: metrics.sectionGap));
  return children;
}

pw.Widget _sidebarColumn(List<pw.Widget> children, double pad) {
  return pw.Padding(
    padding: pw.EdgeInsets.all(pad),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisSize: pw.MainAxisSize.min,
      children: children,
    ),
  );
}

pw.Widget _main(
  OnePagePlan plan,
  OnePageMetrics metrics,
  OnePagePalette palette, {
  required bool includeSummary,
}) {
  final children = <pw.Widget>[
    _header(plan, metrics, palette),
    if (includeSummary && plan.summary != null)
      _summarySection(
        plan.summary!,
        metrics,
        titleColor: palette.accent,
        ruleColor: palette.accent,
        bodyColor: palette.text,
      ),
    if (plan.projects.isNotEmpty)
      _twoColumnSection(
        title: OnePagePlan.projectsTitle,
        entries: plan.projects,
        metrics: metrics,
        palette: palette,
        gap: 6 * PdfPageFormat.mm,
        card: (entry) => _projectCard(entry, metrics, palette),
      ),
    if (plan.experience.isNotEmpty)
      _titled(
        title: OnePagePlan.experienceTitle,
        blocks: [
          for (final entry in plan.experience) _entry(entry, metrics, palette),
        ],
        metrics: metrics,
        titleColor: palette.accent,
        ruleColor: palette.accent,
      ),
    if (plan.education.isNotEmpty)
      _titled(
        title: OnePagePlan.educationTitle,
        blocks: [
          for (final entry in plan.education) _entry(entry, metrics, palette),
        ],
        metrics: metrics,
        titleColor: palette.accent,
        ruleColor: palette.accent,
      ),
  ];

  return pw.Padding(
    padding: pw.EdgeInsets.fromLTRB(
      metrics.mainPad,
      metrics.mainPad,
      metrics.mainPad,
      metrics.mainPad,
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisSize: pw.MainAxisSize.min,
      children: children,
    ),
  );
}

pw.Widget _header(
  OnePagePlan plan,
  OnePageMetrics metrics,
  OnePagePalette palette,
) {
  return pw.Padding(
    padding: pw.EdgeInsets.only(bottom: metrics.sectionGap),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text(
          _displayName(plan.name),
          style: pw.TextStyle(
            fontSize: metrics.nameSize,
            fontWeight: pw.FontWeight.bold,
            color: palette.text,
            height: 1.02,
            letterSpacing: 0.4,
          ),
        ),
        if (plan.profession != null) ...[
          pw.SizedBox(height: metrics.lineGap + 1),
          pw.Text(
            plan.profession!,
            style: pw.TextStyle(
              fontSize: metrics.roleSize,
              fontWeight: pw.FontWeight.bold,
              color: palette.accent,
              letterSpacing: 0.15,
              height: 1.15,
            ),
          ),
        ],
        pw.SizedBox(height: metrics.headerGap),
        pw.Container(height: 1.4, width: 42, color: palette.accent),
      ],
    ),
  );
}

pw.Widget _photo(pw.ImageProvider photo, double size) {
  return pw.Container(
    alignment: pw.Alignment.center,
    child: pw.Container(
      padding: const pw.EdgeInsets.all(2.2),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.white, width: 1.1),
      ),
      child: pw.SizedBox(
        width: size,
        height: size,
        child: pw.Image(photo, fit: pw.BoxFit.cover),
      ),
    ),
  );
}

pw.Widget _contact(
  List<String> lines,
  OnePageMetrics metrics,
  OnePagePalette palette,
) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    mainAxisSize: pw.MainAxisSize.min,
    children: [
      for (final line in lines)
        pw.Padding(
          padding: pw.EdgeInsets.only(bottom: metrics.lineGap + 0.6),
          child: pw.Text(
            line,
            style: pw.TextStyle(
              fontSize: metrics.smallSize,
              color: palette.onSidebar,
              height: metrics.textHeight,
            ),
          ),
        ),
    ],
  );
}

/// El título y el primer bloque no se separan al saltar de página.
pw.Widget _titled({
  required String title,
  required List<pw.Widget> blocks,
  required OnePageMetrics metrics,
  required PdfColor titleColor,
  required PdfColor ruleColor,
}) {
  if (blocks.isEmpty) return pw.SizedBox();
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    mainAxisSize: pw.MainAxisSize.min,
    children: _titledParts(
      heading: _sectionHeading(title, metrics, titleColor, ruleColor),
      blocks: blocks,
      metrics: metrics,
    ),
  );
}

/// Título con la primera línea, y el resto de la sección para poder partirla.
List<pw.Widget> _titledParts({
  required pw.Widget heading,
  required List<pw.Widget> blocks,
  required OnePageMetrics metrics,
}) {
  if (blocks.isEmpty) return const [];
  return [
    pw.Inseparable(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisSize: pw.MainAxisSize.min,
        children: [heading, blocks.first],
      ),
    ),
    ...blocks.skip(1),
    pw.SizedBox(height: metrics.sectionGap),
  ];
}

/// Bloques de la columna derecha, en orden, para continuar en otra página.
List<pw.Widget> buildOnePageMainFlow({
  required OnePagePlan plan,
  required OnePageMetrics metrics,
  required OnePagePalette palette,
}) {
  final blocks = <pw.Widget>[_header(plan, metrics, palette)];
  void add(String title, List<pw.Widget> entries) {
    if (entries.isEmpty) return;
    blocks.addAll(
      _titledParts(
        heading: _sectionHeading(
          title,
          metrics,
          palette.accent,
          palette.accent,
        ),
        blocks: entries,
        metrics: metrics,
      ),
    );
  }

  add(OnePagePlan.projectsTitle, [
    for (final entry in plan.projects) _entry(entry, metrics, palette),
  ]);
  add(OnePagePlan.experienceTitle, [
    for (final entry in plan.experience) _entry(entry, metrics, palette),
  ]);
  add(OnePagePlan.educationTitle, [
    for (final entry in plan.education) _entry(entry, metrics, palette),
  ]);
  return blocks;
}

/// Columna principal de la primera página, lista para repartir si no cabe.
List<OnePageFlowPiece> onePagePrimaryPieces({
  required OnePagePlan plan,
  required OnePageMetrics metrics,
  required OnePagePalette palette,
  required bool includeSummary,
}) {
  final pieces = <OnePageFlowPiece>[_leaf(_header(plan, metrics, palette))];
  if (includeSummary && plan.summary != null) {
    pieces.add(_summaryPiece(plan.summary!, metrics, palette));
  }
  if (plan.projects.isNotEmpty) {
    pieces.add(
      _balancedSectionPiece(
        title: OnePagePlan.projectsTitle,
        entries: plan.projects,
        metrics: metrics,
        palette: palette,
        gap: 6 * PdfPageFormat.mm,
        card: (entry) => _projectCard(entry, metrics, palette),
        loose: (entry) =>
            _looseCardParts(entry, metrics, palette, showDateAbove: false),
      ),
    );
  }
  pieces.addAll(
    _listedSectionPieces(
      title: OnePagePlan.experienceTitle,
      entries: plan.experience,
      metrics: metrics,
      palette: palette,
    ),
  );
  pieces.addAll(
    _listedSectionPieces(
      title: OnePagePlan.educationTitle,
      entries: plan.education,
      metrics: metrics,
      palette: palette,
    ),
  );
  return pieces;
}

/// Certificaciones de la segunda página, con el mismo criterio de partición.
List<OnePageFlowPiece> onePageCertificationPieces({
  required OnePagePlan plan,
  required OnePageMetrics metrics,
  required OnePagePalette palette,
}) {
  if (plan.certifications.isEmpty) return const [];
  return [
    _balancedSectionPiece(
      title: OnePagePlan.certificationsTitle,
      entries: plan.certifications,
      metrics: metrics,
      palette: palette,
      gap: 7 * PdfPageFormat.mm,
      card: (entry) => _certCard(entry, metrics, palette),
      loose: (entry) =>
          _looseCardParts(entry, metrics, palette, showDateAbove: true),
    ),
  ];
}

OnePageFlowPiece _leaf(pw.Widget widget) => OnePageFlowPiece(widget);

OnePageFlowPiece _summaryPiece(
  String summary,
  OnePageMetrics metrics,
  OnePagePalette palette,
) {
  final chunks = _wordChunks(summary, 900);
  final style = pw.TextStyle(
    fontSize: metrics.bodySize,
    color: palette.text,
    height: metrics.textHeight,
  );
  final blocks = [for (final chunk in chunks) pw.Text(chunk, style: style)];
  return OnePageFlowPiece(
    _summarySection(
      summary,
      metrics,
      titleColor: palette.accent,
      ruleColor: palette.accent,
      bodyColor: palette.text,
    ),
    children: [
      for (final part in _titledParts(
        heading: _sectionHeading(
          OnePagePlan.summaryTitle,
          metrics,
          palette.accent,
          palette.accent,
        ),
        blocks: blocks,
        metrics: metrics,
      ))
        _leaf(part),
    ],
  );
}

OnePageFlowPiece _balancedSectionPiece({
  required String title,
  required List<OnePageEntry> entries,
  required OnePageMetrics metrics,
  required OnePagePalette palette,
  required double gap,
  required pw.Widget Function(OnePageEntry entry) card,
  required List<pw.Widget> Function(OnePageEntry entry) loose,
}) {
  final heights = [
    for (final entry in entries) estimateOnePageEntryHeight(entry, metrics),
  ];
  final split = splitIndexForBalance(heights);
  final left = entries.sublist(0, split);
  final right = entries.sublist(split);
  final rows = <OnePageFlowPiece>[];
  final count = left.length > right.length ? left.length : right.length;
  for (var index = 0; index < count; index++) {
    final leftEntry = index < left.length ? left[index] : null;
    final rightEntry = index < right.length ? right[index] : null;
    rows.add(
      OnePageFlowPiece(
        _pairRow(
          leftEntry == null ? null : card(leftEntry),
          rightEntry == null ? null : card(rightEntry),
          gap,
        ),
        children: [
          if (leftEntry != null)
            OnePageFlowPiece(
              card(leftEntry),
              children: [for (final part in loose(leftEntry)) _leaf(part)],
            ),
          if (rightEntry != null)
            OnePageFlowPiece(
              card(rightEntry),
              children: [for (final part in loose(rightEntry)) _leaf(part)],
            ),
        ],
      ),
    );
  }
  return _sectionPiece(
    title: title,
    metrics: metrics,
    palette: palette,
    body: _twoColumnSection(
      title: title,
      entries: entries,
      metrics: metrics,
      palette: palette,
      gap: gap,
      card: card,
    ),
    children: rows,
  );
}

OnePageFlowPiece _sectionPiece({
  required String title,
  required OnePageMetrics metrics,
  required OnePagePalette palette,
  required pw.Widget body,
  required List<OnePageFlowPiece> children,
}) {
  final heading = _sectionHeading(
    title,
    metrics,
    palette.accent,
    palette.accent,
  );
  if (children.isEmpty) return _leaf(body);
  return OnePageFlowPiece(
    body,
    children: [
      ..._withHeading(heading, children.first),
      ...children.skip(1),
      _leaf(pw.SizedBox(height: metrics.sectionGap)),
    ],
  );
}

/// El título viaja con el primer bloque. El resto se parte sin repetir texto.
List<OnePageFlowPiece> _withHeading(pw.Widget heading, OnePageFlowPiece piece) {
  return [
    OnePageFlowPiece(
      pw.Inseparable(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisSize: pw.MainAxisSize.min,
          children: [heading, piece.widget],
        ),
      ),
      children: piece.children.isEmpty
          ? const []
          : [
              ..._withHeading(heading, piece.children.first),
              ...piece.children.skip(1),
            ],
    ),
  ];
}

List<OnePageFlowPiece> _listedSectionPieces({
  required String title,
  required List<OnePageEntry> entries,
  required OnePageMetrics metrics,
  required OnePagePalette palette,
}) {
  if (entries.isEmpty) return const [];
  final items = [
    for (final entry in entries)
      OnePageFlowPiece(
        _entry(entry, metrics, palette),
        children: [
          for (final part in _looseEntryParts(entry, metrics, palette))
            _leaf(part),
        ],
      ),
  ];
  return [
    _sectionPiece(
      title: title,
      metrics: metrics,
      palette: palette,
      body: _titled(
        title: title,
        blocks: [for (final entry in entries) _entry(entry, metrics, palette)],
        metrics: metrics,
        titleColor: palette.accent,
        ruleColor: palette.accent,
      ),
      children: items,
    ),
  ];
}

pw.Widget _pairRow(pw.Widget? left, pw.Widget? right, double gap) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(child: left ?? pw.SizedBox()),
      pw.SizedBox(width: gap),
      pw.Expanded(child: right ?? pw.SizedBox()),
    ],
  );
}

/// Aptitudes del sidebar: pares L→R y la última impar a ancho completo.
List<pw.Widget> _sidebarAptitudeRows(
  List<OnePageTextItem> items,
  OnePageMetrics metrics, {
  required PdfColor primary,
  required PdfColor secondary,
  required double gap,
}) {
  final rows = <pw.Widget>[];
  final compact = <OnePageTextItem>[];

  pw.Widget itemOf(OnePageTextItem item) {
    return _textItem(
      item,
      metrics,
      primary: primary,
      secondary: secondary,
      bullet: false,
    );
  }

  void flushCompact() {
    for (final row in pdfAptitudePlacements(compact.length)) {
      if (row.fullWidth) {
        rows.add(itemOf(compact[row.left]));
      } else {
        rows.add(
          _pairRow(itemOf(compact[row.left]), itemOf(compact[row.right!]), gap),
        );
      }
    }
    compact.clear();
  }

  for (final item in items) {
    final detail = item.secondary ?? '';
    if (detail.length > 280) {
      flushCompact();
      rows.add(itemOf(OnePageTextItem(primary: item.primary)));
      for (final chunk in _wordChunks(detail, 220)) {
        rows.add(
          pw.Padding(
            padding: pw.EdgeInsets.only(bottom: metrics.itemGap),
            child: pw.Text(
              chunk,
              style: pw.TextStyle(
                fontSize: metrics.smallSize,
                color: secondary,
                height: metrics.textHeight,
              ),
            ),
          ),
        );
      }
      continue;
    }
    compact.add(item);
  }
  flushCompact();
  return rows;
}

List<pw.Widget> _looseCardParts(
  OnePageEntry entry,
  OnePageMetrics metrics,
  OnePagePalette palette, {
  required bool showDateAbove,
}) {
  final institution = entry.subtitle?.trim() ?? '';
  final hours = entry.hours?.trim() ?? '';
  final meta = [
    if (institution.isNotEmpty) institution,
    if (hours.isNotEmpty) hours,
  ].join(' · ');
  final date = entry.trailing?.trim() ?? '';
  final paragraphs = [
    for (final paragraph in entry.paragraphs) ..._wordChunks(paragraph, 700),
  ];
  final heading = pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    mainAxisSize: pw.MainAxisSize.min,
    children: [
      if (showDateAbove && date.isNotEmpty)
        pw.Text(
          date,
          style: pw.TextStyle(
            fontSize: metrics.smallSize,
            fontWeight: pw.FontWeight.bold,
            color: palette.accent,
            height: metrics.textHeight,
          ),
        ),
      pw.Text(
        entry.title,
        style: pw.TextStyle(
          fontSize: metrics.bodySize,
          fontWeight: pw.FontWeight.bold,
          color: palette.text,
          height: metrics.textHeight,
        ),
      ),
      if (!showDateAbove && date.isNotEmpty)
        pw.Text(
          date,
          style: pw.TextStyle(
            fontSize: metrics.smallSize,
            color: palette.accent,
            height: metrics.textHeight,
          ),
        ),
      if (meta.isNotEmpty)
        pw.Text(
          meta,
          style: pw.TextStyle(
            fontSize: metrics.smallSize,
            fontStyle: pw.FontStyle.italic,
            color: palette.muted,
            height: metrics.textHeight,
          ),
        ),
      if (paragraphs.isNotEmpty)
        pw.Padding(
          padding: pw.EdgeInsets.only(top: metrics.lineGap),
          child: pw.Text(
            paragraphs.first,
            style: pw.TextStyle(
              fontSize: metrics.bodySize - 0.4,
              color: palette.text,
              height: metrics.textHeight,
            ),
          ),
        ),
    ],
  );
  return [
    pw.Container(
      margin: pw.EdgeInsets.only(bottom: metrics.itemGap + 3),
      padding: const pw.EdgeInsets.fromLTRB(6, 1, 2, 2),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          left: pw.BorderSide(color: palette.accent, width: PdfPageFormat.mm),
        ),
      ),
      child: heading,
    ),
    for (final chunk in paragraphs.skip(1))
      pw.Padding(
        padding: pw.EdgeInsets.only(bottom: metrics.lineGap),
        child: pw.Text(
          chunk,
          style: pw.TextStyle(
            fontSize: metrics.bodySize - 0.4,
            color: palette.text,
            height: metrics.textHeight,
          ),
        ),
      ),
  ];
}

List<pw.Widget> _looseEntryParts(
  OnePageEntry entry,
  OnePageMetrics metrics,
  OnePagePalette palette,
) {
  final paragraphs = [
    for (final paragraph in entry.paragraphs) ..._wordChunks(paragraph, 700),
  ];
  final head = _entry(
    OnePageEntry(
      title: entry.title,
      subtitle: entry.subtitle,
      trailing: entry.trailing,
      paragraphs: paragraphs.isEmpty ? const [] : [paragraphs.first],
      dateAbove: entry.dateAbove,
      hours: entry.hours,
    ),
    metrics,
    palette,
  );
  return [
    head,
    for (final chunk in paragraphs.skip(1))
      pw.Padding(
        padding: pw.EdgeInsets.only(bottom: metrics.itemGap),
        child: pw.Text(
          chunk,
          style: pw.TextStyle(
            fontSize: metrics.bodySize - 0.4,
            color: palette.text,
            height: metrics.textHeight,
          ),
        ),
      ),
  ];
}

/// Parte un texto largo por palabras, sin descartar ningún carácter.
List<String> _wordChunks(String text, int maxChars) {
  final source = text.trim();
  if (source.isEmpty) return const [];
  if (source.length <= maxChars) return [source];
  final chunks = <String>[];
  var start = 0;
  while (start < source.length) {
    var end = start + maxChars;
    if (end >= source.length) {
      chunks.add(source.substring(start).trim());
      break;
    }
    var split = source.lastIndexOf(' ', end);
    if (split <= start) split = end;
    final chunk = source.substring(start, split).trim();
    if (chunk.isNotEmpty) chunks.add(chunk);
    start = split;
    while (start < source.length && source[start] == ' ') {
      start++;
    }
  }
  return chunks;
}

/// Segunda página: solo certificaciones, en dos columnas.
pw.Widget buildOnePageSecondMain({
  required OnePagePlan plan,
  required OnePageMetrics metrics,
  required OnePagePalette palette,
}) {
  return pw.Padding(
    padding: pw.EdgeInsets.fromLTRB(
      metrics.mainPad,
      metrics.mainPad,
      metrics.mainPad,
      metrics.mainPad,
    ),
    child: plan.certifications.isEmpty
        ? pw.SizedBox()
        : _twoColumnSection(
            title: OnePagePlan.certificationsTitle,
            entries: plan.certifications,
            metrics: metrics,
            palette: palette,
            gap: 7 * PdfPageFormat.mm,
            card: (entry) => _certCard(entry, metrics, palette),
          ),
  );
}

/// Índice del primer elemento de la columna derecha.
///
/// Conserva el orden: 0..k-1 a la izquierda y el resto a la derecha.
/// Si las alturas empatan, se queda el reparto más cercano a la mitad.
int splitIndexForBalance(List<double> heights) =>
    pdfSplitIndexForBalance(heights);

/// Altura estimada de una tarjeta, para repartir columnas sin partirlas.
double estimateOnePageEntryHeight(
  OnePageEntry entry,
  OnePageMetrics metrics, {
  double columnWidth = 160,
}) {
  final chars = (columnWidth / (metrics.bodySize * 0.5)).floor().clamp(10, 70);
  var lines = _wrappedLines(entry.title, chars);
  if ((entry.trailing ?? '').trim().isNotEmpty) lines += 1;
  if ((entry.subtitle ?? '').trim().isNotEmpty ||
      (entry.hours ?? '').trim().isNotEmpty) {
    lines += 1;
  }
  for (final paragraph in entry.paragraphs) {
    lines += _wrappedLines(paragraph, chars);
  }
  for (final bullet in entry.bullets) {
    lines += _wrappedLines(bullet, chars);
  }
  return lines * metrics.bodySize * metrics.textHeight + metrics.itemGap + 8;
}

int _wrappedLines(String text, int chars) {
  if (text.trim().isEmpty) return 0;
  var lines = 0;
  for (final part in text.split('\n')) {
    final length = part.trim().length;
    lines += length == 0 ? 1 : (length / chars).ceil();
  }
  return lines;
}

pw.Widget _twoColumnSection({
  required String title,
  required List<OnePageEntry> entries,
  required OnePageMetrics metrics,
  required OnePagePalette palette,
  required double gap,
  required pw.Widget Function(OnePageEntry entry) card,
}) {
  final heights = [
    for (final entry in entries) estimateOnePageEntryHeight(entry, metrics),
  ];
  final split = splitIndexForBalance(heights);
  final left = entries.sublist(0, split);
  final right = entries.sublist(split);
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    mainAxisSize: pw.MainAxisSize.min,
    children: [
      _sectionHeading(title, metrics, palette.accent, palette.accent),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [for (final entry in left) card(entry)],
            ),
          ),
          if (right.isNotEmpty) ...[
            pw.SizedBox(width: gap),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [for (final entry in right) card(entry)],
              ),
            ),
          ],
        ],
      ),
      pw.SizedBox(height: metrics.sectionGap),
    ],
  );
}

pw.Widget _projectCard(
  OnePageEntry entry,
  OnePageMetrics metrics,
  OnePagePalette palette,
) {
  return _accentCard(
    entry: entry,
    metrics: metrics,
    palette: palette,
    showDateAbove: false,
  );
}

pw.Widget _certCard(
  OnePageEntry entry,
  OnePageMetrics metrics,
  OnePagePalette palette,
) {
  return _accentCard(
    entry: entry,
    metrics: metrics,
    palette: palette,
    showDateAbove: true,
  );
}

pw.Widget _accentCard({
  required OnePageEntry entry,
  required OnePageMetrics metrics,
  required OnePagePalette palette,
  required bool showDateAbove,
}) {
  final institution = entry.subtitle?.trim() ?? '';
  final hours = entry.hours?.trim() ?? '';
  final meta = [
    if (institution.isNotEmpty) institution,
    if (hours.isNotEmpty) hours,
  ].join(' · ');
  final date = entry.trailing?.trim() ?? '';
  return pw.Container(
    margin: pw.EdgeInsets.only(bottom: metrics.itemGap + 3),
    padding: const pw.EdgeInsets.fromLTRB(6, 1, 2, 2),
    decoration: pw.BoxDecoration(
      border: pw.Border(
        left: pw.BorderSide(color: palette.accent, width: PdfPageFormat.mm),
      ),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (showDateAbove && date.isNotEmpty)
          pw.Text(
            date,
            style: pw.TextStyle(
              fontSize: metrics.smallSize,
              fontWeight: pw.FontWeight.bold,
              color: palette.accent,
              height: metrics.textHeight,
            ),
          ),
        pw.Text(
          entry.title,
          style: pw.TextStyle(
            fontSize: metrics.bodySize,
            fontWeight: pw.FontWeight.bold,
            color: palette.text,
            height: metrics.textHeight,
          ),
        ),
        if (!showDateAbove && date.isNotEmpty)
          pw.Text(
            date,
            style: pw.TextStyle(
              fontSize: metrics.smallSize,
              color: palette.accent,
              height: metrics.textHeight,
            ),
          ),
        if (meta.isNotEmpty)
          pw.Text(
            meta,
            style: pw.TextStyle(
              fontSize: metrics.smallSize,
              fontStyle: pw.FontStyle.italic,
              color: palette.muted,
              height: metrics.textHeight,
            ),
          ),
        for (final paragraph in entry.paragraphs)
          pw.Padding(
            padding: pw.EdgeInsets.only(top: metrics.lineGap),
            child: pw.Text(
              paragraph,
              style: pw.TextStyle(
                fontSize: metrics.bodySize - 0.4,
                color: palette.text,
                height: metrics.textHeight,
              ),
            ),
          ),
      ],
    ),
  );
}

pw.Widget _sectionHeading(
  String title,
  OnePageMetrics metrics,
  PdfColor titleColor,
  PdfColor ruleColor,
) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    mainAxisSize: pw.MainAxisSize.min,
    children: [
      pw.Text(
        title.toUpperCase(),
        style: pw.TextStyle(
          fontSize: metrics.sectionSize,
          fontWeight: pw.FontWeight.bold,
          color: titleColor,
          letterSpacing: 1.05,
        ),
      ),
      pw.SizedBox(height: 2),
      pw.Container(height: 0.6, width: 28, color: ruleColor),
      pw.SizedBox(height: metrics.headerGap),
    ],
  );
}

List<pw.Widget> _paragraphBlocks(
  String text,
  OnePageMetrics metrics,
  PdfColor color,
) {
  final parts = splitOnePageLead(text);
  final style = pw.TextStyle(
    fontSize: metrics.bodySize,
    color: color,
    height: metrics.textHeight,
  );
  return [
    pw.Text(parts.lead, style: style),
    if (parts.rest.isNotEmpty) pw.Text(parts.rest, style: style),
  ];
}

pw.Widget _summarySection(
  String summary,
  OnePageMetrics metrics, {
  required PdfColor titleColor,
  required PdfColor ruleColor,
  required PdfColor bodyColor,
}) {
  return _titled(
    title: OnePagePlan.summaryTitle,
    blocks: _paragraphBlocks(summary, metrics, bodyColor),
    metrics: metrics,
    titleColor: titleColor,
    ruleColor: ruleColor,
  );
}

pw.Widget _textItem(
  OnePageTextItem item,
  OnePageMetrics metrics, {
  required PdfColor primary,
  required PdfColor secondary,
  required bool bullet,
}) {
  return pw.Padding(
    padding: pw.EdgeInsets.only(bottom: metrics.itemGap),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (bullet)
              pw.Text(
                '•  ',
                style: pw.TextStyle(fontSize: metrics.bodySize, color: primary),
              ),
            pw.Expanded(
              child: pw.Text(
                item.primary,
                style: pw.TextStyle(
                  fontSize: metrics.bodySize,
                  fontWeight: pw.FontWeight.bold,
                  color: primary,
                  height: metrics.textHeight,
                ),
              ),
            ),
          ],
        ),
        if (item.secondary != null && item.secondary!.isNotEmpty)
          pw.Padding(
            padding: pw.EdgeInsets.only(
              left: bullet ? 12 : 0,
              top: metrics.lineGap,
            ),
            child: pw.Text(
              item.secondary!,
              style: pw.TextStyle(
                fontSize: metrics.smallSize,
                color: secondary,
                height: metrics.textHeight,
              ),
            ),
          ),
      ],
    ),
  );
}

pw.Widget _entry(
  OnePageEntry entry,
  OnePageMetrics metrics,
  OnePagePalette palette,
) {
  final trailing = entry.trailing?.trim() ?? '';
  final subtitle = entry.subtitle?.trim() ?? '';
  final dateBesideTitle = !entry.dateAbove || !metrics.compactLists;
  final showDateAbove =
      entry.dateAbove && trailing.isNotEmpty && !metrics.compactLists;
  final meta = metrics.compactLists && entry.dateAbove && trailing.isNotEmpty
      ? (subtitle.isEmpty ? trailing : '$trailing · $subtitle')
      : subtitle;
  final paragraphs = metrics.compactLists
      ? _paragraphsWithoutRepeatedTech(entry.paragraphs)
      : entry.paragraphs;
  return pw.Padding(
    padding: pw.EdgeInsets.only(bottom: metrics.itemGap),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        if (showDateAbove)
          pw.Text(
            trailing,
            style: pw.TextStyle(
              fontSize: metrics.smallSize,
              fontWeight: pw.FontWeight.bold,
              color: palette.accent,
              height: metrics.textHeight,
            ),
          ),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Text(
                entry.title,
                style: pw.TextStyle(
                  fontSize: metrics.bodySize + 0.4,
                  fontWeight: pw.FontWeight.bold,
                  color: palette.text,
                  height: metrics.textHeight,
                ),
              ),
            ),
            if (dateBesideTitle && !entry.dateAbove && trailing.isNotEmpty) ...[
              pw.SizedBox(width: 6),
              pw.Text(
                trailing,
                style: pw.TextStyle(
                  fontSize: metrics.smallSize,
                  fontWeight: pw.FontWeight.bold,
                  color: palette.accent,
                ),
              ),
            ],
          ],
        ),
        if (meta.isNotEmpty) ...[
          pw.SizedBox(height: metrics.lineGap),
          pw.Text(
            meta,
            style: pw.TextStyle(
              fontSize: metrics.smallSize,
              fontStyle: pw.FontStyle.italic,
              color: palette.muted,
              height: metrics.textHeight,
            ),
          ),
        ],
        for (final paragraph in paragraphs)
          pw.Padding(
            padding: pw.EdgeInsets.only(top: metrics.lineGap),
            child: pw.Text(
              paragraph,
              style: pw.TextStyle(
                fontSize: metrics.bodySize,
                color: palette.text,
                height: metrics.textHeight,
              ),
            ),
          ),
        for (final bullet in entry.bullets)
          pw.Padding(
            padding: pw.EdgeInsets.only(top: metrics.lineGap),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '•  ',
                  style: pw.TextStyle(
                    fontSize: metrics.bodySize,
                    color: palette.text,
                  ),
                ),
                pw.Expanded(
                  child: pw.Text(
                    bullet,
                    style: pw.TextStyle(
                      fontSize: metrics.bodySize,
                      color: palette.text,
                      height: metrics.textHeight,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

/// Quita tecnologías ya dichas en el párrafo anterior.
///
/// Si de una lista queda una sola tecnología breve, se pasa a la línea
/// siguiente junto con la última palabra (`laboral. · Flutter`).
List<String> _paragraphsWithoutRepeatedTech(List<String> paragraphs) {
  if (paragraphs.length < 2) return paragraphs;
  final kept = <String>[paragraphs.first];
  for (final extra in paragraphs.skip(1)) {
    final previous = kept.last.toLowerCase();
    final tokens = extra
        .split(' · ')
        .map((token) => token.trim())
        .where((token) => token.isNotEmpty)
        .where((token) => !previous.contains(token.toLowerCase()))
        .toList();
    if (tokens.isEmpty) continue;
    if (extra.contains(' · ') &&
        tokens.length == 1 &&
        tokens.single.length <= 24) {
      kept[kept.length - 1] = _continueShortToken(kept.last, tokens.single);
      continue;
    }
    kept.add(tokens.join(' · '));
  }
  return kept;
}

/// Cierra el párrafo y deja la tecnología en la misma línea que la última palabra.
String _continueShortToken(String paragraph, String token) {
  final lastWord = RegExp(r'\S+$').firstMatch(paragraph);
  if (lastWord == null) return '$paragraph · $token';
  final head = paragraph.substring(0, lastWord.start).trimRight();
  final tail = '${lastWord.group(0)} · $token';
  if (head.isEmpty) return tail;
  return '$head\n$tail';
}

/// El nombre se dibuja en mayúsculas. El valor guardado en el CV no cambia.
String _displayName(String name) => name.trim().toUpperCase();

/// Barra de continuación: identidad ligera y, si hace falta, bloques que no
/// cupieron en la primera página (p. ej. Habilidades).
pw.Widget buildOnePageContinuationSidebar({
  required OnePagePlan plan,
  required OnePageMetrics metrics,
  required OnePagePalette palette,
  List<OnePageSidebarBlock> overflowBlocks = const [],
}) {
  final children = <pw.Widget>[
    ..._identityBlocks(plan, metrics, palette, null, compact: true),
  ];
  if (overflowBlocks.isEmpty && plan.contactLines.isNotEmpty) {
    children.add(_contact(plan.contactLines, metrics, palette));
  }
  for (final block in overflowBlocks) {
    children.add(block.widget);
  }
  return _sidebarColumn(children, metrics.sidebarPad);
}

/// Une bloques del cuerpo en una columna con el padding del sidebar.
pw.Widget buildOnePageSidebarFromBodyBlocks({
  required OnePagePlan plan,
  required OnePageMetrics metrics,
  required OnePagePalette palette,
  required pw.ImageProvider? photo,
  required List<OnePageSidebarBlock> bodyBlocks,
  bool compactIdentity = false,
}) {
  return _sidebarColumn([
    ..._identityBlocks(
      plan,
      metrics,
      palette,
      compactIdentity ? null : photo,
      compact: compactIdentity,
    ),
    for (final block in bodyBlocks) block.widget,
  ], metrics.sidebarPad);
}
