import 'package:flutter/material.dart';

import 'features/feature_menu_screen.dart';
import 'l10n/app_localizations.dart';

void main() {
  runApp(const VisioOneMeetApp());
}

class VisioOneMeetApp extends StatelessWidget {
  const VisioOneMeetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'VisioOne Meet',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: FeatureMenuScreen(),
    );
  }
}
