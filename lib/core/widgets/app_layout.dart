import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

enum AppLayoutType { mobile, tablet, desktop }

class AppLayout {
  static AppLayoutType of(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (AppBreakpoints.isMobile(w)) return AppLayoutType.mobile;
    if (AppBreakpoints.isTablet(w)) return AppLayoutType.tablet;
    return AppLayoutType.desktop;
  }

  static bool get isCompact => false;
}

/// Contenedor de contenido con ancho máximo en desktop.
class AppContentWidth extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  const AppContentWidth({
    super.key,
    required this.child,
    this.maxWidth = 1100,
    this.padding = const EdgeInsets.all(AppSpacing.md),
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
