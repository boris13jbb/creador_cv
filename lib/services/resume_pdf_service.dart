import 'dart:convert';
import 'dart:typed_data';
import 'package:universal_io/io.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/resume.dart';

class ResumePdfService {
  static pw.Widget _pdfBulletDot(PdfColor color, {double size = 6}) => pw.Container(
        width: size,
        height: size,
        decoration: pw.BoxDecoration(color: color, shape: pw.BoxShape.circle),
      );

  static Future<Uint8List> generateResumePdf(Resume resume) async {
    switch (resume.designIndex) {
      case 0:
        return _generateClassicPdf(resume);
      case 1:
        return _generateModernPdf(resume);
      case 2:
        return _generateExecutivePdf(resume);
      case 3:
        return _generateCreativePdf(resume);
      default:
        return _generateClassicPdf(resume);
    }
  }

  // --- DISEÑO EJECUTIVO (Estilo profesional y corporativo) ---
  static Future<Uint8List> _generateExecutivePdf(Resume resume) async {
    final pdf = pw.Document();
    final PdfColor primaryColor = PdfColor.fromInt(resume.colorHex);
    final PdfColor secondaryColor = PdfColor.fromInt(0xFF4A4A4A);
    final PdfColor lightGray = PdfColor.fromInt(0xFFF5F5F5);
    final PdfColor darkGray = PdfColor.fromInt(0xFF333333);

    pw.ImageProvider? profileImage;
    if (resume.fotoPath != null && resume.fotoPath!.isNotEmpty) {
      try {
        if (resume.fotoPath!.startsWith('data:')) {
          final base64 = resume.fotoPath!.split(',').last;
          profileImage = pw.MemoryImage(base64Decode(base64));
        } else if (!kIsWeb) {
          final file = File(resume.fotoPath!);
          if (await file.exists()) profileImage = pw.MemoryImage(await file.readAsBytes());
        }
      } catch (_) {}
    }

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.all(50),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Cabecera con nombre y foto
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Foto
                pw.Container(
                  width: 100,
                  height: 130,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: primaryColor, width: 2),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: profileImage != null
                    ? pw.Image(profileImage, fit: pw.BoxFit.cover)
                    : pw.Container(color: PdfColors.grey300),
                ),
                pw.SizedBox(width: 20),
                // Nombre y título
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        resume.nombre.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: primaryColor,
                          letterSpacing: 1.5,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: pw.BoxDecoration(
                          color: lightGray,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Text(
                          "PROFESIONAL EJECUTIVO",
                          style: pw.TextStyle(
                            fontSize: 10,
                            color: secondaryColor,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 15),
                      // Datos personales
                      pw.Wrap(
                        spacing: 20,
                        runSpacing: 8,
                        children: resume.datosPersonales.map((d) =>
                          pw.Row(
                            mainAxisSize: pw.MainAxisSize.min,
                            children: [
                              _pdfBulletDot(secondaryColor),
                              pw.SizedBox(width: 6),
                              pw.Text(d.value, style: pw.TextStyle(fontSize: 10, color: darkGray)),
                            ],
                          )
                        ).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            pw.SizedBox(height: 30),
            
            // Perfil
            _executiveSectionHeader('Perfil Profesional', primaryColor),
            pw.SizedBox(height: 10),
            pw.Text(
              resume.perfil,
              style: pw.TextStyle(fontSize: 11, height: 1.5, color: darkGray),
              textAlign: pw.TextAlign.justify,
            ),
            
            pw.SizedBox(height: 25),
            
            // Experiencia
            _executiveSectionHeader('Experiencia Profesional', primaryColor),
            pw.SizedBox(height: 15),
            ...resume.experiencia.map((e) => _executiveExpItem(e, primaryColor, darkGray)),
            
            pw.SizedBox(height: 25),
            
            // Formación
            _executiveSectionHeader('Formación Académica', primaryColor),
            pw.SizedBox(height: 15),
            ...resume.formacion.map((f) => _executiveEduItem(f, darkGray)),
            
            pw.SizedBox(height: 25),
            
            // Competencias
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _executiveSectionHeader('Competencias', primaryColor),
                      pw.SizedBox(height: 15),
                      ...resume.competencias.map((s) => _executiveSkillItem(s.nombre, s.nivel, primaryColor)),
                    ],
                  ),
                ),
                pw.SizedBox(width: 30),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _executiveSectionHeader('Idiomas', primaryColor),
                      pw.SizedBox(height: 15),
                      ...resume.idiomas.map((s) => _executiveSkillItem(s.nombre, s.nivel, primaryColor)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    ));
    
    return pdf.save();
  }

  // Helpers para diseño ejecutivo
  static pw.Widget _executiveSectionHeader(String title, PdfColor color) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 12),
    decoration: pw.BoxDecoration(
      color: color,
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
    ),
    child: pw.Text(
      title,
      style: pw.TextStyle(
        fontSize: 12,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
    ),
  );

  static pw.Widget _executiveExpItem(Experience e, PdfColor accentColor, PdfColor textColor) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Text(
              e.cargo,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
          pw.Text(
            e.periodo,
            style: pw.TextStyle(
              fontSize: 10,
              color: accentColor,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 4),
      pw.Text(
        e.empresa,
        style: pw.TextStyle(
          fontSize: 11,
          fontStyle: pw.FontStyle.italic,
          color: accentColor,
        ),
      ),
      pw.SizedBox(height: 8),
      ...e.logros.map((logro) => pw.Padding(
        padding: const pw.EdgeInsets.only(left: 15),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text("• ", style: pw.TextStyle(fontSize: 11, color: textColor)),
            pw.Expanded(
              child: pw.Text(logro, style: pw.TextStyle(fontSize: 11, color: textColor)),
            ),
          ],
        ),
      )),
    ],
  );

  static pw.Widget _executiveEduItem(Education f, PdfColor textColor) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            f.titulo,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: textColor,
            ),
          ),
          pw.Text(
            f.anio,
            style: pw.TextStyle(
              fontSize: 10,
              color: textColor,
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 4),
      pw.Text(
        f.institucion,
        style: pw.TextStyle(
          fontSize: 11,
          color: textColor,
        ),
      ),
    ],
  );

  static pw.Widget _executiveSkillItem(String name, int level, PdfColor color) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 8),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          name,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Stack(
          children: [
            pw.Container(
              height: 6,
              width: 100,
              decoration: pw.BoxDecoration(
                color: PdfColors.grey300,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
              ),
            ),
            pw.Container(
              height: 6,
              width: (level / 5) * 100,
              decoration: pw.BoxDecoration(
                color: color,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  // --- DISEÑO CREATIVO (Estilo moderno y visualmente atractivo) ---
  static Future<Uint8List> _generateCreativePdf(Resume resume) async {
    final pdf = pw.Document();
    final PdfColor accentColor = PdfColor.fromInt(resume.colorHex);
    final PdfColor backgroundColor = PdfColor.fromInt(0xFFF9F9F9);
    final PdfColor textColor = PdfColor.fromInt(0xFF333333);

    pw.ImageProvider? profileImage;
    if (resume.fotoPath != null && resume.fotoPath!.isNotEmpty) {
      try {
        if (resume.fotoPath!.startsWith('data:')) {
          final base64 = resume.fotoPath!.split(',').last;
          profileImage = pw.MemoryImage(base64Decode(base64));
        } else if (!kIsWeb) {
          final file = File(resume.fotoPath!);
          if (await file.exists()) profileImage = pw.MemoryImage(await file.readAsBytes());
        }
      } catch (_) {}
    }

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (context) {
        return pw.Stack(
          children: [
            // Fondo
            pw.Positioned.fill(
              child: pw.Container(color: backgroundColor),
            ),
            
            // Contenido principal
            pw.Positioned(
              top: 40,
              left: 40,
              right: 40,
              bottom: 40,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Cabecera con nombre
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Foto redonda
                      pw.Container(
                        width: 120,
                        height: 120,
                        decoration: pw.BoxDecoration(
                          shape: pw.BoxShape.circle,
                          border: pw.Border.all(color: accentColor, width: 4),
                        ),
                        child: pw.ClipOval(
                          child: profileImage != null
                            ? pw.Image(profileImage, fit: pw.BoxFit.cover)
                            : pw.Container(color: PdfColors.grey300),
                        ),
                      ),
                      pw.SizedBox(width: 30),
                      // Nombre y datos
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              resume.nombre,
                              style: pw.TextStyle(
                                fontSize: 32,
                                fontWeight: pw.FontWeight.bold,
                                color: accentColor,
                                letterSpacing: 1,
                              ),
                            ),
                            pw.SizedBox(height: 8),
                            pw.Text(
                              "Diseñador Creativo & Estratega",
                              style: pw.TextStyle(
                                fontSize: 16,
                                color: textColor,
                                fontStyle: pw.FontStyle.italic,
                              ),
                            ),
                            pw.SizedBox(height: 20),
                            // Datos personales en fila
                            pw.Wrap(
                              spacing: 25,
                              runSpacing: 10,
                              children: resume.datosPersonales.map((d) =>
                                pw.Row(
                                  mainAxisSize: pw.MainAxisSize.min,
                                  children: [
                                    _pdfBulletDot(accentColor),
                                    pw.SizedBox(width: 8),
                                    pw.Text(d.value, style: pw.TextStyle(fontSize: 11, color: textColor)),
                                  ],
                                )
                              ).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  pw.SizedBox(height: 40),
                  
                  // Secciones en dos columnas
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Columna izquierda - Perfil
                      pw.Expanded(
                        flex: 2,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _creativeSectionHeader('Perfil', accentColor),
                            pw.SizedBox(height: 15),
                            pw.Text(
                              resume.perfil,
                              style: pw.TextStyle(fontSize: 11, height: 1.6, color: textColor),
                              textAlign: pw.TextAlign.justify,
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 40),
                      // Columna derecha - Competencias e Idiomas
                      pw.Expanded(
                        flex: 1,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _creativeSectionHeader('Habilidades', accentColor),
                            pw.SizedBox(height: 15),
                            ...resume.competencias.map((s) => _creativeSkillChip(s.nombre, accentColor)).toList(),
                            
                            pw.SizedBox(height: 30),
                            _creativeSectionHeader('Idiomas', accentColor),
                            pw.SizedBox(height: 15),
                            ...resume.idiomas.map((s) => _creativeLanguageItem(s.nombre, s.nivel, accentColor)).toList(),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  pw.SizedBox(height: 40),
                  
                  // Experiencia
                  _creativeSectionHeader('Experiencia', accentColor),
                  pw.SizedBox(height: 20),
                  ...resume.experiencia.map((e) => _creativeExpItem(e, accentColor, textColor)).toList(),
                  
                  pw.SizedBox(height: 30),
                  
                  // Formación
                  _creativeSectionHeader('Formación', accentColor),
                  pw.SizedBox(height: 20),
                  ...resume.formacion.map((f) => _creativeEduItem(f, accentColor, textColor)).toList(),
                ],
              ),
            ),
          ],
        );
      },
    ));
    
    return pdf.save();
  }

  // Helpers para diseño creativo
  static pw.Widget _creativeSectionHeader(String title, PdfColor color) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 16),
    decoration: pw.BoxDecoration(
      color: color,
      borderRadius: const pw.BorderRadius.only(
        topLeft: pw.Radius.circular(20),
        bottomRight: pw.Radius.circular(20),
      ),
    ),
    child: pw.Text(
      title,
      style: pw.TextStyle(
        fontSize: 16,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
    ),
  );

  static pw.Widget _creativeSkillChip(String skill, PdfColor color) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 15, vertical: 8),
    margin: const pw.EdgeInsets.only(right: 10, bottom: 10),
    decoration: pw.BoxDecoration(
      color: PdfColor(color.red, color.green, color.blue, 0.1),
      border: pw.Border.all(color: color, width: 1),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(20)),
    ),
    child: pw.Text(
      skill,
      style: pw.TextStyle(
        fontSize: 10,
        color: color,
        fontWeight: pw.FontWeight.bold,
      ),
    ),
  );

  static pw.Widget _creativeLanguageItem(String language, int level, PdfColor color) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 12),
    child: pw.Row(
      children: [
        pw.Container(
          width: 80,
          child: pw.Text(language, style: pw.TextStyle(fontSize: 11, color: color, fontWeight: pw.FontWeight.bold)),
        ),
        pw.SizedBox(width: 15),
        pw.Expanded(
          child: pw.Row(
            children: List.generate(5, (index) =>
              pw.Container(
                width: 12,
                height: 12,
                margin: const pw.EdgeInsets.only(right: 4),
                decoration: pw.BoxDecoration(
                  shape: pw.BoxShape.circle,
                  color: index < level ? color : PdfColors.grey300,
                  border: pw.Border.all(color: index < level ? color : PdfColors.grey300, width: 1),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  static pw.Widget _creativeExpItem(Experience e, PdfColor accentColor, PdfColor textColor) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Text(
              e.cargo,
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: accentColor,
              ),
            ),
          ),
          pw.Text(
            e.periodo,
            style: pw.TextStyle(
              fontSize: 11,
              color: textColor,
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 4),
      pw.Text(
        e.empresa,
        style: pw.TextStyle(
          fontSize: 12,
          fontStyle: pw.FontStyle.italic,
          color: textColor,
        ),
      ),
      pw.SizedBox(height: 12),
      ...e.logros.map((logro) => pw.Padding(
        padding: const pw.EdgeInsets.only(left: 20),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              margin: const pw.EdgeInsets.only(top: 6, right: 8),
              height: 4,
              width: 4,
              decoration: pw.BoxDecoration(shape: pw.BoxShape.circle, color: accentColor),
            ),
            pw.Expanded(
              child: pw.Text(logro, style: pw.TextStyle(fontSize: 11, color: textColor)),
            ),
          ],
        ),
      )),
      pw.SizedBox(height: 20),
    ],
  );

  static pw.Widget _creativeEduItem(Education f, PdfColor accentColor, PdfColor textColor) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            f.titulo,
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: accentColor,
            ),
          ),
          pw.Text(
            f.anio,
            style: pw.TextStyle(
              fontSize: 11,
              color: textColor,
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 4),
      pw.Text(
        f.institucion,
        style: pw.TextStyle(
          fontSize: 11,
          color: textColor,
        ),
      ),
      pw.SizedBox(height: 15),
    ],
  );

  // --- DISEÑO CLÁSICO (Estilo Diego Fernando - Profesional) ---
  static Future<Uint8List> _generateClassicPdf(Resume resume) async {
    final pdf = pw.Document();
    final PdfColor accentColor = PdfColor.fromInt(resume.colorHex);
    final PdfColor headerColor = PdfColor.fromInt(0xFF20354B); 
    final PdfColor sidebarBg = PdfColor.fromInt(0xFFF2F4F7); 
    final PdfColor textColor = PdfColor.fromInt(0xFF333333);

    pw.ImageProvider? profileImage;
    if (resume.fotoPath != null && resume.fotoPath!.isNotEmpty) {
      try {
        if (resume.fotoPath!.startsWith('data:')) {
          final base64 = resume.fotoPath!.split(',').last;
          profileImage = pw.MemoryImage(base64Decode(base64));
        } else if (!kIsWeb) {
          final file = File(resume.fotoPath!);
          if (await file.exists()) profileImage = pw.MemoryImage(await file.readAsBytes());
        }
      } catch (_) {}
    }

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (context) {
        return pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // COLUMNA IZQUIERDA (SIDEBAR)
            pw.Container(
              width: 210,
              color: sidebarBg,
              child: pw.Column(
                children: [
                  pw.Container(
                    width: double.infinity,
                    height: 160,
                    color: headerColor,
                    padding: const pw.EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                    child: pw.Text(
                      resume.nombre.toUpperCase(),
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  
                  // Foto solapada ligeramente
                  pw.SizedBox(height: 20),
                  pw.Container(
                    width: 130,
                    height: 130,
                    decoration: pw.BoxDecoration(
                      shape: pw.BoxShape.circle,
                      color: PdfColors.white,
                      border: pw.Border.all(color: PdfColors.white, width: 4),
                    ),
                    child: pw.ClipOval(
                      child: profileImage != null
                        ? pw.Image(profileImage, fit: pw.BoxFit.cover)
                        : pw.Container(color: PdfColors.grey300),
                    ),
                  ),
                  pw.SizedBox(height: 30),
                  
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 25),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _classicSidebarHeader('Datos personales', headerColor),
                        pw.SizedBox(height: 10),
                        ...resume.datosPersonales.map((d) => _classicSidebarInfoItem(d, textColor)),
                        
                        pw.SizedBox(height: 30),
                        _classicSidebarHeader('Competencias', headerColor),
                        pw.SizedBox(height: 10),
                        ...resume.competencias.map((s) => _classicSidebarSkillDots(s.nombre, s.nivel, headerColor)),
                        
                        pw.SizedBox(height: 30),
                        _classicSidebarHeader('Idiomas', headerColor),
                        pw.SizedBox(height: 10),
                        ...resume.idiomas.map((s) => _classicSidebarSkillDots(s.nombre, s.nivel, headerColor)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // COLUMNA DERECHA (CONTENIDO)
            pw.Expanded(
              child: pw.Container(
                color: PdfColors.white,
                padding: const pw.EdgeInsets.all(40),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _classicMainHeader('Perfil', headerColor),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      resume.perfil,
                      style: pw.TextStyle(fontSize: 10, color: textColor),
                      textAlign: pw.TextAlign.justify,
                    ),
                    
                    pw.SizedBox(height: 30),
                    _classicMainHeader('Experiencia', headerColor),
                    ...resume.experiencia.map((e) => _classicExpItem(e, accentColor, textColor)),
                    
                    pw.SizedBox(height: 30),
                    _classicMainHeader('Formación', headerColor),
                    ...resume.formacion.map((f) => _classicEduItem(f, textColor)),
                    
                    pw.Spacer(),
                    pw.Align(
                      alignment: pw.Alignment.center,
                      child: pw.Text('© Jobseeker', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey400)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ));
    return pdf.save();
  }

  // --- DISEÑO MODERNO ---
  static Future<Uint8List> _generateModernPdf(Resume resume) async {
    final pdf = pw.Document();
    final PdfColor accentColor = PdfColor.fromInt(resume.colorHex);
    final PdfColor sidebarDark = PdfColor.fromInt(0xFF2C2E3E);

    pw.ImageProvider? profileImage;
    if (resume.fotoPath != null && resume.fotoPath!.isNotEmpty) {
      try {
        if (resume.fotoPath!.startsWith('data:')) {
          final base64 = resume.fotoPath!.split(',').last;
          profileImage = pw.MemoryImage(base64Decode(base64));
        } else if (!kIsWeb) {
          final file = File(resume.fotoPath!);
          if (await file.exists()) profileImage = pw.MemoryImage(await file.readAsBytes());
        }
      } catch (_) {}
    }

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (context) {
        return pw.Stack(
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Container(width: 160, color: sidebarDark),
                pw.Expanded(child: pw.Container(color: PdfColors.white)),
              ],
            ),
            pw.Positioned(
              top: 50, left: 160, right: 30,
              child: pw.Container(
                height: 110,
                color: accentColor,
                padding: const pw.EdgeInsets.only(left: 85, right: 20),
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(resume.nombre.toUpperCase(), style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.white, letterSpacing: 1.2)),
                    pw.SizedBox(height: 6),
                    pw.Wrap(
                      spacing: 12, runSpacing: 4,
                      children: resume.datosPersonales.map((d) => pw.Text(d.value, style: const pw.TextStyle(fontSize: 8, color: PdfColors.white))).toList(),
                    ),
                  ],
                ),
              ),
            ),
            pw.Positioned(
              left: 0, top: 220, 
              child: pw.SizedBox(
                width: 160,
                child: pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 20),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _modernSidebarTitle('COMPETENCIAS'),
                      pw.SizedBox(height: 12),
                      ...resume.competencias.map((s) => _modernSkillBar(s.nombre, s.nivel, accentColor)),
                      pw.SizedBox(height: 35),
                      _modernSidebarTitle('IDIOMAS'),
                      pw.SizedBox(height: 12),
                      ...resume.idiomas.map((s) => _modernSkillBar(s.nombre, s.nivel, accentColor)),
                    ],
                  ),
                ),
              ),
            ),
            pw.Positioned(
              left: 160 + 40, top: 180, right: 40,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _modernSectionHeader('PERFIL', accentColor),
                  pw.SizedBox(height: 10),
                  pw.Text(resume.perfil, style: const pw.TextStyle(fontSize: 9.5), textAlign: pw.TextAlign.justify),
                  pw.SizedBox(height: 25),
                  _modernSectionHeader('EXPERIENCIA', accentColor),
                  ...resume.experiencia.map((e) => _modernExpItem(e, accentColor)),
                  pw.SizedBox(height: 25),
                  _modernSectionHeader('FORMACIÓN', accentColor),
                  ...resume.formacion.map((f) => _educationItem(f)),
                ],
              ),
            ),
            pw.Positioned(
              top: 35, left: 90,
              child: pw.Container(
                width: 140, height: 140,
                decoration: pw.BoxDecoration(
                  shape: pw.BoxShape.circle,
                  color: PdfColors.white,
                  border: pw.Border.all(color: PdfColors.white, width: 6),
                ),
                child: pw.ClipOval(
                  child: profileImage != null ? pw.Image(profileImage, fit: pw.BoxFit.cover) : pw.Container(color: PdfColors.grey300),
                ),
              ),
            ),
          ],
        );
      }
    ));
    return pdf.save();
  }

  // --- HELPERS CLÁSICOS ---
  static pw.Widget _classicSidebarHeader(String title, PdfColor color) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(title, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: color)),
      pw.Divider(color: PdfColors.grey400, thickness: 0.5),
    ],
  );

  static pw.Widget _classicSidebarInfoItem(PersonalData d, PdfColor color) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Text(d.value, style: pw.TextStyle(fontSize: 9, color: color)),
    );
  }

  static pw.Widget _classicSidebarSkillDots(String name, int level, PdfColor color) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 4),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Expanded(child: pw.Text(name, style: const pw.TextStyle(fontSize: 8.5))),
        pw.Row(
          children: List.generate(5, (i) => pw.Container(
            width: 6, height: 6,
            margin: const pw.EdgeInsets.only(left: 2),
            decoration: pw.BoxDecoration(shape: pw.BoxShape.circle, color: i < level ? color : PdfColors.grey300),
          )),
        ),
      ],
    ),
  );

  static pw.Widget _classicMainHeader(String title, PdfColor color) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(title, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: color)),
      pw.Divider(color: PdfColors.grey300, thickness: 0.8),
    ],
  );

  static pw.Widget _classicExpItem(Experience e, PdfColor accent, PdfColor text) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 10),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(e.cargo, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: text)),
            pw.Text(e.periodo, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          ],
        ),
        pw.Text(e.empresa, style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic, color: accent)),
        ...e.logros.map((l) => pw.Padding(
          padding: const pw.EdgeInsets.only(left: 10, top: 2),
          child: pw.Text("- $l", style: pw.TextStyle(fontSize: 8.5, color: text)),
        )),
      ],
    ),
  );

  static pw.Widget _classicEduItem(Education f, PdfColor text) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 10),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(f.titulo, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: text)),
            pw.Text(f.institucion, style: pw.TextStyle(fontSize: 9, color: text)),
          ],
        ),
        pw.Text(f.anio, style: pw.TextStyle(fontSize: 9, color: text)),
      ],
    ),
  );

  // --- HELPERS MODERNOS ---
  static pw.Widget _modernSidebarTitle(String text) => pw.Text(text.toUpperCase(), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white, letterSpacing: 1.2));
  static pw.Widget _modernSkillBar(String name, int level, PdfColor color) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 6),
    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(name, style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.white)),
      pw.SizedBox(height: 3),
      pw.Stack(children: [
        pw.Container(height: 3, width: 120, color: PdfColors.grey800),
        pw.Container(height: 3, width: (level / 5) * 120, color: color),
      ]),
    ]),
  );
  static pw.Widget _modernSectionHeader(String title, PdfColor color) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: pw.BoxDecoration(color: color, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2))),
    child: pw.Text(title, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
  );
  static pw.Widget _modernExpItem(Experience e, PdfColor color) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 10),
    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(e.cargo, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10.5)),
        pw.Text(e.periodo, style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
      ]),
      pw.Text(e.empresa, style: pw.TextStyle(fontSize: 9, color: color, fontStyle: pw.FontStyle.italic)),
      ...e.logros.map((l) => pw.Padding(padding: const pw.EdgeInsets.only(left: 10, top: 2), child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text("- ", style: const pw.TextStyle(fontSize: 9)),
        pw.Expanded(child: pw.Text(l, style: const pw.TextStyle(fontSize: 9))),
      ]))),
    ]),
  );
  static pw.Widget _educationItem(Education f) => pw.Padding(padding: const pw.EdgeInsets.only(bottom: 10), child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(f.titulo, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10.5)),
      pw.Text(f.institucion, style: const pw.TextStyle(fontSize: 9.5)),
    ]),
    pw.Text(f.anio, style: const pw.TextStyle(fontSize: 9.5)),
  ]));
}
