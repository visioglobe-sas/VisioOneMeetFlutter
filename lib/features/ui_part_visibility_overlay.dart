import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../visio_one/visio_one_controller.dart';

/// Les 5 valeurs `UIPart` acceptées par `view.setUIPartVisible(uiPart, isVisible)`
/// côté SDK (voir `visioone/src/VisioOne/View/View.ts`, type `UIPart`) — ce
/// sont exactement ces 5 chaînes, sensibles à la casse, aucune autre n'existe.
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
/// ouvert par le FAB de [VisioOneMapShell]. Chaque bascule appelle
/// immédiatement [VisioOneController.setUIPartVisible] pour un effet visible
/// tout de suite sur la carte derrière le panneau.
///
/// `setUIPartVisible` existait déjà de bout en bout dans ce dépôt *avant*
/// cette branche — `window.MapBridge.setUIPartVisible` dans
/// `assets/www/map.html` et `VisioOneController.setUIPartVisible` dans
/// `lib/visio_one/visio_one_controller.dart` étaient tous les deux déjà
/// présents sur `main` (scaffold initial). Seule manquait l'UI : ce widget.
///
/// Les 5 interrupteurs démarrent à ON (visible), comme l'état par défaut du
/// SDK lui-même — rien n'est masqué tant que l'utilisateur n'a pas basculé
/// un interrupteur. Voir `docs/features/ui-part-visibility.md`.
class UiPartVisibilityOverlay extends StatefulWidget {
  const UiPartVisibilityOverlay({super.key, required this.controller});

  final VisioOneController controller;

  @override
  State<UiPartVisibilityOverlay> createState() => _UiPartVisibilityOverlayState();
}

class _UiPartVisibilityOverlayState extends State<UiPartVisibilityOverlay> {
  final Map<_UIPart, bool> _isVisible = {for (final part in _UIPart.values) part: true};

  void _toggle(_UIPart part, bool isVisible) {
    setState(() => _isVisible[part] = isVisible);
    widget.controller.setUIPartVisible(part.value, isVisible);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: _UIPart.values.map((part) {
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(part.label(l10n)),
          value: _isVisible[part]!,
          onChanged: (isVisible) => _toggle(part, isVisible),
        );
      }).toList(),
    );
  }
}
