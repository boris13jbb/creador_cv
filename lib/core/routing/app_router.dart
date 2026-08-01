import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../saas/providers/auth_controller.dart';
import '../../screens/account/account_screen.dart';
import '../../screens/account/pricing_screen.dart';
import '../../screens/auth/forgot_password_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/auth/verify_email_screen.dart';
import '../../screens/historial_cv_screen.dart';
import '../../screens/home_screen.dart';
import '../../screens/nuevo_cv_screen.dart';
import '../../models/resume.dart';
import '../../screens/resume_preview_screen.dart';
import '../../screens/legal/legal_document_screen.dart';
import '../../screens/templates_gallery_screen.dart';
import '../widgets/app_shell.dart';
import '../theme/app_tokens.dart';

/// Rutas centralizadas de la aplicación.
abstract final class AppRoutes {
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const verifyEmail = '/verify-email';
  static const home = '/';
  static const resumes = '/resumes';
  static const resumeNew = '/resumes/new';
  static const templates = '/templates';
  static const account = '/account';
  static const pricing = '/pricing';
  static const privacy = '/privacy';
  static const terms = '/terms';
}

GoRouter createAppRouter(AuthController auth) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: auth,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final loggingIn =
          loc == AppRoutes.login ||
          loc == AppRoutes.register ||
          loc == AppRoutes.forgotPassword;
      final legal = loc == AppRoutes.privacy || loc == AppRoutes.terms;

      if (auth.loading && !auth.isAuthenticated) return null;

      if (!auth.isAuthenticated) {
        return (loggingIn || legal) ? null : AppRoutes.login;
      }

      if (!auth.emailVerified) {
        if (loc == AppRoutes.verifyEmail || legal) return null;
        return AppRoutes.verifyEmail;
      }

      if (loggingIn || loc == AppRoutes.verifyEmail) {
        return AppRoutes.home;
      }
      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.login, builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: AppRoutes.register,
        builder: (_, __) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.verifyEmail,
        builder: (_, __) => const VerifyEmailScreen(),
      ),
      GoRoute(
        path: AppRoutes.privacy,
        builder: (_, __) => const LegalDocumentScreen(
          title: 'Privacidad',
          assetPath: 'assets/legal/privacy_es.md',
        ),
      ),
      GoRoute(
        path: AppRoutes.terms,
        builder: (_, __) => const LegalDocumentScreen(
          title: 'Términos',
          assetPath: 'assets/legal/terms_es.md',
        ),
      ),
      ShellRoute(
        builder: (context, state, child) {
          final auth = context.watch<AuthController>();
          if (auth.loading && auth.isAuthenticated) {
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Conectando con Firebase…',
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Si tarda más de unos segundos, revisa Wi‑Fi/datos.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.inkMuted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          return AppShell(child: child);
        },
        routes: [
          GoRoute(
            path: AppRoutes.home,
            pageBuilder: (_, __) => const NoTransitionPage(child: HomeScreen()),
          ),
          GoRoute(
            path: AppRoutes.resumes,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: HistorialCVScreen()),
          ),
          GoRoute(
            path: AppRoutes.templates,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: TemplatesGalleryScreen()),
          ),
          GoRoute(
            path: AppRoutes.account,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: AccountScreen()),
          ),
          GoRoute(
            path: AppRoutes.pricing,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: PricingScreen()),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.resumeNew,
        builder: (_, state) {
          final raw = state.uri.queryParameters['design'];
          final design = int.tryParse(raw ?? '');
          return NuevoCvScreen(initialDesignIndex: design);
        },
      ),
      GoRoute(
        path: '/resumes/edit',
        builder: (context, state) {
          final resume = state.extra as Resume?;
          return NuevoCvScreen(resumeExistente: resume);
        },
      ),
      GoRoute(
        path: '/resumes/preview',
        builder: (context, state) {
          final resume = state.extra as Resume;
          return ResumePreviewScreen(resume: resume);
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.map_outlined,
                size: 48,
                color: AppColors.inkMuted,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Ruta no encontrada',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('${state.uri}', textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () => context.go(AppRoutes.home),
                child: const Text('Ir al inicio'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

extension AppRouterX on BuildContext {
  AuthController get authController => read<AuthController>();
}
