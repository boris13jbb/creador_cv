import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../core/observability/app_observability.dart';
import '../core/routing/app_router.dart';
import '../core/theme/app_tokens.dart';
import '../features/templates/cv_templates.dart';
import '../models/resume.dart';
import '../saas/providers/auth_controller.dart';
import '../services/resume_pdf_service.dart';

class ResumePreviewScreen extends StatefulWidget {
  final Resume resume;

  const ResumePreviewScreen({super.key, required this.resume});

  @override
  State<ResumePreviewScreen> createState() => _ResumePreviewScreenState();
}

class _ResumePreviewScreenState extends State<ResumePreviewScreen> {
  late Resume _resume;
  Uint8List? _cachedPdf;
  String? _cacheKey;

  @override
  void initState() {
    super.initState();
    _resume = widget.resume;
  }

  String _keyFor(bool isPro) =>
      '${_resume.id}|$isPro|${_resume.designIndex}|'
      '${_resume.updatedAt?.millisecondsSinceEpoch ?? 0}|${_resume.nombre}|'
      '${_resume.experiencia.length}|${_resume.perfil.length}|'
      '${_resume.effectivePhotoRef ?? ''}|${_resume.fotoBytes?.length ?? 0}|'
      '${_resume.ocultarFoto}';

  Future<Uint8List> _buildPdf(bool isPro) async {
    final key = _keyFor(isPro);
    if (_cachedPdf != null && _cacheKey == key) {
      return _cachedPdf!;
    }
    final bytes = await ResumePdfService.generateResumePdf(
      _resume,
      isPro: isPro,
    );
    _cachedPdf = bytes;
    _cacheKey = key;
    return bytes;
  }

  Future<void> _compartirPdf(BuildContext context) async {
    final isPro = context.read<AuthController>().isPro;
    try {
      final bytes = await _buildPdf(isPro);
      final fileName = 'CV_${_resume.nombre.replaceAll(' ', '_')}.pdf';
      await Share.shareXFiles([
        XFile.fromData(bytes, mimeType: 'application/pdf', name: fileName),
      ], text: 'CV: ${_resume.nombre}');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Listo para compartir')));
      }
    } catch (e, st) {
      await AppObservability.captureException(
        e,
        stackTrace: st,
        context: 'share_pdf',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al compartir: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPro = context.watch<AuthController>().isPro;
    final lockedProDesign =
        CvTemplates.requiresPro(_resume.designIndex) && !isPro;
    final templateName = CvTemplates.byIndex(
      CvTemplates.resolveDesignIndex(_resume.designIndex, isPro: isPro),
    ).name;

    return Scaffold(
      appBar: AppBar(
        title: Text('CV: ${_resume.nombre}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Editar CV',
            onPressed: () async {
              final result = await context.push<bool>(
                '/resumes/edit',
                extra: _resume,
              );
              if (!mounted) return;
              if (result == true && context.mounted) {
                context.pop(true);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Compartir / Descargar',
            onPressed: () => _compartirPdf(context),
          ),
        ],
      ),
      body: Column(
        children: [
          if (lockedProDesign)
            Material(
              color: AppColors.amber.withValues(alpha: 0.12),
              child: ListTile(
                leading: const Icon(Icons.lock_outline, color: AppColors.amber),
                title: Text(
                  'Plantilla Pro bloqueada. Vista previa Free: $templateName.',
                ),
                trailing: TextButton(
                  onPressed: () => context.push(AppRoutes.pricing),
                  child: const Text('Ver Pro'),
                ),
              ),
            ),
          Expanded(
            child: PdfPreview(
              key: ValueKey(_keyFor(isPro)),
              build: (_) => _buildPdf(isPro),
              canChangeOrientation: false,
              canChangePageFormat: false,
            ),
          ),
        ],
      ),
    );
  }
}
