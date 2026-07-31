import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../theme/app_theme.dart';
import '../models/resume.dart';
import '../services/db_service.dart';
import 'resume_preview_screen.dart';

class NuevoCvScreen extends StatefulWidget {
  final Resume? resumeExistente;
  const NuevoCvScreen({super.key, this.resumeExistente});

  @override
  State<NuevoCvScreen> createState() => _NuevoCvScreenState();
}

class _NuevoCvScreenState extends State<NuevoCvScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _perfilController = TextEditingController();

  String? _fotoPath;
  Uint8List? _fotoBytes;

  Color _colorSeleccionado = const Color(0xFF1A1A2E);
  int _designIndex = 0; // Valor por defecto: Diseño Clásico

  int get colorHex => _colorSeleccionado.value; // Getter para obtener el valor hexadecimal del color seleccionado

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
      _nombreController.text = r.nombre;
      _perfilController.text = r.perfil;
      _fotoPath = r.fotoPath;
      _colorSeleccionado = Color(r.colorHex);
      _designIndex = r.designIndex;
      _ocultarFoto = r.ocultarFoto;
      _ocultarPerfil = r.ocultarPerfil;
      _ocultarExperiencia = r.ocultarExperiencia;
      _ocultarFormacion = r.ocultarFormacion;
      _ocultarCompetencias = r.ocultarCompetencias;
      _ocultarIdiomas = r.ocultarIdiomas;

      if (r.fotoPath != null && r.fotoPath!.startsWith('data:')) {
        try {
          final base64Data = r.fotoPath!.split(',').last;
          _fotoBytes = base64Decode(base64Data);
        } catch (_) {}
      }
      _datosPersonales.clear();
      _datosPersonales.addAll(r.datosPersonales);
      if (_datosPersonales.isEmpty) {
        // Los datos personales iniciales se añaden en el constructor del widget o en initState
        // para mantener la consistencia con los valores por defecto
      }
      _competencias.clear();
      _competencias.addAll(r.competencias);
      _idiomas.clear();
      _idiomas.addAll(r.idiomas);
      _experiencia.clear();
      _experiencia.addAll(r.experiencia);
      _formacion.clear();
      _formacion.addAll(r.formacion);
    } else {
      _designIndex = 0; // Inicializar con valor por defecto
      _datosPersonales.add(PersonalData(label: 'Nombre', value: '', icon: 'person'));
      _datosPersonales.add(PersonalData(label: 'Email', value: '', icon: 'email'));
      _datosPersonales.add(PersonalData(label: 'Teléfono', value: '', icon: 'phone'));
      _datosPersonales.add(PersonalData(label: 'Dirección', value: '', icon: 'home'));
    }
  }

  Future<void> _seleccionarFoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _fotoBytes = bytes;
        _fotoPath = kIsWeb
            ? 'data:image/jpeg;base64,${base64Encode(bytes)}'
            : pickedFile.path;
      });
    }
  }

  Resume _buildResume() {
    final id = widget.resumeExistente?.id ?? const Uuid().v4();
    return Resume(
      id: id,
      nombre: _nombreController.text,
      perfil: _perfilController.text,
      fotoPath: _fotoPath,
      datosPersonales: _datosPersonales.where((d) => d.value.isNotEmpty).toList(),
      competencias: _competencias,
      idiomas: _idiomas,
      experiencia: _experiencia,
      formacion: _formacion,
      colorHex: _colorSeleccionado.value,
      designIndex: _designIndex,
      ocultarFoto: _ocultarFoto,
      ocultarPerfil: _ocultarPerfil,
      ocultarExperiencia: _ocultarExperiencia,
      ocultarFormacion: _ocultarFormacion,
      ocultarCompetencias: _ocultarCompetencias,
      ocultarIdiomas: _ocultarIdiomas,
    );
  }

  Future<void> _guardarCv() async {
    if (!_formKey.currentState!.validate()) return;
    final resume = _buildResume();
    await DBService.instance.insertarResume(resume);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.resumeExistente != null ? 'CV actualizado correctamente' : 'CV guardado en el historial')),
      );
      Navigator.pop(context, true);
    }
  }

  Future<void> _generarPreview() async {
    if (!_formKey.currentState!.validate()) return;
    final resume = _buildResume();
    await DBService.instance.insertarResume(resume);
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResumePreviewScreen(resume: resume),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.resumeExistente != null ? 'Editar CV' : 'Crear CV Profesional'),
        actions: [
          IconButton(icon: const Icon(Icons.save), tooltip: 'Guardar CV', onPressed: _guardarCv),
          IconButton(icon: const Icon(Icons.picture_as_pdf), tooltip: 'Ver PDF', onPressed: _generarPreview),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderSection(),
              const Divider(),
              
              _buildSectionTitle('Selecciona un Diseño'),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildDesignOption(0, 'Diseño Clásico', Icons.list_alt),
                  _buildDesignOption(1, 'Diseño Moderno', Icons.dashboard_customize),
                  _buildDesignOption(2, 'Diseño Ejecutivo', Icons.business_center),
                  _buildDesignOption(3, 'Diseño Creativo', Icons.palette),
                ],
              ),
              const SizedBox(height: 16),
              
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
                      onTap: () => setState(() => _colorSeleccionado = colorVal),
                      child: Container(
                        width: 40,
                        height: 40,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: colorVal,
                          shape: BoxShape.circle,
                          border: isSelected 
                            ? Border.all(color: Colors.black, width: 3)
                            : Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                        ),
                        child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 32),

              _buildSectionTitle('Configuración de Visibilidad'),
              _buildVisibilitySwitch('Ocultar Foto', _ocultarFoto, (v) => setState(() => _ocultarFoto = v)),
              _buildVisibilitySwitch('Ocultar Perfil', _ocultarPerfil, (v) => setState(() => _ocultarPerfil = v)),
              _buildVisibilitySwitch('Ocultar Experiencia', _ocultarExperiencia, (v) => setState(() => _ocultarExperiencia = v)),
              _buildVisibilitySwitch('Ocultar Formación', _ocultarFormacion, (v) => setState(() => _ocultarFormacion = v)),
              _buildVisibilitySwitch('Ocultar Competencias', _ocultarCompetencias, (v) => setState(() => _ocultarCompetencias = v)),
              _buildVisibilitySwitch('Ocultar Idiomas', _ocultarIdiomas, (v) => setState(() => _ocultarIdiomas = v)),
              const Divider(height: 32),

              _buildSectionTitle('Datos Personales'),
              ..._datosPersonales.asMap().entries.map((entry) {
                int index = entry.key;
                PersonalData data = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 160,
                        child: DropdownButtonFormField<String>(
                          value: data.icon,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Tipo', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12)),
                          items: _iconosDisponibles.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 14)))).toList(),
                          onChanged: (icon) {
                            if (icon != null) {
                              final label = _iconosDisponibles[icon]?.split(' ').skip(1).join(' ') ?? data.label;
                              setState(() => _datosPersonales[index] = PersonalData(label: label, value: data.value, icon: icon));
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: TextEditingController(text: data.value),
                          decoration: InputDecoration(labelText: data.label, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12)),
                          onChanged: (val) => _datosPersonales[index] = PersonalData(label: data.label, value: val, icon: data.icon),
                          // initialValue está en desuso, se debe usar controller
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red), onPressed: () => setState(() => _datosPersonales.removeAt(index)))
                    ],
                  ),
                );
              }),
              TextButton.icon(onPressed: _mostrarDialogoNuevoDatoPersonal, icon: const Icon(Icons.add), label: const Text('Añadir campo de contacto')),
              const Divider(),
              _buildDynamicListSection<Experience>(
                title: 'Experiencia Laboral',
                items: _experiencia,
                onAdd: () => _mostrarDialogoExperiencia(),
                itemBuilder: (exp, index) => ListTile(
                  title: Text(exp.cargo),
                  subtitle: Text('${exp.empresa} | ${exp.periodo}'),
                  onTap: () => _mostrarDialogoExperiencia(existing: exp, index: index),
                  trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => setState(() => _experiencia.removeAt(index))),
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
                  onTap: () => _mostrarDialogoFormacion(existing: edu, index: index),
                  trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => setState(() => _formacion.removeAt(index))),
                ),
              ),
              const Divider(),
              _buildSkillSection('Competencias', _competencias),
              const Divider(),
              _buildSkillSection('Idiomas', _idiomas),
              const SizedBox(height: 120), // Más espacio para los botones
            ],
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16, right: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FloatingActionButton(
              heroTag: 'btnGuardar',
              onPressed: _guardarCv,
              tooltip: 'Guardar CV',
              backgroundColor: AppTheme.secondaryGreen,
              child: const Icon(Icons.save, color: Colors.white),
            ),
            const SizedBox(width: 12),
            FloatingActionButton(
              heroTag: 'btnPreview',
              onPressed: _generarPreview,
              tooltip: 'Ver PDF',
              backgroundColor: AppTheme.accentGreen,
              child: const Icon(Icons.picture_as_pdf, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisibilitySwitch(String label, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(label, style: const TextStyle(fontSize: 14)),
      value: value,
      onChanged: onChanged,
      dense: true,
    );
  }

  Widget _buildDesignOption(int index, String title, IconData icon) {
    final isSelected = _designIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _designIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? _colorSeleccionado.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? _colorSeleccionado : Colors.grey.withValues(alpha: 0.3), width: 2),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? _colorSeleccionado : Colors.grey, size: 32),
              const SizedBox(height: 8),
              Text(title, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? _colorSeleccionado : Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      children: [
        Center(
          child: GestureDetector(
            onTap: _seleccionarFoto,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: _fotoBytes != null ? MemoryImage(_fotoBytes!) : null,
                  child: _fotoBytes == null ? const Icon(Icons.camera_alt, size: 40, color: Colors.grey) : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                    child: const Icon(Icons.edit, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _nombreController,
          decoration: const InputDecoration(labelText: 'Nombre Completo', border: OutlineInputBorder()),
          validator: (v) => v!.isEmpty ? 'Requerido' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _perfilController,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Perfil Profesional / Extracto', border: OutlineInputBorder()),
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
            IconButton(icon: const Icon(Icons.add_circle, color: Colors.blue), onPressed: onAdd),
          ],
        ),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No hay elementos añadidos', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
          )
        else
          ...items.asMap().entries.map((entry) => itemBuilder(entry.value, entry.key)),
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
            IconButton(icon: const Icon(Icons.add_circle, color: Colors.blue), onPressed: () => _mostrarDialogoSkill(title, list)),
          ],
        ),
        Wrap(
          spacing: 8,
          children: list.asMap().entries.map((entry) => Chip(
            label: Text(entry.value.nombre),
            onDeleted: () => setState(() => list.removeAt(entry.key)),
          )).toList(),
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
        content: TextField(controller: labelCtrl, decoration: const InputDecoration(labelText: 'Nombre del campo (Ej: LinkedIn)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(onPressed: () {
            if (labelCtrl.text.isNotEmpty) {
              setState(() => _datosPersonales.add(PersonalData(label: labelCtrl.text, value: '', icon: 'link')));
              Navigator.pop(context);
            }
          }, child: const Text('Añadir')),
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
        content: TextField(controller: ctrl, decoration: InputDecoration(labelText: title)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(onPressed: () {
            if (ctrl.text.isNotEmpty) {
              setState(() => list.add(Skill(nombre: ctrl.text, nivel: 3)));
              Navigator.pop(context);
            }
          }, child: const Text('Añadir')),
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
        title: Text(existing == null ? 'Añadir Experiencia' : 'Editar Experiencia'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: cargoCtrl, decoration: const InputDecoration(labelText: 'Cargo')),
              TextField(controller: empresaCtrl, decoration: const InputDecoration(labelText: 'Empresa')),
              TextField(controller: periodoCtrl, decoration: const InputDecoration(labelText: 'Periodo (Ej: 2020 - Actual)')),
              TextField(controller: logrosCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Logros / Descripción')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(onPressed: () {
            final exp = Experience(
              cargo: cargoCtrl.text, 
              empresa: empresaCtrl.text, 
              periodo: periodoCtrl.text, 
              logros: logrosCtrl.text.split('\n').where((l) => l.isNotEmpty).toList(),
            );
            setState(() {
              if (index != null) {
                _experiencia[index] = exp;
              } else {
                _experiencia.add(exp);
              }
            });
            Navigator.pop(context);
          }, child: const Text('Guardar')),
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
            TextField(controller: tituloCtrl, decoration: const InputDecoration(labelText: 'Título')),
            TextField(controller: instCtrl, decoration: const InputDecoration(labelText: 'Institución')),
            TextField(controller: anioCtrl, decoration: const InputDecoration(labelText: 'Año o Periodo')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(onPressed: () {
            final edu = Education(titulo: tituloCtrl.text, institucion: instCtrl.text, anio: anioCtrl.text);
            setState(() {
              if (index != null) {
                _formacion[index] = edu;
              } else {
                _formacion.add(edu);
              }
            });
            Navigator.pop(context);
          }, child: const Text('Guardar')),
        ],
      ),
    );
  }
}










