import 'dart:convert';
import 'dart:io';

/// Extrae texto de un PDF con PyMuPDF cuando está disponible.
///
/// La búsqueda en bytes crudos falla con fuentes embebidas. Escribe el texto
/// a un archivo UTF-8 (más fiable que stdout en Windows) y lo lee en Dart.
Future<String?> extractPdfTextWithPyMuPdf(
  List<int> bytes, {
  String? saveAs,
}) async {
  final dir = Directory('build');
  dir.createSync(recursive: true);
  final pdfFile = File(saveAs ?? 'build/_pdf_extract_probe.pdf');
  await pdfFile.writeAsBytes(bytes, flush: true);
  final outFile = File('${pdfFile.path}.txt');

  final script = '''
import sys
try:
    import pymupdf
except ImportError:
    import fitz as pymupdf
doc = pymupdf.open(sys.argv[1])
text = "\\n".join(page.get_text() for page in doc)
open(sys.argv[2], "w", encoding="utf-8").write(text)
''';

  for (final cmd in const ['python', 'py', 'python3']) {
    try {
      final result = await Process.run(cmd, [
        '-c',
        script,
        pdfFile.absolute.path,
        outFile.absolute.path,
      ]);
      if (result.exitCode == 0 && outFile.existsSync()) {
        return outFile.readAsStringSync(encoding: utf8);
      }
    } on ProcessException {
      continue;
    }
  }
  return null;
}

/// Colapsa espacios/saltos para localizar marcas partidas por el sidebar.
String collapsePdfText(String text) => text.replaceAll(RegExp(r'\s+'), '');
