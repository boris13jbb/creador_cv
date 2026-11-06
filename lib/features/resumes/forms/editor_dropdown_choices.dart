import 'package:flutter/material.dart';

/// Opción de un desplegable del editor. [value] es el identificador persistido.
class EditorDropdownChoice<T> {
  const EditorDropdownChoice({
    required this.value,
    required this.label,
    this.preserved = false,
  });

  final T value;
  final String label;

  /// El valor no está en el catálogo actual y se conserva tal como está guardado.
  final bool preserved;
}

/// Tipos de contacto que el editor ofrece al crear un campo nuevo.
const Map<String, String> contactIconCatalog = {
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

/// Deja una sola opción por valor. La primera aparición gana.
List<EditorDropdownChoice<T>> uniqueDropdownChoices<T>(
  Iterable<EditorDropdownChoice<T>> raw,
) {
  final seen = <T>{};
  final choices = <EditorDropdownChoice<T>>[];
  for (final choice in raw) {
    if (seen.add(choice.value)) choices.add(choice);
  }
  return choices;
}

/// Opciones del tipo de contacto.
///
/// Si [storedIcon] no está en el catálogo (p. ej. `info` o `place`), se añade
/// una sola opción extra con ese mismo valor. Así el desplegable no revienta
/// y el documento no se reescribe al abrirlo.
List<EditorDropdownChoice<String>> contactIconChoices(String storedIcon) {
  final catalogChoices = contactIconCatalog.entries.map(
    (entry) =>
        EditorDropdownChoice<String>(value: entry.key, label: entry.value),
  );
  final stored = storedIcon;
  final preserved = EditorDropdownChoice<String>(
    value: stored,
    label: stored.isEmpty ? 'Dato guardado' : 'Dato guardado: $stored',
    preserved: true,
  );
  return uniqueDropdownChoices([...catalogChoices, preserved]);
}

/// Etiqueta que el editor asigna al elegir un tipo conocido.
/// Si el tipo es antiguo, devuelve null para no sustituir la etiqueta guardada.
String? contactIconSelectionLabel(String icon) {
  final known = contactIconCatalog[icon];
  if (known == null) return null;
  final parts = known.split(' ');
  if (parts.length < 2) return known;
  return parts.skip(1).join(' ');
}

const List<int?> aptitudeLevelCatalog = [null, 1, 2, 3, 4, 5];

/// Niveles de aptitud. Un nivel fuera de 1–5 se conserva como opción única.
List<EditorDropdownChoice<int?>> aptitudeLevelChoices(int? storedLevel) {
  final standard = <EditorDropdownChoice<int?>>[
    const EditorDropdownChoice(value: null, label: 'Sin nivel'),
    for (var level = 1; level <= 5; level++)
      EditorDropdownChoice(value: level, label: '$level'),
  ];
  if (storedLevel != null && !aptitudeLevelCatalog.contains(storedLevel)) {
    standard.add(
      EditorDropdownChoice(
        value: storedLevel,
        label: 'Nivel guardado: $storedLevel',
        preserved: true,
      ),
    );
  }
  return uniqueDropdownChoices(standard);
}

/// Desplegable de tipo de contacto. El valor seleccionado siempre existe una vez.
class ContactIconDropdown extends StatelessWidget {
  const ContactIconDropdown({
    super.key,
    required this.icon,
    required this.onChanged,
  });

  final String icon;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final choices = contactIconChoices(icon);
    return DropdownButtonFormField<String>(
      key: ValueKey('contact-icon-$icon'),
      initialValue: icon,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Tipo',
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      ),
      items: [
        for (final choice in choices)
          DropdownMenuItem<String>(
            value: choice.value,
            child: Text(choice.label, style: const TextStyle(fontSize: 14)),
          ),
      ],
      onChanged: (icon) {
        if (icon != null) onChanged(icon);
      },
    );
  }
}

/// Desplegable de nivel de aptitud. Conserva niveles fuera del catálogo.
class AptitudeLevelDropdown extends StatelessWidget {
  const AptitudeLevelDropdown({
    super.key,
    required this.level,
    required this.onChanged,
  });

  final int? level;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final choices = aptitudeLevelChoices(level);
    return DropdownButtonFormField<int?>(
      key: ValueKey<int?>(level),
      initialValue: level,
      decoration: const InputDecoration(labelText: 'Nivel (opcional)'),
      items: [
        for (final choice in choices)
          DropdownMenuItem<int?>(
            value: choice.value,
            child: Text(choice.label),
          ),
      ],
      onChanged: onChanged,
    );
  }
}
