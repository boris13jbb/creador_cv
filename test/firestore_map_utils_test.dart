import 'package:creador_cv/core/utils/firestore_map_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('stripNullsForFirestore', () {
    test('elimina nulls de primer nivel y anidados', () {
      final cleaned = stripNullsForFirestore({
        'a': 1,
        'b': null,
        'c': {'d': 'ok', 'e': null},
        'list': [
          {'x': 1, 'y': null},
          {'z': null},
        ],
      });

      expect(cleaned.containsKey('b'), isFalse);
      expect(cleaned['c'], {'d': 'ok'});
      expect(cleaned['list'], [
        {'x': 1},
        <String, dynamic>{},
      ]);
    });

    test('omite claves vacías', () {
      final cleaned = stripNullsForFirestore({'': 'x', 'ok': true});
      expect(cleaned.keys, ['ok']);
    });
  });
}
