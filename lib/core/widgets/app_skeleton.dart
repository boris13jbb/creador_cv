import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

/// Skeleton de carga reutilizable.
class AppSkeleton extends StatelessWidget {
  final double height;
  final double? width;
  final BorderRadius? borderRadius;

  const AppSkeleton({
    super.key,
    this.height = 16,
    this.width,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width ?? double.infinity,
      decoration: BoxDecoration(
        color: AppColors.border.withValues(alpha: 0.55),
        borderRadius: borderRadius ?? BorderRadius.circular(AppRadii.sm),
      ),
    );
  }
}

class ResumeListSkeleton extends StatelessWidget {
  const ResumeListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, __) => const Card(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              AppSkeleton(height: 44, width: 44, borderRadius: AppRadii.pill),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSkeleton(height: 14, width: 160),
                    SizedBox(height: AppSpacing.sm),
                    AppSkeleton(height: 12, width: 220),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
