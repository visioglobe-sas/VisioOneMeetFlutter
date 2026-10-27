import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../visio_one/visio_one_controller.dart';
import 'ui_part_visibility_bridge.dart';

/// Les 5 valeurs `UIPart` acceptées par `view.setUIPartVisible(uiPart, isVisible)`
/// (type `UIPart` des typings du SDK) — exactement ces 5 chaînes, sensibles
/// à la casse.
enum _UIPart {
  floorSelector('floorSelector'),
  navigation('navigation'),
  poiDetails('poiDetails'),
  search('search'),
  userTracking('userTracking');

  const _UIPart(this.value);

  /// Valeur exacte attendue par le SDK, à transmettre telle quelle au pont.
  final String value;

  String label(AppLocalizations l10n) => switch (this) {
    _UIPart.floorSelector => l10n.uiPartVisibilityFloorSelectorLabel,
    _UIPart.navigation => l10n.uiPartVisibilityNavigationLabel,
    _UIPart.poiDetails => l10n.uiPartVisibilityPoiDetailsLabel,
    _UIPart.search => l10n.uiPartVisibilitySearchLabel,
    _UIPart.userTracking => l10n.uiPartVisibilityUserTrackingLabel,
  };
}

/// Overlay de la feature `ui-part-visibility` : un interrupteur par partie
/// d'UI overlay fournie nativement par le SDK, affiché dans le bottom sheet
/// ouvert par le FAB de `VisioOneMapShell`. Chaque bascule appelle
/// immédiatement [UiPartVisibilityBridge.setUIPartVisible] pour un effet visible
/// tout de suite sur la carte derrière le panneau.
///
/// Les 5 interrupteurs démarrent à ON (visible), comme l'état par défaut du
/// SDK. Leur valeur vit dans `controller.panel` : rouvrir le panneau affiche
/// ce qui est réellement masqué sur la carte. Voir
/// `docs/features/ui-part-visibility.md`.
class UiPartVisibilityOverlay extends StatelessWidget {
  const UiPartVisibilityOverlay({super.key, required this.controller});

  final VisioOneController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: _UIPart.values.map((part) {
        final visible = controller.panel.value<bool>('ui-part-visibility.${part.value}', true);
        return ValueListenableBuilder<bool>(
          valueListenable: visible,
          builder: (context, value, _) => SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(part.label(l10n)),
            value: value,
            onChanged: (isVisible) {
              visible.value = isVisible;
              controller.setUIPartVisible(part.value, isVisible);
            },
          ),
        );
      }).toList(),
    );
  }
}
