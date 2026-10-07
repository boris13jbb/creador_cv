/// Mueve un elemento dentro de la misma lista.
/// No hace nada si el origen o el destino están fuera de rango.
void moveListItem<T>(List<T> items, int from, int to) {
  if (from < 0 || to < 0 || from >= items.length || to >= items.length) {
    return;
  }
  if (from == to) return;
  final item = items.removeAt(from);
  items.insert(to, item);
}
