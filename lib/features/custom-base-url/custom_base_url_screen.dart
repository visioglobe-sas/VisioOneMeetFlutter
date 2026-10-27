import 'package:flutter/material.dart';

import '../../visio_one/visio_one_map_shell.dart';
import '../feature.dart';
import '../feature_screen.dart';
import 'custom_base_url_overlay.dart';

/// Écran de `custom-base-url` : `baseURL` est une option de `loadVenue`, pas
/// une propriété mutable sur une venue déjà chargée (voir
/// `docs/features/custom-base-url.md`), donc la changer passe par un remount
/// complet de [VisioOneMapShell] (nouveau contrôleur, nouveau `setup`). La
/// valeur vit ici (pas dans le panneau, recréé à chaque ouverture du bottom
/// sheet) et pilote la `Key` du shell.
class CustomBaseUrlScreen extends StatefulWidget {
  const CustomBaseUrlScreen({super.key, required this.feature});

  final FeatureSpec feature;

  @override
  State<CustomBaseUrlScreen> createState() => _CustomBaseUrlScreenState();
}

class _CustomBaseUrlScreenState extends State<CustomBaseUrlScreen> {
  String _baseUrl = kDefaultMapServerBaseUrl;

  @override
  Widget build(BuildContext context) {
    return FeatureScaffold(
      feature: widget.feature,
      child: VisioOneMapShell(
        key: ValueKey(_baseUrl),
        hash: widget.feature.mapHash,
        baseURL: _baseUrl,
        // Une `baseURL` invalide fait échouer le chargement : le FAB doit
        // rester accessible pour en taper une autre.
        showControlsOnError: true,
        overlayBuilder: (context, controller) => CustomBaseUrlOverlay(
          currentBaseUrl: _baseUrl,
          onReload: (value) => setState(() => _baseUrl = value),
        ),
      ),
    );
  }
}
