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
import '../saas/models/subscription_access.dart';
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

  String _keyFor(SubscriptionAccess access) =>
      '${_resume.id}|${access.name}|${_resume.designIndex}|'
      '${_resume.updatedAt?.millisecondsSinceEpoch ?? 0}|${_resume.nombre}|'
      '${_resume.experiencia.length}|${_resume.perfil.length}|'
      '${_resume.effectivePhotoRef ?? ''}|${_resume.fotoBytes?.length ?? 0}|'
      '${_resume.ocultarFoto}';

  Future<Uint8List> _buildPdf(SubscriptionAccess access) async {
    final key = _keyFor(access);
    if (_cachedPdf != null && _cacheKey == key) {
      return _cachedPdf!;
    }
    final bytes = await ResumePdfService.generateResumePdf(
      _resume,
      isPro: access == SubscriptionAccess.pro,
      access: access,
    );
    _cachedPdf = bytes;
    _cacheKey = key;
    return bytes;
  }

  Future<void> _compartirPdf(BuildContext context) async {
    final access = context.read<AuthController>().subscriptionAccess;
    final decision = CvTemplates.decideRender(
      _resume.designIndex,
      access: access,
    );
    if (decision.holdForPlan) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            access == SubscriptionAccess.error
                ? 'No se pudo verificar tu plan. Reintenta; el PDF se generará al confirmarlo.'
                : 'Estamos verificando tu plan. El PDF se generará cuando se confirme.',
          ),
        ),
      );
      return;
    }
    try {
      final bytes = await _buildPdf(access);
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
    final auth = context.watch<AuthController>();
    final access = auth.subscriptionAccess;
    final decision = CvTemplates.decideRender(
      _resume.designIndex,
      access: access,
    );
    final waitingForPlan = decision.holdForPlan;
    final lockedProDesign =
        access == SubscriptionAccess.free &&
        CvTemplates.requiresPro(_resume.designIndex);
    final templateName = waitingForPlan
        ? CvTemplates.byIndex(_resume.designIndex).name
        : CvTemplates.byIndex(decision.renderIndex!).name;

    return Scaffold(
      appBar: AppBar(
        title: Text('CV: ${_resume.nombre} · $templateName'),
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
          if (waitingForPlan)
            Material(
              color: AppColors.amber.withValues(alpha: 0.12),
              child: ListTile(
                leading: const Icon(Icons.hourglass_top_outlined),
                title: Text(
                  'Verificando tu plan. $templateName sigue guardada y no se ha cambiado a Clásico.',
                ),
                subtitle: const Text(
                  'La vista previa se generará cuando el plan quede confirmado.',
                ),
                trailing: TextButton(
                  onPressed: auth.retrySessionLoad,
                  child: const Text('Reintentar'),
                ),
              ),
            )
          else if (lockedProDesign)
            Material(
              color: AppColors.amber.withValues(alpha: 0.12),
              child: ListTile(
                leading: const Icon(Icons.lock_outline, color: AppColors.amber),
                title: Text(
                  'Plantilla Pro bloqueada. Vista previa Free: $templateName.',
                ),
                subtitle: const Text(
                  'One Page, Ejecutiva y Creativa están en el plan Pro.',
                ),
                trailing: TextButton(
                  onPressed: () => context.push(AppRoutes.pricing),
                  child: const Text('Ver Pro'),
                ),
              ),
            ),
          Expanded(
            child: waitingForPlan
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No se muestra otra plantilla mientras se verifica la suscripción.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : PdfPreview(
                    key: ValueKey(_keyFor(access)),
                    build: (_) => _buildPdf(access),
                    canChangeOrientation: false,
                    canChangePageFormat: false,
                  ),
          ),
        ],
      ),
    );
  }
}
