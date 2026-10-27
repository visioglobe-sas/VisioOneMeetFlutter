import 'dart:async';

import 'package:flutter/material.dart';

import '../../demo_map.dart';
import '../../l10n/app_localizations.dart';
import '../../visio_one/visio_one_controller.dart';
import '../goto-poi/goto_poi_bridge.dart';
import '../shared/bridge_error_text.dart';
import 'icon_marker_bridge.dart';

/// Icône 96x96 (PNG, disque bleu + étoile blanche) placée par la démo, en
/// data URL.
const String kIconMarkerDataUrl =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAGAAAABgCAYAAADimHc4AAACBklEQVR42u3dWW4CMRBFUVbLarOn5JsIqRlsv6FuSfmE0O+IwS7bfbtR1GXdf34/+qMOhg2KcehgGIU+HsMt+DEQ7sHXQqQFXwWRHn4sQkvwkRCt4dsjtAdvDTEtfCuEqeFbIAgv/H/NQzAKfx6CYfhzEIzD70cQf+FFAGxFAEAIEBJ+J4LB7+04gKUIAAgBTEackQBfI4SG34MAgBDAaMIrHuAjBACEAGZTvhUAbyEAIAQwbHrUALyEAAAAcwGMe68V4V8iHAjJHeAI7mqAb0oNcOK1vwYgCP+di1E/334EMcDVRSmewx5gd60COPk6K94Bzy7u1OP4CAqrNQCCQdJ4gAcE0Uh1dPgrASYirB0Ri+dsRoa/A6AdYt+ckNksZn3wpwDSIc7NiprP69cFrwJwBdH3BUo6YLlN+qI2ZGZ7EgAA+AgqD99/ueKA8K0Q0veAxSMk7v+tQnABULQrvQZhQgBVv9gCQb00cXVoUQgOa0MBEALsCitvFlSEMBpAvT9gd0g5TRgATAGMe8Ru/ydul+TJULIBNiGMBlDvlFcE4rkGSISgCsICwOG0FGUIuQDCdaM121ydTs1S/wrJDP8gQN3pu44nJzo1RXLC56h6Ts4FAAROUCd8ELiLBuGDwJ2UCB8E7qhH8BMR4orgQZgdfjJEbRE8ELODd8KgBBjUQRSKuqo/fm7G7BpJ/VcAAAAASUVORK5CYII=';

/// Id sous lequel l'objet `Image` du SDK est indexé côté JS (`assets/www/features/3d-icon-marker.js`).
/// Une seule icône à la fois pour cette démo.
const String _kImageId = '3d-icon-marker';

/// Overlay de la feature `3d-icon-marker` : champ "Anchor POI ID",
/// sélecteur d'orientation (Fixed / Flat / Facing camera) et actions
/// Place icon / Remove icon, affichés dans le bottom sheet ouvert par le FAB
/// de `VisioOneMapShell`. Chaque action est une commande Native -> JS
/// corrélée par `requestId` sur `controller.messages`, et la position de
/// l'icône est copiée depuis le POI ancre par le helper JS partagé
/// `poiDisplayPosition` (via `resolveAnchor`).
///
/// L'état (ancre courante, orientation) et le champ vivent dans
/// `controller.panel`, pour survivre à la fermeture du bottom sheet ; une
/// réponse arrivée panneau fermé met quand même cet état à jour. Voir
/// `docs/features/3d-icon-marker.md`.
class IconMarkerOverlay extends StatefulWidget {
  const IconMarkerOverlay({super.key, required this.controller});

  final VisioOneController controller;

  @override
  State<IconMarkerOverlay> createState() => _IconMarkerOverlayState();
}

class _IconMarkerOverlayState extends State<IconMarkerOverlay> {
  late final TextEditingController _anchorIdController =
      _c.panel.text('3d-icon-marker.anchorId', DemoMap.anchorPoiId);

  bool _busy = false;
  String? _errorMessage;

