import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// Miniatura esquemática de cada plantilla PDF (sin assets estáticos).
/// Refleja la estructura real: Clásico, Moderno, Ejecutivo, Creativo.
class CvTemplateThumbnail extends StatelessWidget {
  const CvTemplateThumbnail({
    super.key,
    required this.designIndex,
    this.accent,
    this.locked = false,
  });

  final int designIndex;
  final Color? accent;
  final bool locked;

  Color get _accent => accent ?? AppColors.emerald;

  @override
  Widget build(BuildContext context) {
    final preview = switch (designIndex.clamp(0, 3)) {
      0 => _ClassicMini(accent: _accent),
      1 => _ModernMini(accent: _accent),
      2 => _ExecutiveMini(accent: _accent),
      _ => _CreativeMini(accent: _accent),
    };

    return AspectRatio(
      aspectRatio: 0.72,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.navy.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.sm - 1),
          child: Stack(
            fit: StackFit.expand,
            children: [
              preview,
              if (locked)
                ColoredBox(
                  color: Colors.white.withValues(alpha: 0.45),
                  child: const Center(
                    child: Icon(
                      Icons.lock_outline,
                      color: AppColors.amber,
                      size: 28,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.widthFactor, this.height = 3});

  final double widthFactor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFD1D5DB),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({required this.accent, this.lines = 2});

  final Color accent;
  final int lines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 10, height: 3, color: accent),
            const SizedBox(width: 4),
            const Expanded(child: _SkeletonLine(widthFactor: 0.35, height: 3)),
          ],
        ),
        const SizedBox(height: 4),
        for (var i = 0; i < lines; i++) ...[
          _SkeletonLine(widthFactor: i == lines - 1 ? 0.55 : 0.92, height: 2.5),
          if (i < lines - 1) const SizedBox(height: 3),
        ],
      ],
    );
  }
}

/// Clásico: cabecera navy + barra de acento izquierda.
class _ClassicMini extends StatelessWidget {
  const _ClassicMini({required this.accent});
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          decoration: BoxDecoration(
            color: const Color(0xFF20354B),
            border: Border(left: BorderSide(color: accent, width: 4)),
          ),
          child: Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.25),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 5,
                      width: 64,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      height: 2.5,
                      width: 48,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
            child: Column(
              children: [
                _SectionBlock(accent: accent),
                const SizedBox(height: 8),
                _SectionBlock(accent: accent, lines: 3),
                const SizedBox(height: 8),
                _SectionBlock(accent: accent),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Moderno: fondo oscuro + banda de acento con nombre.
class _ModernMini extends StatelessWidget {
  const _ModernMini({required this.accent});
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: const Color(0xFF2C2E3E),
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                color: accent,
                child: Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Container(
                        height: 5,
                        color: Colors.white.withValues(alpha: 0.95),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Container(
                      width: 18,
                      height: 2,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                    if (i < 2) const SizedBox(width: 6),
                  ],
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
            child: Column(
              children: [
                _SectionBlock(accent: accent, lines: 3),
                const SizedBox(height: 8),
                _SectionBlock(accent: accent),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Ejecutivo: foto rectangular + nombre en color + chip gris.
class _ExecutiveMini extends StatelessWidget {
  const _ExecutiveMini({required this.accent});
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  border: Border.all(color: accent, width: 1.5),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 6, width: 70, color: accent),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      color: const Color(0xFFF5F5F5),
                      child: Container(
                        height: 2.5,
                        width: 42,
                        color: const Color(0xFF9CA3AF),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const _SkeletonLine(widthFactor: 0.85, height: 2),
                    const SizedBox(height: 2),
                    const _SkeletonLine(widthFactor: 0.6, height: 2),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _SectionBlock(accent: accent, lines: 3),
          const SizedBox(height: 8),
          _SectionBlock(accent: accent),
        ],
      ),
    );
  }
}

/// Creativo: bloque suave + barra vertical de acento + borde inferior.
class _CreativeMini extends StatelessWidget {
  const _CreativeMini({required this.accent});
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F7F7),
            border: Border(bottom: BorderSide(color: accent, width: 3)),
          ),
          child: Row(
            children: [
              Container(width: 5, height: 36, color: accent),
              const SizedBox(width: 6),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: accent, width: 1.5),
                  color: accent.withValues(alpha: 0.15),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 6, width: 58, color: accent),
                    const SizedBox(height: 3),
                    const _SkeletonLine(widthFactor: 0.7, height: 2),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
            child: Column(
              children: [
                _SectionBlock(accent: accent),
                const SizedBox(height: 8),
                _SectionBlock(accent: accent, lines: 3),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
