import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_layout.dart';
import '../../features/templates/cv_template_thumbnail.dart';
import '../../features/templates/cv_templates.dart';
import '../../saas/providers/auth_controller.dart';

/// Galería de plantillas con miniaturas, bloqueo Free/Pro y deep-link al editor.
class TemplatesGalleryScreen extends StatelessWidget {
  const TemplatesGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isPro = context.watch<AuthController>().isPro;
    final theme = Theme.of(context);
    final layout = AppLayout.of(context);
    final crossAxisCount = layout == AppLayoutType.mobile
        ? 1
        : (layout == AppLayoutType.tablet ? 2 : 3);

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
                  ? 'Tu plan Pro incluye las 5 plantillas profesionales.'
                  : 'Free: Clásico y Moderno. Ejecutiva, Creativa y One Page requieren Pro.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: AppSpacing.md,
                  crossAxisSpacing: AppSpacing.md,
                  // Más alto para dar espacio a la miniatura tipo página.
                  childAspectRatio: crossAxisCount == 1 ? 0.78 : 0.72,
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
                      clipBehavior: Clip.antiAlias,
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
                          ),
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: CvTemplateThumbnail(
                                  designIndex: t.designIndex,
                                  locked: locked,
                                  accent: switch (t.designIndex) {
                                    0 => AppColors.emerald,
                                    1 => AppColors.navyMid,
                                    2 => AppColors.navy,
                                    3 => AppColors.amber,
                                    _ => AppColors.emeraldBright,
                                  },
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      t.name,
                                      style: theme.textTheme.titleLarge
                                          ?.copyWith(fontSize: 18),
                                    ),
                                  ),
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
                                      child: const Text(
                                        'Pro',
                                        style: TextStyle(
                                          color: AppColors.amber,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 2),
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
