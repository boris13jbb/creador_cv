import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../saas/providers/auth_controller.dart';
import 'pricing_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final profile = auth.profile;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi cuenta')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: CircleAvatar(
              child: Text(
                (profile?.displayName.isNotEmpty == true)
                    ? profile!.displayName[0].toUpperCase()
                    : '?',
              ),
            ),
            title: Text(profile?.displayName ?? 'Usuario'),
            subtitle: Text(profile?.email ?? auth.user?.email ?? ''),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: const Text('Plan'),
            subtitle: Text(profile?.plan.label ?? 'Free'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PricingScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.cloud_done_outlined),
            title: const Text('Datos'),
            subtitle: const Text('Sincronizados en la nube (Firestore)'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Cerrar sesión', style: TextStyle(color: Colors.red)),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Cerrar sesión'),
                  content: const Text('¿Seguro que deseas salir?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Salir')),
                  ],
                ),
              );
              if (confirm == true && context.mounted) {
                await context.read<AuthController>().signOut();
              }
            },
          ),
        ],
      ),
    );
  }
}
