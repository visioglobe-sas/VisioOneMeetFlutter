import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../visio_one/visio_one_controller.dart';

/// Formulaire origine/destination partagé par les écrans d'itinéraire
/// (`compute-navigation`, `custom-navigation-trace`,
/// `navigation-exclude-modalities`, `accessible-mode`) : champs "From" /
/// "To", contrôles propres à l'écran ([options], ex. un interrupteur), puis
/// bouton "Itinerary" qui appelle [onSubmit] avec les deux ids saisis.
///
/// Les valeurs saisies vivent dans `controller.panel` (clés
/// `'<stateKey>.origin'` / `'<stateKey>.destination'`) : elles sont
/// conservées quand le panneau est fermé puis rouvert.
class NavigationForm extends StatelessWidget {
  const NavigationForm({
    super.key,
    required this.controller,
    required this.stateKey,
    required this.initialOriginId,
    required this.initialDestinationId,
    required this.onSubmit,
    this.options = const [],
  });

  final VisioOneController controller;

  /// Préfixe des clés de `controller.panel` (le slug de la feature).
  final String stateKey;
  final String initialOriginId;
  final String initialDestinationId;
  final void Function(String origin, String destination) onSubmit;

  /// Widgets affichés entre les champs et le bouton.
  final List<Widget> options;

  void _submit(TextEditingController origin, TextEditingController destination) {
    final originId = origin.text.trim();
    final destinationId = destination.text.trim();
    if (originId.isEmpty || destinationId.isEmpty) return;
    onSubmit(originId, destinationId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final origin = controller.panel.text('$stateKey.origin', initialOriginId);
    final destination = controller.panel.text('$stateKey.destination', initialDestinationId);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: origin,
          decoration: InputDecoration(labelText: l10n.navigationFromLabel, isDense: true),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: destination,
          decoration: InputDecoration(labelText: l10n.navigationToLabel, isDense: true),
        ),
        const SizedBox(height: 8),
        ...options,
        const SizedBox(height: 4),
        FilledButton(onPressed: () => _submit(origin, destination), child: Text(l10n.navigationItineraryButton)),
      ],
    );
  }
}
