# Réinitialiser la vue

## Description

Recentre la caméra sur la vue globale du site, via `view.goToGlobal()` côté SDK VisioOne, exposé au pont `window.MapBridge` / `VisioOneController` sous le nom `goToGlobal`.

Point notable : la commande `goToGlobal` existait déjà de bout en bout dans ce dépôt *avant* cette branche — `window.MapBridge.goToGlobal` dans `assets/www/map.html` et `VisioOneController.goToGlobal()` dans `lib/visio_one/visio_one_controller.dart` étaient tous les deux déjà présents sur `main`. Vraisemblablement câblé par avance au moment de la construction du squelette de pont, sans attendre un besoin de démo précis. Le seul manquant était une affordance UI pour déclencher cette commande — voir `docs/COMMUNICATION_GUIDE.md` de ce dépôt pour le contrat de pont complet.

## Step by step

1. **Vérifier l'existant côté pont** (aucun code à écrire ici, seulement à confirmer) :
   ```js
   // assets/www/map.html, dans window.MapBridge
   goToGlobal: function () {
     if (view) view.goToGlobal();
   },
   ```
   ```dart
   // lib/visio_one/visio_one_controller.dart
   Future<void> goToGlobal() => _run('window.MapBridge.goToGlobal()');
   ```
   Les deux étaient déjà là — rien à ajouter côté pont.
2. **Ajouter le bouton natif** en tant qu'overlay de feature (`lib/features/reset_view_overlay.dart`, widget `ResetViewOverlay`), branché sur `VisioOneMapShell.overlayBuilder` (`lib/visio_one/visio_one_map_shell.dart`), qui ne l'affiche que lorsque la carte est prête :
   ```dart
   if (controller != null && _state == _MapLoadState.ready)
     Positioned(
       top: 0,
       right: 0,
       child: SafeArea(
         child: Padding(
           padding: const EdgeInsets.all(12),
           child: FilledButton(
             onPressed: controller.goToGlobal,
             child: const Text('Reset view'),
           ),
         ),
       ),
     ),
   ```
3. C'est tout : aucun changement côté `map.html` ou `VisioOneController`, seule la couche UI manquait.

## Points d'attention

- **Le tracking checklist du hub (`VisioOneHub/CHECKLIST.md`) avait cette feature marquée ❌ sur cette plateforme** — pas même 🟡 ("câblé mais non relié à l'UI") — alors que le pont natif↔JS était déjà entièrement fonctionnel. Rappel que l'exactitude d'un checklist dépend de la lecture réelle du code, pas seulement de l'absence d'un contrôle UI visible : un ❌ peut cacher un 🟡 non détecté si personne n'a rouvert le fichier.
- `view.goToGlobal()` ne fait rien de visible si `view` n'est pas encore initialisé (carte pas encore `ready`) — d'où la garde `if (view) ...` côté JS et le fait que `VisioOneMapShell` n'invoque `overlayBuilder` qu'une fois l'état `ready` atteint.
- Bouton placé en haut à droite, dans un `SafeArea`, pour ne pas chevaucher les encoches/barres système.

## Pour aller plus loin

- Voir `docs/COMMUNICATION_GUIDE.md` de ce dépôt pour le contrat de messages complet du pont (`window.MapBridge` / `VisioOneController`).
