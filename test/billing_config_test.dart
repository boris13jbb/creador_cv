import 'package:creador_cv/saas/config/saas_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('billing config tiene URL de Functions por defecto del proyecto', () {
    expect(SaasConfig.billingFunctionsBaseUrl, contains('cvmaker-saas-jb'));
    expect(SaasConfig.billingBackendEnabled, isTrue);
  });

  test('Payment Link vacío por defecto (no secretos en binario)', () {
    expect(SaasConfig.stripePaymentLink, isEmpty);
  });
}
