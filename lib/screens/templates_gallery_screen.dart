import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_layout.dart';
import '../../features/templates/cv_templates.dart';
import '../../saas/providers/auth_controller.dart';

IconData _templateIcon(IconDataHint hint) {
  switch (hint) {
    case IconDataHint.dashboard:
      return Icons.dashboard_customize_outlined;
    case IconDataHint.business:
      return Icons.business_center_outlined;
    case IconDataHint.palette:
      return Icons.palette_outlined;
    case IconDataHint.description:
      return Icons.description_outlined;
  }
}

/// Galería de plantillas con bloqueo Free/Pro y deep-link al editor.
class TemplatesGalleryScreen extends StatelessWidget {
  const TemplatesGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isPro = context.watch<AuthController>().isPro;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Plantillas')),
      body: AppContentWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Elige un estilo para tu CV',
              style: theme.textTheme.headlineMedium?.copyWith(fontSize: 26),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              isPro
                  ? 'Tu plan Pro incluye las 4 plantillas profesionales.'
                  : 'Free: Clásico y Moderno. Ejecutiva y Creativa requieren Pro.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: AppLayout.of(context) == AppLayoutType.mobile
                      ? 1
                      : (AppLayout.of(context) == AppLayoutType.tablet ? 2 : 3),
                  mainAxisSpacing: AppSpacing.md,
                  crossAxisSpacing: AppSpacing.md,
                  childAspectRatio: 1.25,
                ),
                itemCount: CvTemplates.all.length,
                itemBuilder: (context, i) {
                  final t = CvTemplates.all[i];
                  final locked = t.requiresPro && !isPro;
                  return Semantics(
                    button: true,
                    label: '${t.name}${locked ? ', requiere Pro' : ''}',
                    child: Material(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                        onTap: () {
                          if (locked) {
                            context.push(AppRoutes.pricing);
                            return;
                          }
                          context.push(
                            '${AppRoutes.resumeNew}?design=${t.designIndex}',
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadii.lg),
                            border: Border.all(
                              color: locked
                                  ? AppColors.border
                                  : AppColors.emerald.withValues(alpha: 0.35),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.navy.withValues(alpha: 0.06),
                                AppColors.emerald.withValues(alpha: 0.08),
                              ],
                            ),
                          ),
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _templateIcon(t.icon),
                                    color: AppColors.navy,
                                    size: 28,
                                  ),
                                  const Spacer(),
                                  if (t.requiresPro)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.amber.withValues(
                                          alpha: 0.15,
                                        ),
                                        borderRadius: AppRadii.pill,
                                      ),
                                      child: Text(
                                        locked ? 'Pro' : 'Pro',
                                        style: const TextStyle(
                                          color: AppColors.amber,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const Spacer(),
                              Text(t.name, style: theme.textTheme.titleLarge),
                              const SizedBox(height: 4),
                              Text(
                                locked
                                    ? 'Disponible en plan Pro'
                                    : t.description,
                                style: theme.textTheme.bodyMedium,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
