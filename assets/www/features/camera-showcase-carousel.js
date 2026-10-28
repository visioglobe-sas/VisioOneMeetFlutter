// camera-showcase-carousel : visite caméra en boucle sur une liste de POI
// fournie par le natif (`view.goToFloor` puis `view.goToPOI` pour chaque
// arrêt, pause de 3 s), mise en pause par un toucher sur la carte et reprise
// après 10 s sans interaction. L'état est renvoyé au natif par des messages
// `carouselState` ({ state, index, total, poiId }). Voir
// docs/features/camera-showcase-carousel.md.
(function (core) {
  // La boucle vit ici, au niveau de la page (pas dans le panneau natif, qui
  // se ferme pour laisser voir la carte), et il n'y en a jamais qu'une :
  // chaque démarrage/pause/arrêt incrémente `runId`, et une boucle dont le
  // `runId` n'est plus le courant s'arrête d'elle-même au prochain `await`.
  // `state` : 'stopped' | 'running' | 'paused'.
  var CAROUSEL_RESUME_DELAY_MS = 10000;
  var CAROUSEL_DWELL_MS = 3000;
  var carousel = {
    stops: [],
    state: 'stopped',
    runId: 0,
    nextIndex: 0,
    currentIndex: -1,
    // Animation caméra SDK en cours lancée par la visite (AnimationPromise),
    // `null` pendant la pause de 3 s entre deux arrêts.
    animation: null,
    dwellTimer: null,
    resumeTimer: null,
  };

  function carouselReport() {
    var i = carousel.currentIndex;
    core.sendToNative('carouselState', {
      state: carousel.state,
      index: i >= 0 ? i + 1 : null,
      total: carousel.stops.length,
      poiId: i >= 0 ? carousel.stops[i] : null,
    });
  }

  function carouselClearTimers() {
    if (carousel.dwellTimer) clearTimeout(carousel.dwellTimer.id);
    if (carousel.dwellTimer) carousel.dwellTimer.resolve();
    carousel.dwellTimer = null;
    if (carousel.resumeTimer) clearTimeout(carousel.resumeTimer);
    carousel.resumeTimer = null;
  }

  function carouselDwell(ms) {
    return new Promise(function (resolve) {
      carousel.dwellTimer = { id: setTimeout(resolve, ms), resolve: resolve };
    });
  }

  // Interrompt l'animation caméra SDK en cours SANS saut. Mesuré sur
  // simulateur iOS (WKWebView, SDK 1.1.0) : `cancel()` fige la caméra là où
  // elle est (cap, inclinaison et cible inchangés, pas de saut vers la
  // destination, quel que soit le moment de l'appel) ; l'alternative d'une
  // animation `goToViewpoint` de durée nulle vers `view.camera.target`
  // interrompt bien l'animation (isCanceled === true) mais décale la vue
  // (~20 m à 160 m d'altitude).
  function carouselInterruptInPlace() {
    var animation = carousel.animation;
    carousel.animation = null;
    if (animation) animation.cancel();
  }

  async function carouselLoop(runId) {
    function alive(animation) {
      return runId === carousel.runId && core.view && !(animation && animation.isCanceled);
    }
    while (alive()) {
      var view = core.view;
      var count = carousel.stops.length;
      var index = carousel.nextIndex % count;
      var poiId = carousel.stops[index];
      var poi = core.findPoi(poiId);
      carousel.currentIndex = index;
      carousel.nextIndex = (index + 1) % count;
      if (!poi) {
        console.warn('[Carousel] POI introuvable, ignoré :', poiId);
        await carouselDwell(0);
        continue;
      }
      carouselReport();
      console.log('[Carousel] hop ' + (index + 1) + '/' + count + ' ' + poiId + ' (floor ' + poi.floor.id + ')');
      // Ordre documenté par le SDK : `goToFloor` avant `goToPOI` quand le
      // POI est sur un autre étage.
      var toFloor = (carousel.animation = view.goToFloor(poi.floor, { duration: 800 }));
      await toFloor;
      if (!alive(toFloor)) return;
      var toPoi = (carousel.animation = view.goToPOI(poi, {
        duration: 2500,
        easing: 'easeInOutQuad',
        orientation: { heading: index * 90, pitch: 30 },
      }));
      await toPoi;
      if (!alive(toPoi)) return;
      carousel.animation = null;
      console.log('[Carousel] arrived ' + poiId);
      await carouselDwell(CAROUSEL_DWELL_MS);
    }
  }

  function carouselRun() {
    carousel.runId++;
    carousel.state = 'running';
    carouselLoop(carousel.runId).catch(function (error) {
      console.error('[Carousel] erreur :', error);
    });
  }

  function carouselStop(report) {
    carousel.runId++;
    carouselClearTimers();
    // Pas de `cancel()` : une éventuelle animation en cours va à son terme.
    carousel.animation = null;
    carousel.state = 'stopped';
    carousel.currentIndex = -1;
    if (report) carouselReport();
  }

  // Pause sur interaction : le SDK n'émet aucun événement "caméra
  // déplacée par l'utilisateur" et un glisser n'interrompt pas une
  // animation SDK en cours -- on écoute donc soi-même les pointeurs sur
  // le conteneur de la carte (phase de capture, avant le SDK). Chaque
  // interaction pendant la pause relance le délai de reprise de 10 s.
  // Listeners posés une seule fois sur le conteneur de la page (il survit
  // aux rechargements de carte).
  function carouselOnUserInput(event) {
    if (carousel.state === 'stopped') return;
    if (event.type === 'pointermove' && !event.buttons) return;
    if (carousel.state === 'running') {
      carousel.runId++;
      carouselClearTimers();
      carouselInterruptInPlace();
      carousel.state = 'paused';
      console.log('[Carousel] paused by ' + event.type);
      carouselReport();
    }
    if (carousel.resumeTimer) clearTimeout(carousel.resumeTimer);
    carousel.resumeTimer = setTimeout(function () {
      carousel.resumeTimer = null;
      if (carousel.state !== 'paused') return;
      console.log('[Carousel] resume');
      carouselRun();
    }, CAROUSEL_RESUME_DELAY_MS);
  }
  ['pointerdown', 'pointermove', 'pointerup', 'pointercancel', 'wheel'].forEach(function (type) {
    core.container.addEventListener(type, carouselOnUserInput, { capture: true, passive: true });
  });

  // Rechargement de carte : la visite s'arrête (et le natif en est informé
  // si elle tournait).
  core.onReset(function () {
    carouselStop(carousel.state !== 'stopped');
  });

  core.register({
    // Démarre la visite (depuis le premier arrêt) sur `poiIds`, dans
    // l'ordre, en boucle. L'état est renvoyé à chaque arrêt, pause, reprise
    // et arrêt -- y compris quand le changement vient d'un toucher sur la
    // carte ou du minuteur de reprise, pas du natif.
    startCarousel: function (poiIds) {
      if (!core.venue || !core.view || !poiIds || !poiIds.length) return;
      carouselStop(false);
      carousel.stops = poiIds.slice();
      carousel.nextIndex = 0;
      carouselRun();
    },

    // Arrête la visite : plus aucun arrêt n'est programmé. Choix de
    // conception : l'animation en cours, s'il y en a une, est laissée
    // aller à son terme (pas de `cancel()`), la caméra finit son trajet
    // vers l'arrêt courant plutôt que de s'immobiliser en plein vol.
    stopCarousel: function () {
      carouselStop(true);
    },
  });
})(window.MapCore);
