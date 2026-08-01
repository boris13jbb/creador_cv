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
    if (text.toLowerCase().contains('permission') ||
        text.toLowerCase().contains('permiso')) {
      return PermissionAppException(text);
    }
    if (text.toLowerCase().contains('network') ||
        text.toLowerCase().contains('socket') ||
        text.toLowerCase().contains('conexión')) {
      return NetworkAppException(text);
    }
    return AppException(text, cause: error);
  }

  static String messageOf(Object error) => map(error).message;
}
