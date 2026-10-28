import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Écran `auth-token` : simple page de texte, sans carte. Cette démo n'a
/// aucune carte protégée à charger -- la feature est un exemple de code
/// (`lib/features/auth_token_sample.dart`), volontairement jamais exécuté ici
/// (aucun appel `loadVenue` avec les valeurs fictives).
class AuthTokenScreen extends StatelessWidget {
  const AuthTokenScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.code),
              const SizedBox(width: 16),
              Expanded(
                child: SelectableText(
                  l10n.authTokenScreenText,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
