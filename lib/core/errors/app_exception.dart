/// Errores de dominio de la aplicación.
class AppException implements Exception {
  final String message;
  final String? code;
  final Object? cause;

  const AppException(this.message, {this.code, this.cause});

  @override
  String toString() => message;
}

class NetworkAppException extends AppException {
  const NetworkAppException([super.message = 'Sin conexión a internet.'])
    : super(code: 'network');
}

class AuthAppException extends AppException {
  const AuthAppException(super.message) : super(code: 'auth');
}

class PermissionAppException extends AppException {
  const PermissionAppException([
    super.message = 'No tienes permiso para esta acción.',
  ]) : super(code: 'permission');
}

class ValidationAppException extends AppException {
  const ValidationAppException(super.message) : super(code: 'validation');
}

class StorageAppException extends AppException {
  const StorageAppException(super.message) : super(code: 'storage');
}

/// Normaliza excepciones desconocidas a mensajes seguros para la UI.
class ErrorMapper {
  static AppException map(Object error) {
    if (error is AppException) return error;
    final text = error.toString().replaceFirst('Exception: ', '');
    final lower = text.toLowerCase();
    if (lower.contains('permission') || lower.contains('permiso')) {
      return PermissionAppException(text);
    }
    if (lower.contains('unknownhost') ||
        lower.contains('failed host lookup') ||
        lower.contains('unable to resolve host') ||
        lower.contains('network') ||
        lower.contains('socket') ||
        lower.contains('conexión') ||
        lower.contains('unavailable')) {
      return const NetworkAppException(
        'Sin conexión a Firebase. Revisa Wi‑Fi/datos e inténtalo de nuevo.',
      );
    }
    if (lower.contains('object-not-found') ||
        lower.contains('storage bucket') ||
        (lower.contains('storage') && lower.contains('404'))) {
      return const StorageAppException(
        'Firebase Storage no está disponible. Activa Storage en la consola.',
      );
    }
    if (lower.contains('no hay sesión activa') ||
        lower.contains('sesión expiró')) {
      return AuthAppException(text);
    }
    return AppException(text, cause: error);
  }

  static String messageOf(Object error) => map(error).message;
}
