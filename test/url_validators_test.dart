import 'package:creador_cv/core/utils/url_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isOptionalHttpUrl', () {
    test('vacía es válida', () {
      expect(isOptionalHttpUrl(null), isTrue);
      expect(isOptionalHttpUrl(''), isTrue);
      expect(isOptionalHttpUrl('   '), isTrue);
    });

    test('https válido', () {
      expect(isOptionalHttpUrl('https://example.com/path'), isTrue);
      expect(isOptionalHttpUrl('http://localhost:3000'), isTrue);
    });

    test('rechaza basura', () {
      expect(isOptionalHttpUrl('ftp://x'), isFalse);
      expect(isOptionalHttpUrl('not a url'), isFalse);
      expect(isOptionalHttpUrl('https://'), isFalse);
    });
  });

  group('shortenUrlForDisplay', () {
    test('recorta URLs largas', () {
      final short = shortenUrlForDisplay(
        'https://very-long-domain.example.com/path/to/resource/page',
        maxLen: 30,
      );
      expect(short.length, lessThanOrEqualTo(30));
      expect(short, contains('…'));
    });
  });
}