  VisioOneController get _c => widget.controller;

  /// Id du POI ancre de l'icône placée, ou `null` si aucune icône n'est placée.
  ValueNotifier<String?> get _placedOn => _c.panel.value<String?>('3d-icon-marker.placedOn', null);

  /// `OrientationType` du SDK choisi pour l'icône (`'fixed'`, `'flat'` ou
  /// `'facing'`).
  ValueNotifier<String> get _orientation => _c.panel.value<String>('3d-icon-marker.orientation', 'facing');

  /// Envoie une commande, attend sa réponse ([VisioOneController.request],
  /// 5 s max), applique [onResult] à l'état de l'écran même si le panneau a
  /// été fermé entre-temps, puis affiche l'éventuelle erreur si le panneau
  /// est toujours ouvert.
  Future<void> _perform(
    Future<Map<String, Object?>?> Function() send,
    void Function(Map<String, Object?> result) onResult,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final anchorId = _anchorIdController.text.trim();
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    final result = await send() ?? kBridgeTimeoutResult;
    onResult(result);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result['success'] != true && result['error'] != 'noImage') {
        _errorMessage = bridgeErrorText(l10n, result, anchorId: anchorId);
      }
    });
  }

  Future<void> _place() async {
    final anchorId = _anchorIdController.text.trim();
    if (anchorId.isEmpty) return;
    await _perform(() => _c.placeIconImage(imageId: _kImageId,
        anchorId: anchorId,
        url: kIconMarkerDataUrl,
        orientationType: _orientation.value,
      ),
      (result) {
        if (result['success'] == true) {
          _placedOn.value = anchorId;
          // Sans ça, l'icône reste invisible depuis la vue globale par défaut
          // (l'étage intérieur de l'ancre n'y est pas affiché) — même appel que
          // la démo `goto-poi`.
          unawaited(_c.goToPOI(anchorId));
        } else if (result['previousRemoved'] == true) {
          _placedOn.value = null;
        }
      },
    );
  }

  Future<void> _setOrientation(String orientation) async {
    final previous = _orientation.value;
    _orientation.value = orientation;
    if (_placedOn.value == null) return; // appliqué au prochain "Place icon".
    await _perform(() => _c.updateIconImageOrientation(_kImageId, orientation),
      (result) {
        if (result['success'] != true) _orientation.value = previous;
        if (result['error'] == 'noImage') _placedOn.value = null;
      },
    );
  }

  Future<void> _remove() async {
    if (_placedOn.value == null) return;
    await _perform(() => _c.removeIconImage(_kImageId), (result) {
      if (result['success'] == true || result['error'] == 'noImage') _placedOn.value = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: Listenable.merge([_placedOn, _orientation]),
      builder: (context, _) {
        final placedOn = _placedOn.value;
        final orientation = _orientation.value;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _anchorIdController,
              decoration: InputDecoration(
                labelText: l10n.anchorPoiIdLabel,
                helperText: l10n.iconMarkerAnchorHelper,
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Text(l10n.iconMarkerOrientationLabel, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'fixed', label: Text(l10n.iconMarkerOrientationFixed)),
                ButtonSegment(value: 'flat', label: Text(l10n.iconMarkerOrientationFlat)),
                ButtonSegment(value: 'facing', label: Text(l10n.iconMarkerOrientationFacing)),
              ],
              selected: {orientation},
              showSelectedIcon: false,
              onSelectionChanged: _busy ? null : (selection) => _setOrientation(selection.first),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(onPressed: _busy ? null : _place, child: Text(l10n.iconMarkerPlaceButton)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy || placedOn == null ? null : _remove,
                    child: Text(l10n.iconMarkerRemoveButton),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? (placedOn != null ? l10n.iconMarkerStatusPlaced(placedOn) : l10n.iconMarkerStatusNone),
              style: _errorMessage != null
                  ? TextStyle(color: Theme.of(context).colorScheme.error)
                  : Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        );
      },
    );
  }
}
