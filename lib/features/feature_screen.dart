import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../visio_one/visio_one_map_shell.dart';
import 'feature.dart';

/// Écran plein écran d'une feature : une carte VisioOne fraîchement créée
/// (voir [VisioOneMapShell]) avec l'overlay propre à [feature] par-dessus.
class FeatureScreen extends StatelessWidget {
  const FeatureScreen({super.key, required this.feature});

  final Feature feature;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(feature.title(l10n))),
      body: SafeArea(
        child: VisioOneMapShell(
          hash: kDefaultMapHash,
          overlayBuilder: (context, controller) => feature.buildOverlay(context, controller),
          onMessage: (context, message) => feature.onMapMessage(context, message),
        ),
      ),
    );
  }
}
