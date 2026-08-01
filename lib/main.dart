import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'core/observability/app_observability.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'saas/providers/auth_controller.dart';
import 'saas/services/cloud_resume_repository.dart';
import 'screens/auth/firebase_init_error_screen.dart';

Future<void> main() async {
  await AppObservability.run(_bootstrapApp);
}

Future<void> _bootstrapApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Evita descargas de fuentes en cada hot restart en release/CI si se embebe asset;
  // en debug se permiten para desarrollo.
  GoogleFonts.config.allowRuntimeFetching = !bool.fromEnvironment(
    'DISABLE_GOOGLE_FONTS_FETCH',
    defaultValue: false,
  );

  Object? firebaseError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e, st) {
    await AppObservability.captureException(
      e,
      stackTrace: st,
      context: 'firebase_init',
    );
    firebaseError = e;
  }

  if (firebaseError != null) {
    runApp(
      FirebaseInitErrorScreen(
        message: firebaseError.toString(),
        onRetry: () {},
      ),
    );
    return;
  }

  try {
    await initializeDateFormatting('es', null);
  } catch (e, st) {
    await AppObservability.captureException(
      e,
      stackTrace: st,
      context: 'date_formatting',
    );
  }

  final authController = AuthController();
  CloudResumeRepository.instance.bindAuth(authController);
  final router = createAppRouter(authController);

  runApp(
    ChangeNotifierProvider.value(
      value: authController,
      child: CvApp(router: router),
    ),
  );
}

class CvApp extends StatelessWidget {
  final GoRouter router;

  const CvApp({super.key, required this.router});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'CV Maker SaaS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
