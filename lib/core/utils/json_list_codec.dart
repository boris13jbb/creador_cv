import 'dart:convert';

/// Codec retrocompatible: acepta JSON-string legacy o List/Map nativos.
class JsonListCodec {
  static List<Map<String, dynamic>> decodeObjectList(dynamic raw) {
    if (raw == null) return [];
    if (raw is String) {
      if (raw.trim().isEmpty) return [];
      final decoded = jsonDecode(raw);
      return decodeObjectList(decoded);
    }
    if (raw is List) {
      return raw.map((e) {
        if (e is Map<String, dynamic>) return e;
        if (e is Map) return Map<String, dynamic>.from(e);
        return <String, dynamic>{};
      }).toList();
    }
    return [];
  }

  /// Escritura nativa (schema v2+).
  static List<Map<String, dynamic>> encodeObjectList(
    List<Map<String, dynamic>> items,
  ) => items;
}
