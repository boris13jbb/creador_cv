import 'dart:typed_data';
import '../../../features/templates/cv_templates.dart';
import '../../../models/resume.dart';
import '../../../saas/models/subscription_access.dart';
import 'classic_pdf_generator.dart';
import 'creative_pdf_generator.dart';
import 'executive_pdf_generator.dart';
import 'modern_pdf_generator.dart';
import 'professional_one_page_pdf_generator.dart';

/// Fachada de generación PDF. Aplica bloqueo Free/Pro y MultiPage por plantilla.
class ResumePdfService {
  /// Genera el PDF del CV.
  ///
  /// Si [access] es [SubscriptionAccess.free] y el diseño requiere Pro, se usa
  /// Clásico sin mutar el modelo persistido. Si el plan está pendiente, no
  /// genera ni sustituye una plantilla Pro.
  ///
  /// [isPro] se conserva para llamadas que ya confirmaron el plan.
  static Future<Uint8List> generateResumePdf(
    Resume resume, {
    bool isPro = false,
    SubscriptionAccess? access,
  }) async {
    final decision = CvTemplates.decideRender(
      resume.designIndex,
      access:
          access ?? (isPro ? SubscriptionAccess.pro : SubscriptionAccess.free),
    );
    if (decision.holdForPlan) {
      throw const PlanVerificationPending();
    }
    final design = decision.renderIndex!;
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
      case 4:
        return generateProfessionalOnePagePdf(effective);
      default:
        return generateClassicPdf(effective);
    }
  }
}

/// El plan aún no está verificado. No se genera Clásico ni una plantilla Pro.
class PlanVerificationPending implements Exception {
  const PlanVerificationPending();

  @override
  String toString() => 'El plan todavía no está verificado.';
}
