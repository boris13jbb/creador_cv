import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../saas/config/saas_config.dart';

/// Pantalla mostrada cuando Firebase no puede inicializarse.
class FirebaseInitErrorScreen extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const FirebaseInitErrorScreen({
    super.key,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cloud_off_outlined,
                      size: 64,
                      color: Colors.red.shade700,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No se pudo iniciar ${SaasConfig.productName}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Firebase no está disponible en este dispositivo. '
                      'Revisa tu conexión e intenta de nuevo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 16),
                    SelectableText(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 24),
                    if (onRetry != null)
                      FilledButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                      ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: message));
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copiar detalle técnico'),
                    ),
                    TextButton(
                      onPressed: () {
                        // No hay más que cerrar la app en algunos entornos.
                      },
                      child: Text('Soporte: ${SaasConfig.supportEmail}'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
