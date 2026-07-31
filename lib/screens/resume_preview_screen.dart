import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../models/resume.dart';
import '../services/resume_pdf_service.dart';
import 'nuevo_cv_screen.dart';

class ResumePreviewScreen extends StatefulWidget {
  final Resume resume;

  const ResumePreviewScreen({super.key, required this.resume});

  @override
  State<ResumePreviewScreen> createState() => _ResumePreviewScreenState();
}

class _ResumePreviewScreenState extends State<ResumePreviewScreen> {
  late Resume _resume;

  @override
  void initState() {
    super.initState();
    _resume = widget.resume;
  }

  Future<void> _compartirPdf(BuildContext context) async {
    try {
      final bytes = await ResumePdfService.generateResumePdf(_resume);
      final fileName = 'CV_${_resume.nombre.replaceAll(' ', '_')}.pdf';
      await Share.shareXFiles(
        [XFile.fromData(bytes, mimeType: 'application/pdf', name: fileName)],
        text: 'CV: ${_resume.nombre}',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listo para compartir')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al compartir: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('CV: ${_resume.nombre}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Editar CV',
            onPressed: () async {
              final navigator = Navigator.of(context);
              final result = await navigator.push(
                MaterialPageRoute(
                  builder: (context) => NuevoCvScreen(resumeExistente: _resume),
                ),
              );
              if (result == true && mounted) {
                navigator.pop(true);
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
      body: PdfPreview(
        build: (format) => ResumePdfService.generateResumePdf(_resume),
        allowPrinting: true,
        allowSharing: true,
        pdfFileName: "CV_${_resume.nombre.replaceAll(' ', '_')}.pdf",
      ),
    );
  }
}
