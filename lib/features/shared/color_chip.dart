import 'package:flutter/material.dart';

/// Convertit une couleur hex `#RRGGBB` (format envoyé au SDK) en [Color]
/// opaque pour l'affichage natif. Accepte aussi `RRGGBB` sans `#`.
Color parseHexColor(String hex) {
  final digits = hex.startsWith('#') ? hex.substring(1) : hex;
  return Color(0xFF000000 | int.parse(digits, radix: 16));
}

/// Puce de choix de couleur partagée par les panneaux qui proposent des
/// couleurs (`custom-text-label`, `custom-theme`, `accuracy-circle-style`,
/// `custom-navigation-trace`) : pastille [hex] cerclée (le blanc et le noir
/// restent visibles sur le fond du panneau) + libellé.
class ColorChoiceChip extends StatelessWidget {
  const ColorChoiceChip({
    super.key,
    required this.hex,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String hex;
  final String label;
  final bool selected;

  /// `null` désactive la puce.
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      avatar: SizedBox.square(
        dimension: 18,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: parseHexColor(hex),
            shape: BoxShape.circle,
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
        ),
      ),
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: onSelected == null ? null : (_) => onSelected!(),
    );
  }
}
