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
import '../features/resumes/data/resume_photo_service.dart';
import '../models/resume.dart';
import '../saas/providers/auth_controller.dart';
import '../services/db_service.dart';
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

  bool _photoLoadWarned = false;

  @override
  void initState() {
    super.initState();
    _resume = widget.resume;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _attachStoredPhoto();
    });
  }

  @override
  void didUpdateWidget(covariant ResumePreviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.resume, widget.resume)) {
      _resume = widget.resume;
      _cachedPdf = null;
      _cacheKey = null;
    }
  }

  /// La vista previa recibe el CV sin los bytes (no se guardan en Firestore).
  Future<void> _attachStoredPhoto() async {
    if (!mounted || _resume.ocultarFoto || _resume.hasPhotoBytes) return;
    final hasStoredPhoto =
        (_resume.effectivePhotoRef != null &&
            _resume.effectivePhotoRef!.isNotEmpty) ||
        (_resume.fotoStoragePath != null &&
            _resume.fotoStoragePath!.isNotEmpty);
    if (!hasStoredPhoto) return;
    final bytes = await ResumePhotoService.instance.loadBytesForResume(_resume);
    if (!mounted) return;
    if (bytes == null || bytes.isEmpty) {
      if (_photoLoadWarned) return;
      _photoLoadWarned = true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo cargar la fotografía guardada de este CV.'),
        ),
      );
      return;
    }
    setState(() {
      _resume = _resume.copyWith(fotoBytes: bytes);
      _cachedPdf = null;
      _cacheKey = null;
    });
  }

  /// La vista previa que ya estaba abierta debe tomar el CV editado.
  ///
  /// Si no, sigue generando el PDF con el designIndex anterior.
  Future<void> _openEditor() async {
    final result = await context.push<Object?>('/resumes/edit', extra: _resume);
    if (!mounted) return;
    final edited = await _resumeAfterEdit(result);
    if (!mounted || edited == null) return;
    setState(() {
      _resume = edited;
      _cachedPdf = null;
      _cacheKey = null;
    });
  }

  Future<Resume?> _resumeAfterEdit(Object? result) async {
    if (result is Resume) {
      if (result.fotoBytes == null && _resume.fotoBytes != null) {
        return result.copyWith(fotoBytes: _resume.fotoBytes);
      }
      return result;
    }
    final stored = await DBService.instance.getById(_resume.id);
    if (stored == null) return null;
    if (_resume.fotoBytes == null) return stored;
    return stored.copyWith(fotoBytes: _resume.fotoBytes);
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
          Semantics(
            label: 'Editar CV',
            button: true,
            onTap: _openEditor,
            child: IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Editar CV',
              onPressed: _openEditor,
            ),
          ),
          Semantics(
            label: 'Compartir / Descargar',
            button: true,
            onTap: () => _compartirPdf(context),
            child: IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Compartir / Descargar',
              onPressed: () => _compartirPdf(context),
            ),
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
