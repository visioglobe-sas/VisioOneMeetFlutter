import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../visio_one/visio_one_controller.dart';
import 'floor_selector_overlay.dart';

/// Panneau persistant de la feature `native-ui-replacement`, affiché
/// directement sur la carte (pas dans le bottom sheet du FAB, contrairement
/// au reste des features) : c'est le point de la démo — un visiteur doit
/// *voir* tout de suite que l'app a son propre sélecteur d'étage natif à
/// l'écran, sans avoir à ouvrir un panneau pour le découvrir.
///
/// Réutilise tel quel [FloorSelectorOverlay] (feature `floor-selector`)
/// plutôt que de réimplémenter un sélecteur — seule la présentation change
/// (carte opaque flottante sur la carte 3D au lieu d'un contenu de bottom
/// sheet). C'est cette même instance qui reste montée tant que l'écran de
/// feature est ouvert (elle n'est pas recréée à chaque ouverture du FAB,
/// contrairement à l'overlay de bottom sheet des autres features) : son
/// [initState] est donc le bon endroit pour masquer le composant d'UI par
/// défaut du SDK (`floorSelector`, voir `ui-part-visibility`) dès que la
/// carte est prête, une seule fois, avant même que le visiteur n'ouvre le
/// FAB — c'est l'état par défaut demandé par cette démo (SDK masqué, natif
/// seul visible et fonctionnel).
class NativeUiReplacementMapPanel extends StatefulWidget {
  const NativeUiReplacementMapPanel({super.key, required this.controller});

  final VisioOneController controller;

  @override
  State<NativeUiReplacementMapPanel> createState() => _NativeUiReplacementMapPanelState();
}

class _NativeUiReplacementMapPanelState extends State<NativeUiReplacementMapPanel> {
  @override
  void initState() {
    super.initState();
    widget.controller.setUIPartVisible('floorSelector', false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            color: Theme.of(context).colorScheme.surface,
            elevation: 4,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220, maxHeight: 320),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.nativeUiReplacementPanelLabel,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      FloorSelectorOverlay(controller: widget.controller),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Overlay de la feature `native-ui-replacement` ouvert par le FAB : un seul
/// interrupteur pour révéler le composant d'UI par défaut du SDK
/// (`floorSelector`) à côté du panneau natif de [NativeUiReplacementMapPanel]
/// — pour comparer les deux en train de piloter le même état d'étage en
/// direct. Éteint par défaut (état déjà mis en place par
/// [NativeUiReplacementMapPanel] dès que la carte est prête, avant même la
/// première ouverture de ce panneau).
class NativeUiReplacementOverlay extends StatefulWidget {
  const NativeUiReplacementOverlay({super.key, required this.controller});

  final VisioOneController controller;

  @override
  State<NativeUiReplacementOverlay> createState() => _NativeUiReplacementOverlayState();
}

class _NativeUiReplacementOverlayState extends State<NativeUiReplacementOverlay> {
  bool _showSdkFloorSelector = false;

  void _toggle(bool value) {
    setState(() => _showSdkFloorSelector = value);
    widget.controller.setUIPartVisible('floorSelector', value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.nativeUiReplacementToggleLabel),
          value: _showSdkFloorSelector,
          onChanged: _toggle,
        ),
      ],
    );
  }
}
