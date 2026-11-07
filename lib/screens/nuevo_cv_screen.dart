import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../core/errors/app_exception.dart';
import '../core/routing/app_router.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_tokens.dart';
import '../core/utils/list_edit.dart';
import '../core/utils/url_validators.dart';
import '../core/widgets/app_layout.dart';
import '../features/resumes/data/resume_photo_service.dart';
import '../features/resumes/forms/editor_dropdown_choices.dart';
import '../features/templates/cv_template_thumbnail.dart';
import '../features/templates/cv_templates.dart';
import '../models/resume.dart';
import '../saas/models/subscription_access.dart';
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

class _NuevoCvScreenState extends State<NuevoCvScreen>
    with WidgetsBindingObserver {
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
  bool _leavingEditor = false;

  int get colorHex => _colorSeleccionado.toARGB32();

  ImageProvider? get _avatarImage {
    if (_fotoBytes != null && _fotoBytes!.isNotEmpty) {
      return MemoryImage(_fotoBytes!);
    }
    final url = _fotoUrl;
    if (url != null && url.isNotEmpty) return NetworkImage(url);
    return null;
  }

  bool _ocultarFoto = false;
  bool _ocultarPerfil = false;
  bool _ocultarExperiencia = false;
  bool _ocultarFormacion = false;
  bool _ocultarCompetencias = false;
  bool _ocultarIdiomas = false;
  bool _ocultarProyectos = false;
  bool _ocultarCertificaciones = false;
  bool _ocultarAptitudes = false;

  final List<PersonalData> _datosPersonales = [];
  final List<Experience> _experiencia = [];
  final List<Education> _formacion = [];
  final List<Skill> _competencias = [];
  final List<Skill> _idiomas = [];
  final List<Project> _projects = [];
  final List<Certification> _certifications = [];
  final List<Aptitude> _aptitudes = [];

  /// Id estable tras el primer guardado (permite autosave en CVs nuevos).
  String? _persistedId;
  Timer? _autosaveTimer;
  bool _dirtyNotifyScheduled = false;
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

  bool _awaitingGallery = false;
  bool _recoveringLostPhoto = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
      _ocultarProyectos = r.ocultarProyectos;
      _ocultarCertificaciones = r.ocultarCertificaciones;
      _ocultarAptitudes = r.ocultarAptitudes;

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
      _projects
        ..clear()
        ..addAll(r.projects);
      _certifications
        ..clear()
        ..addAll(r.certifications);
      _aptitudes
        ..clear()
        ..addAll(r.aptitudes);
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
      _applyConfirmedFreeFallback();
      _recoverLostPhoto();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _awaitingGallery) {
      _recoverLostPhoto();
    }
  }

  /// Un CV nuevo con plantilla Pro vuelve a Clásico solo si Free está confirmado.
  void _applyConfirmedFreeFallback() {
    if (widget.resumeExistente != null) return;
    final access = context.read<AuthController>().subscriptionAccess;
    if (access != SubscriptionAccess.free) return;
    if (CvTemplates.canUseDesign(_designIndex, isPro: false)) return;
    if (_designIndex == CvTemplates.freeFallbackIndex) return;
    setState(() => _designIndex = CvTemplates.freeFallbackIndex);
  }

  void _onFormChanged() => _markDirty();

  void _markDirty() {
    if (!_autosaveEnabled || _uploadingPhoto) return;
    _autosaveTimer?.cancel();
    _autosaveStatus = _AutosaveStatus.dirty;
    _autosaveTimer = Timer(const Duration(seconds: 3), _runAutosave);
    // No hacer setState dentro del listener del TextEditingController:
    // en Flutter web reconstruye el campo a mitad del input y el texto nuevo
    // se inserta sobre el anterior.
    if (_dirtyNotifyScheduled) return;
    _dirtyNotifyScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dirtyNotifyScheduled = false;
      if (!mounted || _autosaveStatus != _AutosaveStatus.dirty) return;
      setState(() {});
    });
  }

  Future<void> _runAutosave() async {
    if (!_autosaveEnabled || !mounted || _uploadingPhoto) return;
    if (_nombreController.text.trim().isEmpty) return;
    setState(() {
      _autosaveStatus = _AutosaveStatus.saving;
      _autosaveError = null;
    });
    try {
      final photoWarning = await _persistResume(
        showSnack: false,
        popOnSuccess: false,
      );
      if (!mounted) return;
      setState(() {
        if (photoWarning != null) {
          _autosaveStatus = _AutosaveStatus.error;
          _autosaveError = 'CV guardado. Foto: $photoWarning';
        } else {
          _autosaveStatus = _AutosaveStatus.saved;
        }
      });
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
    WidgetsBinding.instance.removeObserver(this);
    _autosaveTimer?.cancel();
    _nombreController.removeListener(_onFormChanged);
    _perfilController.removeListener(_onFormChanged);
    _nombreController.dispose();
    _perfilController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingPhoto(Resume r) async {
    final hasStoredPhoto =
        (r.effectivePhotoRef != null && r.effectivePhotoRef!.isNotEmpty) ||
        (r.fotoStoragePath != null && r.fotoStoragePath!.isNotEmpty);
    if (!hasStoredPhoto) return;
    final bytes = await ResumePhotoService.instance.loadBytesForResume(r);
    if (!mounted || _pendingUploadBytes != null) return;
    if (bytes == null || bytes.isEmpty) {
      _showPhotoMessage(
        'No se pudo cargar la fotografía guardada. Puedes elegir otra.',
      );
      return;
    }
    setState(() => _applyPhotoDraft(_photoDraft.withLoadedBytes(bytes)));
  }

  bool _clearStoredPhoto = false;

  bool get _hasVisiblePhoto =>
      _fotoBytes != null || (_fotoUrl != null && _fotoUrl!.isNotEmpty);

  void _showPhotoMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _seleccionarFoto() async {
    if (_awaitingGallery) return;
    _awaitingGallery = true;
    try {
      final picker = ImagePicker();
      // El plugin de Android decodifica HEIC y fotos grandes a JPEG.
      // Sin estos límites, el archivo original puede fallar al leerse.
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
        requestFullMetadata: false,
      );
      if (!mounted) return;
      if (pickedFile == null) {
        await _recoverLostPhoto();
        return;
      }
      await _applyPickedFile(pickedFile);
    } catch (e, st) {
      debugPrint('seleccionarFoto: $e\n$st');
      _showPhotoMessage(ErrorMapper.messageOf(e));
    } finally {
      _awaitingGallery = false;
    }
  }

  /// Android puede destruir la actividad al abrir la galería. La foto queda
  /// en la caché del plugin y hay que recuperarla al volver.
  Future<void> _recoverLostPhoto() async {
    if (_recoveringLostPhoto) return;
    _recoveringLostPhoto = true;
    try {
      final lost = await ImagePicker().retrieveLostData();
      if (!mounted || lost.isEmpty) return;
      final error = lost.exception;
      if (error != null) {
        debugPrint('retrieveLostData: ${error.code} ${error.message}');
        _showPhotoMessage(ErrorMapper.messageOf(error));
        return;
      }
      final file = lost.file;
      if (file == null || lost.type == RetrieveType.video) return;
      _awaitingGallery = false;
      await _applyPickedFile(file);
    } on UnimplementedError {
      // Escritorio y web no conservan una selección interrumpida.
    } catch (e, st) {
      debugPrint('recoverLostPhoto: $e\n$st');
    } finally {
      _recoveringLostPhoto = false;
    }
  }

  Future<void> _applyPickedFile(XFile pickedFile) async {
    final raw = await pickedFile.readAsBytes();
    final processed = ResumePhotoService.instance.processGalleryPick(
      raw,
      squareCrop: _squareCrop,
    );
    if (!mounted || processed == null) return;
    setState(() => _applyPhotoDraft(_photoDraft.accept(processed)));
    _markDirty();
  }

  CvPhotoDraft get _photoDraft => CvPhotoDraft(
    bytes: _fotoBytes,
    pendingUploadBytes: _pendingUploadBytes,
    fotoUrl: _fotoUrl,
    fotoPath: _fotoPath,
    fotoStoragePath: _fotoStoragePath,
    ocultarFoto: _ocultarFoto,
    clearStoredPhoto: _clearStoredPhoto,
  );

  void _applyPhotoDraft(CvPhotoDraft draft) {
    _fotoBytes = draft.bytes;
    _pendingUploadBytes = draft.pendingUploadBytes;
    _fotoUrl = draft.fotoUrl;
    _fotoPath = draft.fotoPath;
    _fotoStoragePath = draft.fotoStoragePath;
    _ocultarFoto = draft.ocultarFoto;
    _clearStoredPhoto = draft.clearStoredPhoto;
  }

  void _quitarFoto() {
    setState(() => _applyPhotoDraft(_photoDraft.remove()));
    _markDirty();
  }

  Resume _buildResume() {
    final id = _persistedId ?? widget.resumeExistente?.id ?? const Uuid().v4();
    return Resume(
      id: id,
      nombre: _nombreController.text,
      perfil: _perfilController.text,
      fotoPath: _clearStoredPhoto ? '' : _fotoPath,
      fotoUrl: _clearStoredPhoto ? '' : _fotoUrl,
      fotoStoragePath: _clearStoredPhoto ? '' : _fotoStoragePath,
      datosPersonales: _datosPersonales
          .where((d) => d.value.isNotEmpty)
          .toList(),
      competencias: _competencias,
      idiomas: _idiomas,
      experiencia: _experiencia,
      formacion: _formacion,
      projects: List<Project>.from(_projects),
      certifications: List<Certification>.from(_certifications),
      aptitudes: List<Aptitude>.from(_aptitudes),
      colorHex: _colorSeleccionado.toARGB32(),
      designIndex: _designIndex,
      fotoBytes: _fotoBytes,
      ocultarFoto: _ocultarFoto,
      ocultarPerfil: _ocultarPerfil,
      ocultarExperiencia: _ocultarExperiencia,
      ocultarFormacion: _ocultarFormacion,
      ocultarCompetencias: _ocultarCompetencias,
      ocultarIdiomas: _ocultarIdiomas,
      ocultarProyectos: _ocultarProyectos,
      ocultarCertificaciones: _ocultarCertificaciones,
      ocultarAptitudes: _ocultarAptitudes,
      createdAt: widget.resumeExistente?.createdAt,
    );
  }

  /// Persiste el CV. Devuelve aviso de foto si Storage falló (el CV sí se guardó).
  Future<String?> _persistResume({
    required bool showSnack,
    required bool popOnSuccess,
  }) async {
    final resume = _buildResume();
    final outcome = await DBService.instance.saveWithOptionalPhoto(
      resume: resume,
      pendingPhotoBytes: _pendingUploadBytes,
      squareCrop: _squareCrop,
    );
    final saved = outcome.resume;
    // Solo limpia la foto pendiente si se subió; si falló, permite reintentar.
    if (outcome.photoWarning == null) {
      _pendingUploadBytes = null;
    }
    _persistedId = saved.id;
    _fotoUrl = saved.fotoUrl;
    _fotoStoragePath = saved.fotoStoragePath;
    _fotoPath = saved.fotoPath;
    _autosaveEnabled = true;
    if (!mounted) return outcome.photoWarning;
    if (showSnack) {
      final photoIssue = outcome.photoWarning;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            photoIssue != null
                ? 'CV guardado. Foto no subida: $photoIssue'
                : (_autosaveEnabled && widget.resumeExistente == null
                      ? 'CV guardado. Autosave activo.'
                      : 'CV guardado correctamente'),
          ),
          duration: Duration(seconds: photoIssue != null ? 6 : 3),
        ),
      );
    }
    if (popOnSuccess) context.pop(_buildResume());
    return outcome.photoWarning;
  }

  /// Al salir del editor devuelve el CV en memoria, con la plantilla elegida.
  ///
  /// La vista previa que abrió Editar conserva el objeto anterior. Si no se le
  /// entrega este Resume, sigue generando el PDF con el designIndex viejo.
  Future<void> _returnEditedResume() async {
    if (_leavingEditor) return;
    _leavingEditor = true;
    _autosaveTimer?.cancel();
    try {
      final editingExisting =
          widget.resumeExistente != null || _persistedId != null;
      if (editingExisting &&
          _nombreController.text.trim().isNotEmpty &&
          !_uploadingPhoto) {
        await _persistResume(showSnack: false, popOnSuccess: false);
      }
    } catch (e, st) {
      debugPrint('returnEditedResume: $e\n$st');
    }
    if (!mounted) return;
    context.pop(_buildResume());
  }

  Future<void> _guardarCv() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    _autosaveTimer?.cancel();
    setState(() => _uploadingPhoto = true);
    try {
      final photoWarning = await _persistResume(
        showSnack: true,
        popOnSuccess: false,
      );
      if (!mounted) return;
      setState(() {
        if (photoWarning != null) {
          _autosaveStatus = _AutosaveStatus.error;
          _autosaveError = 'CV guardado. Foto: $photoWarning';
        } else {
          _autosaveStatus = _AutosaveStatus.saved;
          _autosaveError = null;
        }
      });
    } catch (e, st) {
      debugPrint('guardarCv error: $e\n$st');
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
    final access = context.read<AuthController>().subscriptionAccess;
    if (access.isUnresolved) {
      if (CvTemplates.requiresPro(index) && index != _designIndex) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              access == SubscriptionAccess.error
                  ? 'No se pudo verificar tu plan. La plantilla guardada no cambia hasta confirmarlo.'
                  : 'Estamos verificando tu plan. La plantilla guardada no cambia hasta confirmarlo.',
            ),
          ),
        );
        return;
      }
      if (!CvTemplates.requiresPro(index)) {
        setState(() => _designIndex = index);
        _markDirty();
      }
      return;
    }
    final isPro = access == SubscriptionAccess.pro;
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

  @override
  Widget build(BuildContext context) {
    final desktop = AppLayout.of(context) == AppLayoutType.desktop;
    final access = context.watch<AuthController>().subscriptionAccess;
    if (widget.resumeExistente == null &&
        access == SubscriptionAccess.free &&
        !CvTemplates.canUseDesign(_designIndex, isPro: false)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _applyConfirmedFreeFallback();
      });
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _leavingEditor) return;
        _returnEditedResume();
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
            if (!_uploadingPhoto) {
              _guardarCv();
            }
          },
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
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
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width * 0.32,
                        ),
                        child: Text(
                          _autosaveLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                          style: TextStyle(
                            fontSize: 12,
                            color: _autosaveStatus == _AutosaveStatus.error
                                ? AppColors.danger
                                : AppColors.inkMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                Semantics(
                  label: 'Guardar CV',
                  button: true,
                  enabled: !_uploadingPhoto,
                  onTap: _uploadingPhoto
                      ? null
                      : () {
                          _guardarCv();
                        },
                  child: IconButton(
                    icon: const Icon(Icons.save),
                    tooltip: 'Guardar CV',
                    onPressed: _uploadingPhoto ? null : _guardarCv,
                  ),
                ),
                Semantics(
                  label: 'Ver PDF',
                  button: true,
                  enabled: !_uploadingPhoto,
                  onTap: _uploadingPhoto
                      ? null
                      : () {
                          _generarPreview();
                        },
                  child: IconButton(
                    icon: const Icon(Icons.picture_as_pdf),
                    tooltip: 'Ver PDF',
                    onPressed: _uploadingPhoto ? null : _generarPreview,
                  ),
                ),
              ],
            ),
            body: Form(
              key: _formKey,
              child: desktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 3, child: _buildFormScroll(access)),
                        const VerticalDivider(width: 1),
                        SizedBox(
                          width: 320,
                          child: _buildDesktopSummaryPanel(),
                        ),
                      ],
                    )
                  : _buildFormScroll(access),
            ),
            floatingActionButton: Padding(
              padding: const EdgeInsets.only(bottom: 16, right: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Semantics(
                    label: 'Guardar CV',
                    button: true,
                    enabled: !_uploadingPhoto,
                    onTap: _uploadingPhoto
                        ? null
                        : () {
                            _guardarCv();
                          },
                    child: FloatingActionButton(
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
                  ),
                  const SizedBox(width: 12),
                  FloatingActionButton(
                    heroTag: 'btnPreview',
                    onPressed: _uploadingPhoto ? null : _generarPreview,
                    tooltip: 'Ver PDF',
                    backgroundColor: AppTheme.accentGreen,
                    child: const Icon(
                      Icons.picture_as_pdf,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormScroll(SubscriptionAccess access) {
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
            if (access.isUnresolved)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  access == SubscriptionAccess.error
                      ? 'No se pudo verificar tu plan. Reintenta; la plantilla guardada se conserva.'
                      : 'Verificando tu plan. La plantilla guardada se conserva.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              )
            else if (access == SubscriptionAccess.free)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  'Free: Clásico y Moderno. Ejecutiva, Creativa y One Page requieren Pro.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final template in CvTemplates.all)
                  _buildDesignOption(
                    template.designIndex,
                    template.name,
                    access,
                  ),
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
            _buildVisibilitySwitch('Ocultar Proyectos', _ocultarProyectos, (v) {
              setState(() => _ocultarProyectos = v);
              _markDirty();
            }),
            _buildVisibilitySwitch(
              'Ocultar Certificaciones',
              _ocultarCertificaciones,
              (v) {
                setState(() => _ocultarCertificaciones = v);
                _markDirty();
              },
            ),
            _buildVisibilitySwitch('Ocultar Aptitudes', _ocultarAptitudes, (v) {
              setState(() => _ocultarAptitudes = v);
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
                      child: ContactIconDropdown(
                        key: ValueKey('contact-icon-$index-${data.icon}'),
                        icon: data.icon,
                        onChanged: (icon) {
                          final known = contactIconSelectionLabel(icon);
                          setState(
                            () => _datosPersonales[index] = PersonalData(
                              label: known ?? data.label,
                              value: data.value,
                              icon: icon,
                            ),
                          );
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
            const Divider(),
            _buildDynamicListSection<Project>(
              title: 'Proyectos',
              items: _projects,
              onAdd: () => _mostrarDialogoProyecto(),
              itemBuilder: (project, index) => _buildEditableEntry(
                title: project.name,
                subtitle: [
                  if (project.periodLabel.isNotEmpty) project.periodLabel,
                  if (project.technologies.isNotEmpty)
                    project.technologies.join(' · '),
                ].join(' | '),
                onTap: () =>
                    _mostrarDialogoProyecto(existing: project, index: index),
                actions: _buildReorderDeleteActions(
                  index: index,
                  length: _projects.length,
                  onMove: (from, to) => setState(() {
                    moveListItem(_projects, from, to);
                    _markDirty();
                  }),
                  onDelete: () => setState(() {
                    _projects.removeAt(index);
                    _markDirty();
                  }),
                ),
              ),
            ),
            const Divider(),
            _buildDynamicListSection<Certification>(
              title: 'Certificaciones y cursos',
              items: _certifications,
              onAdd: () => _mostrarDialogoCertificacion(),
              itemBuilder: (cert, index) => _buildEditableEntry(
                title: cert.name,
                subtitle: [
                  if (cert.institution.isNotEmpty) cert.institution,
                  if (cert.date != null && cert.date!.isNotEmpty) cert.date!,
                ].join(' · '),
                onTap: () =>
                    _mostrarDialogoCertificacion(existing: cert, index: index),
                actions: _buildReorderDeleteActions(
                  index: index,
                  length: _certifications.length,
                  onMove: (from, to) => setState(() {
                    moveListItem(_certifications, from, to);
                    _markDirty();
                  }),
                  onDelete: () => setState(() {
                    _certifications.removeAt(index);
                    _markDirty();
                  }),
                ),
              ),
            ),
            const Divider(),
            _buildDynamicListSection<Aptitude>(
              title: 'Aptitudes',
              items: _aptitudes,
              onAdd: () => _mostrarDialogoAptitud(),
              itemBuilder: (apt, index) => _buildEditableEntry(
                title: apt.name,
                subtitle: apt.description != null && apt.description!.isNotEmpty
                    ? apt.description!
                    : (apt.level != null ? 'Nivel ${apt.level}' : ''),
                onTap: () =>
                    _mostrarDialogoAptitud(existing: apt, index: index),
                actions: _buildReorderDeleteActions(
                  index: index,
                  length: _aptitudes.length,
                  onMove: (from, to) => setState(() {
                    moveListItem(_aptitudes, from, to);
                    _markDirty();
                  }),
                  onDelete: () => setState(() {
                    _aptitudes.removeAt(index);
                    _markDirty();
                  }),
                ),
              ),
            ),
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopSummaryPanel() {
    final design = CvTemplates.byIndex(_designIndex).name;
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
                  _summaryRow('Proyectos', '${_projects.length}'),
                  _summaryRow('Certificaciones', '${_certifications.length}'),
                  _summaryRow('Aptitudes', '${_aptitudes.length}'),
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
          Semantics(
            label: 'Guardar CV',
            button: true,
            enabled: !_uploadingPhoto,
            onTap: _uploadingPhoto
                ? null
                : () {
                    _guardarCv();
                  },
            child: OutlinedButton.icon(
              onPressed: _uploadingPhoto ? null : _guardarCv,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Guardar CV'),
            ),
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
    SubscriptionAccess access,
  ) {
    final isSelected = _designIndex == index;
    final locked =
        CvTemplates.requiresPro(index) && access == SubscriptionAccess.free;
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
                    3 => AppColors.amber,
                    _ => AppColors.emeraldBright,
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
        if (_hasVisiblePhoto)
          TextButton.icon(
            onPressed: _uploadingPhoto ? null : _quitarFoto,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Quitar foto'),
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
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Requerido' : null,
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
              tooltip: 'Añadir $title',
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
              tooltip: 'Añadir $title',
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

  Widget _buildReorderDeleteActions({
    required int index,
    required int length,
    required void Function(int from, int to) onMove,
    required VoidCallback onDelete,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _listActionButton(
          label: 'Subir',
          icon: Icons.arrow_upward,
          onPressed: index > 0 ? () => onMove(index, index - 1) : null,
        ),
        _listActionButton(
          label: 'Bajar',
          icon: Icons.arrow_downward,
          onPressed: index < length - 1 ? () => onMove(index, index + 1) : null,
        ),
        _listActionButton(
          label: 'Eliminar',
          icon: Icons.delete_outline,
          onPressed: onDelete,
        ),
      ],
    );
  }

  /// Título editable y acciones fuera del InkWell del ListTile.
  /// Si los botones van en `trailing`, el toque lo absorbe la fila y no
  /// llega a Subir, Bajar ni Eliminar.
  Widget _buildEditableEntry({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Widget actions,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(title),
            subtitle: subtitle.isEmpty
                ? null
                : Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
            onTap: onTap,
          ),
        ),
        actions,
      ],
    );
  }

  Widget _listActionButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: IconButton(
          tooltip: label,
          onPressed: onPressed,
          icon: Icon(icon, size: 20),
        ),
      ),
    );
  }

  void _mostrarDialogoProyecto({Project? existing, int? index}) {
    final nameCtrl = TextEditingController(text: existing?.name);
    final descCtrl = TextEditingController(text: existing?.description);
    final techCtrl = TextEditingController(
      text: existing?.technologies.join(', '),
    );
    final urlCtrl = TextEditingController(text: existing?.url);
    final repoCtrl = TextEditingController(text: existing?.repositoryUrl);
    final startCtrl = TextEditingController(text: existing?.startDate);
    final endCtrl = TextEditingController(text: existing?.endDate);
    var isOngoing = existing?.isOngoing ?? false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: Text(
                existing == null ? 'Añadir proyecto' : 'Editar proyecto',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Nombre *'),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    TextField(
                      controller: descCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Descripción',
                      ),
                    ),
                    TextField(
                      controller: techCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Tecnologías (separadas por coma)',
                      ),
                    ),
                    TextField(
                      controller: urlCtrl,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(labelText: 'URL'),
                    ),
                    TextField(
                      controller: repoCtrl,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'Repositorio',
                      ),
                    ),
                    TextField(
                      controller: startCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Fecha inicio (ej. 2024)',
                      ),
                    ),
                    TextField(
                      controller: endCtrl,
                      enabled: !isOngoing,
                      decoration: const InputDecoration(labelText: 'Fecha fin'),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Proyecto actual'),
                      value: isOngoing,
                      onChanged: (v) => setLocal(() => isOngoing = v),
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
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'El nombre del proyecto es obligatorio',
                          ),
                        ),
                      );
                      return;
                    }
                    if (!isOptionalHttpUrl(urlCtrl.text) ||
                        !isOptionalHttpUrl(repoCtrl.text)) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Las URLs deben ser http(s) válidas o vacías',
                          ),
                        ),
                      );
                      return;
                    }
                    final project = Project(
                      id: existing?.id ?? const Uuid().v4(),
                      name: name,
                      description: descCtrl.text.trim(),
                      technologies: techCtrl.text
                          .split(',')
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .toList(),
                      url: urlCtrl.text.trim().isEmpty
                          ? null
                          : urlCtrl.text.trim(),
                      repositoryUrl: repoCtrl.text.trim().isEmpty
                          ? null
                          : repoCtrl.text.trim(),
                      startDate: startCtrl.text.trim().isEmpty
                          ? null
                          : startCtrl.text.trim(),
                      endDate: isOngoing || endCtrl.text.trim().isEmpty
                          ? null
                          : endCtrl.text.trim(),
                      isOngoing: isOngoing,
                    );
                    setState(() {
                      if (index != null) {
                        _projects[index] = project;
                      } else {
                        _projects.add(project);
                      }
                    });
                    Navigator.pop(context);
                    _markDirty();
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _mostrarDialogoCertificacion({Certification? existing, int? index}) {
    final nameCtrl = TextEditingController(text: existing?.name);
    final instCtrl = TextEditingController(text: existing?.institution);
    final dateCtrl = TextEditingController(text: existing?.date);
    final expCtrl = TextEditingController(text: existing?.expirationDate);
    final credIdCtrl = TextEditingController(text: existing?.credentialId);
    final credUrlCtrl = TextEditingController(text: existing?.credentialUrl);
    final descCtrl = TextEditingController(text: existing?.description);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          existing == null
              ? 'Añadir certificación o curso'
              : 'Editar certificación o curso',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nombre *'),
              ),
              TextField(
                controller: instCtrl,
                decoration: const InputDecoration(labelText: 'Institución'),
              ),
              TextField(
                controller: dateCtrl,
                decoration: const InputDecoration(
                  labelText: 'Fecha (ej. 2025)',
                ),
              ),
              TextField(
                controller: expCtrl,
                decoration: const InputDecoration(
                  labelText: 'Fecha de expiración',
                ),
              ),
              TextField(
                controller: credIdCtrl,
                decoration: const InputDecoration(
                  labelText: 'ID de credencial',
                ),
              ),
              TextField(
                controller: credUrlCtrl,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'URL de credencial',
                ),
              ),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Descripción'),
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
              final name = nameCtrl.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('El nombre es obligatorio')),
                );
                return;
              }
              if (!isOptionalHttpUrl(credUrlCtrl.text)) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'La URL de credencial debe ser http(s) o vacía',
                    ),
                  ),
                );
                return;
              }
              final cert = Certification(
                id: existing?.id ?? const Uuid().v4(),
                name: name,
                institution: instCtrl.text.trim(),
                date: dateCtrl.text.trim().isEmpty
                    ? null
                    : dateCtrl.text.trim(),
                expirationDate: expCtrl.text.trim().isEmpty
                    ? null
                    : expCtrl.text.trim(),
                credentialId: credIdCtrl.text.trim().isEmpty
                    ? null
                    : credIdCtrl.text.trim(),
                credentialUrl: credUrlCtrl.text.trim().isEmpty
                    ? null
                    : credUrlCtrl.text.trim(),
                description: descCtrl.text.trim().isEmpty
                    ? null
                    : descCtrl.text.trim(),
              );
              setState(() {
                if (index != null) {
                  _certifications[index] = cert;
                } else {
                  _certifications.add(cert);
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

  void _mostrarDialogoAptitud({Aptitude? existing, int? index}) {
    final nameCtrl = TextEditingController(text: existing?.name);
    final descCtrl = TextEditingController(text: existing?.description);
    var level = existing?.level;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: Text(
                existing == null ? 'Añadir aptitud' : 'Editar aptitud',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre *',
                      hintText: 'Ej. Liderazgo, Comunicación',
                    ),
                  ),
                  const SizedBox(height: 8),
                  AptitudeLevelDropdown(
                    level: level,
                    onChanged: (v) => setLocal(() => level = v),
                  ),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Descripción (opcional)',
                    ),
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
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'El nombre de la aptitud es obligatorio',
                          ),
                        ),
                      );
                      return;
                    }
                    final apt = Aptitude(
                      id: existing?.id ?? const Uuid().v4(),
                      name: name,
                      level: level,
                      description: descCtrl.text.trim().isEmpty
                          ? null
                          : descCtrl.text.trim(),
                    );
                    setState(() {
                      if (index != null) {
                        _aptitudes[index] = apt;
                      } else {
                        _aptitudes.add(apt);
                      }
                    });
                    Navigator.pop(context);
                    _markDirty();
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
