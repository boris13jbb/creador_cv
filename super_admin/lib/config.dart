/// Configuración del panel superadmin.
class AdminConfig {
  static const String productName = 'CV Maker Admin';

  /// Base URL de Cloud Functions (sin barra final).
  static const String functionsBaseUrl = String.fromEnvironment(
    'ADMIN_FUNCTIONS_BASE_URL',
    defaultValue: 'https://us-central1-cvmaker-saas-jb.cloudfunctions.net',
  );
}
