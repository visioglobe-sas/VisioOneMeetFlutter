# VisioOne Meet Flutter

App Flutter (Dart) qui affiche une carte [VisioOne](https://www.npmjs.com/package/@visioglobe/visioone) dans une `WebView`.

Ce projet fait partie d'une série d'exemples d'intégration du SDK VisioOne sur différentes plateformes (natif Android, natif iOS, React Native, Flutter).

## Comment ça marche

Le SDK VisioOne (`@visioglobe/visioone` sur npm) est un SDK **JS/WebGL** : il n'existe pas de binaire Dart natif. L'app embarque donc :

- le bundle **UMD** du SDK (`assets/www/visioone.umd.cjs`, vendored depuis npm — voir [`docs/INTEGRATION_GUIDE.md`](docs/INTEGRATION_GUIDE.md) partie F pour le mettre à jour),
- une page hôte (`assets/www/map.html`) qui charge ce bundle en `<script>` classique et expose un pont JS,
- affichés dans une `WebView` plein écran via le package [`webview_flutter`](https://pub.dev/packages/webview_flutter).

Le bundle **UMD** est utilisé volontairement, et pas le build ESM (`visioone.js`) : c'est la même leçon tirée d'autres intégrations natives du SDK VisioOne (voir [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)) — les `import()` dynamiques d'un module ES échouent sous `file://` (restrictions CORS de WebKit), alors qu'un `<script>` classique fonctionne aussi bien en `file://` (iOS) qu'en origine `https://` interne (Android via `loadFlutterAsset`).

La communication native ↔ SDK passe par un pont bidirectionnel :

| Direction | Mécanisme | Détails |
|---|---|---|
| Native → JS | `WebViewController.runJavaScript()` appelant `window.MapBridge.<methode>(...)` | [`lib/visio_one/visio_one_controller.dart`](lib/visio_one/visio_one_controller.dart) |
| JS → Native | `JavaScriptChannel` unique (`VisioOneBridge`), enveloppe `{type, data}` | [`lib/visio_one/visio_one_message.dart`](lib/visio_one/visio_one_message.dart) |

Voir [`docs/COMMUNICATION_GUIDE.md`](docs/COMMUNICATION_GUIDE.md) pour le détail complet du pont et [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) pour la vue d'ensemble.

## Structure

```
lib/
  main.dart                          Point d'entrée, hash de démo
  visio_one/
    visio_one_message.dart           Enveloppe JSON du canal JS -> Native
    visio_one_controller.dart        Pont typé Native <-> WebView/SDK
    visio_one_map_screen.dart        Écran (loading / carte / erreur)
assets/www/
  map.html                           Page hôte + window.MapBridge
  visioone.umd.cjs                   SDK VisioOne (vendored depuis npm)
docs/
  ARCHITECTURE.md                    Vue d'ensemble, comparaison avec les autres plateformes
  INTEGRATION_GUIDE.md                Guide pas à pas (intégrateur, sans prérequis Flutter)
  COMMUNICATION_GUIDE.md              Détail du pont Native <-> JS
```

## Build & run

```bash
flutter pub get
flutter run                 # appareil/émulateur connecté
flutter build apk --debug   # ou : build ios, build appbundle...
```

## Mettre à jour le bundle SDK (nouvelle version de `@visioglobe/visioone`)

```bash
npm pack @visioglobe/visioone
tar xzf visioglobe-visioone-*.tgz
cp package/dist/visioone.umd.cjs assets/www/visioone.umd.cjs
rm -rf package visioglobe-visioone-*.tgz
```

Aucun changement de code Dart n'est nécessaire pour une mise à jour mineure du SDK — uniquement si l'API du bundle (`window.MapBridge`, événements du `View`) change côté `assets/www/map.html`.

## Changer de carte

Modifiez `kDefaultMapHash` dans `lib/main.dart` (voir [`docs/INTEGRATION_GUIDE.md`](docs/INTEGRATION_GUIDE.md), partie E, pour obtenir le hash de votre carte).
