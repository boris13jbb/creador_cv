import '../../saas/models/subscription_access.dart';

/// Metadatos y acceso a plantillas PDF (Free vs Pro).
class CvTemplateInfo {
  final int designIndex;
  final String name;
  final String description;
  final bool requiresPro;
  final IconDataHint icon;

  const CvTemplateInfo({
    required this.designIndex,
    required this.name,
    required this.description,
    this.requiresPro = false,
    this.icon = IconDataHint.description,
  });
}

/// Hint tipográfico para evitar importar Flutter en tests puros de metadatos.
enum IconDataHint { description, dashboard, business, palette, columns }

abstract final class CvTemplates {
  static const freeFallbackIndex = 0;

  static const all = <CvTemplateInfo>[
    CvTemplateInfo(
      designIndex: 0,
      name: 'Clásico',
      description: 'Sidebar claro y estructura formal',
      icon: IconDataHint.description,
    ),
    CvTemplateInfo(
      designIndex: 1,
      name: 'Moderno',
      description: 'Barra de acento y tipografía limpia',
      icon: IconDataHint.dashboard,
    ),
    CvTemplateInfo(
      designIndex: 2,
      name: 'Ejecutivo',
      description: 'Estilo corporativo premium',
      requiresPro: true,
      icon: IconDataHint.business,
    ),
    CvTemplateInfo(
      designIndex: 3,
      name: 'Creativo',
      description: 'Bloques visuales y acento fuerte',
      requiresPro: true,
      icon: IconDataHint.palette,
    ),
    CvTemplateInfo(
      designIndex: 4,
      name: 'One Page',
      description: 'Una página A4, sidebar y contenido en dos columnas',
      requiresPro: true,
      icon: IconDataHint.columns,
    ),
  ];

  static CvTemplateInfo byIndex(int index) {
    for (final t in all) {
      if (t.designIndex == index) return t;
    }
    return all.first;
  }

  static bool requiresPro(int designIndex) => byIndex(designIndex).requiresPro;

  static bool canUseDesign(int designIndex, {required bool isPro}) {
    if (isPro) return true;
    return !requiresPro(designIndex);
  }

  /// Si el diseño es Pro y el usuario no lo es, cae al fallback Free.
  ///
  /// Solo para un plan ya confirmado. Si el plan está pendiente, usa
  /// [decideRender] para no sustituir el índice guardado.
  static int resolveDesignIndex(int requested, {required bool isPro}) {
    if (canUseDesign(requested, isPro: isPro)) return requested;
    return freeFallbackIndex;
  }

  /// Qué índice dibujar sin mutar el CV guardado.
  ///
  /// Con el plan pendiente, una plantilla Pro no se convierte en Clásico ni
  /// se genera: [TemplateRenderDecision.holdForPlan] queda en true.
  static TemplateRenderDecision decideRender(
    int savedIndex, {
    required SubscriptionAccess access,
  }) {
    switch (access) {
      case SubscriptionAccess.pro:
        return TemplateRenderDecision(
          savedIndex: savedIndex,
          renderIndex: savedIndex,
        );
      case SubscriptionAccess.free:
        return TemplateRenderDecision(
          savedIndex: savedIndex,
          renderIndex: resolveDesignIndex(savedIndex, isPro: false),
        );
      case SubscriptionAccess.pending:
      case SubscriptionAccess.error:
        // No Free ni Pro: plantillas Pro en espera; Free siguen disponibles.
        if (requiresPro(savedIndex)) {
          return TemplateRenderDecision(
            savedIndex: savedIndex,
            renderIndex: null,
          );
        }
        return TemplateRenderDecision(
          savedIndex: savedIndex,
          renderIndex: savedIndex,
        );
    }
  }

  static List<CvTemplateInfo> freeOnly() =>
      all.where((t) => !t.requiresPro).toList(growable: false);

  static List<CvTemplateInfo> proOnly() =>
      all.where((t) => t.requiresPro).toList(growable: false);
}

/// Decisión de dibujo. [renderIndex] null significa esperar, no cambiar de plantilla.
class TemplateRenderDecision {
  const TemplateRenderDecision({
    required this.savedIndex,
    required this.renderIndex,
  });

  final int savedIndex;
  final int? renderIndex;

  bool get holdForPlan => renderIndex == null;

  bool get keptSavedDesign => renderIndex == savedIndex;
}
