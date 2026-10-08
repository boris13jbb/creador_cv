import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'one_page_metrics.dart';
import 'one_page_plan.dart';

/// Columnas de la plantilla. El título y el primer bloque van juntos.
class OnePageColumns {
  const OnePageColumns({required this.sidebar, required this.main});

  final pw.Widget sidebar;
  final pw.Widget main;
}

OnePageColumns buildOnePageColumns({
  required OnePagePlan plan,
  required OnePageMetrics metrics,
  required OnePagePalette palette,
  required pw.ImageProvider? photo,
}) {
  return OnePageColumns(
    sidebar: _sidebar(plan, metrics, palette, photo),
    main: _main(plan, metrics, palette),
  );
}

pw.Widget _sidebar(
  OnePagePlan plan,
  OnePageMetrics metrics,
  OnePagePalette palette,
  pw.ImageProvider? photo,
) {
  final children = <pw.Widget>[];
  if (plan.showPhoto && photo != null) {
    children.add(_photo(photo, metrics.photoSize));
    children.add(pw.SizedBox(height: metrics.sectionGap));
  }
  if (plan.contactLines.isNotEmpty) {
    children.add(_contact(plan.contactLines, metrics, palette));
    children.add(pw.SizedBox(height: metrics.sectionGap));
  }
  if (plan.summary != null) {
    children.add(
      _titled(
        title: OnePagePlan.summaryTitle,
        blocks: _paragraphBlocks(
          plan.summary!,
          metrics,
          palette.onSidebarMuted,
        ),
        metrics: metrics,
        titleColor: palette.onSidebar,
        ruleColor: palette.onSidebarMuted,
      ),
    );
  }
  if (plan.aptitudes.isNotEmpty) {
    children.add(
      _titled(
        title: OnePagePlan.aptitudesTitle,
        blocks: [
          for (final item in plan.aptitudes)
            _textItem(
              item,
              metrics,
              primary: palette.onSidebar,
              secondary: palette.onSidebarMuted,
              bullet: true,
            ),
        ],
        metrics: metrics,
        titleColor: palette.onSidebar,
        ruleColor: palette.onSidebarMuted,
      ),
    );
  }
  if (plan.skills.isNotEmpty) {
    children.add(
      _titled(
        title: OnePagePlan.skillsTitle,
        blocks: [
          for (final item in plan.skills)
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

  return pw.Padding(
    padding: pw.EdgeInsets.all(metrics.sidebarPad),
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
  OnePagePalette palette,
) {
  final children = <pw.Widget>[
    _header(plan, metrics, palette),
    if (plan.projects.isNotEmpty)
      _titled(
        title: OnePagePlan.projectsTitle,
        blocks: [
          for (final entry in plan.projects) _entry(entry, metrics, palette),
        ],
        metrics: metrics,
        titleColor: palette.accent,
        ruleColor: palette.accent,
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
    if (plan.certifications.isNotEmpty)
      _titled(
        title: OnePagePlan.certificationsTitle,
        blocks: [
          for (final entry in plan.certifications)
            _entry(entry, metrics, palette),
        ],
        metrics: metrics,
        titleColor: palette.accent,
        ruleColor: palette.accent,
      ),
    if (plan.languages.isNotEmpty)
      _titled(
        title: OnePagePlan.languagesTitle,
        blocks: [
          for (final item in plan.languages)
            _textItem(
              item,
              metrics,
              primary: palette.text,
              secondary: palette.muted,
              bullet: false,
            ),
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
          plan.name,
          style: pw.TextStyle(
            fontSize: metrics.nameSize,
            fontWeight: pw.FontWeight.bold,
            color: palette.accent,
            height: 1.05,
          ),
        ),
        if (plan.profession != null) ...[
          pw.SizedBox(height: metrics.lineGap + 1),
          pw.Text(
            plan.profession!,
            style: pw.TextStyle(
              fontSize: metrics.roleSize,
              color: palette.muted,
              height: 1.2,
            ),
          ),
        ],
        pw.SizedBox(height: metrics.headerGap),
        pw.Container(height: 1.1, color: palette.accent),
      ],
    ),
  );
}

pw.Widget _photo(pw.ImageProvider photo, double size) {
  return pw.Container(
    alignment: pw.Alignment.center,
    child: pw.Container(
      width: size,
      height: size,
      child: pw.ClipRRect(
        horizontalRadius: 2,
        verticalRadius: 2,
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
          padding: pw.EdgeInsets.only(bottom: metrics.lineGap + 1),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '•  ',
                style: pw.TextStyle(
                  fontSize: metrics.smallSize,
                  color: palette.onSidebar,
                ),
              ),
              pw.Expanded(
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
  final heading = pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    mainAxisSize: pw.MainAxisSize.min,
    children: [
      pw.Text(
        title.toUpperCase(),
        style: pw.TextStyle(
          fontSize: metrics.sectionSize,
          fontWeight: pw.FontWeight.bold,
          color: titleColor,
          letterSpacing: 0.5,
        ),
      ),
      pw.SizedBox(height: 2),
      pw.Container(height: 0.7, width: double.infinity, color: ruleColor),
      pw.SizedBox(height: metrics.headerGap),
    ],
  );

  return pw.Padding(
    padding: pw.EdgeInsets.only(bottom: metrics.sectionGap),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Inseparable(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisSize: pw.MainAxisSize.min,
            children: [heading, blocks.first],
          ),
        ),
        ...blocks.skip(1),
      ],
    ),
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
    if (parts.rest.isNotEmpty)
      pw.Text(parts.rest, style: style, overflow: pw.TextOverflow.span),
  ];
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

/// Continuación controlada cuando el contenido no cabe en una página A4.
///
/// Mantiene títulos con su primera línea y deja que los párrafos largos
/// sigan en la página siguiente. No recorta texto.
List<pw.Widget> buildOnePageOverflowFlow({
  required OnePagePlan plan,
  required OnePageMetrics metrics,
  required OnePagePalette palette,
  required pw.ImageProvider? photo,
}) {
  final blocks = <pw.Widget>[];
  final body = pw.TextStyle(
    fontSize: metrics.bodySize,
    color: palette.text,
    height: 1.28,
  );

  void addSection(String title, List<pw.Widget> parts) {
    if (parts.isEmpty) return;
    blocks.add(
      pw.Inseparable(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Text(
              title.toUpperCase(),
              style: pw.TextStyle(
                fontSize: metrics.sectionSize,
                fontWeight: pw.FontWeight.bold,
                color: palette.accent,
              ),
            ),
            pw.SizedBox(height: metrics.headerGap),
            parts.first,
          ],
        ),
      ),
    );
    blocks.addAll(parts.skip(1));
    blocks.add(pw.SizedBox(height: metrics.sectionGap));
  }

  pw.Widget span(String text, {bool bold = false}) {
    return pw.Padding(
      padding: pw.EdgeInsets.only(bottom: metrics.itemGap),
      child: pw.Text(
        text,
        style: bold
            ? pw.TextStyle(
                fontSize: metrics.bodySize,
                fontWeight: pw.FontWeight.bold,
                color: palette.text,
                height: 1.25,
              )
            : body,
        overflow: pw.TextOverflow.span,
      ),
    );
  }

  blocks.add(
    pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        if (plan.showPhoto && photo != null) ...[
          _photo(photo, metrics.photoSize),
          pw.SizedBox(height: metrics.headerGap),
        ],
        pw.Text(
          plan.name,
          style: pw.TextStyle(
            fontSize: metrics.nameSize,
            fontWeight: pw.FontWeight.bold,
            color: palette.accent,
          ),
        ),
        if (plan.profession != null)
          pw.Text(
            plan.profession!,
            style: pw.TextStyle(
              fontSize: metrics.roleSize,
              color: palette.muted,
            ),
          ),
      ],
    ),
  );

  if (plan.contactLines.isNotEmpty) {
    blocks.add(span(plan.contactLines.join('\n')));
  }
  if (plan.summary != null) {
    final parts = splitOnePageLead(plan.summary!);
    addSection(OnePagePlan.summaryTitle, [
      pw.Text(parts.lead, style: body),
      if (parts.rest.isNotEmpty)
        pw.Text(parts.rest, style: body, overflow: pw.TextOverflow.span),
    ]);
  }
  if (plan.aptitudes.isNotEmpty) {
    addSection(OnePagePlan.aptitudesTitle, [
      for (final item in plan.aptitudes)
        span(
          item.secondary == null
              ? '• ${item.primary}'
              : '• ${item.primary}\n${item.secondary}',
        ),
    ]);
  }
  if (plan.skills.isNotEmpty) {
    addSection(OnePagePlan.skillsTitle, [
      for (final item in plan.skills)
        span(
          item.secondary == null
              ? item.primary
              : '${item.primary}\n${item.secondary}',
          bold: true,
        ),
    ]);
  }
  void addEntries(String title, List<OnePageEntry> entries) {
    if (entries.isEmpty) return;
    final parts = <pw.Widget>[];
    for (final entry in entries) {
      parts.add(span(entry.title, bold: true));
      final body = _entryBody(entry);
      if (body.isNotEmpty) parts.add(span(body));
    }
    addSection(title, parts);
  }

  addEntries(OnePagePlan.projectsTitle, plan.projects);
  addEntries(OnePagePlan.experienceTitle, plan.experience);
  addEntries(OnePagePlan.educationTitle, plan.education);
  addEntries(OnePagePlan.certificationsTitle, plan.certifications);
  if (plan.languages.isNotEmpty) {
    addSection(OnePagePlan.languagesTitle, [
      for (final item in plan.languages)
        span(
          item.secondary == null
              ? item.primary
              : '${item.primary} — ${item.secondary}',
        ),
    ]);
  }
  return blocks;
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

String _entryBody(OnePageEntry entry) {
  final lines = <String>[
    if ((entry.trailing ?? '').trim().isNotEmpty) entry.trailing!.trim(),
    if ((entry.subtitle ?? '').trim().isNotEmpty) entry.subtitle!.trim(),
    ...entry.paragraphs,
    for (final bullet in entry.bullets) '• $bullet',
  ];
  return lines.join('\n');
}
