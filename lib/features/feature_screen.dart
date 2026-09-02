import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../visio_one/visio_one_map_shell.dart';
import 'custom_base_url_overlay.dart';
import 'feature.dart';

/// Écran plein écran d'une feature : une carte VisioOne fraîchement créée
/// (voir [VisioOneMapShell]) avec l'overlay propre à [feature] par-dessus.
class FeatureScreen extends StatefulWidget {
  const FeatureScreen({super.key, required this.feature});

  final Feature feature;

  @override
  State<FeatureScreen> createState() => _FeatureScreenState();
}

class _FeatureScreenState extends State<FeatureScreen> {
  // Seule `custom-base-url` s'en sert : `baseURL` est une option de
  // `loadVenue`, pas une propriété mutable sur une venue déjà chargée
  // (voir `docs/features/custom-base-url.md`), donc la recharger passe par
  // un remount complet de `VisioOneMapShell` -- cet état vit ici (pas dans
  // l'overlay, qui serait recréé à chaque ouverture du bottom sheet) pour
  // survivre à la fermeture du panneau et pour piloter la `Key` du shell.
  String? _customBaseUrl;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final feature = widget.feature;
    final isCustomBaseUrl = feature == Feature.customBaseUrl;
    final baseUrl = isCustomBaseUrl ? (_customBaseUrl ?? kDefaultMapServerBaseUrl) : null;

    return Scaffold(
      appBar: AppBar(title: Text(feature.title(l10n))),
      body: SafeArea(
        child: VisioOneMapShell(
          // Remonter toute la coquille (nouveau `VisioOneController`, nouvel
          // appel `setup`) quand `baseUrl` change : c'est le seul moyen de
          // recharger la venue avec une nouvelle `baseURL`, comme changer de
          // hash l'exigerait aussi.
          key: isCustomBaseUrl ? ValueKey(baseUrl) : null,
          // `custom-data` a besoin d'une carte avec de vraies `CustomData`
          // publiées -- la carte de démo partagée n'en a aucune (voir
          // `docs/features/custom-data.md`). Toutes les autres features
          // restent sur `kDefaultMapHash`, inchangé.
          hash: feature == Feature.customData ? kCustomDataMapHash : kDefaultMapHash,
          baseURL: baseUrl,
          showControlsOnError: isCustomBaseUrl,
          overlayBuilder: (context, controller) => isCustomBaseUrl
              ? CustomBaseUrlOverlay(
                  currentBaseUrl: baseUrl!,
                  onReload: (value) => setState(() => _customBaseUrl = value),
                )
              : feature.buildOverlay(context, controller),
          mapOverlayBuilder: (context, controller) => feature.buildMapOverlay(context, controller),
          onMessage: (context, message) => feature.onMapMessage(context, message),
        ),
      ),
    );
  }
}
