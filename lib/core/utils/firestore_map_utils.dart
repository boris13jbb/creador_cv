/// Utilidades para payloads Firestore seguros (sin nulls ni claves vacías).
///
/// En arrays de mapas, un valor `null` puede provocar
/// `cloud_firestore/invalid-argument` en el SDK nativo.
Map<String, dynamic> stripNullsForFirestore(Map<String, dynamic> input) {
  final out = <String, dynamic>{};
  for (final entry in input.entries) {
    final key = entry.key;
    if (key.isEmpty) continue;
    final sanitized = _sanitizeValue(entry.value);
    if (sanitized == _omit) continue;
    out[key] = sanitized;
  }
  return out;
}

const Object _omit = Object();

dynamic _sanitizeValue(dynamic value) {
  if (value == null) return _omit;
  // FieldValue y otros sentinels del SDK: no tocar.
  final typeName = value.runtimeType.toString();
  if (typeName.contains('FieldValue')) return value;

  if (value is Map) {
    final nested = <String, dynamic>{};
    value.forEach((k, v) {
      final key = '$k';
      if (key.isEmpty) return;
      final sanitized = _sanitizeValue(v);
      if (sanitized == _omit) return;
      nested[key] = sanitized;
    });
    return nested;
  }

  if (value is List) {
    return value.map((item) {
      if (item is Map) {
        return stripNullsForFirestore(Map<String, dynamic>.from(item));
      }
      return item;
    }).toList();
  }

  if (value is String && value.contains('\u0000')) {
    return value.replaceAll('\u0000', '');
  }

  return value;
}
