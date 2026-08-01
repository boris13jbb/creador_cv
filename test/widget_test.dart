import 'package:flutter_test/flutter_test.dart';
import 'package:creador_cv/saas/config/saas_config.dart';

void main() {
  test('paquete creador_cv y config SaaS cargan', () {
    expect(SaasConfig.productName, 'CV Maker');
    expect(SaasConfig.freeMaxCvs, 3);
  });
}
