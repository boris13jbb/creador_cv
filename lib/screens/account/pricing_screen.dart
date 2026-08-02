import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_layout.dart';
import '../../saas/config/saas_config.dart';
import '../../saas/providers/auth_controller.dart';
import '../../saas/services/billing_service.dart';

class PricingScreen extends StatefulWidget {
  const PricingScreen({super.key});

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  bool _busy = false;

  Future<void> _openUrl(Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el enlace')),
      );
    }
  }

  Future<void> _upgrade() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (SaasConfig.billingBackendEnabled) {
        try {
          final url = await BillingService.instance.createCheckoutUrl();
          await _openUrl(url);
          return;
        } catch (e) {
          if (SaasConfig.stripePaymentLink.isEmpty) rethrow;
          // Fallback temporal a Payment Link si Functions aún no están desplegadas.
        }
      }

      final link = SaasConfig.stripePaymentLink;
      if (link.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Billing no configurado. Despliega Cloud Functions Stripe '
              'o define STRIPE_PAYMENT_LINK. Ver docs/STRIPE_BILLING.md',
            ),
          ),
        );
        return;
      }
      await _openUrl(Uri.parse(link));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openPortal() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final url = await BillingService.instance.createPortalUrl();
      await _openUrl(url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refreshPlan() async {
    setState(() => _busy = true);
    try {
      await context.read<AuthController>().refreshEntitlement();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Plan actualizado')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final isPro = auth.isPro;
    final theme = Theme.of(context);
    final desktop = AppLayout.of(context) == AppLayoutType.desktop;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Planes'),
        actions: [
          IconButton(
            tooltip: 'Actualizar plan',
            onPressed: _busy ? null : _refreshPlan,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: AppContentWidth(
        child: ListView(
          children: [
            Text('Elige tu plan', style: theme.textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Plan actual: ${auth.plan.label}'
              '${auth.entitlement?.subscriptionStatus != null ? ' (${auth.entitlement!.subscriptionStatus})' : ''}'
              '${auth.isAdminGrant ? ' · cortesía admin' : ''}',
              style: theme.textTheme.bodyLarge,
            ),
            if (auth.isAdminGrant) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Acceso Pro otorgado por el administrador'
                '${auth.entitlement?.grantExpiresAt != null ? ' (hasta ${_fmt(auth.entitlement!.grantExpiresAt!)})' : ''}.',
                style: theme.textTheme.bodyMedium,
              ),
            ] else if (auth.entitlement?.source == 'stripe') ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Suscripción gestionada por Stripe.',
                style: theme.textTheme.bodyMedium,
              ),
            ] else if (auth.entitlement?.trialEndsAt != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Prueba registrada hasta ${_fmt(auth.entitlement!.trialEndsAt!)}. '
                'Pro se activa tras pago verificado (webhook Stripe).',
                style: theme.textTheme.bodyMedium,
              ),
            ],
            if (_busy) ...[
              const SizedBox(height: AppSpacing.md),
              const LinearProgressIndicator(),
            ],
            const SizedBox(height: AppSpacing.lg),
            if (desktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _PlanCard(
                      title: 'Free',
                      price: r'$0',
                      features: [
                        'Hasta ${SaasConfig.freeMaxCvs} CVs',
                        'Diseños básicos',
                        'Exportación PDF',
                        'Nube sincronizada',
                      ],
                      highlighted: !isPro,
                      actionLabel: isPro ? 'Plan inferior' : 'Plan actual',
                      onPressed: null,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _PlanCard(
                      title: 'Pro',
                      price: r'$7.99/mes',
                      features: const [
                        'CVs ilimitados',
                        'Todos los diseños PDF',
                        'Prioridad de exportación',
                        'Soporte prioritario',
                      ],
                      highlighted: isPro,
                      actionLabel: isPro ? 'Plan actual' : 'Mejorar a Pro',
                      onPressed: isPro || _busy ? null : _upgrade,
                      isProCard: true,
                    ),
                  ),
                ],
              )
            else ...[
              _PlanCard(
                title: 'Free',
                price: r'$0',
                features: [
                  'Hasta ${SaasConfig.freeMaxCvs} CVs',
                  'Diseños básicos',
                  'Exportación PDF',
                  'Nube sincronizada',
                ],
                highlighted: !isPro,
                actionLabel: isPro ? 'Plan inferior' : 'Plan actual',
                onPressed: null,
              ),
              const SizedBox(height: AppSpacing.md),
              _PlanCard(
                title: 'Pro',
                price: r'$7.99/mes',
                features: const [
                  'CVs ilimitados',
                  'Todos los diseños PDF',
                  'Prioridad de exportación',
                  'Soporte prioritario',
                ],
                highlighted: isPro,
                actionLabel: isPro ? 'Plan actual' : 'Mejorar a Pro',
                onPressed: isPro || _busy ? null : _upgrade,
                isProCard: true,
              ),
            ],
            if (isPro) ...[
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                onPressed: _busy ? null : _openPortal,
                icon: const Icon(Icons.manage_accounts_outlined),
                label: const Text('Gestionar suscripción (Stripe)'),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Text(
              'Tras pagar, pulsa actualizar plan. La activación Pro la escribe '
              'el webhook de Stripe (no el cliente).',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

String _fmt(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final List<String> features;
  final bool highlighted;
  final String actionLabel;
  final VoidCallback? onPressed;
  final bool isProCard;

  const _PlanCard({
    required this.title,
    required this.price,
    required this.features,
    required this.highlighted,
    required this.actionLabel,
    required this.onPressed,
    this.isProCard = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isProCard ? AppColors.amber : AppColors.emerald;
    return Card(
      elevation: highlighted ? AppElevations.mid : AppElevations.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        side: BorderSide(
          color: highlighted ? accent : AppColors.border,
          width: highlighted ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: accent,
                  ),
                ),
                if (isProCard) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.workspace_premium, color: AppColors.amber),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              price,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.md),
            ...features.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, size: 18, color: accent),
                    const SizedBox(width: 8),
                    Expanded(child: Text(f)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onPressed,
                style: isProCard
                    ? FilledButton.styleFrom(backgroundColor: AppColors.amber)
                    : null,
                child: Text(actionLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
