import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('assets legales embebidos', () async {
    final privacy = await rootBundle.loadString('assets/legal/privacy_es.md');
    final terms = await rootBundle.loadString('assets/legal/terms_es.md');
    expect(privacy, contains('Política de privacidad'));
    expect(terms, contains('Términos de uso'));
    expect(privacy, isNot(contains('lorem ipsum')));
  });
}
