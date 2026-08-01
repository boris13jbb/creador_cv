import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_layout.dart';

/// Muestra un documento legal embebido desde `docs/legal/` vía assets.
class LegalDocumentScreen extends StatefulWidget {
  final String title;
  final String assetPath;

  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.assetPath,
  });

  @override
  State<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends State<LegalDocumentScreen> {
  String? _text;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await rootBundle.loadString(widget.assetPath);
      if (!mounted) return;
      setState(() => _text = raw);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: AppContentWidth(
        maxWidth: 800,
        child: _error != null
            ? Center(
                child: Text(
                  'No se pudo cargar el documento.',
                  style: TextStyle(color: AppColors.danger),
                ),
              )
            : _text == null
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                child: SelectableText(
                  _text!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(height: 1.45),
                ),
              ),
      ),
    );
  }
}
