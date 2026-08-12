import 'package:flutter/material.dart';

import 'visio_one/visio_one_map_screen.dart';

/// Hash de démo (41 caractères) — même carte que celle utilisée par défaut
/// dans VisioOneMeetAndroid et VisioOneMeetIos, pour vérifier facilement
/// que l'intégration fonctionne avant de brancher sa propre carte.
///
/// Voir docs/INTEGRATION_GUIDE.md, partie D, pour obtenir le hash de VOTRE
/// carte depuis my.visioglobe.com.
const String kDefaultMapHash = 'kbae8e6c066cca4b02c2afac2bc963a643d87437a';

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
      home: Scaffold(
        body: SafeArea(child: VisioOneMapScreen(hash: kDefaultMapHash)),
      ),
    );
  }
}
