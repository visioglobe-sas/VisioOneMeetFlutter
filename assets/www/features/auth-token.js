// auth-token : remplace le jeton d'autorisation d'une venue déjà chargée
// (`venue.setAuthorizationToken`). Le jeton initial est passé à `setup`
// (bridge/core.js, option `authorizationToken` de `loadVenue`). Code
// d'exemple seulement : l'app n'a aucune carte protégée à charger (voir
// lib/features/auth-token/auth_token_sample.dart et docs/features/auth-token.md).
(function (core) {
  core.register({
    // À appeler AVANT l'expiration du jeton courant, sans recharger la carte.
    setAuthorizationToken: function (freshToken) {
      var venue = core.venue;
      if (!venue) {
        console.warn('[MapBridge] setAuthorizationToken: aucune venue chargée');
        return;
      }
      try {
        venue.setAuthorizationToken(freshToken);
        // Un rechargement ultérieur (ex. changement de projection) doit
        // repartir du jeton frais, pas de celui passé à `setup`.
        if (core.lastSetup) core.lastSetup.authorizationToken = freshToken;
        console.log('[MapBridge] setAuthorizationToken OK');
      } catch (error) {
        console.error('[MapBridge] setAuthorizationToken a échoué:', error);
      }
    },
  });
})(window.MapCore);
