import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../saas/providers/auth_controller.dart';
import '../home_screen.dart';
import 'login_screen.dart';

/// Decide entre login y app según sesión Firebase.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    if (auth.loading && !auth.isAuthenticated) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!auth.isAuthenticated) {
      return const LoginScreen();
    }

    return const HomeScreen();
  }
}
