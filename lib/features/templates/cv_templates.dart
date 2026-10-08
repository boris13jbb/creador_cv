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
  static int resolveDesignIndex(int requested, {required bool isPro}) {
    if (canUseDesign(requested, isPro: isPro)) return requested;
    return freeFallbackIndex;
  }

  static List<CvTemplateInfo> freeOnly() =>
      all.where((t) => !t.requiresPro).toList(growable: false);

  static List<CvTemplateInfo> proOnly() =>
      all.where((t) => t.requiresPro).toList(growable: false);
}
