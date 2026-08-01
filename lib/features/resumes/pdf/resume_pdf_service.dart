import 'dart:typed_data';
import '../../../features/templates/cv_templates.dart';
import '../../../models/resume.dart';
import 'classic_pdf_generator.dart';
import 'creative_pdf_generator.dart';
import 'executive_pdf_generator.dart';
import 'modern_pdf_generator.dart';

/// Fachada de generación PDF. Aplica bloqueo Free/Pro y MultiPage por plantilla.
class ResumePdfService {
  /// Genera el PDF del CV.
  ///
  /// Si [isPro] es false y el diseño requiere Pro, se usa la plantilla Free
  /// de respaldo (Clásico) sin mutar el modelo persistido.
  static Future<Uint8List> generateResumePdf(
    Resume resume, {
    bool isPro = false,
  }) async {
    final design = CvTemplates.resolveDesignIndex(
      resume.designIndex,
      isPro: isPro,
    );
    final effective = design == resume.designIndex
        ? resume
        : resume.copyWith(designIndex: design);

    switch (effective.designIndex) {
      case 0:
        return generateClassicPdf(effective);
      case 1:
        return generateModernPdf(effective);
      case 2:
        return generateExecutivePdf(effective);
      case 3:
        return generateCreativePdf(effective);
      default:
        return generateClassicPdf(effective);
    }
  }
}
