import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../visio_one/visio_one_map_shell.dart';
import 'feature.dart';

/// Écran plein écran d'une feature : une carte VisioOne fraîchement créée
/// (voir [VisioOneMapShell]) avec le panneau de [feature] derrière le FAB,
/// ou l'écran propre à la feature ([FeatureSpec.screen]).
class FeatureScreen extends StatelessWidget {
  const FeatureScreen({super.key, required this.feature});

  final FeatureSpec feature;

  @override
  Widget build(BuildContext context) {
    final screen = feature.screen;
    if (screen != null) return screen(context, feature);
    return FeatureScaffold(
      feature: feature,
      child: VisioOneMapShell(
        hash: feature.mapHash,
        viewOptions: feature.viewOptions,
        createSession: feature.createSession,
        overlayBuilder: feature.panel!,
        mapOverlayBuilder: feature.mapOverlay,
        onMessage: feature.onMapMessage,
      ),
    );
  }
}

/// Barre de titre (avec bouton retour) + zone sûre autour de la carte,
/// commune à tous les écrans de feature.
class FeatureScaffold extends StatelessWidget {
  const FeatureScaffold({super.key, required this.feature, required this.child});

  final FeatureSpec feature;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(feature.title(AppLocalizations.of(context)!))),
      body: SafeArea(child: child),
    );
  }
}
