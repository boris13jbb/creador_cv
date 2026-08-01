import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../core/errors/app_exception.dart';
import '../core/routing/app_router.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_tokens.dart';
import '../core/widgets/app_layout.dart';
import '../features/resumes/data/resume_photo_service.dart';
import '../features/templates/cv_template_thumbnail.dart';
import '../features/templates/cv_templates.dart';
import '../models/resume.dart';
import '../saas/providers/auth_controller.dart';
import '../services/db_service.dart';

enum _AutosaveStatus { idle, dirty, saving, saved, error }

class NuevoCvScreen extends StatefulWidget {
  final Resume? resumeExistente;
  final int? initialDesignIndex;

  const NuevoCvScreen({
    super.key,
    this.resumeExistente,
    this.initialDesignIndex,
  });

  @override
  State<NuevoCvScreen> createState() => _NuevoCvScreenState();
}

class _NuevoCvScreenState extends State<NuevoCvScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _perfilController = TextEditingController();

  String? _fotoPath;
  String? _fotoUrl;
  String? _fotoStoragePath;
  Uint8List? _fotoBytes;
  Uint8List? _pendingUploadBytes;
  bool _uploadingPhoto = false;
  bool _squareCrop = true;

  Color _colorSeleccionado = const Color(0xFF1A1A2E);
  int _designIndex = 0;

  int get colorHex => _colorSeleccionado.toARGB32();

  ImageProvider? get _avatarImage {
    if (_fotoBytes != null) return MemoryImage(_fotoBytes!);
    if (_fotoUrl != null) return NetworkImage(_fotoUrl!);
    return null;
  }

  bool _ocultarFoto = false;
  bool _ocultarPerfil = false;
  bool _ocultarExperiencia = false;
  bool _ocultarFormacion = false;
  bool _ocultarCompetencias = false;
  bool _ocultarIdiomas = false;

  final List<PersonalData> _datosPersonales = [];
  final List<Experience> _experiencia = [];
  final List<Education> _formacion = [];
  final List<Skill> _competencias = [];
  final List<Skill> _idiomas = [];

  /// Id estable tras el primer guardado (permite autosave en CVs nuevos).
  String? _persistedId;
  Timer? _autosaveTimer;
  _AutosaveStatus _autosaveStatus = _AutosaveStatus.idle;
  String? _autosaveError;
  bool _autosaveEnabled = false;

  final List<Color> _coloresDisponibles = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.blueGrey,
    Colors.black,
  ];

  final Map<String, String> _iconosDisponibles = {
    'person': '👤 Perfil',
    'email': '📧 Email',
    'phone': '📞 Teléfono',
    'home': '🏠 Dirección',
    'work': '💼 Trabajo',
    'school': '🎓 Educación',
    'language': '🌐 Idioma',
    'link': '🔗 Enlace/Web',
    'facebook': 'f Facebook',
    'instagram': 'i Instagram',
    'linkedin': 'in LinkedIn',
    'github': 'gh GitHub',
  };

  @override
  void initState() {
    super.initState();
    final r = widget.resumeExistente;
    if (r != null) {
      _persistedId = r.id;
      _autosaveEnabled = true;
      _nombreController.text = r.nombre;
      _perfilController.text = r.perfil;
      _fotoPath = r.fotoPath;
      _fotoUrl = r.fotoUrl;
      _fotoStoragePath = r.fotoStoragePath;
      _colorSeleccionado = Color(r.colorHex);
      _designIndex = r.designIndex;
      _ocultarFoto = r.ocultarFoto;
      _ocultarPerfil = r.ocultarPerfil;
      _ocultarExperiencia = r.ocultarExperiencia;
      _ocultarFormacion = r.ocultarFormacion;
      _ocultarCompetencias = r.ocultarCompetencias;
      _ocultarIdiomas = r.ocultarIdiomas;

      _loadExistingPhoto(r);
      _datosPersonales.clear();
      _datosPersonales.addAll(r.datosPersonales);
      _competencias.clear();
      _competencias.addAll(r.competencias);
      _idiomas.clear();
      _idiomas.addAll(r.idiomas);
      _experiencia.clear();
      _experiencia.addAll(r.experiencia);
      _formacion.clear();
      _formacion.addAll(r.formacion);
    } else {
      final requested = widget.initialDesignIndex ?? 0;
      _designIndex = CvTemplates.byIndex(requested).designIndex;
      _datosPersonales.add(
        PersonalData(label: 'Nombre', value: '', icon: 'person'),
      );
      _datosPersonales.add(
        PersonalData(label: 'Email', value: '', icon: 'email'),
      );
      _datosPersonales.add(
        PersonalData(label: 'Teléfono', value: '', icon: 'phone'),
      );
      _datosPersonales.add(
        PersonalData(label: 'Dirección', value: '', icon: 'home'),
      );
    }
    _nombreController.addListener(_onFormChanged);
    _perfilController.addListener(_onFormChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final isPro = context.read<AuthController>().isPro;
      // Solo fuerza fallback en CVs nuevos abiertos con ?design=Pro.
      if (widget.resumeExistente == null &&
          !CvTemplates.canUseDesign(_designIndex, isPro: isPro)) {
        setState(() => _designIndex = CvTemplates.freeFallbackIndex);
      }
    });
  }

  void _onFormChanged() => _markDirty();

  void _markDirty() {
    if (!_autosaveEnabled || _uploadingPhoto) return;
    _autosaveTimer?.cancel();
    if (_autosaveStatus != _AutosaveStatus.dirty) {
      setState(() => _autosaveStatus = _AutosaveStatus.dirty);
    } else {
      _autosaveStatus = _AutosaveStatus.dirty;
    }
    _autosaveTimer = Timer(const Duration(seconds: 3), _runAutosave);
  }

  Future<void> _runAutosave() async {
    if (!_autosaveEnabled || !mounted || _uploadingPhoto) return;
    if (_nombreController.text.trim().isEmpty) return;
    setState(() {
      _autosaveStatus = _AutosaveStatus.saving;
      _autosaveError = null;
    });
    try {
      await _persistResume(showSnack: false, popOnSuccess: false);
      if (!mounted) return;
      setState(() => _autosaveStatus = _AutosaveStatus.saved);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _autosaveStatus = _AutosaveStatus.error;
        _autosaveError = ErrorMapper.messageOf(e);
      });
    }
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _nombreController.removeListener(_onFormChanged);
    _perfilController.removeListener(_onFormChanged);
    _nombreController.dispose();
    _perfilController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingPhoto(Resume r) async {
    final bytes = await ResumePhotoService.instance.loadBytes(
      r.effectivePhotoRef,
    );
    if (!mounted || bytes == null) return;
    setState(() => _fotoBytes = bytes);
  }

  Future<void> _seleccionarFoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;
    try {
      final raw = await pickedFile.readAsBytes();
      final processed = ResumePhotoService.instance.processBytes(
        raw,
        squareCrop: _squareCrop,
      );
      setState(() {
        _fotoBytes = processed.bytes;
        _pendingUploadBytes = processed.bytes;
        _fotoPath = null;
      });
      _markDirty();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ErrorMapper.messageOf(e))));
    }
  }

  Resume _buildResume() {
    final id = _persistedId ?? widget.resumeExistente?.id ?? const Uuid().v4();
    return Resume(
      id: id,
      nombre: _nombreController.text,
      perfil: _perfilController.text,
      fotoPath: _fotoPath,
      fotoUrl: _fotoUrl,
      fotoStoragePath: _fotoStoragePath,
      datosPersonales: _datosPersonales
          .where((d) => d.value.isNotEmpty)
          .toList(),
      competencias: _competencias,
      idiomas: _idiomas,
      experiencia: _experiencia,
      formacion: _formacion,
      colorHex: _colorSeleccionado.toARGB32(),
      designIndex: _designIndex,
      ocultarFoto: _ocultarFoto,
      ocultarPerfil: _ocultarPerfil,
      ocultarExperiencia: _ocultarExperiencia,
      ocultarFormacion: _ocultarFormacion,
      ocultarCompetencias: _ocultarCompetencias,
      ocultarIdiomas: _ocultarIdiomas,
      createdAt: widget.resumeExistente?.createdAt,
    );
  }

  Future<Resume> _persistResume({
    required bool showSnack,
    required bool popOnSuccess,
  }) async {
    final resume = _buildResume();
    final saved = await DBService.instance.saveWithOptionalPhoto(
      resume: resume,
      pendingPhotoBytes: _pendingUploadBytes,
      squareCrop: _squareCrop,
    );
    _pendingUploadBytes = null;
    _persistedId = saved.id;
    _fotoUrl = saved.fotoUrl;
    _fotoStoragePath = saved.fotoStoragePath;
    _fotoPath = saved.fotoPath;
    _autosaveEnabled = true;
    if (!mounted) return saved;
    if (showSnack) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _autosaveEnabled && widget.resumeExistente == null
                ? 'CV guardado. Autosave activo.'
                : 'CV guardado correctamente',
          ),
        ),
      );
    }
    if (popOnSuccess) context.pop(true);
    return saved;
  }

  Future<void> _guardarCv() async {
    if (!_formKey.currentState!.validate()) return;
    _autosaveTimer?.cancel();
    setState(() => _uploadingPhoto = true);
    try {
      await _persistResume(showSnack: true, popOnSuccess: false);
      if (!mounted) return;
      setState(() => _autosaveStatus = _AutosaveStatus.saved);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ErrorMapper.messageOf(e))));
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _generarPreview() async {
    if (!_formKey.currentState!.validate()) return;
    // Preview sin guardado automático.
    final resume = _buildResume();
    if (!mounted) return;
    await context.push('/resumes/preview', extra: resume);
  }

  String get _autosaveLabel {
    switch (_autosaveStatus) {
      case _AutosaveStatus.idle:
        return '';
      case _AutosaveStatus.dirty:
        return 'Cambios sin guardar';
      case _AutosaveStatus.saving:
        return 'Guardando…';
      case _AutosaveStatus.saved:
        return 'Guardado';
      case _AutosaveStatus.error:
        return _autosaveError ?? 'Error al guardar';
    }
  }

  Future<void> _selectDesign(int index) async {
    final isPro = context.read<AuthController>().isPro;
    if (!CvTemplates.canUseDesign(index, isPro: isPro)) {
      final goPro = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Plantilla Pro'),
          content: Text(
            '${CvTemplates.byIndex(index).name} requiere plan Pro.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ver planes'),
            ),
          ],
        ),
      );
      if (goPro == true && mounted) {
        await context.push(AppRoutes.pricing);
      }
      return;
    }
    setState(() => _designIndex = index);
    _markDirty();
  }

  static const _designLabels = ['Clásico', 'Moderno', 'Ejecutivo', 'Creativo'];

  @override
  Widget build(BuildContext context) {
    final desktop = AppLayout.of(context) == AppLayoutType.desktop;
    final isPro = context.watch<AuthController>().isPro;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.resumeExistente != null || _persistedId != null
              ? 'Editar CV'
              : 'Crear CV Profesional',
        ),
        actions: [
          if (_autosaveLabel.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Text(
                  _autosaveLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: _autosaveStatus == _AutosaveStatus.error
                        ? AppColors.danger
                        : AppColors.inkMuted,
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Guardar CV',
            onPressed: _uploadingPhoto ? null : _guardarCv,
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Ver PDF',
            onPressed: _uploadingPhoto ? null : _generarPreview,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: desktop
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 3, child: _buildFormScroll(isPro)),
                  const VerticalDivider(width: 1),
                  SizedBox(width: 320, child: _buildDesktopSummaryPanel()),
                ],
              )
            : _buildFormScroll(isPro),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16, right: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FloatingActionButton(
              heroTag: 'btnGuardar',
              onPressed: _uploadingPhoto ? null : _guardarCv,
              tooltip: 'Guardar CV',
              backgroundColor: AppTheme.secondaryGreen,
              child: _uploadingPhoto
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save, color: Colors.white),
            ),
            const SizedBox(width: 12),
            FloatingActionButton(
              heroTag: 'btnPreview',
              onPressed: _uploadingPhoto ? null : _generarPreview,
              tooltip: 'Ver PDF',
              backgroundColor: AppTheme.accentGreen,
              child: const Icon(Icons.picture_as_pdf, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormScroll(bool isPro) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: AppContentWidth(
        maxWidth: 900,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderSection(),
            const Divider(),
            _buildSectionTitle('Selecciona un Diseño'),
            if (!isPro)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  'Free: Clásico y Moderno. Ejecutiva/Creativa requieren Pro.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildDesignOption(0, 'Diseño Clásico', isPro),
                _buildDesignOption(1, 'Diseño Moderno', isPro),
                _buildDesignOption(2, 'Diseño Ejecutivo', isPro),
                _buildDesignOption(3, 'Diseño Creativo', isPro),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _buildSectionTitle('Color del Diseño'),
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _coloresDisponibles.length,
                itemBuilder: (context, index) {
                  final colorVal = _coloresDisponibles[index];
                  final isSelected = _colorSeleccionado == colorVal;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _colorSeleccionado = colorVal);
                      _markDirty();
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: colorVal,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: AppColors.ink, width: 3)
                            : Border.all(color: AppColors.border),
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 20,
                            )
                          : null,
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 32),
            _buildSectionTitle('Configuración de Visibilidad'),
            _buildVisibilitySwitch('Ocultar Foto', _ocultarFoto, (v) {
              setState(() => _ocultarFoto = v);
              _markDirty();
            }),
            _buildVisibilitySwitch('Ocultar Perfil', _ocultarPerfil, (v) {
              setState(() => _ocultarPerfil = v);
              _markDirty();
            }),
            _buildVisibilitySwitch('Ocultar Experiencia', _ocultarExperiencia, (
              v,
            ) {
              setState(() => _ocultarExperiencia = v);
              _markDirty();
            }),
            _buildVisibilitySwitch('Ocultar Formación', _ocultarFormacion, (v) {
              setState(() => _ocultarFormacion = v);
              _markDirty();
            }),
            _buildVisibilitySwitch(
              'Ocultar Competencias',
              _ocultarCompetencias,
              (v) {
                setState(() => _ocultarCompetencias = v);
                _markDirty();
              },
            ),
            _buildVisibilitySwitch('Ocultar Idiomas', _ocultarIdiomas, (v) {
              setState(() => _ocultarIdiomas = v);
              _markDirty();
            }),
            const Divider(height: 32),
            _buildSectionTitle('Datos Personales'),
            ..._datosPersonales.asMap().entries.map((entry) {
              final index = entry.key;
              final data = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 160,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('contact-icon-$index-${data.icon}'),
                        initialValue: data.icon,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Tipo',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 12,
                          ),
                        ),
                        items: _iconosDisponibles.entries
                            .map(
                              (e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(
                                  e.value,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (icon) {
                          if (icon != null) {
                            final label =
                                _iconosDisponibles[icon]
                                    ?.split(' ')
                                    .skip(1)
                                    .join(' ') ??
                                data.label;
                            setState(
                              () => _datosPersonales[index] = PersonalData(
                                label: label,
                                value: data.value,
                                icon: icon,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        initialValue: data.value,
                        decoration: InputDecoration(
                          labelText: data.label,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 12,
                          ),
                        ),
                        onChanged: (val) =>
                            _datosPersonales[index] = PersonalData(
                              label: data.label,
                              value: val,
                              icon: data.icon,
                            ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: AppColors.danger,
                      ),
                      onPressed: () =>
                          setState(() => _datosPersonales.removeAt(index)),
                    ),
                  ],
                ),
              );
            }),
            TextButton.icon(
              onPressed: _mostrarDialogoNuevoDatoPersonal,
              icon: const Icon(Icons.add),
              label: const Text('Añadir campo de contacto'),
            ),
            const Divider(),
            _buildDynamicListSection<Experience>(
              title: 'Experiencia Laboral',
              items: _experiencia,
              onAdd: () => _mostrarDialogoExperiencia(),
              itemBuilder: (exp, index) => ListTile(
                title: Text(exp.cargo),
                subtitle: Text('${exp.empresa} | ${exp.periodo}'),
                onTap: () =>
                    _mostrarDialogoExperiencia(existing: exp, index: index),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => setState(() => _experiencia.removeAt(index)),
                ),
              ),
            ),
            const Divider(),
            _buildDynamicListSection<Education>(
              title: 'Formación Académica',
              items: _formacion,
              onAdd: () => _mostrarDialogoFormacion(),
              itemBuilder: (edu, index) => ListTile(
                title: Text(edu.titulo),
                subtitle: Text('${edu.institucion} | ${edu.anio}'),
                onTap: () =>
                    _mostrarDialogoFormacion(existing: edu, index: index),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => setState(() => _formacion.removeAt(index)),
                ),
              ),
            ),
            const Divider(),
            _buildSkillSection('Competencias', _competencias),
            const Divider(),
            _buildSkillSection('Idiomas', _idiomas),
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopSummaryPanel() {
    final design = _designLabels[_designIndex.clamp(0, 3)];
    return ColoredBox(
      color: AppColors.surface,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text('Resumen', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: _colorSeleccionado,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.border),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Diseño $design',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _summaryRow('Contactos', '${_datosPersonales.length}'),
                  _summaryRow('Experiencia', '${_experiencia.length}'),
                  _summaryRow('Formación', '${_formacion.length}'),
                  _summaryRow('Competencias', '${_competencias.length}'),
                  _summaryRow('Idiomas', '${_idiomas.length}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: _uploadingPhoto ? null : _generarPreview,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Abrir vista previa'),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: _uploadingPhoto ? null : _guardarCv,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Guardar CV'),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Tras el primer guardado, los cambios se sincronizan solos (autosave).',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.inkMuted),
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildVisibilitySwitch(
    String label,
    bool value,
    Function(bool) onChanged,
  ) {
    return SwitchListTile(
      title: Text(label, style: const TextStyle(fontSize: 14)),
      value: value,
      onChanged: onChanged,
      dense: true,
    );
  }

  Widget _buildDesignOption(
    int index,
    String title,
    bool isPro,
  ) {
    final isSelected = _designIndex == index;
    final locked = CvTemplates.requiresPro(index) && !isPro;
    final width = MediaQuery.sizeOf(context).width;
    final tileWidth = width < 600
        ? (width - 48) / 2
        : (width < 1024 ? 160.0 : 180.0);

    return SizedBox(
      width: tileWidth.clamp(140, 200),
      child: Material(
        color: isSelected
            ? AppTheme.secondaryGreen.withValues(alpha: 0.08)
            : AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.md),
          onTap: () => _selectDesign(index),
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(
                color: isSelected
                    ? AppTheme.secondaryGreen
                    : (locked
                          ? AppColors.amber.withValues(alpha: 0.5)
                          : AppColors.border),
                width: 2,
              ),
            ),
            child: Column(
              children: [
                CvTemplateThumbnail(
                  designIndex: index,
                  locked: locked,
                  accent: switch (index) {
                    0 => AppColors.emerald,
                    1 => AppColors.navyMid,
                    2 => AppColors.navy,
                    _ => AppColors.amber,
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isSelected ? AppColors.ink : AppColors.inkMuted,
                  ),
                ),
                if (locked)
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Text(
                      'Pro',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.amber,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.navy,
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      children: [
        Center(
          child: GestureDetector(
            onTap: _uploadingPhoto ? null : _seleccionarFoto,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: _avatarImage,
                  child: _avatarImage == null
                      ? const Icon(
                          Icons.camera_alt,
                          size: 40,
                          color: Colors.grey,
                        )
                      : null,
                ),
                if (_uploadingPhoto)
                  const Positioned.fill(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.edit,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SwitchListTile(
          title: const Text('Recorte cuadrado al centro'),
          subtitle: const Text('Compresión automática al seleccionar'),
          value: _squareCrop,
          onChanged: (v) => setState(() => _squareCrop = v),
          dense: true,
        ),
        if (_fotoUrl != null)
          Text(
            'Foto sincronizada en la nube',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _nombreController,
          decoration: const InputDecoration(
            labelText: 'Nombre Completo',
            border: OutlineInputBorder(),
          ),
          validator: (v) => v!.isEmpty ? 'Requerido' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _perfilController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Perfil Profesional / Extracto',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildDynamicListSection<T>({
    required String title,
    required List<T> items,
    required VoidCallback onAdd,
    required Widget Function(T, int) itemBuilder,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle(title),
            IconButton(
              icon: const Icon(Icons.add_circle, color: AppColors.emerald),
              onPressed: onAdd,
            ),
          ],
        ),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No hay elementos añadidos',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: AppColors.inkMuted,
              ),
            ),
          )
        else
          ...items.asMap().entries.map(
            (entry) => itemBuilder(entry.value, entry.key),
          ),
      ],
    );
  }

  Widget _buildSkillSection(String title, List<Skill> list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle(title),
            IconButton(
              icon: const Icon(Icons.add_circle, color: AppColors.emerald),
              onPressed: () => _mostrarDialogoSkill(title, list),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          children: list
              .asMap()
              .entries
              .map(
                (entry) => Chip(
                  label: Text(entry.value.nombre),
                  onDeleted: () => setState(() => list.removeAt(entry.key)),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  void _mostrarDialogoNuevoDatoPersonal() {
    final labelCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuevo Campo de Contacto'),
        content: TextField(
          controller: labelCtrl,
          decoration: const InputDecoration(
            labelText: 'Nombre del campo (Ej: LinkedIn)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              if (labelCtrl.text.isNotEmpty) {
                setState(
                  () => _datosPersonales.add(
                    PersonalData(
                      label: labelCtrl.text,
                      value: '',
                      icon: 'link',
                    ),
                  ),
                );
                Navigator.pop(context);
                _markDirty();
              }
            },
            child: const Text('Añadir'),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoSkill(String title, List<Skill> list) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Añadir $title'),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(labelText: title),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              if (ctrl.text.isNotEmpty) {
                setState(() => list.add(Skill(nombre: ctrl.text, nivel: 3)));
                Navigator.pop(context);
                _markDirty();
              }
            },
            child: const Text('Añadir'),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoExperiencia({Experience? existing, int? index}) {
    final cargoCtrl = TextEditingController(text: existing?.cargo);
    final empresaCtrl = TextEditingController(text: existing?.empresa);
    final periodoCtrl = TextEditingController(text: existing?.periodo);
    final logrosCtrl = TextEditingController(text: existing?.logros.join('\n'));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          existing == null ? 'Añadir Experiencia' : 'Editar Experiencia',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: cargoCtrl,
                decoration: const InputDecoration(labelText: 'Cargo'),
              ),
              TextField(
                controller: empresaCtrl,
                decoration: const InputDecoration(labelText: 'Empresa'),
              ),
              TextField(
                controller: periodoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Periodo (Ej: 2020 - Actual)',
                ),
              ),
              TextField(
                controller: logrosCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Logros / Descripción',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final exp = Experience(
                cargo: cargoCtrl.text,
                empresa: empresaCtrl.text,
                periodo: periodoCtrl.text,
                logros: logrosCtrl.text
                    .split('\n')
                    .where((l) => l.isNotEmpty)
                    .toList(),
              );
              setState(() {
                if (index != null) {
                  _experiencia[index] = exp;
                } else {
                  _experiencia.add(exp);
                }
              });
              Navigator.pop(context);
              _markDirty();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoFormacion({Education? existing, int? index}) {
    final tituloCtrl = TextEditingController(text: existing?.titulo);
    final instCtrl = TextEditingController(text: existing?.institucion);
    final anioCtrl = TextEditingController(text: existing?.anio);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Añadir Formación' : 'Editar Formación'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: tituloCtrl,
              decoration: const InputDecoration(labelText: 'Título'),
            ),
            TextField(
              controller: instCtrl,
              decoration: const InputDecoration(labelText: 'Institución'),
            ),
            TextField(
              controller: anioCtrl,
              decoration: const InputDecoration(labelText: 'Año o Periodo'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final edu = Education(
                titulo: tituloCtrl.text,
                institucion: instCtrl.text,
                anio: anioCtrl.text,
              );
              setState(() {
                if (index != null) {
                  _formacion[index] = edu;
                } else {
                  _formacion.add(edu);
                }
              });
              Navigator.pop(context);
              _markDirty();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
