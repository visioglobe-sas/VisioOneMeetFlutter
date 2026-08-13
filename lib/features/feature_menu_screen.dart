import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'feature.dart';
import 'feature_screen.dart';

/// Écran d'accueil : liste des features démontrées par l'app.
class FeatureMenuScreen extends StatelessWidget {
  const FeatureMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/icon/app_icon.png', width: 32, height: 32),
            const SizedBox(width: 12),
            const Text('VisioOne Meet by VisioGlobe'),
          ],
        ),
      ),
      body: ListView.separated(
        itemCount: Feature.values.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final feature = Feature.values[index];
          return ListTile(
            title: Text(feature.title(l10n)),
            subtitle: Text(feature.description(l10n)),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => FeatureScreen(feature: feature)),
            ),
          );
        },
      ),
    );
  }
}
