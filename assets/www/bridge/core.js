// Cœur du pont JS de `map.html` : chargement du SDK (venue + vue), canal
// unique JS -> Native `{type, data}`, helpers partagés et API
// d'enregistrement des features.
//
// Chaque feature vit dans son propre fichier `assets/www/features/<slug>.js`
// (même slug que `docs/features/<slug>.md`), chargé APRÈS ce fichier par une
// balise `<script src>` classique de `map.html` -- pas de modules ES : leurs
// imports échouent sous file:// dans WKWebView (iOS). Un fichier de feature :
//   - ajoute ses commandes Native -> JS à `window.MapBridge` via
//     `MapCore.register({ ... })` ;
//   - écoute les événements de la vue via `MapCore.onViewCreated(fn)` ;
//   - remet son propre état à zéro via `MapCore.onReset(fn)`, appelé au
//     début de chaque (re)chargement de carte (`MapBridge.setup`).
// Voir docs/ARCHITECTURE.md et docs/COMMUNICATION_GUIDE.md.
(function () {
  var visioOne = null;
  var venue = null;
  var view = null;
  // Derniers arguments de `setup()`, rejoués par `setCameraProjection`
  // (features/camera-projection-toggle.js).
  var lastSetup = null;
  var container = document.getElementById('container');

  var resetHooks = [];
  var viewCreatedHooks = [];
  var createdObjectProviders = [];

  // ---------------------------------------------------------------
  // JS -> Native : un seul canal, un contrat de messages {type, data}.
  // Voir docs/COMMUNICATION_GUIDE.md pour la liste des types de messages.
  // ---------------------------------------------------------------
  function sendToNative(type, data) {
    var bridge = window.VisioOneBridge;
    if (!bridge) {
      // Pas dans la WebView Flutter (ex. test dans un navigateur classique).
      console.log('[VisioOne:web]', type, data);
      return;
    }
    bridge.postMessage(JSON.stringify({ type: type, data: data }));
  }

  function errorMessage(error) {
    return error && error.message ? error.message : String(error);
  }

  function findPoi(poiId) {
    return venue ? venue.pois.find(function (p) { return p.id === poiId; }) : undefined;
  }

  // Position WGS84 d'affichage d'un POI. Un POI (`POI` dans les typings
  // du SDK) n'a pas de latitude/longitude propre : seuls ses éléments
  // visuels en ont. Ordre de priorité, le même pour toutes les démos :
  //   1. `poi.labels[0].position`
  //   2. `poi.images[0].position`, sinon `poi.markers[0].position`
  //   3. centre (moyenne des sommets) de `poi.surfaces[0].positions`
  // Renvoie `{ latitude, longitude, altitude? }`, ou `null` si le POI n'a
  // aucun de ces éléments. `ignored` (optionnel) : objets créés par les
  // démos elles-mêmes (label, image, marker) encore attachés au POI, à ne
  // jamais utiliser comme source.
  function poiDisplayPosition(poi, ignored) {
    var skip = ignored || [];
    function first(list) {
      return list.filter(function (item) { return skip.indexOf(item) === -1; })[0];
    }
    var source = first(poi.labels) || first(poi.images) || first(poi.markers);
    if (source) {
      var position = { latitude: source.position.latitude, longitude: source.position.longitude };
      if (source.position.altitude !== undefined) position.altitude = source.position.altitude;
      return position;
    }
    var surface = poi.surfaces[0];
    if (!surface || !surface.positions.length) return null;
    var latitude = 0;
    var longitude = 0;
    surface.positions.forEach(function (p) {
      latitude += p.latitude;
      longitude += p.longitude;
    });
    return { latitude: latitude / surface.positions.length, longitude: longitude / surface.positions.length };
  }

  // Objets créés sur la carte par les démos de cette page (déclarés par
  // chaque feature via `registerCreatedObjects`), à ne jamais prendre comme
  // source de position d'un POI ancre.
  function demoCreatedObjects() {
    var objects = [];
    createdObjectProviders.forEach(function (provider) {
      objects = objects.concat(provider());
    });
    return objects.filter(function (o) { return !!o; });
  }

  // Résout un POI "ancre" existant par son id et la position à copier
  // depuis lui (`poiDisplayPosition`). Partagé par `dynamic-poi-crud`,
  // `3d-icon-marker`, `custom-text-label` et `html-overlay-marker`.
  // Renvoie `{ poi, position }`, ou `{ error }` avec `error` =
  // 'notFound' (aucun POI de cet id) ou 'noPosition' (POI sans élément
  // visuel) — deux états normaux des démos, traduits côté natif.
  function resolveAnchor(anchorId) {
    var poi = findPoi(anchorId);
    if (!poi) return { error: 'notFound' };
    var position = poiDisplayPosition(poi, demoCreatedObjects());
    if (!position) return { poi: poi, error: 'noPosition' };
    return { poi: poi, position: position };
  }

  // Décale une position de ~4 m (+0.00004° en lat/lng) pour qu'un objet
  // posé à côté d'un POI ne recouvre pas son propre label.
  function offsetPosition(position) {
    var shifted = { latitude: position.latitude + 0.00004, longitude: position.longitude + 0.00004 };
    if (position.altitude !== undefined) shifted.altitude = position.altitude;
    return shifted;
  }

  // `UnauthorizedError` (jeton invalide, expiré ou absent) n'est pas
  // exporté par le bundle UMD (seuls `VisioOne`/`createVisioOne` le
  // sont), donc pas de `instanceof` possible : et comme c'est une simple
  // `class UnauthorizedError extends Error {}`, `error.name` vaut
  // `'Error'`. Son nom de constructeur l'identifie (non minifié dans le
  // bundle UMD 1.1.0), avec repli sur son message, propre à ce cas (réponse
  // 403 du serveur de cartes sur `descriptor.json`).
  function isUnauthorizedError(error) {
    if (!error) return false;
    if (error.constructor && error.constructor.name === 'UnauthorizedError') return true;
    return error.message === 'This venue needs an Authorization token to be loaded';
  }

  function runHooks(hooks, arg) {
    hooks.forEach(function (hook) {
      try {
        hook(arg);
      } catch (error) {
        console.error('[MapBridge] hook en échec : ' + errorMessage(error));
      }
    });
  }

  // ---------------------------------------------------------------
  // Native -> JS : window.MapBridge, une méthode par commande.
  //
  // Chaque appel est généré côté Dart via `jsonEncode(valeur)` interpolé
  // dans le script (ex. `window.MapBridge.goToPOI("B3-UL00-ID0076")`) :
  // c'est du texte JSON, mais il est *évalué comme code JS* par le moteur
  // qui exécute le script, pas relu comme texte par la fonction appelée.
  // Les paramètres reçoivent donc déjà de vraies valeurs JS (string,
  // boolean, objet...), jamais du texte JSON à re-parser — ne PAS appeler
  // `JSON.parse()` dessus (un hash de carte n'est pas du JSON valide : le
  // `SyntaxError` bloquerait `setup()` sans message).
  //
  // Seule `setup` est définie ici ; toutes les autres commandes sont
  // ajoutées par les fichiers `features/<slug>.js`.
  // ---------------------------------------------------------------
  window.onerror = function (message, source, lineno, colno, error) {
    console.error('[MapBridge] erreur non interceptée:', message, 'at', lineno + ':' + colno);
    sendToNative('error', { message: 'Erreur JS non interceptée: ' + message });
  };

  window.MapBridge = {
    // `baseURL` est optionnel (undefined si non fourni depuis Dart) :
    // le SDK retombe alors sur son défaut public,
    // https://mapserver.visioglobe.com/ (voir docs/features/custom-base-url.md).
    // C'est une option de `loadVenue`, pas une propriété mutable sur une
    // venue déjà chargée -- changer de baseURL passe donc entièrement
    // par ce chemin de rechargement, comme un changement de hash.
    //
    // `viewOptions` (optionnel, `null`/undefined par défaut) est passé
    // tel quel en 3e argument de `createView` — seule la démo
    // `custom-theme` le renseigne (`{ enableShadows: true }`, sans quoi
    // `view.setTheme` n'a aucun effet visible) ; toutes les autres
    // features gardent un `createView(container, venue)` inchangé. Voir
    // docs/features/custom-theme.md.
    //
    // Rechargement (2e appel et suivants) : la vue ET la venue courantes
    // sont détruites dans l'ordre, en attendant chaque promesse, avant de
    // recharger -- jamais `destroyView` puis `createView` sur la MÊME
    // venue, qui lève `Error: Cannot fetch model` (non intercepté) et
    // laisse la promesse de `createView` pendante à jamais (SDK 1.1.0,
    // voir docs/features/camera-projection-toggle.md). Tout ce qui est
    // accroché à la vue (listeners `onViewCreated`, objets créés par les
    // démos) est perdu : chaque feature remet son état à zéro dans son hook
    // `onReset`, et ses listeners sont réinstallés sur la nouvelle vue.
    //
    // `authorizationToken` (optionnel) : seul le code d'exemple
    // `auth-token` le renseigne (carte protégée, voir
    // docs/features/auth-token.md) ; rejeté avec `UnauthorizedError` si
    // invalide/expiré/absent -> `error` avec `unauthorized: true`.
    // Jamais journalisé en clair (c'est un secret de session).
    setup: function (hash, baseURL, viewOptions, authorizationToken) {
      try {
        console.log('[MapBridge] setup, hash =', hash, ', baseURL =', baseURL, ', viewOptions =', viewOptions, ', authorizationToken =', authorizationToken ? '(set)' : '(none)', ', typeof VisioOne =', typeof VisioOne);
        lastSetup = { hash: hash, baseURL: baseURL, viewOptions: viewOptions, authorizationToken: authorizationToken };

        var oldView = view;
        var oldVenue = venue;
        view = null;
        venue = null;
        core.currentNavigationTrace = null;
        runHooks(resetHooks);

        if (!visioOne) visioOne = VisioOne.createVisioOne();
        sendToNative('loading', { hash: hash });

        Promise.resolve()
          .then(function () { if (oldView) return visioOne.destroyView(oldView); })
          .then(function () { if (oldVenue) return visioOne.unloadVenue(oldVenue); })
          .then(function () {
            console.log('[MapBridge] appel loadVenue...');
            var loadOptions = { vg_maphash: hash };
            if (baseURL) loadOptions.baseURL = baseURL;
            // Envoyé par le SDK en en-tête `Authorization: Bearer <token>`
            // sur chaque requête de carte -- voir docs/features/auth-token.md.
            if (authorizationToken) loadOptions.authorizationToken = authorizationToken;
            return visioOne.loadVenue(loadOptions, container);
          })
          .then(function (v) {
            console.log('[MapBridge] loadVenue résolu, appel createView...');
            venue = v;
            return viewOptions
              ? visioOne.createView(container, venue, viewOptions)
              : visioOne.createView(container, venue);
          })
          .then(function (createdView) {
            view = createdView;
            console.log('[MapBridge] createView résolu, carte prête, cameraProjection =', view.cameraProjection);
            runHooks(viewCreatedHooks, view);
            // `view.cameraProjection` (lecture seule) : la projection avec
            // laquelle la vue a réellement été créée -- relayée pour que la
            // démo `camera-projection-toggle` affiche la valeur du SDK, pas
            // celle demandée.
            sendToNative('ready', { cameraProjection: view.cameraProjection });
          })
          .catch(function (error) {
            console.error('[MapBridge] échec loadVenue/createView:', error);
            visioOne.showError(error, container);
            sendToNative('error', {
              message: errorMessage(error),
              // `true` => jeton invalide, expiré ou absent (démo `auth-token`).
              unauthorized: isUnauthorizedError(error),
            });
          });
      } catch (error) {
        console.error('[MapBridge] erreur synchrone dans setup():', error);
        sendToNative('error', {
          message: errorMessage(error),
        });
      }
    },
  };

  // API utilisée par les fichiers `features/<slug>.js`.
  var core = {
    container: container,

    // Trace de navigation actuellement affichée, créée par
    // `compute-navigation` (`startItinerary`) ou
    // `navigation-exclude-modalities`, et restylée par
    // `custom-navigation-trace` (`venue.updateNavigationTrace()` prend
    // l'objet `NavigationTrace` lui-même, pas un id). Remise à `null` à
    // chaque rechargement de carte.
    currentNavigationTrace: null,

    sendToNative: sendToNative,
    errorMessage: errorMessage,
    findPoi: findPoi,
    poiDisplayPosition: poiDisplayPosition,
    resolveAnchor: resolveAnchor,
    offsetPosition: offsetPosition,

    // Ajoute des commandes à `window.MapBridge`. Un nom déjà pris est une
    // erreur de câblage (deux features qui se marchent dessus) : signalé en
    // console et ignoré.
    register: function (methods) {
      Object.keys(methods).forEach(function (name) {
        if (window.MapBridge[name]) {
          console.error('[MapBridge] commande déjà enregistrée : ' + name);
          return;
        }
        window.MapBridge[name] = methods[name];
      });
    },

    // `fn()` est appelée au début de chaque `setup` (premier chargement et
    // rechargements) : la feature y oublie les objets SDK qu'elle a créés
    // sur l'ancienne venue/vue.
    onReset: function (fn) {
      resetHooks.push(fn);
    },

    // `fn(view)` est appelée à chaque vue créée, juste avant le message
    // `ready` : la feature y installe ses listeners d'événements de vue.
    onViewCreated: function (fn) {
      viewCreatedHooks.push(fn);
    },

    // `fn()` renvoie la liste des objets SDK (labels, images, markers)
    // créés par la feature et attachés à un POI existant : `resolveAnchor`
    // ne les prend jamais comme source de position.
    registerCreatedObjects: function (fn) {
      createdObjectProviders.push(fn);
    },
  };

  // Venue/vue courantes (`null` tant que la carte n'est pas prête ou
  // pendant un rechargement) et derniers arguments de `setup`.
  Object.defineProperty(core, 'venue', { get: function () { return venue; } });
  Object.defineProperty(core, 'view', { get: function () { return view; } });
  Object.defineProperty(core, 'lastSetup', { get: function () { return lastSetup; } });

  window.MapCore = core;
})();
