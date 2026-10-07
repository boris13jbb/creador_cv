import 'package:creador_cv/core/utils/list_edit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bajar el primero intercambia con el segundo', () {
    final items = ['CotizaPro', 'NotesPro', 'Neps'];
    moveListItem(items, 0, 1);
    expect(items, ['NotesPro', 'CotizaPro', 'Neps']);
  });

  test('subir el primero y bajar el último no cambian la lista', () {
    final items = ['CotizaPro', 'NotesPro', 'Neps'];
    moveListItem(items, 0, -1);
    moveListItem(items, 2, 3);
    expect(items, ['CotizaPro', 'NotesPro', 'Neps']);
  });

  test('eliminar por índice quita solo ese elemento', () {
    final items = ['Uno', 'TEMP E2E BORRAR', 'Tres'];
    items.removeAt(1);
    expect(items, ['Uno', 'Tres']);
    expect(items.contains('TEMP E2E BORRAR'), isFalse);
  });
}
