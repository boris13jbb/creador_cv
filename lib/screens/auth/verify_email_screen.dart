import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../saas/config/saas_config.dart';
import '../../saas/providers/auth_controller.dart';
import 'auth_scaffold.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _sending = false;
  bool _checking = false;

  Future<void> _resend() async {
    setState(() => _sending = true);
    final auth = context.read<AuthController>();
    final ok = await auth.sendEmailVerification();
    if (!mounted) return;
    setState(() => _sending = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Te enviamos un correo de verificación'
              : (auth.error ?? 'No se pudo enviar el correo'),
        ),
      ),
    );
  }

  Future<void> _check() async {
    setState(() => _checking = true);
    final auth = context.read<AuthController>();
    final ok = await auth.refreshEmailVerification();
    if (!mounted) return;
    setState(() => _checking = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            auth.error ??
                'Aún no detectamos la verificación. Revisa tu bandeja e inténtalo de nuevo.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final email = auth.email ?? '';

    return AuthScaffold(
      title: 'Verifica tu correo',
      subtitle:
          'Enviamos un enlace a $email. Confírmalo para proteger tu cuenta en ${SaasConfig.productName}.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(
            onPressed: _checking ? null : _check,
            child: _checking
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Ya verifiqué mi correo'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _sending ? null : _resend,
            child: _sending
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Reenviar verificación'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => context.read<AuthController>().signOut(),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }
}
