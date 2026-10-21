import 'package:flutter/material.dart';

import 'features/feature.dart';
import 'features/feature_menu_screen.dart';
import 'features/feature_screen.dart';
import 'l10n/app_localizations.dart';

void main() {
  runApp(const VisioOneMeetApp());
}

class VisioOneMeetApp extends StatelessWidget {
  const VisioOneMeetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VisioOne Meet',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const bool.fromEnvironment('HARNESS') ? FeatureScreen(feature: Feature.values.firstWhere((f) => f.slug == const String.fromEnvironment('HFEATURE'))) : const FeatureMenuScreen(),
    );
  }
}
