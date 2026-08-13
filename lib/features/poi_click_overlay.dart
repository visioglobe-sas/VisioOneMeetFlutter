import 'package:flutter/material.dart';

import '../visio_one/visio_one_message.dart';

/// Overlay de la feature `poi-click`, affichée dans le bottom sheet ouvert
/// par le FAB de [VisioOneMapShell] : contrairement aux autres features, il
/// n'y a rien à piloter ici (pas de champ, pas de bouton) — le seul rappel
/// utile est que la réaction se produit ailleurs, déclenchée par un tap sur
/// la carte plutôt que par ce panneau. Voir [handlePoiSelectedMessage] pour
/// le panneau réellement affiché au clic sur un POI.
class PoiClickOverlay extends StatelessWidget {
  const PoiClickOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.touch_app_outlined),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Tap any POI on the map: its details will pop up in a panel automatically.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

/// Réagit au message JS -> Native `poiSelected` (voir `assets/www/map.html`,
/// fonction `forwardViewEvents`, événement SDK `poiclick` sur `view`, et
/// `docs/COMMUNICATION_GUIDE.md` §3 pour la forme `{id, name}` du payload)
/// en affichant les infos du POI tapé dans un bottom sheet modal.
///
/// Même style que le sheet de contrôle ouvert par le FAB de
/// [VisioOneMapShell] (fond opaque = `colorScheme.surface`, poignée de
/// glissement, dismissable par swipe vers le bas ou tap sur le scrim) —
/// seule différence : c'est l'événement carte qui déclenche l'ouverture ici,
/// pas un tap sur le FAB (voir `docs/features/poi-click.md`, "Points
/// d'attention", pour pourquoi ce panneau ne réutilise pas directement
/// `_showFeatureControls`).
void handlePoiSelectedMessage(BuildContext context, VisioOneMessage message) {
  if (message.type != 'poiSelected') return;

  final data = message.data;
  final id = data is Map ? data['id'] as String? : null;
  final name = data is Map ? data['name'] as String? : null;
  if (id == null && name == null) return;

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name ?? id!,
            style: Theme.of(sheetContext).textTheme.titleLarge,
          ),
          if (id != null) ...[
            const SizedBox(height: 4),
            Text(
              'ID: $id',
              style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
