import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_layout.dart';
import '../../saas/providers/auth_controller.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  Future<void> _exportData(BuildContext context) async {
    final auth = context.read<AuthController>();
    try {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      final json = await auth.exportPersonalDataJson();
      if (!context.mounted) return;
      Navigator.pop(context);
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Exportar mis datos'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: SelectableText(json, style: const TextStyle(fontSize: 12)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: json));
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Datos copiados al portapapeles'),
                    ),
                  );
                }
              },
              child: const Text('Copiar JSON'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar cuenta'),
        content: const Text(
          'Se eliminarán tus CVs y tu perfil. Esta acción no se puede deshacer. '
          'Los registros de facturación quedan solo accesibles al backend.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final auth = context.read<AuthController>();
    final ok = await auth.deleteAccount();
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'No se pudo eliminar la cuenta')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final profile = auth.profile;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Mi cuenta')),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          AppContentWidth(
            maxWidth: 720,
            child: Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: AppColors.navy,
                          child: Text(
                            (profile?.displayName.isNotEmpty == true)
                                ? profile!.displayName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile?.displayName ?? 'Usuario',
                                style: theme.textTheme.titleLarge,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                profile?.email ?? auth.email ?? '',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(
                          auth.emailVerified
                              ? Icons.verified_outlined
                              : Icons.mark_email_unread_outlined,
                          color: auth.emailVerified
                              ? AppColors.success
                              : AppColors.amber,
                        ),
                        title: const Text('Correo'),
                        subtitle: Text(
                          auth.emailVerified
                              ? 'Verificado'
                              : 'Pendiente de verificación',
                        ),
                        trailing: auth.emailVerified
                            ? null
                            : TextButton(
                                onPressed: () async {
                                  final ok = await auth.sendEmailVerification();
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        ok
                                            ? 'Correo de verificación enviado'
                                            : (auth.error ??
                                                  'No se pudo enviar'),
                                      ),
                                    ),
                                  );
                                },
                                child: const Text('Reenviar'),
                              ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.workspace_premium_outlined),
                        title: const Text('Plan'),
                        subtitle: Text(auth.plan.label),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(AppRoutes.pricing),
                      ),
                      const Divider(height: 1),
                      const ListTile(
                        leading: Icon(Icons.cloud_done_outlined),
                        title: Text('Datos'),
                        subtitle: Text('Sincronizados en la nube (Firestore)'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.download_outlined),
                        title: const Text('Exportar mis datos'),
                        subtitle: const Text('Descarga JSON de perfil y CVs'),
                        onTap: () => _exportData(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.privacy_tip_outlined),
                        title: const Text('Política de privacidad'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(AppRoutes.privacy),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.gavel_outlined),
                        title: const Text('Términos de uso'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(AppRoutes.terms),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(
                          Icons.logout,
                          color: AppColors.danger,
                        ),
                        title: const Text(
                          'Cerrar sesión',
                          style: TextStyle(color: AppColors.danger),
                        ),
                        onTap: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Cerrar sesión'),
                              content: const Text('¿Seguro que deseas salir?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancelar'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Salir'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true && context.mounted) {
                            await context.read<AuthController>().signOut();
                          }
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(
                          Icons.delete_forever_outlined,
                          color: AppColors.danger,
                        ),
                        title: const Text(
                          'Eliminar cuenta',
                          style: TextStyle(color: AppColors.danger),
                        ),
                        onTap: () => _deleteAccount(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
