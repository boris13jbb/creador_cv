/// Validación laxa de URLs opcionales (http/https).
bool isOptionalHttpUrl(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) return true;
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return false;
  if (!uri.hasScheme || !uri.hasAuthority) return false;
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') return false;
  return uri.host.isNotEmpty;
}

/// Recorta URL larga para layout PDF (muestra host + path corto).
String shortenUrlForDisplay(String url, {int maxLen = 42}) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return '';
  final uri = Uri.tryParse(trimmed);
  if (uri == null || uri.host.isEmpty) {
    return trimmed.length <= maxLen
        ? trimmed
        : '${trimmed.substring(0, maxLen - 1)}…';
  }
  final path = uri.path == '/' ? '' : uri.path;
  final compact = '${uri.host}$path';
  if (compact.length <= maxLen) return compact;
  return '${compact.substring(0, maxLen - 1)}…';
}
