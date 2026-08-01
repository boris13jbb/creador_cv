import 'package:creador_cv/core/observability/app_observability.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Sentry desactivado sin DSN (default seguro)', () {
    expect(AppObservability.dsn, isEmpty);
    expect(AppObservability.isEnabled, isFalse);
  });

  test('captureException sin DSN no lanza', () async {
    await AppObservability.captureException(
      Exception('test'),
      context: 'unit_test',
    );
  });
}
