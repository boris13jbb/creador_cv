import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'state/admin_session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const CvMakerAdminApp());
}

class CvMakerAdminApp extends StatelessWidget {
  const CvMakerAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0B1F3A),
        brightness: Brightness.light,
      ),
      useMaterial3: true,
    );

    return ChangeNotifierProvider(
      create: (_) => AdminSession(),
      child: MaterialApp(
        title: 'CV Maker Admin',
        debugShowCheckedModeBanner: false,
        theme: base.copyWith(
          textTheme: GoogleFonts.sourceSans3TextTheme(base.textTheme),
        ),
        home: const _RootGate(),
      ),
    );
  }
}

class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AdminSession>();

    if (session.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!session.isAuthenticated) {
      return const LoginScreen();
    }

    if (!session.isSuperAdmin) {
      return Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    session.error ?? 'Sin permiso de superadmin.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Asigna el claim con functions/scripts/set-superadmin.mjs '
                    'y vuelve a entrar.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: session.refreshClaims,
                    child: const Text('Reintentar claims'),
                  ),
                  TextButton(
                    onPressed: session.signOut,
                    child: const Text('Cerrar sesión'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return const DashboardScreen();
  }
}
