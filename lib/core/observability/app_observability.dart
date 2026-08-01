import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Observabilidad opcional. Sin DSN no envía nada (seguro en CI/local).
///
/// Activación:
/// `flutter run --dart-define=SENTRY_DSN=https://...@....ingest.sentry.io/...`
abstract final class AppObservability {
  static const String dsn = String.fromEnvironment(
    'SENTRY_DSN',
    defaultValue: '',
  );
  static const String environment = String.fromEnvironment(
    'SENTRY_ENVIRONMENT',
    defaultValue: 'development',
  );
  static const String release = String.fromEnvironment(
    'SENTRY_RELEASE',
    defaultValue: 'creador_cv@1.0.0+1',
  );

  static bool get isEnabled => dsn.trim().isNotEmpty;

  /// Ejecuta [appRunner] con Sentry si hay DSN; si no, solo corre la app.
  static Future<void> run(FutureOr<void> Function() appRunner) async {
    if (!isEnabled) {
      await appRunner();
      return;
    }

    await SentryFlutter.init(
      (options) {
        options.dsn = dsn;
        options.environment = environment;
        options.release = release;
        options.tracesSampleRate = kReleaseMode ? 0.15 : 0.0;
        options.attachScreenshot = false;
        options.sendDefaultPii = false;
        options.enableUserInteractionBreadcrumbs = false;
        options.beforeSend = _scrubEvent;
      },
      appRunner: () async {
        await appRunner();
      },
    );
  }

  static FutureOr<SentryEvent?> _scrubEvent(SentryEvent event, Hint hint) {
    final headers = Map<String, String>.from(event.request?.headers ?? {});
    headers.remove('Authorization');
    headers.remove('authorization');

    final crumbs = event.breadcrumbs?.where((b) {
      final msg = (b.message ?? '').toLowerCase();
      if (msg.contains('password') ||
          msg.contains('token') ||
          msg.contains('authorization')) {
        return false;
      }
      return true;
    }).toList();

    return event.copyWith(
      breadcrumbs: crumbs ?? const <Breadcrumb>[],
      request: event.request?.copyWith(headers: headers, removeCookies: true),
    );
  }

  static Future<void> captureException(
    Object error, {
    StackTrace? stackTrace,
    String? context,
  }) async {
    debugPrint(
      'AppObservability: $error${context != null ? ' [$context]' : ''}',
    );
    if (!isEnabled) return;
    await Sentry.captureException(
      error,
      stackTrace: stackTrace,
      withScope: (scope) {
        if (context != null) {
          scope.setTag('context', context);
        }
      },
    );
  }

  static Future<void> captureMessage(
    String message, {
    SentryLevel level = SentryLevel.info,
  }) async {
    debugPrint('AppObservability: $message');
    if (!isEnabled) return;
    await Sentry.captureMessage(message, level: level);
  }
}
