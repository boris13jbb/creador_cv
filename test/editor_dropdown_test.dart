import 'package:creador_cv/features/resumes/forms/editor_dropdown_choices.dart';
import 'package:creador_cv/models/resume.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('el catálogo no ofrece info y el valor guardado entra una sola vez', () {
    expect(contactIconCatalog.containsKey('info'), isFalse);
    final choices = contactIconChoices('info');
    expect(choices.where((choice) => choice.value == 'info'), hasLength(1));
    expect(
      choices.lastWhere((choice) => choice.value == 'info').preserved,
      isTrue,
    );
    expect(
      choices.map((choice) => choice.value).toSet(),
      hasLength(choices.length),
    );
  });

  test('un tipo válido no se duplica ni se marca como dato antiguo', () {
    final choices = contactIconChoices('email');
    expect(choices.where((choice) => choice.value == 'email'), hasLength(1));
    expect(
      choices.singleWhere((choice) => choice.value == 'email').preserved,
      isFalse,
    );
  });

  test('un tipo antiguo o desconocido se conserva sin sustituirlo', () {
    for (final icon in ['place', 'location', 'legacy-contact']) {
      final choices = contactIconChoices(icon);
      expect(choices.where((choice) => choice.value == icon), hasLength(1));
      expect(
        choices.singleWhere((choice) => choice.value == icon).preserved,
        isTrue,
      );
      expect(contactIconSelectionLabel(icon), isNull);
    }
    expect(contactIconSelectionLabel('phone'), 'Teléfono');
  });

  test('las opciones duplicadas se reducen a un valor', () {
    final choices = uniqueDropdownChoices(const [
      EditorDropdownChoice(value: 'info', label: 'A'),
      EditorDropdownChoice(value: 'info', label: 'B'),
      EditorDropdownChoice(value: 'email', label: 'Email'),
    ]);
    expect(choices.map((choice) => choice.value), ['info', 'email']);
  });

  test('un nivel de aptitud válido, nulo o antiguo tiene una sola opción', () {
    expect(
      aptitudeLevelChoices(3).where((choice) => choice.value == 3),
      hasLength(1),
    );
    expect(
      aptitudeLevelChoices(null).where((choice) => choice.value == null),
      hasLength(1),
    );
    final legacy = aptitudeLevelChoices(0);
    expect(legacy.where((choice) => choice.value == 0), hasLength(1));
    expect(legacy.singleWhere((choice) => choice.value == 0).preserved, isTrue);
    expect(
      aptitudeLevelChoices(9).map((choice) => choice.value).toSet(),
      hasLength(aptitudeLevelChoices(9).length),
    );
  });

  test('reabrir el documento conserva info y el resto del CV', () {
    final stored = _savedResume();
    final reopened = Resume.fromMap(stored.toFirestoreMap(userId: 'owner'));

    expect(reopened.nombre, stored.nombre);
    expect(reopened.perfil, stored.perfil);
    expect(reopened.datosPersonales[1].icon, 'info');
    expect(
      reopened.datosPersonales[1].value,
      'Aviso: Analista de canales',
    );
    expect(reopened.datosPersonales[4].icon, 'place');
    expect(reopened.experiencia, hasLength(3));
    expect(reopened.formacion, hasLength(2));
    expect(reopened.competencias, hasLength(3));
    expect(reopened.projects, hasLength(3));
    expect(reopened.certifications, hasLength(6));
    expect(reopened.aptitudes, hasLength(7));
    expect(reopened.idiomas.single.nombre, 'Español');
    expect(reopened.aptitudes.first.name, 'Responsabilidad y compromiso');
  });

  test('un icono ausente en documentos viejos sigue siendo info', () {
    final resume = Resume.fromMap({
      'id': 'old',
      'nombre': 'Ana',
      'perfil': '',
      'datosPersonales': [
        {'label': 'Ciudad', 'value': 'Quito'},
      ],
    });
    expect(resume.datosPersonales.single.icon, 'info');
    expect(resume.datosPersonales.single.value, 'Quito');
    expect(
      contactIconChoices(
        resume.datosPersonales.single.icon,
      ).where((choice) => choice.value == 'info'),
      hasLength(1),
    );
  });

  testWidgets('el menú sin la opción info falla con el value info', (
    tester,
  ) async {
    Object? captured;
    try {
      await tester.pumpWidget(
        _app(
          DropdownButtonFormField<String>(
            initialValue: 'info',
            items: [
              for (final entry in contactIconCatalog.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: (_) {},
          ),
        ),
      );
    } catch (error) {
      captured = error;
    }
    expect(captured, isA<AssertionError>());
    expect(captured.toString(), contains('info'));
  });

  testWidgets('abrir el CV guardado con info no lanza la assertion', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(_contactColumn(_savedResume().datosPersonales)),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Dato guardado: info'), findsOneWidget);
    expect(find.text('Dato guardado: place'), findsOneWidget);
    expect(find.text('💼 Trabajo'), findsWidgets);
  });

  testWidgets('varios iconos antiguos abren sin excepción', (tester) async {
    const legacy = ['info', 'place', 'location', 'information', 'personal'];
    await tester.pumpWidget(
      _app(
        Column(
          children: [
            for (final icon in legacy)
              ContactIconDropdown(icon: icon, onChanged: (_) {}),
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    for (final icon in legacy) {
      expect(find.text('Dato guardado: $icon'), findsOneWidget);
    }
  });

  testWidgets('las opciones llegan después y el valor info se conserva', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const _DelayedContactForm(icon: 'info')));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);

    await tester.pump(Duration.zero);
    expect(tester.takeException(), isNull);
    expect(find.text('Dato guardado: info'), findsOneWidget);
  });

  testWidgets('cambiar el tipo guarda la selección y no borra el texto', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    PersonalData? saved;
    await tester.pumpWidget(
      _app(
        Center(
          child: SizedBox(
            width: 280,
            child: _EditableContact(
              data: _savedResume().datosPersonales[1],
              onSaved: (data) => saved = data,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(ContactIconDropdown));
    await tester.pumpAndSettle();
    final phone = find.text('📞 Teléfono').last;
    await tester.ensureVisible(phone);
    await tester.tap(phone);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pump();

    expect(saved, isNotNull);
    expect(saved!.icon, 'phone');
    expect(saved!.label, 'Teléfono');
    expect(saved!.value, 'Aviso: Analista de canales');

    await tester.pumpWidget(
      _app(ContactIconDropdown(icon: saved!.icon, onChanged: (_) {})),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('📞 Teléfono'), findsWidgets);
    expect(find.text('Dato guardado: info'), findsNothing);
  });

  testWidgets('editar el tipo no elimina el resto del currículum', (
    tester,
  ) async {
    final resume = _savedResume();
    final updated = resume.copyWith(
      datosPersonales: [
        resume.datosPersonales.first,
        PersonalData(
          label: 'Teléfono',
          value: resume.datosPersonales[1].value,
          icon: 'phone',
        ),
        ...resume.datosPersonales.skip(2),
      ],
    );
    final reopened = Resume.fromMap(updated.toFirestoreMap(userId: 'owner'));

    expect(reopened.datosPersonales[1].icon, 'phone');
    expect(reopened.datosPersonales[1].value, contains('Analista'));
    expect(reopened.experiencia.map((item) => item.cargo), [
      'Cargo uno',
      'Cargo dos',
      'Cargo tres',
    ]);
    expect(reopened.projects.map((item) => item.name), [
      'Proyecto uno',
      'Proyecto dos',
      'Proyecto tres',
    ]);
    expect(reopened.certifications, hasLength(6));
    expect(reopened.aptitudes, hasLength(7));
    expect(reopened.perfil, contains('perfil de prueba'));

    await tester.pumpWidget(_app(_contactColumn(reopened.datosPersonales)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('un nivel de aptitud desconocido no rompe el desplegable', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(AptitudeLevelDropdown(level: 0, onChanged: (_) {})),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Nivel guardado: 0'), findsOneWidget);
  });
}

Widget _app(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    ),
  );
}

Widget _contactColumn(List<PersonalData> data) {
  return Column(
    children: [
      for (final item in data)
        ContactIconDropdown(icon: item.icon, onChanged: (_) {}),
    ],
  );
}

class _DelayedContactForm extends StatefulWidget {
  const _DelayedContactForm({required this.icon});

  final String icon;

  @override
  State<_DelayedContactForm> createState() => _DelayedContactFormState();
}

class _DelayedContactFormState extends State<_DelayedContactForm> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(Duration.zero, () {
      if (!mounted) return;
      setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const CircularProgressIndicator();
    }
    return ContactIconDropdown(icon: widget.icon, onChanged: (_) {});
  }
}

class _EditableContact extends StatefulWidget {
  const _EditableContact({required this.data, required this.onSaved});

  final PersonalData data;
  final ValueChanged<PersonalData> onSaved;

  @override
  State<_EditableContact> createState() => _EditableContactState();
}

class _EditableContactState extends State<_EditableContact> {
  late PersonalData _data = widget.data;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ContactIconDropdown(
          key: ValueKey(_data.icon),
          icon: _data.icon,
          onChanged: (icon) {
            setState(() {
              _data = PersonalData(
                label: contactIconSelectionLabel(icon) ?? _data.label,
                value: _data.value,
                icon: icon,
              );
            });
          },
        ),
        TextFormField(initialValue: _data.value, readOnly: true),
        TextButton(
          onPressed: () => widget.onSaved(_data),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

Resume _savedResume() {
  return Resume(
    id: 'cv-legacy-icons',
    nombre: 'Persona de prueba',
    perfil: 'Texto de perfil de prueba para un icono de contacto antiguo.',
    datosPersonales: const [
      PersonalData(
        label: 'Profesión',
        value: 'Profesión de prueba',
        icon: 'work',
      ),
      PersonalData(
        label: '',
        value: 'Aviso: Analista de canales',
        icon: 'info',
      ),
      PersonalData(label: 'Teléfono', value: '0990000000', icon: 'phone'),
      PersonalData(
        label: 'Correo electrónico',
        value: 'persona@example.com',
        icon: 'email',
      ),
      PersonalData(label: 'País', value: 'Ecuador', icon: 'place'),
    ],
    competencias: const [
      Skill(nombre: 'Ofimática y herramientas digitales: Excel', nivel: 2),
      Skill(nombre: 'Inteligencia artificial: prompts', nivel: 2),
      Skill(nombre: 'Tecnología: programación', nivel: 2),
    ],
    idiomas: const [Skill(nombre: 'Español', nivel: 5)],
    experiencia: const [
      Experience(
        cargo: 'Cargo uno',
        empresa: 'Empresa de prueba',
        periodo: '2021 - Actualidad',
        logros: ['Logro de prueba.'],
      ),
      Experience(
        cargo: 'Cargo dos',
        empresa: 'Empresa de prueba',
        periodo: '2012 - 2021',
        logros: ['Logro de prueba.'],
      ),
      Experience(
        cargo: 'Cargo tres',
        empresa: 'Empresa de prueba',
        periodo: '2011',
        logros: ['Logro de prueba.'],
      ),
    ],
    formacion: const [
      Education(
        titulo: 'Título de prueba',
        institucion: 'Instituto de prueba',
        anio: '2025',
      ),
      Education(
        titulo: 'Estudios de prueba',
        institucion: 'Centro de prueba',
        anio: '2006',
      ),
    ],
    projects: const [
      Project(id: 'p1', name: 'Proyecto uno', description: 'Descripción'),
      Project(id: 'p2', name: 'Proyecto dos', description: 'Descripción'),
      Project(id: 'p3', name: 'Proyecto tres', description: 'Descripción'),
    ],
    certifications: const [
      Certification(id: 'c1', name: 'Curso uno', institution: 'Centro'),
      Certification(id: 'c2', name: 'Curso dos', institution: 'Centro'),
      Certification(id: 'c3', name: 'Curso tres', institution: 'Centro'),
      Certification(id: 'c4', name: 'Curso cuatro', institution: 'Centro'),
      Certification(id: 'c5', name: 'Curso cinco', institution: 'Centro'),
      Certification(id: 'c6', name: 'Curso seis', institution: 'Centro'),
    ],
    aptitudes: const [
      Aptitude(id: 'a1', name: 'Responsabilidad y compromiso'),
      Aptitude(
        id: 'a2',
        name: 'Capacidad de análisis y resolución de problemas',
      ),
      Aptitude(id: 'a3', name: 'Organización y puntualidad'),
      Aptitude(id: 'a4', name: 'Trabajo en equipo'),
      Aptitude(id: 'a5', name: 'Adaptación a nuevas tecnologías'),
      Aptitude(id: 'a6', name: 'Aprendizaje continuo'),
      Aptitude(id: 'a7', name: 'Orientación a resultados'),
    ],
    designIndex: 0,
    ocultarFoto: true,
  );
}
