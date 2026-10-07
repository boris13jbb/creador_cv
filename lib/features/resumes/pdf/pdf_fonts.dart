import 'package:flutter/widgets.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Tipografía Unicode compartida por todas las plantillas PDF.
///
/// Usa Noto Sans (cubre ñ, tildes y caracteres latinos). Cache en memoria
/// por proceso para no re-descargar en cada generación.
class ResumePdfFonts {
  ResumePdfFonts._();

  static pw.ThemeData? _cached;

  static Future<pw.ThemeData> theme() async {
    final existing = _cached;
    if (existing != null) return existing;

    WidgetsFlutterBinding.ensureInitialized();

    final base = await PdfGoogleFonts.notoSansRegular();
    final bold = await PdfGoogleFonts.notoSansBold();
    final italic = await PdfGoogleFonts.notoSansItalic();
    final boldItalic = await PdfGoogleFonts.notoSansBoldItalic();

    final theme = pw.ThemeData.withFont(
      base: base,
      bold: bold,
      italic: italic,
      boldItalic: boldItalic,
    );
    _cached = theme;
    return theme;
  }

  /// Solo tests: limpia caché entre casos si hace falta.
  static void resetCacheForTests() => _cached = null;
}
