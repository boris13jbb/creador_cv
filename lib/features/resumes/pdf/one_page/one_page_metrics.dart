import 'package:pdf/pdf.dart';

/// Densidad de la plantilla One Page.
///
/// Niveles, en orden: espaciado normal, menos espacio vertical, menos padding,
/// listas más compactas, tipografía ligeramente menor y alturas secundarias
/// menores. El nivel 6 es el piso de legibilidad.
class OnePageMetrics {
  const OnePageMetrics({
    required this.level,
    required this.nameSize,
    required this.roleSize,
    required this.sectionSize,
    required this.bodySize,
    required this.smallSize,
    required this.sectionGap,
    required this.itemGap,
    required this.lineGap,
    required this.sidebarPad,
    required this.mainPad,
    required this.photoSize,
    required this.headerGap,
    required this.textHeight,
    required this.compactLists,
  });

  final int level;
  final double nameSize;
  final double roleSize;
  final double sectionSize;
  final double bodySize;
  final double smallSize;
  final double sectionGap;
  final double itemGap;
  final double lineGap;
  final double sidebarPad;
  final double mainPad;
  final double photoSize;
  final double headerGap;
  final double textHeight;

  /// Junta fecha e institución y funde los párrafos cortos de cada ítem.
  final bool compactLists;

  static const sidebarFraction = 0.32;
  static const minBodySize = 8.0;
  static const minSectionSize = 9.0;
  static const minNameSize = 16.0;
  static const minPhotoSize = 56.0;
  static const int maxLevel = 6;

  bool get meetsReadability =>
      bodySize >= minBodySize &&
      sectionSize >= minSectionSize &&
      nameSize >= minNameSize &&
      photoSize >= minPhotoSize &&
      smallSize >= 7.5;

  static OnePageMetrics forLevel(int level) {
    switch (level.clamp(1, maxLevel)) {
      case 1:
        return const OnePageMetrics(
          level: 1,
          nameSize: 20,
          roleSize: 11,
          sectionSize: 11,
          bodySize: 9.5,
          smallSize: 8.5,
          sectionGap: 10,
          itemGap: 6,
          lineGap: 2,
          sidebarPad: 14,
          mainPad: 16,
          photoSize: 84,
          headerGap: 7,
          textHeight: 1.28,
          compactLists: false,
        );
      case 2:
        return const OnePageMetrics(
          level: 2,
          nameSize: 20,
          roleSize: 11,
          sectionSize: 11,
          bodySize: 9.5,
          smallSize: 8.5,
          sectionGap: 6,
          itemGap: 4,
          lineGap: 1.3,
          sidebarPad: 14,
          mainPad: 16,
          photoSize: 84,
          headerGap: 4,
          textHeight: 1.22,
          compactLists: false,
        );
      case 3:
        return const OnePageMetrics(
          level: 3,
          nameSize: 20,
          roleSize: 11,
          sectionSize: 11,
          bodySize: 9.5,
          smallSize: 8.5,
          sectionGap: 6,
          itemGap: 4,
          lineGap: 1.3,
          sidebarPad: 10,
          mainPad: 11,
          photoSize: 80,
          headerGap: 4,
          textHeight: 1.18,
          compactLists: false,
        );
      case 4:
        return const OnePageMetrics(
          level: 4,
          nameSize: 18.5,
          roleSize: 10.5,
          sectionSize: 10.5,
          bodySize: 9,
          smallSize: 8.2,
          sectionGap: 3.5,
          itemGap: 2,
          lineGap: 0.6,
          sidebarPad: 9,
          mainPad: 10,
          photoSize: 72,
          headerGap: 2.5,
          textHeight: 1.16,
          compactLists: true,
        );
      case 5:
        return const OnePageMetrics(
          level: 5,
          nameSize: 17,
          roleSize: 9.5,
          sectionSize: 9.5,
          bodySize: 8.5,
          smallSize: 8,
          sectionGap: 3,
          itemGap: 1.6,
          lineGap: 0.4,
          sidebarPad: 8,
          mainPad: 8,
          photoSize: 74,
          headerGap: 2,
          textHeight: 1.14,
          compactLists: true,
        );
      default:
        return const OnePageMetrics(
          level: 6,
          nameSize: minNameSize,
          roleSize: 9,
          sectionSize: minSectionSize,
          bodySize: minBodySize,
          smallSize: 7.5,
          sectionGap: 2.5,
          itemGap: 1.2,
          lineGap: 0.3,
          sidebarPad: 7,
          mainPad: 7,
          photoSize: minPhotoSize,
          headerGap: 1.6,
          textHeight: 1.12,
          compactLists: true,
        );
    }
  }
}

/// Paleta de la página. El acento y el sidebar salen de [colorHex].
class OnePagePalette {
  const OnePagePalette({
    required this.sidebar,
    required this.onSidebar,
    required this.onSidebarMuted,
    required this.accent,
    required this.text,
    required this.muted,
    required this.rule,
  });

  final PdfColor sidebar;
  final PdfColor onSidebar;
  final PdfColor onSidebarMuted;
  final PdfColor accent;
  final PdfColor text;
  final PdfColor muted;
  final PdfColor rule;

  static OnePagePalette fromColorHex(int colorHex) {
    final accent = PdfColor.fromInt(colorHex);
    final dark = _isDark(colorHex);
    return OnePagePalette(
      sidebar: accent,
      onSidebar: dark ? PdfColors.white : const PdfColor(0.1, 0.12, 0.16),
      onSidebarMuted: dark
          ? const PdfColor(1, 1, 1, 0.9)
          : const PdfColor(0.16, 0.18, 0.22),
      accent: accent,
      text: const PdfColor(0.12, 0.13, 0.16),
      muted: const PdfColor(0.29, 0.32, 0.36),
      rule: const PdfColor(0.75, 0.78, 0.82),
    );
  }

  static bool _isDark(int argb) {
    final r = ((argb >> 16) & 0xFF) / 255;
    final g = ((argb >> 8) & 0xFF) / 255;
    final b = (argb & 0xFF) / 255;
    final luminance = (0.2126 * r) + (0.7152 * g) + (0.0722 * b);
    return luminance < 0.62;
  }
}
