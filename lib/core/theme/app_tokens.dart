import 'package:flutter/material.dart';

/// Tokens de diseño CV Maker (identidad: navy / esmeralda / ámbar).
abstract final class AppColors {
  static const Color navy = Color(0xFF0B1F3A);
  static const Color navyMid = Color(0xFF163A5F);
  static const Color emerald = Color(0xFF0F766E);
  static const Color emeraldBright = Color(0xFF14B8A6);
  static const Color amber = Color(0xFFD97706);
  static const Color amberSoft = Color(0xFFFBBF24);
  static const Color surface = Color(0xFFF3F6F9);
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF0F172A);
  static const Color inkMuted = Color(0xFF64748B);
  static const Color border = Color(0xFFD8E0EA);
  static const Color danger = Color(0xFFB91C1C);
  static const Color dangerSoft = Color(0xFFFEE2E2);
  static const Color success = Color(0xFF047857);
  static const Color successSoft = Color(0xFFD1FAE5);
}

abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

abstract final class AppRadii {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const BorderRadius card = BorderRadius.all(Radius.circular(md));
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));
}

abstract final class AppElevations {
  static const double none = 0;
  static const double low = 1;
  static const double mid = 3;
  static const double high = 8;
}

abstract final class AppDurations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
}

abstract final class AppBreakpoints {
  static const double mobile = 600;
  static const double tablet = 1024;
  static const double desktop = 1280;

  static bool isMobile(double w) => w < mobile;
  static bool isTablet(double w) => w >= mobile && w < tablet;
  static bool isDesktop(double w) => w >= tablet;
}

abstract final class AppTouch {
  static const double min = 48;
}
